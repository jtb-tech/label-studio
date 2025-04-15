# create_superuser.py

import os
import django
from django.contrib.auth import get_user_model

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings.label_studio')
django.setup()

User = get_user_model()
email = 'yillkid@gmail.com'
password = '2ulidgoo'  # Replace with a strong password

if not User.objects.filter(email=email).exists():
    User.objects.create_superuser(email=email, password=password)
    print(f'Superuser {email} created successfully.')
else:
    print(f'Superuser {email} already exists.')

