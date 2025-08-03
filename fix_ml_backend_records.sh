#!/bin/bash
# fix_ml_backend_records.sh
# 修復 Label Studio 數據庫中的 ML Backend 記錄

DB_PATH="/home/yillkid/.local/share/label-studio/label_studio.sqlite3"

echo "🔧 修復 ML Backend 記錄..."

# 1. 顯示當前的 ML Backend 記錄
echo "📋 當前的 ML Backend 記錄："
sqlite3 "$DB_PATH" <<EOF
.headers on
.mode column
SELECT id, state, url, title, project_id, created_at FROM ml_mlbackend ORDER BY id;
EOF

# 2. 停止 Docker Label Studio
echo -e "\n⏹️ 停止 Docker Label Studio..."
docker stop jtbtech-label-studio 2>/dev/null || echo "容器未運行"

# 3. 清理舊的 ML Backend 記錄
echo -e "\n🧹 清理舊的 ML Backend 記錄..."

# 清理指向錯誤 IP (.78) 的記錄
sqlite3 "$DB_PATH" <<EOF
-- 顯示要刪除的記錄
SELECT '要刪除的記錄:' as info;
SELECT id, state, url, project_id FROM ml_mlbackend WHERE url LIKE '%140.127.196.78%';

-- 清理相關的訓練任務
DELETE FROM ml_mlbackendtrainjob 
WHERE ml_backend_id IN (
    SELECT id FROM ml_mlbackend WHERE url LIKE '%140.127.196.78%'
);

-- 清理相關的預測任務
DELETE FROM ml_mlbackendpredictionjob 
WHERE ml_backend_id IN (
    SELECT id FROM ml_mlbackend WHERE url LIKE '%140.127.196.78%'
);

-- 刪除舊的 ML Backend 記錄
DELETE FROM ml_mlbackend WHERE url LIKE '%140.127.196.78%';

-- 同時清理任何指向 .91:9090 但狀態為 DI 的記錄
DELETE FROM ml_mlbackendtrainjob 
WHERE ml_backend_id IN (
    SELECT id FROM ml_mlbackend WHERE url LIKE '%140.127.196.91%' AND state = 'DI'
);

DELETE FROM ml_mlbackendpredictionjob 
WHERE ml_backend_id IN (
    SELECT id FROM ml_mlbackend WHERE url LIKE '%140.127.196.91%' AND state = 'DI'
);

DELETE FROM ml_mlbackend WHERE url LIKE '%140.127.196.91%' AND state = 'DI';
EOF

# 4. 顯示清理後的狀態
echo -e "\n📊 清理後的 ML Backend 記錄："
sqlite3 "$DB_PATH" <<EOF
.headers on
.mode column
SELECT id, state, url, title, project_id FROM ml_mlbackend ORDER BY id;
EOF

# 5. 檢查是否還有孤立的任務引用
echo -e "\n🔍 檢查孤立的任務引用..."
sqlite3 "$DB_PATH" <<EOF
-- 檢查是否有任務表中的 ml_backend_id 字段（如果存在）
.schema task
EOF

# 6. 重新啟動 Docker Label Studio
echo -e "\n🚀 重新啟動 Docker Label Studio..."
docker start jtbtech-label-studio

echo "⏳ 等待容器啟動..."
sleep 10

# 7. 測試服務狀態
echo -e "\n🧪 測試服務狀態..."
if curl -s --max-time 5 http://localhost:8080/api/health/ > /dev/null; then
    echo "✅ Docker Label Studio 啟動成功"
else
    echo "⚠️ Docker Label Studio 可能還在啟動中"
fi

if curl -s --max-time 5 http://localhost:9090/health > /dev/null; then
    echo "✅ SAM ML Backend 運行正常"
    
    # 獲取 SAM Backend 的內部 IP
    SAM_IP=$(docker inspect sam-ml-backend 2>/dev/null | jq -r '.[0].NetworkSettings.IPAddress' || echo "172.17.0.2")
    echo "🔗 SAM Backend 內部 IP: $SAM_IP"
else
    echo "❌ SAM ML Backend 無響應"
fi

echo -e "\n🎉 清理完成！"
echo ""
echo "📋 下一步操作："
echo "1. 打開 http://140.127.196.91:8080/projects/231/settings/ml"
echo "2. 添加新的 ML Backend："
echo "   URL: http://172.17.0.2:9090"
echo "   Title: SAM Auto Segmentation"
echo "3. 測試自動標註功能"
echo ""
echo "📊 清理統計："
echo "- 清理了指向 140.127.196.78:9090 的舊記錄"
echo "- 清理了狀態為 DI (Disconnected) 的記錄"
echo "- 清理了相關的訓練和預測任務記錄"
