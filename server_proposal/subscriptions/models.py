from django.db import models
from uuid import uuid4


class Subscription(models.Model):
    """
    Placeholder for your existing Subscription model.
    In your project this already exists; do not duplicate. This class is here
    only to make references readable in this isolated proposal.
    Remove this shim when integrating.
    """
    class Meta:
        abstract = True


class SubscriptionDay(models.Model):
    """One row per (subscription, date) with explicit qty and time slot."""
    subscription = models.ForeignKey(
        'subscriptions.Subscription', on_delete=models.CASCADE, related_name='days'
    )
    date = models.DateField()
    qty = models.PositiveIntegerField(default=0)  # 0 = skip
    time_slot_start = models.TimeField(null=True, blank=True)
    time_slot_end = models.TimeField(null=True, blank=True)
    order = models.ForeignKey(
        'orders.Order', null=True, blank=True, on_delete=models.SET_NULL, related_name='subscription_day'
    )

    class Meta:
        unique_together = ('subscription', 'date')
        indexes = [
            models.Index(fields=['date']),
            models.Index(fields=['subscription', 'date']),
        ]


class SubscriptionOrder(models.Model):
    """
    Immutable placement snapshot capturing: per-day schedule, selected time slot,
    address snapshot, and pricing breakdown.
    """
    id = models.BigAutoField(primary_key=True)
    idempotency_key = models.UUIDField(default=uuid4, unique=True, editable=False)

    subscription = models.ForeignKey(
        'subscriptions.Subscription', on_delete=models.CASCADE, related_name='placements'
    )
    outlet = models.ForeignKey(
        'outlets.Outlet', on_delete=models.CASCADE, related_name='subscription_orders'
    )

    # Address (FK + immutable snapshot)
    address = models.ForeignKey(
        'accounts.Address', on_delete=models.PROTECT, related_name='subscription_orders'
    )
    address_snapshot = models.JSONField(default=dict)  # requires Django >=3.1

    # Selected time slot
    time_slot_start = models.TimeField()
    time_slot_end = models.TimeField()
    time_slot_label = models.CharField(max_length=32)  # e.g., "13:00 - 13:30"

    # Client-submitted per-day schedule snapshot
    detail = models.JSONField()  # [{date: 'YYYY-MM-DD', qty: int}]

    # Pricing snapshot
    subtotal = models.DecimalField(max_digits=10, decimal_places=2)
    discount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    delivery_charges = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    net_total = models.DecimalField(max_digits=10, decimal_places=2)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            models.Index(fields=['created_at']),
            models.Index(fields=['outlet', 'created_at']),
        ]

