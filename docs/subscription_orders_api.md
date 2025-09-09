# Subscription Order Endpoint Proposal

This document specifies the API contract and reference backend implementation to accept subscription order placements from the customer app. It also outlines data storage and daily order generation strategy.

## Endpoint
- Method: `POST`
- URL: `/api/subscription-orders/`
- Auth: Token (customer context)

## Request Body
- `outlet_id` (int): Target outlet.
- `subscription_id` (int): Subscription identifier (must belong to `outlet_id`).
- `subscription_detail` (array): List of objects `{date: YYYY-MM-DD, qty: int}`; `qty=0` means skip.
- `time_slot` (string): Window label in `"HH:MM - HH:MM"`. Must match the slot duration and fall within `ProductSubscriptionConfig.window_start_override` and `window_end_override`. Duration must equal `slot_minutes_override`.
- `address_id` (int): Selected address id; validated to belong to the subscription customer. An address snapshot is stored on placement.
- `subtotal` (decimal string)
- `discount` (decimal string)
- `delivery_charges` (decimal string)
- `net_total` (decimal string) Must equal `subtotal - discount + delivery_charges`.

Example:
```
POST /api/subscription-orders/
Authorization: Token <token>
Content-Type: application/json

{
  "outlet_id": 12,
  "subscription_id": 345,
  "subscription_detail": [
    {"date": "2025-09-10", "qty": 2},
    {"date": "2025-09-11", "qty": 0},
    {"date": "2025-09-12", "qty": 1}
  ],
  "time_slot": "13:00 - 13:30",
  "address_id": 987,
  "subtotal": "300.00",
  "discount": "20.00",
  "delivery_charges": "30.00",
  "net_total": "310.00"
}
```

## Response
```
201 Created
{
  "id": 101,
  "subscription_id": 345,
  "outlet_id": 12,
  "time_slot": "13:00 - 13:30",
  "created_at": "2025-09-08T07:01:23Z"
}
```

## Storage Model
- Keep `Subscription` unchanged (no defaults). Two new models:
  - `SubscriptionDay`: One row per (subscription, date) with `qty` and the explicit `time_slot` captured for that placement cycle.
  - `SubscriptionOrder`: Immutable placement snapshot with the submitted per-day schedule, time slot, address snapshot, and pricing breakdown.

## Daily Order Generation
- Generate a new `Order` each day from `SubscriptionDay` where `date=today`, `qty>0`, and `order` is null.
- Copy `time_slot_start/end` from `SubscriptionDay` and current pricing/product for that day; link created order back to `SubscriptionDay.order`.
- Run via Celery Beat or cron; command example included in `server_proposal/subscriptions/management/commands/generate_subscription_orders.py`.

## Validation Logic
- `time_slot` must have format `HH:MM - HH:MM`.
- Slot duration must equal `ProductSubscriptionConfig.slot_minutes_override` and the start/end must be within the override window.
- `address_id` must belong to the subscription's customer.
- Monetary fields must be consistent: `net_total == subtotal - discount + delivery_charges`.

## Implementation Notes
- Adjust import paths (app labels) to your project (`outlets`, `orders`, `accounts`, `catalog`).
- Uses `models.JSONField` (Django >= 3.1). On older Django, use `django.contrib.postgres.fields.JSONField`.
- Consider adding an optional `idempotency_key` request field and enforce uniqueness for safe retries.

