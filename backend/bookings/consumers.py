import json
from channels.generic.websocket import AsyncWebsocketConsumer
from bookings.models import Booking
from bookings.serializers import BookingSerializer
from users.serializers import PartnerSerializer
import asyncio

class BookingConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.booking_id = self.scope['url_route']['kwargs']['booking_id']
        self.group_name = f'booking_{self.booking_id}'
        self.send_task = None

        await self.channel_layer.group_add(
            self.group_name,
            self.channel_name
        )
        await self.accept()
        
        self.send_task = asyncio.create_task(self.send_booking_periodically())

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(
            self.group_name,
            self.channel_name
        )
        if self.send_task:
            self.send_task.cancel()

    async def receive(self, text_data):
        pass

    async def send_booking_update(self, event):
        booking_data = event.get('booking_data')
        if booking_data:
            await self.send(text_data=json.dumps(booking_data))
        else:
            await self.send(text_data=json.dumps({'error': 'No booking data provided'}))


    async def send_booking_periodically(self):
        while True:
            try:
                booking = await asyncio.to_thread(Booking.objects.get, id=self.booking_id)
                data = await asyncio.to_thread(serialize_booking_with_partner, booking)
                await self.send(text_data=json.dumps(data))
                await asyncio.sleep(5)
            except Booking.DoesNotExist:
                await self.send(text_data=json.dumps({'error': 'Booking not found'}))
                break
            except asyncio.CancelledError:
                break

def serialize_booking_with_partner(booking):
    data = BookingSerializer(booking).data
    data['partner_details'] = PartnerSerializer(booking.partner).data if booking.partner else None
    return data