from storages.backends.s3boto3 import S3Boto3Storage
from django.conf import settings
from botocore.exceptions import ClientError


class MediaStorage(S3Boto3Storage):
    """
    Storage backend for user-uploaded media files such as partner selfies.

    Uses the dedicated media bucket so uploads are written directly to S3.
    """

    bucket_name = settings.AWS_MEDIA_BUCKET_NAME
    custom_domain = getattr(settings, "AWS_MEDIA_CUSTOM_DOMAIN", None)
    default_acl = None
    file_overwrite = False

    def __init__(self, *args, **kwargs):
        if self.custom_domain is None:
            self.custom_domain = f"{self.bucket_name}.s3.amazonaws.com"
        super().__init__(*args, **kwargs)

    def exists(self, name):
        try:
            return super().exists(name)
        except ClientError as err:
            response = getattr(err, "response", {})
            metadata = response.get("ResponseMetadata", {})
            status_code = metadata.get("HTTPStatusCode")
            error_code = response.get("Error", {}).get("Code")
            if status_code in (400, 403) or error_code in ("BadRequest", "AuthorizationHeaderMalformed"):
                return False
            raise

