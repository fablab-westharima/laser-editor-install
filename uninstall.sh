#!/usr/bin/env bash
# LaserEditor uninstaller — macOS / Linux (Raspberry Pi, VPS).
#
#   ./uninstall.sh              # 通常: アプリを外し、データは残す
#   ./uninstall.sh --dry-run    # 何を消して何を残すかだけ表示する(何も変更しない)
#   ./uninstall.sh --purge      # データも消す(確認を求める・取り消せない)
#
# 方針: 「LaserEditor が置いたもの」だけを外す。Docker 本体・Tailscale・
# 導入者のスキャン保存先・参加者のデザインは、**このスクリプトの対象ではない**。
#
# 何が誰のものかの一覧 = prompt/maintenance/local/docs/install-footprint.md
#
# 削除は許可リストからしか行わない。プラン(何を消すか)を先に組み立て、実行は
# そのプランだけを回す 1 箇所で行う — 「表示したものと消したものが違う」形を
# 構造的に作れないようにするため。
set -euo pipefail

IMAGE_REPO=ghcr.io/fablab-westharima/laser-editor
COMPOSE_MARKER='name: laser-editor'

DRY_RUN=0
PURGE=0
REMOVE_IMAGES=0
ASSUME_YES=0
INSTALL_DIR=""

say()  { printf '\n\033[1;32m[laser-editor]\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m[laser-editor WARN]\033[0m %s\n' "$*"; }
fail() { printf '\n\033[1;31m[laser-editor ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'USAGE'
使い方: uninstall.sh [オプション]

  --dry-run         何も変更せず、削除するもの/残すものを表示する
  --purge           データ(デザイン・設定・管理トークン)も削除する
  --remove-images   LaserEditor のコンテナイメージも削除する(約 2GB。再導入時は再取得)
  --dir PATH        インストール先を明示する(既定: macOS=~/laser-editor / Linux=/opt/laser-editor)
  --yes             --purge の確認入力を省略する(自動実行用)
  -h, --help        このヘルプ

消さないもの(--purge でも消しません):
  * ScanSnap の保存先フォルダ(外部Inbox)  — 導入者の資産です
  * Docker / Docker Desktop               — 他の用途にも使われます
  * Tailscale                             — 同上
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)       DRY_RUN=1 ;;
        --purge)         PURGE=1 ;;
        --remove-images) REMOVE_IMAGES=1 ;;
        --yes|-y)        ASSUME_YES=1 ;;
        --dir)           shift; [ $# -gt 0 ] || fail "--dir にパスが必要です"; INSTALL_DIR="$1" ;;
        -h|--help)       usage; exit 0 ;;
        *)               fail "不明なオプション: $1 (--help を見てください)" ;;
    esac
    shift
done

PLATFORM="$(uname -s)"
if [ -z "$INSTALL_DIR" ]; then
    case "$PLATFORM" in
        Darwin) INSTALL_DIR="$HOME/laser-editor" ;;
        Linux)  INSTALL_DIR=/opt/laser-editor ;;
        *)      fail "未対応 OS です(検出: $PLATFORM)。Windows は uninstall.ps1 を使ってください" ;;
    esac
fi

# --------------------------------------------------------------- 対象の確認
# 「LaserEditor のインストール先である」ことを確かめてからでないと、何も消さない。
# --dir にうっかり別のフォルダを渡しても、ここで止まる。
[ -d "$INSTALL_DIR" ] || {
    say "インストール先が見つかりません: $INSTALL_DIR"
    say "すでにアンインストール済みのようです。何もしませんでした。"
    exit 0
}
# 目印は 2 つ見る。通常アンインストールの後は compose.yaml が消えているので、
# それだけを条件にすると 2 回目の実行が「別のフォルダだ」と誤判定して止まる。
HAVE_COMPOSE=0
IS_OURS=0
if [ -f "$INSTALL_DIR/compose.yaml" ] && grep -qF "$COMPOSE_MARKER" "$INSTALL_DIR/compose.yaml"; then
    HAVE_COMPOSE=1
    IS_OURS=1
