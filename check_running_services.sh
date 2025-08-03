#!/bin/bash
# check_running_services.sh
# 檢查當前運行的服務，找出真正的 ML Backend 實現

echo "🔍 檢查當前運行的服務和 ML Backend 實現..."

# 1. 檢查端口 8080 和 9090 上運行的服務
echo "=== 端口 8080 上的服務 ==="
lsof -i :8080 2>/dev/null || netstat -tlnp 2>/dev/null | grep 8080

echo -e "\n=== 端口 9090 上的服務 ==="
lsof -i :9090 2>/dev/null || netstat -tlnp 2>/dev/null | grep 9090

# 2. 檢查所有運行中的 Python 進程
echo -e "\n=== 運行中的 Python 進程 ==="
ps aux | grep python | grep -v grep

# 3. 檢查 Docker 容器狀態
echo -e "\n=== Docker 容器狀態 ==="
docker ps -a 2>/dev/null || echo "Docker 未運行或無權限"

# 4. 測試端口 9090 上的服務
echo -e "\n=== 測試端口 9090 的 ML Backend API ==="
curl -s http://localhost:9090/health 2>/dev/null && echo "健康檢查正常" || echo "健康檢查失敗"
curl -s http://localhost:9090/api/ 2>/dev/null | head -3 && echo "API 端點存在" || echo "API 端點不存在"
curl -s http://localhost:9090/ 2>/dev/null | head -3 && echo "根端點有響應" || echo "根端點無響應"

# 5. 檢查 Label Studio 是否有內建 ML 功能
echo -e "\n=== 檢查 Label Studio 源碼中的 ML 相關功能 ==="
find ./label_studio -name "*.py" -exec grep -l "ml.*backend\|ML.*Backend\|auto.*predict\|predict.*model" {} \; 2>/dev/null | head -5

# 6. 檢查是否有自定義的 ML 相關代碼
echo -e "\n=== 檢查自定義 ML 代碼 ==="
find . -maxdepth 3 -name "*.py" -exec grep -l "SAM\|segment.*anything\|auto.*annot" {} \; 2>/dev/null | grep -v __pycache__ | head -5

# 7. 檢查環境變數中的 ML 配置
echo -e "\n=== 環境變數中的 ML 配置 ==="
env | grep -i -E "(ml|backend|sam|predict|model)" | head -5

# 8. 檢查 Label Studio 啟動腳本或配置
echo -e "\n=== 檢查啟動相關文件 ==="
find . -maxdepth 2 -name "*start*" -o -name "*run*" -o -name "*launch*" | grep -v __pycache__ | head -5

# 9. 檢查最近修改的 Python 文件（可能包含 ML 功能）
echo -e "\n=== 最近修改的 Python 文件 ==="
find . -maxdepth 3 -name "*.py" -mtime -30 2>/dev/null | grep -v __pycache__ | head -5

# 10. 嘗試找到真實的 ML Backend 進程
echo -e "\n=== 尋找可能的 ML Backend 進程 ==="
ps aux | grep -E "(sam|segment|ml|backend|predict)" | grep -v grep

echo -e "\n✅ 檢查完成！"
