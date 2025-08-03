#!/bin/bash

# Docker 啟動腳本 - Label Studio
# 完整的停止、刪除、重新啟動流程

echo "🚀 Label Studio Docker 完整重啟腳本..."

# 檢查當前目錄和 Native 數據庫
if [ ! -f "/home/yillkid/.local/share/label-studio/label_studio.sqlite3" ]; then
    echo "❌ 錯誤：找不到 Native Label Studio 數據庫"
    echo "數據庫路徑: /home/yillkid/.local/share/label-studio/label_studio.sqlite3"
    echo "請先運行 Native Label Studio 創建數據庫"
    exit 1
fi

echo "✅ Native 數據庫文件確認存在: $(ls -lah /home/yillkid/.local/share/label-studio/label_studio.sqlite3)"

# 停止並移除現有容器
echo "📦 停止並移除現有容器..."
if docker ps -q -f name=jtbtech-label-studio | grep -q .; then
    echo "   停止容器: jtbtech-label-studio"
    docker stop jtbtech-label-studio
else
    echo "   容器未運行，跳過停止步驟"
fi

if docker ps -aq -f name=jtbtech-label-studio | grep -q .; then
    echo "   移除容器: jtbtech-label-studio"
    docker rm jtbtech-label-studio
else
    echo "   容器不存在，跳過移除步驟"
fi

# 拉取最新鏡像
echo "📥 拉取 Docker 鏡像..."
docker pull yillkid/jtbtech-label-studio:1.31.2

# 修復權限和創建必要目錄
echo "🔧 修復權限和創建目錄..."
mkdir -p data/media mydata/media
chmod -R 755 data/ mydata/

# 啟動容器
echo "🔧 啟動新容器..."
CONTAINER_ID=$(docker run -d \
  --name jtbtech-label-studio \
  --user $(id -u):$(id -g) \
  -p 8080:8080 \
  -v /home/yillkid/.local/share/label-studio:/label-studio/data \
  -v $(pwd)/mydata/media:/label-studio/media \
  -w /label-studio \
  -e DJANGO_SETTINGS_MODULE=core.settings.label_studio \
  -e LABEL_STUDIO_LOCAL_FILES_SERVING_ENABLED=true \
  -e LABEL_STUDIO_LOCAL_FILES_DOCUMENT_ROOT=/label-studio/data \
  yillkid/jtbtech-label-studio:1.31.2 \
  python3 label_studio/manage.py runserver 0.0.0.0:8080)

echo "   容器 ID: ${CONTAINER_ID:0:12}"

# 等待容器啟動
echo "⏳ 等待容器啟動..."
sleep 5

# 驗證數據庫掛載
echo "🔍 驗證數據庫掛載..."
DB_SIZE=$(docker exec jtbtech-label-studio stat -c%s /label-studio/data/label_studio.sqlite3 2>/dev/null || echo "0")
if [ "$DB_SIZE" -gt 1000000 ]; then
    echo "   ✅ 數據庫掛載成功 (大小: $DB_SIZE 字節)"
else
    echo "   ❌ 數據庫掛載失敗或文件為空 (大小: $DB_SIZE 字節)"
    docker logs jtbtech-label-studio | tail -10
    exit 1
fi

# 檢查容器狀態
if docker ps | grep -q jtbtech-label-studio; then
    echo "✅ 容器啟動成功！"
    echo ""
    echo "🌐 Label Studio 服務信息："
    echo "   Web 界面: http://localhost:8080"
    echo "   Web 界面: http://140.127.196.91:8080"
    echo "   API 端點: http://localhost:8080/api/"
    echo ""
    echo "📋 容器資訊："
    docker ps | grep jtbtech-label-studio
    echo ""
    echo "🛠️  管理命令："
    echo "   查看日誌: docker logs -f jtbtech-label-studio"
    echo "   進入容器: docker exec -it jtbtech-label-studio bash"
    echo "   停止服務: docker stop jtbtech-label-studio"
    echo "   完全移除: docker stop jtbtech-label-studio && docker rm jtbtech-label-studio"
    echo ""
    
    # 測試服務響應
    echo "🧪 測試服務響應..."
    sleep 3
    if curl -s --max-time 5 http://localhost:8080 > /dev/null 2>&1; then
        echo "   ✅ Label Studio 響應正常！"
    else
        echo "   ⚠️  服務可能還在啟動中，請稍等片刻或檢查日誌"
        echo "   查看日誌: docker logs jtbtech-label-studio"
    fi
    
else
    echo "❌ 容器啟動失敗！"
    echo ""
    echo "📝 錯誤日誌："
    docker logs jtbtech-label-studio
    echo ""
    echo "🔧 故障排除："
    echo "   1. 檢查端口 8080 是否被佔用: sudo netstat -tlnp | grep 8080"
    echo "   2. 檢查數據庫文件權限: ls -la data/label_studio.sqlite3"
    echo "   3. 查看完整日誌: docker logs jtbtech-label-studio"
    exit 1
fi