fi
if [ -f "$INSTALL_DIR/.env" ] && grep -q '^LASER_ADMIN_TOKEN=' "$INSTALL_DIR/.env"; then
    IS_OURS=1
fi
if [ "$IS_OURS" -eq 0 ]; then
    fail "$INSTALL_DIR は LaserEditor のインストール先ではないようです（compose.yaml の '$COMPOSE_MARKER' も .env の LASER_ADMIN_TOKEN も見つかりません）。安全のため中止します。"
fi

# 外部Inbox は導入者の資産。パスを読み出して、以降のどのプランにも入らないことを保証する。
EXTERNAL_INBOX=""
if [ -f "$INSTALL_DIR/.env" ]; then
    EXTERNAL_INBOX="$(sed -n 's/^LASER_EXTERNAL_INBOX_HOST=//p' "$INSTALL_DIR/.env" | head -n 1 || true)"
fi

# ------------------------------------------------------------------ プラン
# installer が置いたものだけを名前で列挙する。ワイルドカードは使わない。
PLAN=()
add() {  # $1 = 相対パス
    local p="$INSTALL_DIR/$1"
    [ -e "$p" ] || return 0
    # 外部Inbox とその親は、どんなモードでも対象にしない
    if [ -n "$EXTERNAL_INBOX" ]; then
        case "$EXTERNAL_INBOX" in
            "$p"|"$p"/*) warn "外部Inbox($EXTERNAL_INBOX)を含むため $1 は削除しません"; return 0 ;;
        esac
    fi
    PLAN+=("$p")
}

# installer-owned: 毎回上書きされる、LaserEditor が生成した配置物
add "compose.yaml"
add "管理トークン.txt"
add "power-helper.sh"

KEEP=("data/  … 参加者のデザイン・スキャン・設定"
      ".env  … 管理トークンと設定"
      "tailscale-state/  … 公開 URL を保つノード情報")

if [ "$PURGE" -eq 1 ]; then
    add "data"
    add ".env"
    add "tailscale-state"
    add "scan-inbox"
    add "caddy-data"
    add "Caddyfile"
    KEEP=()
fi

# ---------------------------------------------------------------- 表示
echo
echo "========================================================================"
echo " LaserEditor アンインストール${DRY_RUN:+}"
[ "$DRY_RUN" -eq 1 ] && echo " (--dry-run: 何も変更しません)"
echo "========================================================================"
echo " 対象:        $INSTALL_DIR"
echo " モード:      $([ "$PURGE" -eq 1 ] && echo '--purge（データも削除）' || echo '通常（データは残す）')"
echo
echo " 停止・削除するもの:"
echo "   - コンテナ (docker compose down)"
echo "   - 内部ボリューム (laser-ai-work / tailscale-socket … 使い捨て領域)"
[ "$PLATFORM" = "Linux" ] && echo "   - systemd ユニット (laser-editor-power.path / .service)"
[ "$REMOVE_IMAGES" -eq 1 ] && echo "   - コンテナイメージ ($IMAGE_REPO)"
for p in "${PLAN[@]:-}"; do [ -n "$p" ] && echo "   - $p"; done
echo
echo " 残すもの:"
for k in "${KEEP[@]:-}"; do [ -n "$k" ] && echo "   - $INSTALL_DIR/$k"; done
[ -n "$EXTERNAL_INBOX" ] && echo "   - $EXTERNAL_INBOX  … ScanSnap の保存先(導入者の資産)"
echo "   - Docker / Docker Desktop、Tailscale などの共有ソフト"
[ "$REMOVE_IMAGES" -eq 0 ] && echo "   - コンテナイメージ（消す場合は --remove-images）"
echo "========================================================================"

if [ "$DRY_RUN" -eq 1 ]; then
    say "--dry-run のため、ここで終了します。何も変更していません。"
    exit 0
fi

# 2 回目以降。消すものが無く、停止すべきコンテナ定義も無いなら、そのまま終わる。
if [ "${#PLAN[@]}" -eq 0 ] && [ "$HAVE_COMPOSE" -eq 0 ]; then
    say "アンインストール済みです。残っているのはデータだけなので、何もしませんでした。"
    [ "$PURGE" -eq 1 ] && say "データも消す場合は、$INSTALL_DIR を手動で削除してください。"
    exit 0
fi

if [ "$PURGE" -eq 1 ] && [ "$ASSUME_YES" -eq 0 ]; then
    if [ ! -t 0 ]; then
        fail "--purge は取り消せません。対話端末で実行するか、意図が確かなら --yes を付けてください。"
    fi
    warn "参加者のデザインと管理トークンが失われます。バックアップが必要なら、いま $INSTALL_DIR をコピーしてください。"
    printf 'すべて削除する場合は purge と入力してください: '
    read -r ANSWER
    [ "$ANSWER" = "purge" ] || { say "中止しました。何も変更していません。"; exit 0; }
fi

# ------------------------------------------------------------ ランタイム停止
if [ "$HAVE_COMPOSE" -eq 0 ]; then
    say "compose.yaml がないため、コンテナの停止は省略します（前回のアンインストールで削除済み）"
elif command -v docker >/dev/null 2>&1; then
    say "コンテナを停止・削除します"
    # -v は compose が所有する名前付きボリュームだけを消す(使い捨て領域)。
    # ./data は bind mount なのでこの操作では消えない。
    ( cd "$INSTALL_DIR" && docker compose down -v --remove-orphans ) \
        || warn "docker compose down が完了しませんでした。Docker が起動しているか確認してください"
    if [ "$REMOVE_IMAGES" -eq 1 ]; then
        say "イメージを削除します: $IMAGE_REPO"
        docker images --format '{{.Repository}}:{{.Tag}}' \
            | grep -x -F -e "$IMAGE_REPO:latest" -e "$IMAGE_REPO:<none>" 2>/dev/null \
            | while IFS= read -r img; do docker rmi "$img" >/dev/null 2>&1 || true; done
        docker images --filter "reference=$IMAGE_REPO" --format '{{.ID}}' \
            | while IFS= read -r id; do docker rmi -f "$id" >/dev/null 2>&1 || true; done
    fi
else
    warn "docker が見つかりません。コンテナの停止は省略します(すでに削除済みの可能性があります)"
fi

# ------------------------------------------------------------ 自動起動の解除
if [ "$PLATFORM" = "Linux" ] && command -v systemctl >/dev/null 2>&1; then
    if [ "$(id -u)" -ne 0 ]; then
        warn "systemd ユニットの解除には root が必要です。sudo で再実行してください"
    else
        say "自動起動(systemd)を解除します"
        systemctl disable --now laser-editor-power.path >/dev/null 2>&1 || true
        systemctl disable --now laser-editor-power.service >/dev/null 2>&1 || true
        rm -f /etc/systemd/system/laser-editor-power.path \
              /etc/systemd/system/laser-editor-power.service
        systemctl daemon-reload || true
    fi
fi
# macOS は launchd に何も登録していない — 自動起動は Docker Desktop の設定と
# compose の restart ポリシーで成立しているので、解除するものが無い。

# ---------------------------------------------------------------- 削除の実行
# 削除箇所はここだけ。上で表示したプランをそのまま回す。
for target in "${PLAN[@]:-}"; do
    [ -n "$target" ] || continue
    rm -rf -- "$target"
done

# purge のときだけ、空になっていればインストール先自体を片付ける。
# 中身が残っている(導入者が何か置いた)場合は触らない。
if [ "$PURGE" -eq 1 ]; then
    rmdir "$INSTALL_DIR" 2>/dev/null && say "インストール先を削除しました: $INSTALL_DIR" \
        || say "インストール先に他のファイルが残っているため、フォルダは残しました: $INSTALL_DIR"
fi

echo
if [ "$PURGE" -eq 1 ]; then
    say "アンインストールが完了しました(データも削除しました)。"
else
    say "アンインストールが完了しました。データは $INSTALL_DIR に残っています。"
    say "もう一度使うときは、同じインストーラを実行すればこのデータのまま復帰します。"
fi
