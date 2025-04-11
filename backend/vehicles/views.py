from rest_framework.views import APIView
from rest_framework.response import Response
from .models import VehicleType
from .serializers import VehicleTypeSerializer

class VehicleTypeListView(APIView):
    def get(self, request):
        vehicles = VehicleType.objects.filter(is_active=True)
        serializer = VehicleTypeSerializer(vehicles, many=True, context={'request': request})
        return Response(serializer.data)