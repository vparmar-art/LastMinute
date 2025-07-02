from django.urls import re_path
from . import consumers

user_ws_patterns = [
    re_path(r'^ws/users/partner/(?P<partner_id>\d+)/location/$', consumers.PartnerLocationConsumer.as_asgi()),
]