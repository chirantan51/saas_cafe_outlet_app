from datetime import datetime

from django.utils.dateparse import parse_time
from rest_framework import serializers


class SubscriptionOrderCreateSerializer(serializers.Serializer):
    """Validates and creates a SubscriptionOrder placement, upserting SubscriptionDay rows."""
    outlet_id = serializers.PrimaryKeyRelatedField(source='outlet', queryset=None)
    subscription_id = serializers.PrimaryKeyRelatedField(source='subscription', queryset=None)
    address_id = serializers.PrimaryKeyRelatedField(source='address', queryset=None)

    subscription_detail = serializers.ListSerializer(
        child=serializers.DictField(child=serializers.CharField()), allow_empty=False
    )
    time_slot = serializers.CharField(max_length=32)  # "HH:MM - HH:MM"

    subtotal = serializers.DecimalField(max_digits=10, decimal_places=2)
    discount = serializers.DecimalField(max_digits=10, decimal_places=2)
    delivery_charges = serializers.DecimalField(max_digits=10, decimal_places=2)
    net_total = serializers.DecimalField(max_digits=10, decimal_places=2)

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        # Lazy import of app models to avoid hard-coding app labels here.
        from django.apps import apps
        self.fields['outlet_id'].queryset = apps.get_model('outlets', 'Outlet').objects.all()
        self.fields['subscription_id'].queryset = apps.get_model('subscriptions', 'Subscription').objects.all()
        self.fields['address_id'].queryset = apps.get_model('accounts', 'Address').objects.all()

        self.SubscriptionDay = apps.get_model('subscriptions', 'SubscriptionDay')
        self.SubscriptionOrder = apps.get_model('subscriptions', 'SubscriptionOrder')
        self.Product = apps.get_model('catalog', 'Product')
        self.ProductSubscriptionConfig = apps.get_model('subscriptions', 'ProductSubscriptionConfig')

    def _parse_time_slot(self, s: str):
        # Expect "HH:MM - HH:MM"
        try:
            parts = [p.strip() for p in s.split('-')]
            if len(parts) != 2:
                raise ValueError
            start = parse_time(parts[0])
            end = parse_time(parts[1])
            if not start or not end:
                raise ValueError
            return start, end
        except Exception:
            raise serializers.ValidationError({'time_slot': 'Invalid format. Use "HH:MM - HH:MM".'})

    def validate(self, attrs):
        subscription = attrs['subscription']
        outlet = attrs['outlet']
        address = attrs['address']

        # parse time slot
        start, end = self._parse_time_slot(self.initial_data.get('time_slot'))

        # product config validation
        product = getattr(subscription, 'product', None)
        if product is None:
            raise serializers.ValidationError('Subscription is missing product relation.')

        config = getattr(product, 'subscription_config', None)
        if not config or not (config.window_start_override and config.window_end_override and config.slot_minutes_override):
            raise serializers.ValidationError('ProductSubscriptionConfig overrides are required for this product.')

        # slot length check
        delta_minutes = (datetime.combine(datetime.today(), end) -
                         datetime.combine(datetime.today(), start)).total_seconds() / 60.0
        if delta_minutes <= 0:
            raise serializers.ValidationError({'time_slot': 'End time must be after start time.'})
        if int(delta_minutes) != int(config.slot_minutes_override):
            raise serializers.ValidationError({'time_slot': f'Slot must be exactly {config.slot_minutes_override} minutes.'})

        # within window
        if not (config.window_start_override <= start and end <= config.window_end_override):
            raise serializers.ValidationError({'time_slot': 'Slot must be within allowed override window.'})

        # outlet match
        if getattr(subscription, 'outlet_id', None) != outlet.id:
            raise serializers.ValidationError('Subscription does not belong to the given outlet.')

        # address belongs to customer
        if getattr(address, 'user_id', None) != getattr(subscription, 'customer_id', None):
            raise serializers.ValidationError({'address_id': 'Address does not belong to the subscription customer.'})

        # money consistency
        calc_net = attrs['subtotal'] - attrs['discount'] + attrs['delivery_charges']
        if calc_net != attrs['net_total']:
            raise serializers.ValidationError({'net_total': 'Does not match subtotal - discount + delivery_charges.'})

        # Validate detail items
        normalized_detail = []
        for idx, item in enumerate(self.initial_data.get('subscription_detail', [])):
            if not isinstance(item, dict):
                raise serializers.ValidationError({'subscription_detail': f'Item {idx} must be an object.'})
            date = item.get('date')
            qty = item.get('qty')
            if not date:
                raise serializers.ValidationError({'subscription_detail': f'Item {idx} missing date.'})
            try:
                # Let DRF DateField do final coercion later; here we just sanity-check
                normalized_detail.append({'date': date, 'qty': int(qty)})
            except Exception:
                raise serializers.ValidationError({'subscription_detail': f'Item {idx} has invalid qty.'})

        attrs['_slot_start'] = start
        attrs['_slot_end'] = end
        attrs['_slot_label'] = self.initial_data.get('time_slot')
        attrs['_normalized_detail'] = normalized_detail
        return attrs

    def create(self, validated_data):
        subscription = validated_data['subscription']
        outlet = validated_data['outlet']
        address = validated_data['address']
        detail = validated_data['_normalized_detail']

        # address snapshot (adjust to your Address fields)
        address_snapshot = {
            'line1': getattr(address, 'line1', ''),
            'line2': getattr(address, 'line2', ''),
            'city': getattr(address, 'city', ''),
            'state': getattr(address, 'state', ''),
            'postcode': getattr(address, 'postcode', ''),
            'phone': getattr(address, 'phone', ''),
            'label': getattr(address, 'label', ''),
        }

        placement = self.SubscriptionOrder.objects.create(
            subscription=subscription,
            outlet=outlet,
            address=address,
            address_snapshot=address_snapshot,
            time_slot_start=validated_data['_slot_start'],
            time_slot_end=validated_data['_slot_end'],
            time_slot_label=validated_data['_slot_label'],
            detail=detail,
            subtotal=validated_data['subtotal'],
            discount=validated_data['discount'],
            delivery_charges=validated_data['delivery_charges'],
            net_total=validated_data['net_total'],
        )

        # Upsert SubscriptionDay rows for these dates
        for item in detail:
            self.SubscriptionDay.objects.update_or_create(
                subscription=subscription,
                date=item['date'],
                defaults={
                    'qty': item['qty'],
                    'time_slot_start': validated_data['_slot_start'],
                    'time_slot_end': validated_data['_slot_end'],
                }
            )

        return placement

