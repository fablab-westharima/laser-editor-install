#!/bin/bash

set -u

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"

echo
echo "LaserEditor のアンインストーラーを開始します。"
echo "通常のアンインストールでは、参加者のデータを残します。"
echo

if [ ! -f "$SCRIPT_DIR/uninstall.sh" ]; then
    echo "[エラー] uninstall.sh が同じフォルダにありません。"
    echo "ZIP を展開したフォルダの中から、もう一度実行してください。"
    RC=1
else
    bash "$SCRIPT_DIR/uninstall.sh"
    RC=$?
fi

echo
if [ "$RC" -eq 0 ]; then
    echo "処理が終わりました。このウインドウを閉じて構いません。"
else
    echo "処理が完了しませんでした。上の案内を確認してください。"
fi
printf "Return キーを押すと閉じます: "
read -r _
exit "$RC"
