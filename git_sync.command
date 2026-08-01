#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

if ! command -v dart >/dev/null 2>&1; then
    echo "[错误] 未检测到 Dart SDK，请先安装并加入 PATH。"
    echo "安装：brew install dart  或  https://dart.dev/get-dart"
    read -n 1 -s -r -p "按任意键退出..."
    exit 1
fi

exec dart git_sync.dart