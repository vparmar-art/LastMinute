from django.urls import re_path
from . import consumers

booking_ws_patterns = [
    re_path(r'^ws/bookings/(?P<booking_id>\d+)/$', consumers.BookingConsumer.as_asgi()),
]
