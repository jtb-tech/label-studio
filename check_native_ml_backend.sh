#!/bin/bash
# check_native_ml_backend.sh
# 檢查 native Label Studio 環境中的 ML Backend 配置和版本

echo "🔍 檢查 Native Label Studio ML Backend 配置..."

# 1. 檢查 Label Studio 安裝位置和版本
echo "=== Label Studio 版本資訊 ==="
which label-studio
label-studio version 2>/dev/null || echo "無法獲取版本資訊"

# 2. 檢查 Python 環境中的相關套件
echo -e "\n=== Python 套件版本 ==="
pip list | grep -E "(label-studio|ml)" || echo "未找到相關套件"

# 3. 檢查 Label Studio 配置目錄
echo -e "\n=== Label Studio 配置目錄 ==="
LS_CONFIG_DIR="/home/yillkid/.local/share/label-studio"
if [ -d "$LS_CONFIG_DIR" ]; then
    echo "配置目錄: $LS_CONFIG_DIR"
    ls -la "$LS_CONFIG_DIR"
    
    # 檢查是否有 ML Backend 相關配置
    find "$LS_CONFIG_DIR" -name "*ml*" -o -name "*backend*" 2>/dev/null
else
    echo "配置目錄不存在"
fi

# 4. 檢查當前目錄中的 ML Backend
echo -e "\n=== 當前目錄 ML Backend 檢查 ==="
pwd
find . -name "*ml*" -o -name "*backend*" -type f 2>/dev/null | head -10

# 5. 檢查是否有運行中的 ML Backend 進程
echo -e "\n=== 運行中的相關進程 ==="
ps aux | grep -E "(ml|backend|sam)" | grep -v grep || echo "無相關進程"

# 6. 檢查網路端口使用情況
echo -e "\n=== 端口使用情況 ==="
netstat -tlnp 2>/dev/null | grep -E "(8080|9090)" || lsof -i :8080,9090 2>/dev/null || echo "無相關端口在使用"

# 7. 檢查 Label Studio 數據庫中的 ML Backend 記錄
echo -e "\n=== 數據庫中的 ML Backend 記錄 ==="
DB_PATH="/home/yillkid/.local/share/label-studio/label_studio.sqlite3"
if [ -f "$DB_PATH" ]; then
    sqlite3 "$DB_PATH" "SELECT id, url, title, created_at FROM ml_backend ORDER BY created_at DESC;" 2>/dev/null || echo "無法讀取數據庫"
else
    echo "數據庫文件不存在"
fi

# 8. 檢查 requirements 或 poetry 文件
echo -e "\n=== 依賴文件檢查 ==="
find . -name "requirements*.txt" -o -name "pyproject.toml" -o -name "Pipfile" | while read file; do
    echo "文件: $file"
    grep -E "(label-studio|ml)" "$file" 2>/dev/null || echo "  無相關依賴"
done

# 9. 檢查是否有本地 ML Backend 腳本
echo -e "\n=== 本地 ML Backend 腳本 ==="
find . -name "*.py" -exec grep -l "LabelStudioMLBase\|ml.*backend" {} \; 2>/dev/null | head -5

# 10. 檢查 Label Studio 啟動日誌（如果有）
echo -e "\n=== 最近的日誌檢查 ==="
if [ -d "$LS_CONFIG_DIR/logs" ]; then
    echo "日誌目錄存在"
    ls -lt "$LS_CONFIG_DIR/logs/" | head -3
    
    # 檢查最新日誌中的 ML Backend 相關資訊
    latest_log=$(ls -t "$LS_CONFIG_DIR/logs/"*.log 2>/dev/null | head -1)
    if [ ! -z "$latest_log" ]; then
        echo "最新日誌: $latest_log"
        grep -i "ml\|backend" "$latest_log" | tail -5 2>/dev/null || echo "日誌中無相關資訊"
    fi
else
    echo "無日誌目錄"
fi

echo -e "\n✅ 檢查完成！"
