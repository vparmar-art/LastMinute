import json
from channels.generic.websocket import AsyncWebsocketConsumer
from asgiref.sync import sync_to_async
from users.utils import update_partner_location
from bookings.models import Booking
from bookings.serializers import BookingSerializer
from users.serializers import PartnerSerializer

class PartnerLocationConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.partner_id = self.scope['url_route']['kwargs']['partner_id']
        self.group_name = f'partner_{self.partner_id}'
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def receive(self, text_data):
        data = json.loads(text_data)
        latitude = data.get('lat')
        longitude = data.get('lng')

        if latitude is not None and longitude is not None:
            await sync_to_async(update_partner_location)(self.partner_id, latitude, longitude)

            await self.channel_layer.group_send(
                self.group_name,
                {
                    'type': 'location.update',
                    'lat': latitude,
                    'lng': longitude,
                }
            )

    async def location_update(self, event):
        await self.send(text_data=json.dumps({
            'lat': event['lat'],
            'lng': event['lng'],
        }))