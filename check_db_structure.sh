#!/bin/bash
# check_db_structure.sh
# 檢查 Label Studio 數據庫的實際結構

DB_PATH="/home/yillkid/.local/share/label-studio/label_studio.sqlite3"

echo "🔍 檢查 Label Studio 數據庫結構..."

# 1. 檢查數據庫文件是否存在且可讀
if [ ! -f "$DB_PATH" ]; then
    echo "❌ 數據庫文件不存在: $DB_PATH"
    exit 1
fi

echo "✅ 數據庫文件存在: $(ls -lh $DB_PATH)"

# 2. 檢查數據庫是否被鎖定
echo -e "\n🔐 檢查數據庫鎖定狀態..."
if ! sqlite3 "$DB_PATH" "SELECT 1;" 2>/dev/null; then
    echo "❌ 數據庫被鎖定或無法訪問"
    echo "可能原因："
    echo "- Native Label Studio 正在運行"
    echo "- 文件權限問題"
    echo "- 數據庫損壞"
    
    # 檢查是否有 Label Studio 進程
    echo -e "\n檢查運行中的 Label Studio 進程："
    ps aux | grep "label_studio\|label-studio" | grep -v grep || echo "無運行中的進程"
    
    exit 1
fi

echo "✅ 數據庫可以訪問"

# 3. 列出所有表
echo -e "\n📋 數據庫中的所有表:"
sqlite3 "$DB_PATH" ".tables"

# 4. 檢查是否有 ML 相關的表
echo -e "\n🤖 ML 相關的表結構:"
for table in $(sqlite3 "$DB_PATH" ".tables" | tr ' ' '\n' | grep -i ml); do
    echo "=== 表: $table ==="
    sqlite3 "$DB_PATH" ".schema $table"
    echo ""
done

# 5. 檢查 task 表結構（如果存在）
echo -e "\n📝 Task 表結構:"
if sqlite3 "$DB_PATH" ".tables" | grep -q task; then
    sqlite3 "$DB_PATH" ".schema task"
else
    echo "❌ 未找到 task 表"
fi

# 6. 檢查項目表結構
echo -e "\n📁 Project 相關表:"
for table in $(sqlite3 "$DB_PATH" ".tables" | tr ' ' '\n' | grep -i project); do
    echo "=== 表: $table ==="
    sqlite3 "$DB_PATH" ".schema $table"
    echo ""
done

# 7. 檢查是否有任何 ML Backend 相關數據
echo -e "\n🔍 搜索 ML Backend 相關數據:"
sqlite3 "$DB_PATH" <<EOF
.headers on
.mode column

-- 搜索可能包含 ML Backend 信息的表
SELECT name FROM sqlite_master WHERE type='table' AND (
    name LIKE '%ml%' OR 
    name LIKE '%backend%' OR 
    name LIKE '%model%' OR
    name LIKE '%prediction%'
);
EOF

# 8. 如果找到相關表，顯示內容
echo -e "\n📊 ML 相關表的內容:"
for table in $(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND (name LIKE '%ml%' OR name LIKE '%backend%' OR name LIKE '%model%' OR name LIKE '%prediction%');" | head -5); do
    echo "=== 表 $table 的內容 ==="
    sqlite3 "$DB_PATH" "SELECT * FROM $table LIMIT 5;" 2>/dev/null || echo "無法讀取表內容"
    echo ""
done

echo "✅ 數據庫結構檢查完成！"
