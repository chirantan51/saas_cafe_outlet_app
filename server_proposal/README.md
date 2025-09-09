This folder contains a reference Django implementation for the Subscription Order endpoint that the customer app will call.

Files:
- `subscriptions/models.py` — Data models `SubscriptionDay` and `SubscriptionOrder`.
- `subscriptions/serializers.py` — Request validation and creation logic, including time-slot checks against `ProductSubscriptionConfig`.
- `subscriptions/views.py` — API view for `POST /api/subscription-orders/`.
- `subscriptions/urls.py` — URLConf to include under your root `api/`.
- `subscriptions/management/commands/generate_subscription_orders.py` — Daily generator for orders from scheduled subscription days.

Integration steps:
1) Copy this module into your backend project; fix import paths for your app labels (accounts/outlets/orders/catalog).
2) Create migrations for new models.
3) Include `path('api/', include('subscriptions.urls'))` in your root urls.
4) Schedule the management command via Celery Beat or cron.

