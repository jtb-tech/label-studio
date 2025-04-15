from rest_framework_api_key.models import APIKey
from users.models import User

# 假設你已有用戶
user = User.objects.get(email='你的用戶電子郵件')

# 生成 API Key
api_key, key = APIKey.objects.create_key(name="default", user=user)
print(f"API Key: {key}")
