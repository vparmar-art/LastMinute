import json
from channels.generic.websocket import AsyncWebsocketConsumer
from bookings.models import Booking
from bookings.serializers import BookingSerializer
from users.serializers import PartnerSerializer

class BookingConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.booking_id = self.scope['url_route']['kwargs']['booking_id']
        self.group_name = f'booking_{self.booking_id}'


        await self.channel_layer.group_add(
            self.group_name,
            self.channel_name
        )
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(
            self.group_name,
            self.channel_name
        )

    async def receive(self, text_data):
        pass

    async def send_booking_update(self, event):
        booking_data = event.get('booking_data')
        if booking_data:
            await self.send(text_data=json.dumps(booking_data))
        else:
            await self.send(text_data=json.dumps({'error': 'No booking data provided'}))