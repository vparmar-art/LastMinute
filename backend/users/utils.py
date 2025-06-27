from django.contrib.gis.geos import Point
from users.models import Partner

def update_partner_location(partner_id, latitude, longitude):
    try:
        partner = Partner.objects.get(id=partner_id)
    except Partner.DoesNotExist:
        return {'error': 'Partner not found'}

    if not partner.is_live:
        return {'skipped': True, 'reason': 'Partner is not live'}

    new_point = Point(float(longitude), float(latitude))

    if partner.current_location:
        old_point = partner.current_location
        if new_point.distance(old_point) < 0.0001:
            return {'skipped': True, 'reason': 'Coordinates unchanged'}

    partner.current_location = new_point
    partner.save(update_fields=['current_location'])
    return {'updated': True}
