import os
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "main.settings")

import django
django.setup()

from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack
from django.core.asgi import get_asgi_application
from django.urls import re_path
import users.routing
import bookings.routing

application = ProtocolTypeRouter({
    "http": get_asgi_application(),
    "websocket": AuthMiddlewareStack(
        URLRouter(users.routing.user_ws_patterns + bookings.routing.booking_ws_patterns)
    ),
})