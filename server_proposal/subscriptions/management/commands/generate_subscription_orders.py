from django.core.management import BaseCommand
from django.utils import timezone
from django.apps import apps


class Command(BaseCommand):
    help = 'Generate daily orders from active subscriptions for today.'

    def handle(self, *args, **options):
        SubscriptionDay = apps.get_model('subscriptions', 'SubscriptionDay')
        Subscription = apps.get_model('subscriptions', 'Subscription')
        Order = apps.get_model('orders', 'Order')

        today = timezone.localdate()

        # Filter: only days for today, qty>0, no order yet; subscription active if status field exists
        qs = SubscriptionDay.objects.select_related('subscription').filter(date=today, qty__gt=0, order__isnull=True)
        created = 0
        for day in qs:
            sub = day.subscription
            # If your Subscription has a status field, enforce active-only
            if hasattr(sub, 'status') and getattr(sub, 'status') != 'active':
                continue

            # Build your order fields according to your Order model
            order = Order.objects.create(
                outlet=getattr(sub, 'outlet'),
                customer=getattr(sub, 'customer', None),
                # Example fields; adjust to your schema
                time_slot_start=day.time_slot_start,
                time_slot_end=day.time_slot_end,
                notes='Generated from subscription',
            )
            day.order = order
            day.save(update_fields=['order'])
            created += 1

        self.stdout.write(self.style.SUCCESS(f'Created {created} subscription orders for {today}'))

