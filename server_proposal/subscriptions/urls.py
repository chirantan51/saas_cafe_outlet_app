from django.urls import path
from .views import SubscriptionOrderCreateView

urlpatterns = [
    path('subscription-orders/', SubscriptionOrderCreateView.as_view(), name='subscription-order-create'),
]

