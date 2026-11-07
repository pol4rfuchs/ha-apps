"""Creates the first superuser. Run with: manage.py shell --no-startup --no-imports --interface python < this file.

Input (environment): HA_ADMIN_USERNAME, HA_ADMIN_PASSWORD (never empty; the caller generates one if the option is
empty), HA_ADMIN_EMAIL (optional).
Output (stdout): HA_ADMIN_STATE=exists or HA_ADMIN_STATE=created. The password is never printed here.
"""
import os

from users.models import User

name = os.environ["HA_ADMIN_USERNAME"]
if User.objects.filter(username=name).exists():
    print("HA_ADMIN_STATE=exists")
else:
    password = os.environ["HA_ADMIN_PASSWORD"]
    if not password:
        raise SystemExit("HA_ADMIN_PASSWORD is empty")
    User.objects.create_superuser(name, os.environ.get("HA_ADMIN_EMAIL", ""), password)
    print("HA_ADMIN_STATE=created")
