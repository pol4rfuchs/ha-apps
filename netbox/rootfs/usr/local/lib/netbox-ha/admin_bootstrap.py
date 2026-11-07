"""Creates the first superuser. Run with: manage.py shell --no-startup --no-imports --interface python < this file.

Input (environment): HA_ADMIN_USERNAME, HA_ADMIN_EMAIL (optional), HA_ADMIN_PASSWORD (empty = generate one).
Output (stdout, one marker per line): HA_ADMIN_STATE=exists|created, and for a generated
password HA_ADMIN_PASSWORD=<password>. The caller decides where the password goes; it is never printed to the log.
"""
import os
import secrets

from users.models import User

name = os.environ["HA_ADMIN_USERNAME"]
if User.objects.filter(username=name).exists():
    print("HA_ADMIN_STATE=exists")
else:
    password = os.environ.get("HA_ADMIN_PASSWORD", "")
    generated = not password
    if generated:
        password = secrets.token_urlsafe(18)
    User.objects.create_superuser(name, os.environ.get("HA_ADMIN_EMAIL", ""), password)
    print("HA_ADMIN_STATE=created")
    if generated:
        print("HA_ADMIN_PASSWORD=" + password)
