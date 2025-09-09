from rest_framework import status
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .serializers import SubscriptionOrderCreateSerializer


class SubscriptionOrderCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, *args, **kwargs):
        serializer = SubscriptionOrderCreateSerializer(data=request.data, context={'request': request})
        serializer.is_valid(raise_exception=True)
        placement = serializer.save()
        return Response({
            'id': placement.id,
            'subscription_id': placement.subscription_id,
            'outlet_id': placement.outlet_id,
            'time_slot': placement.time_slot_label,
            'created_at': placement.created_at,
        }, status=status.HTTP_201_CREATED)

