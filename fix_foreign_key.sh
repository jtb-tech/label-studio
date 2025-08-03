#!/bin/bash
# fix_foreign_key.sh
# 修復 Label Studio 數據庫中的 FOREIGN KEY 約束問題

set -e

DB_PATH="/home/yillkid/.local/share/label-studio/label_studio.sqlite3"

echo "🔧 修復 Label Studio FOREIGN KEY 約束問題..."

# 1. 備份數據庫
echo "📦 備份數據庫..."
cp "$DB_PATH" "${DB_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
echo "✅ 備份完成: ${DB_PATH}.backup.$(date +%Y%m%d_%H%M%S)"

# 2. 停止 Docker Label Studio（避免數據庫鎖定）
echo "⏹️ 停止 Docker Label Studio..."
docker stop jtbtech-label-studio 2>/dev/null || echo "   容器未運行"

# 3. 檢查當前數據庫狀態
echo -e "\n🔍 檢查當前數據庫狀態..."
echo "=== ML Backend 記錄 ==="
sqlite3 "$DB_PATH" "SELECT id, url, title, created_at FROM ml_backend ORDER BY id;" 2>/dev/null || echo "無法讀取 ml_backend 表"

echo -e "\n=== 引用 ML Backend 的任務 ==="
sqlite3 "$DB_PATH" "SELECT COUNT(*) as task_count, ml_backend_id FROM task WHERE ml_backend_id IS NOT NULL GROUP BY ml_backend_id;" 2>/dev/null || echo "無法讀取 task 表"

echo -e "\n=== 預測記錄 ==="
sqlite3 "$DB_PATH" "SELECT COUNT(*) as prediction_count FROM prediction;" 2>/dev/null || echo "無法讀取 prediction 表"

# 4. 清理孤立的 ML Backend 記錄
echo -e "\n🧹 清理數據庫..."

# 檢查是否有 ID 121 的問題記錄
HAS_121=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM ml_backend WHERE id = 121;" 2>/dev/null || echo "0")

if [ "$HAS_121" -gt 0 ]; then
    echo "🎯 發現問題記錄 (ID: 121)，開始清理..."
    
    # 清理引用該 ML Backend 的任務
    echo "   清理任務中的 ML Backend 引用..."
    sqlite3 "$DB_PATH" "UPDATE task SET ml_backend_id = NULL WHERE ml_backend_id = 121;"
    
    # 清理相關的預測記錄
    echo "   清理相關的預測記錄..."
    sqlite3 "$DB_PATH" "DELETE FROM prediction WHERE task_id IN (SELECT id FROM task WHERE ml_backend_id = 121);"
    
    # 刪除問題的 ML Backend 記錄
    echo "   刪除問題的 ML Backend 記錄..."
    sqlite3 "$DB_PATH" "DELETE FROM ml_backend WHERE id = 121;"
    
    echo "✅ 清理完成"
else
    echo "ℹ️ 未發現 ID 121 的問題記錄"
fi

# 5. 清理所有可能的孤立記錄
echo -e "\n🔄 清理其他可能的孤立記錄..."

# 找出所有孤立的 ML Backend 引用
sqlite3 "$DB_PATH" <<EOF
-- 清理任務表中引用不存在的 ML Backend
UPDATE task 
SET ml_backend_id = NULL 
WHERE ml_backend_id IS NOT NULL 
AND ml_backend_id NOT IN (SELECT id FROM ml_backend);

-- 清理預測表中的孤立記錄
DELETE FROM prediction 
WHERE task_id NOT IN (SELECT id FROM task);

-- 如果有其他相關表，也清理
-- DELETE FROM annotation WHERE task_id NOT IN (SELECT id FROM task);
EOF

echo "✅ 孤立記錄清理完成"

# 6. 驗證數據庫完整性
echo -e "\n✅ 驗證數據庫完整性..."
echo "=== 清理後的 ML Backend 記錄 ==="
sqlite3 "$DB_PATH" "SELECT id, url, title FROM ml_backend ORDER BY id;" 2>/dev/null || echo "ml_backend 表為空"

echo -e "\n=== 清理後的任務引用統計 ==="
sqlite3 "$DB_PATH" "SELECT COUNT(*) as tasks_with_ml_backend FROM task WHERE ml_backend_id IS NOT NULL;" 2>/dev/null || echo "無 ML Backend 引用"

# 7. 重新啟動 Docker Label Studio
echo -e "\n🚀 重新啟動 Docker Label Studio..."
docker start jtbtech-label-studio

echo "⏳ 等待容器啟動..."
sleep 10

# 8. 測試服務狀態
echo -e "\n🧪 測試服務狀態..."
if curl -s --max-time 5 http://localhost:8080/api/health/ > /dev/null; then
    echo "✅ Docker Label Studio 啟動成功"
else
    echo "⚠️ Docker Label Studio 可能還在啟動中"
fi

if curl -s --max-time 5 http://localhost:9090/health > /dev/null; then
    echo "✅ SAM ML Backend 運行正常"
else
    echo "❌ SAM ML Backend 無響應"
fi

echo -e "\n🎉 修復完成！"
echo ""
echo "📋 下一步操作："
echo "1. 打開 http://140.127.196.91:8080/projects/231/settings/ml"
echo "2. 添加新的 ML Backend："
echo "   URL: http://172.17.0.2:9090 (或 http://140.127.196.91:9090)"
echo "   Title: SAM Auto Segmentation"
echo "3. 測試自動標註功能"
echo ""
echo "🔧 如果還有問題，檢查日誌："
echo "   docker logs jtbtech-label-studio"
echo "   docker logs sam-ml-backend"
