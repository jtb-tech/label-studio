#!/bin/bash
# diagnose_docker_connectivity.sh
# 診斷 Docker Label Studio 與 ML Backend 的連接問題

echo "🔍 診斷 Docker Label Studio 連接問題..."

# 1. 檢查容器網路配置
echo "=== 容器網路配置 ==="
docker network ls
echo ""
docker inspect jtbtech-label-studio | jq '.[0].NetworkSettings.Networks'
echo ""
docker inspect sam-ml-backend | jq '.[0].NetworkSettings.Networks'

# 2. 檢查數據庫掛載
echo -e "\n=== 數據庫掛載檢查 ==="
echo "Docker 容器內的數據庫："
docker exec jtbtech-label-studio ls -la /label-studio/data/ | head -10

echo -e "\nNative 數據庫："
ls -la /home/yillkid/.local/share/label-studio/

echo -e "\n掛載配置："
docker inspect jtbtech-label-studio | jq '.[0].Mounts'

# 3. 測試網路連接
echo -e "\n=== 網路連接測試 ==="

echo "從 Label Studio 容器連接到 ML Backend（localhost）："
docker exec jtbtech-label-studio curl -s --connect-timeout 5 http://localhost:9090/health || echo "連接失敗"

echo "從 Label Studio 容器連接到 ML Backend（容器名）："
docker exec jtbtech-label-studio curl -s --connect-timeout 5 http://sam-ml-backend:9090/health || echo "連接失敗"

echo "從 Label Studio 容器連接到 ML Backend（host IP）："
HOST_IP=$(docker exec jtbtech-label-studio ip route | grep default | awk '{print $3}')
docker exec jtbtech-label-studio curl -s --connect-timeout 5 http://$HOST_IP:9090/health || echo "連接失敗"

# 4. 檢查容器內的環境變數
echo -e "\n=== 容器環境變數 ==="
docker exec jtbtech-label-studio env | grep -E "(ML|BACKEND|HOST|PORT)" | head -10

# 5. 檢查 Docker Compose 網路設定
echo -e "\n=== Docker Compose 配置 ==="
if [ -f "docker-compose.yml" ] || [ -f "docker-compose.yaml" ]; then
    echo "Docker Compose 文件存在："
    cat docker-compose.y*ml | grep -A 20 -B 5 "jtbtech-label-studio\|sam-ml-backend"
else
    echo "未找到 Docker Compose 文件"
fi

# 6. 檢查 Label Studio 數據庫中的 ML Backend 記錄
echo -e "\n=== 數據庫 ML Backend 記錄 ==="
echo "在 Docker 容器內檢查："
docker exec jtbtech-label-studio sqlite3 /label-studio/data/label_studio.sqlite3 "SELECT id, url, title FROM ml_backend;" 2>/dev/null || echo "無法訪問數據庫"

echo -e "\n在 Host 檢查："
sqlite3 /home/yillkid/.local/share/label-studio/label_studio.sqlite3 "SELECT id, url, title FROM ml_backend;" 2>/dev/null || echo "無法訪問數據庫"

# 7. 檢查端口綁定
echo -e "\n=== 端口綁定檢查 ==="
docker port jtbtech-label-studio
docker port sam-ml-backend

echo -e "\n✅ 診斷完成！"
