#!/usr/bin/env bash
# LaserEditor bootstrap installer (containerization Phase 2, P1-6(a)).
#
#   Linux (Raspberry Pi / VPS):
#     curl -fsSL https://raw.githubusercontent.com/fablab-westharima/laser-editor-install/main/install.sh | sudo bash
#   macOS (Docker Desktop):
#     curl -fsSL https://raw.githubusercontent.com/fablab-westharima/laser-editor-install/main/install.sh | bash
#   Windows: このスクリプトではなく install.bat をダブルクリックしてください
#
# アンインストールは uninstall.sh（Windows は uninstall.bat）。何が消えて何が残るかは
# prompt/maintenance/local/docs/install-footprint.md に一覧があります。
#
# Idempotent: re-running repairs/updates the install (pulls the newest image,
# rewrites compose.yaml, keeps your .env and data). If anything fails, fix the
# reported issue and run the same command again.
#
# Self-contained on purpose: the code repo is private (only this installer and
# the image are public), so the script embeds compose.yaml instead of fetching
# it. When compose.yaml changes in the code repo, mirror the change in
# EMBEDDED_COMPOSE below (and vice versa), then copy this file to the public
# distribution repo (fablab-westharima/laser-editor-install).
set -euo pipefail

IMAGE=ghcr.io/fablab-westharima/laser-editor
APP_PORT=8000

say()  { printf '\n\033[1;32m[laser-editor]\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m[laser-editor WARN]\033[0m %s\n' "$*"; }
fail() { printf '\n\033[1;31m[laser-editor ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

# 前提ソフトが整っていないのは LaserEditor の失敗ではないので、終了コードを分ける。
# 3 = 前提が未整備（ユーザーが Docker Desktop 側で作業してから再実行する）
# 1 = LaserEditor 自身のインストールが失敗した
# acceptance 側がこの 2 つを取り違えないために必要（前提不足を製品欠陥と数えない）。
need_prereq() { printf '\n\033[1;33m[laser-editor 準備が必要]\033[0m %s\n' "$*" >&2; exit 3; }

# NOTE: mirror of the repo's compose.yaml — keep the two in sync (see header).
write_compose() {  # $1 = install dir
    cat > "$1/compose.yaml" <<'EMBEDDED_COMPOSE'
name: laser-editor

services:
  tailscale:
    image: tailscale/tailscale:latest
    hostname: ${LASER_TS_HOSTNAME:-laser-editor}
    entrypoint: ["/bin/sh", "-c", "adduser -D -u 1000 app 2>/dev/null; tailscaled --state=/var/lib/tailscale/tailscaled.state --statedir=/var/lib/tailscale --socket=/var/run/tailscale/tailscaled.sock --tun=userspace-networking & TPID=$$!; i=0; while [ ! -S /var/run/tailscale/tailscaled.sock ] && [ $$i -lt 30 ]; do sleep 1; i=$$((i+1)); done; tailscale --socket=/var/run/tailscale/tailscaled.sock set --operator=app || echo 'WARN: operator set failed'; trap 'kill $$TPID' TERM INT; wait $$TPID"]
    volumes:
      - ./tailscale-state:/var/lib/tailscale
      - tailscale-socket:/var/run/tailscale
    ports:
      - "8000:8000"
    restart: unless-stopped

  app:
    # Formal releases pin by digest; the tag rides along so a human can read the
    # version. The engine resolves the digest when both are present, so
    # LASER_IMAGE_DIGEST decides the bytes (B3-a). Empty = previous behaviour.
    image: ghcr.io/fablab-westharima/laser-editor:${LASER_IMAGE_TAG:-latest}${LASER_IMAGE_DIGEST:+@${LASER_IMAGE_DIGEST}}
    network_mode: service:tailscale
    env_file: .env
    environment:
      - TZ=${TZ:-Asia/Tokyo}
      - LASER_EXTERNAL_INBOX=${LASER_EXTERNAL_INBOX_HOST:+/scan-inbox}
    volumes:
      - ./data:/app/data
      - ${LASER_EXTERNAL_INBOX_HOST:-./scan-inbox}:/scan-inbox
      - laser-ai-work:/app/data/ai_work
      - tailscale-socket:/var/run/tailscale
    depends_on:
      - tailscale
    restart: unless-stopped

  cloudflared:
    profiles: ["cloudflared"]
    image: cloudflare/cloudflared:latest
    command: tunnel --no-autoupdate run --token ${CLOUDFLARED_TOKEN:-}
    depends_on:
      - app
    restart: unless-stopped

  caddy:
    profiles: ["caddy"]
    image: caddy:2
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./caddy-data:/data
    depends_on:
      - app
    restart: unless-stopped

volumes:
  tailscale-socket:
  laser-ai-work:
EMBEDDED_COMPOSE
}

write_env_if_missing() {  # $1 = install dir, $2 = workers default
    if [ -f "$1/.env" ]; then
        say ".env: 既存を維持(トークン・設定は変更しません)"
    else
        TOKEN="$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')"
        # この機械の tailnet 上の名前 = 公開 URL。全インストールが同じ名前を名乗ると
        # 2 台目が同じ公開 identity を主張する(2026-08-16 実測)。生成は初回だけで、
        # 以後は .env の値が正 — 再インストールでも変わらない(この関数自体が
        # 「.env があれば何もしない」ため)。
        TS_HOSTNAME="laser-editor-$(head -c 4 /dev/urandom | od -An -tx1 | tr -d ' \n')"
        cat > "$1/.env" <<EOF
LASER_ADMIN_TOKEN=$TOKEN
LASER_WORKERS=$2
LASER_IMAGE_TAG=latest
# 正式リリースを固定する場合は、版名(v1.0.0 等)を上の TAG に、その版の digest を
# 下に書きます。digest を書いた側が実体を決め、tag は人が読むための名前になります。
# 版と digest の対は \`scripts/release.py verify\` が出力します。
#LASER_IMAGE_DIGEST=sha256:...
# この機械の名前です。インターネット公開を使うと、公開 URL は
# https://<この名前>.<あなたの tailnet>.ts.net になります。
# **書き換えると公開 URL が変わり、配布済みの QR は届かなくなります。**
# 2 台目を導入するときは、この行が機械ごとに違うことを確かめてください。
LASER_TS_HOSTNAME=$TS_HOSTNAME
# ScanSnap Home の保存先フォルダ(この機械の実パス)。設定すると自動取込が動きます。
# 空白を含むパスもそのまま書けます（クォート不要）。未設定なら自動取込は休止。
#LASER_EXTERNAL_INBOX_HOST=/Users/you/Documents/ScanSnap Home folder
EOF
        chmod 600 "$1/.env"
        say ".env を生成しました(管理トークン自動生成済み)"
    fi
}

write_token_file() {  # $1 = install dir — Finder で見える閲覧用コピー(.env が正)。
    # ドットファイルは Finder に表示されず、非技術スタッフが確実に詰まる
    # (2026-08-13 手順書ウォークスルーで確定)
    TOKEN_VAL="$(grep '^LASER_ADMIN_TOKEN=' "$1/.env" | cut -d= -f2-)"
    printf '%s\n' "$TOKEN_VAL" > "$1/管理トークン.txt"
}

pull_and_up() {  # $1 = install dir
    cd "$1"
    say "イメージを取得します: $IMAGE (公開イメージ・ログイン不要)"
    if ! docker compose pull; then
        warn "イメージの取得に失敗しました。ネットワーク接続を確認して、同じコマンドをもう一度実行してください"
        exit 1
    fi
    say "起動します"
    docker compose up -d
}

# Docker Desktop の CLI は **アプリバンドルの中**にあり、`/usr/local/bin/docker` は
# Docker Desktop 自身が初回設定のときに(管理者権限で)張る symlink である。
# つまり「Docker.app はインストールしたが、初回設定をまだ終えていない」機械には
#   /Applications/Docker.app         … ある
#   docker コマンド                  … PATH に無い
# という状態が実在する(2026-08-16 実測: MBP M3 Pro / macOS 26.6)。
# ここで PATH を直さないと、`docker info` は「エンジンが起動していない」ではなく
# 「コマンドが無い」で失敗し続け、何秒待っても状況は変わらない。
#
# この関数は **この process の PATH だけ**を直す。ユーザーのシェル設定には触らないし、
# symlink も作らない — それは Docker Desktop の仕事で、管理者権限を要する(拘束 1)。
resolve_docker_cli() {
    command -v docker >/dev/null 2>&1 && return 0
    _d=""
    for _d in "${DOCKER_APP_DIR:-/Applications/Docker.app}/Contents/Resources/bin" \
              "$HOME/.docker/bin"; do
        # 「ファイルがある」で採用しない。実際に起動できることまで確かめる —
        # 壊れた残骸や別アーキテクチャのバイナリを掴むと、この先の失敗の原因が
        # 分からなくなる
        if [ -x "$_d/docker" ] && "$_d/docker" --version >/dev/null 2>&1; then
            PATH="$_d:$PATH"
            export PATH
            return 0
        fi
    done
    return 1
}

# 「Docker Desktop が入っていない」と「入っているが CLI がまだ解決できない」は
# 別の状態で、案内すべき内容も違う。1 つにまとめていたせいで、Docker.app が入って
# いる機械に「Docker Desktop をインストールしてください」と出していた。
docker_desktop_missing() {
    [ ! -d "${DOCKER_APP_DIR:-/Applications/Docker.app}" ] && ! command -v docker >/dev/null 2>&1
}

health_wait() {
    say "ヘルスチェック中 (最大 90 秒)"
    HEALTH_OK=0
    for _ in $(seq 1 30); do
        if curl -fsS -o /dev/null "http://localhost:$APP_PORT/" 2>/dev/null \
           || wget -q -O /dev/null "http://localhost:$APP_PORT/" 2>/dev/null; then
            HEALTH_OK=1
            break
        fi
        sleep 3
    done
}

# =============================================================== macOS =======
macos_install() {
    # Docker Desktop はユーザー権限で動く — root で走らせると別コンテキストを
    # 見てしまうため、macOS では sudo なしが正しい
    [ "$(id -u)" -eq 0 ] && fail "macOS では sudo なしで実行してください: curl -fsSL <同じURL> | bash"

    INSTALL_DIR="$HOME/laser-editor"

    ARCH="$(uname -m)"
    case "$ARCH" in
        arm64|x86_64) say "アーキテクチャ: $ARCH (対応)" ;;
        *)            fail "未対応アーキテクチャ: $ARCH" ;;
    esac

    # ------------------------------------------------------ Docker Desktop
    # ---- preflight: Docker Desktop は外部の前提ソフトである -----------------
    # LaserEditor は Docker Desktop のインストーラではない。導入も初回設定も代行せず、
    # 状態を正しく見分けて、何をすればよいかを伝えて止まる。ここを通過するまで
    # LaserEditor の痕跡は 1 つも作らない(下の mkdir 以降が最初の書き込み)。
    #
    #   A 未導入            → 案内して終了
    #   B 導入済みだが未完了 → 何が足りないかを言って終了(こちらでは直さない)
    #   C 使える状態        → ここで初めてインストールへ進む
    if docker_desktop_missing; then
        open "https://www.docker.com/products/docker-desktop/" 2>/dev/null || true
        need_prereq "Docker Desktop がインストールされていません。

   LaserEditor を動かすには Docker Desktop が必要です。
   ダウンロードページを開きました。インストールしてから、

     1. Docker Desktop を起動する
     2. 画面の案内に従って初回セットアップを完了する
     3. クジラのアイコンが「Engine running」になるまで待つ

   を済ませたうえで、このインストーラをもう一度実行してください。"
    fi

    # 正しく準備された Docker を「この process から確実に見つける」ための探索。
    # 初回セットアップを肩代わりする仕組みではないので、見つからなければ待たずに止まる。
    if ! resolve_docker_cli; then
        need_prereq "Docker Desktop はインストールされていますが、まだ使える状態になっていません。

   Docker Desktop を開き、画面の案内に従って初回セットアップを完了してください
   (「Use recommended settings」→「Finish」。管理者パスワードを求められたら入力します)。

   クジラのアイコンが「Engine running」になったことを確認してから、
   このインストーラをもう一度実行してください。

   ※ Docker Desktop を入れ直す必要はありません。入れ直しても直りませんし、
     かえって復旧が難しくなります。"
    fi

    if ! docker info >/dev/null 2>&1; then
        need_prereq "Docker Desktop は入っていますが、エンジンが動いていません。

   Docker Desktop を起動し、クジラのアイコンが「Engine running」で
   安定するまで待ってから、このインストーラをもう一度実行してください。

   ※ 入れ直す必要はありません。"
    fi
    say "Docker: 稼働中 ($(docker --version))"

    # ------------------------------------------------------ files & start
    say "配置先: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/data" "$INSTALL_DIR/tailscale-state"
    write_compose "$INSTALL_DIR"
    write_env_if_missing "$INSTALL_DIR" 4
    write_token_file "$INSTALL_DIR"
    # 電源操作ヘルパーは導入しない(PC の停止 = Docker Desktop の終了。
    # 管理画面もその案内を表示する — docker.sock 共有は権限過大のため非採用)

    pull_and_up "$INSTALL_DIR"
    health_wait

    if [ "$HEALTH_OK" -eq 1 ]; then
        open "http://localhost:$APP_PORT/" 2>/dev/null || true
        cat <<EOF

========================================================================
 ✅ LaserEditor が起動しました(ブラウザを開きました)

   アプリ:       http://localhost:$APP_PORT
   管理トークン: $INSTALL_DIR の「管理トークン.txt」
   データ実体:   $INSTALL_DIR  (バックアップはこのフォルダごとコピー)

   停止:         Docker Desktop を終了(メニューバーのクジラ → Quit)
   起動:         Docker Desktop を起動するだけ(自動で復帰します)
   更新・修復:   同じ 1 行をもう一度実行するだけです

   インターネット公開: 管理画面 → 設定タブ → 公開設定
========================================================================
EOF
    else
        warn "起動確認がタイムアウトしました。ログを確認してください:"
        warn "  cd $INSTALL_DIR && docker compose logs app"
        exit 1
    fi
}

# =============================================================== Linux =======
linux_install() {
    INSTALL_DIR=/opt/laser-editor

    # ------------------------------------------------------------ root check
    if [ "$(id -u)" -ne 0 ]; then
        if command -v sudo >/dev/null 2>&1 && [ -f "$0" ]; then
            say "root 権限で再実行します(sudo)"
            exec sudo bash "$0" "$@"
        fi
        fail "root 権限が必要です。curl -fsSL <同じURL> | sudo bash で実行してください"
    fi

    # ------------------------------------------------------------- pre-flight
    ARCH="$(uname -m)"
    case "$ARCH" in
        aarch64|x86_64) say "アーキテクチャ: $ARCH (対応)" ;;
        armv7l|armv6l)  fail "32bit OS は非対応です。Raspberry Pi OS は 64bit 版を使ってください" ;;
        *)              fail "未対応アーキテクチャ: $ARCH" ;;
    esac

    MEM_KB="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
    WORKERS_DEFAULT=4
    if [ "$MEM_KB" -lt 1900000 ]; then
        WORKERS_DEFAULT=2
        warn "メモリ $((MEM_KB / 1024))MB は推奨(2GB 以上)未満です。ワーカー数を 2 に落として構成します(AI 画像処理は不安定になる可能性があります)"
    else
        say "メモリ: $((MEM_KB / 1024))MB (OK)"
    fi

    DISK_AVAIL_KB="$(df -Pk "$(dirname "$INSTALL_DIR")" | awk 'NR==2 {print $4}')"
    if [ "$DISK_AVAIL_KB" -lt 3000000 ]; then
        fail "空きディスク $((DISK_AVAIL_KB / 1024 / 1024))GB では不足です(イメージ+データで最低 3GB、推奨 10GB 以上)"
    elif [ "$DISK_AVAIL_KB" -lt 10000000 ]; then
        warn "空きディスク $((DISK_AVAIL_KB / 1024 / 1024))GB は推奨(10GB 以上)未満です"
    else
        say "空きディスク: $((DISK_AVAIL_KB / 1024 / 1024))GB (OK)"
    fi

    ROOT_DEV="$(findmnt -no SOURCE / 2>/dev/null || true)"
    case "$ROOT_DEV" in
        /dev/mmcblk*)
            warn "SD カードから起動しています。常用には USB SSD 起動を推奨します(SD は書込み寿命・速度の面で不利)"
            ;;
    esac

    # ---------------------------------------------------------------- docker
    if command -v docker >/dev/null 2>&1; then
        say "Docker: 導入済み ($(docker --version))"
    else
        say "Docker を導入します (get.docker.com)"
        curl -fsSL https://get.docker.com | sh
    fi
    docker compose version >/dev/null 2>&1 \
        || fail "docker compose プラグインがありません。'apt-get install docker-compose-plugin' 後に再実行してください"

    # ------------------------------------------------------ files & settings
    say "配置先: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/data" "$INSTALL_DIR/tailscale-state"
    write_compose "$INSTALL_DIR"
    write_env_if_missing "$INSTALL_DIR" "$WORKERS_DEFAULT"
    write_token_file "$INSTALL_DIR"
    # 既存 .env への追導入も冪等に(wave 2: 管理画面サーバー操作の有効化フラグ)
    grep -q '^LASER_POWER_HELPER=' "$INSTALL_DIR/.env" \
        || echo "LASER_POWER_HELPER=1" >> "$INSTALL_DIR/.env"

    # ------------------------------------------------- host power helper (wave 2)
    # 管理画面の「サーバー操作」の実体。コンテナは data/settings/power_request を
    # 書くだけで、実行はこのホスト側ヘルパー(root)が担う — privileged コンテナや
    # docker.sock 共有を避ける最小権限の境界。
    # 安全要件(確定): 内容が shutdown/reboot 以外は削除のみ / mtime が 120 秒より
    # 古い要求は実行しない(起動直後の path unit 発火による電源断ループ防止)
    say "電源操作ヘルパーを導入します(systemd path unit)"
    cat > "$INSTALL_DIR/power-helper.sh" <<'POWER_HELPER'
#!/bin/sh
REQ=/opt/laser-editor/data/settings/power_request
[ -f "$REQ" ] || exit 0
action="$(head -n 1 "$REQ" | tr -d '[:space:]')"
mtime="$(stat -c %Y "$REQ" 2>/dev/null || echo 0)"
now="$(date +%s)"
rm -f "$REQ"
[ $((now - mtime)) -le 120 ] || exit 0
case "$action" in
    shutdown) exec systemctl poweroff ;;
    reboot)   exec systemctl reboot ;;
    *)        exit 0 ;;
esac
POWER_HELPER
    chown root:root "$INSTALL_DIR/power-helper.sh"
    chmod 700 "$INSTALL_DIR/power-helper.sh"

    cat > /etc/systemd/system/laser-editor-power.service <<EOF
[Unit]
Description=LaserEditor power request handler

[Service]
Type=oneshot
ExecStart=$INSTALL_DIR/power-helper.sh
EOF

    cat > /etc/systemd/system/laser-editor-power.path <<EOF
[Unit]
Description=LaserEditor power request watcher

[Path]
PathExists=$INSTALL_DIR/data/settings/power_request

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable --now laser-editor-power.path >/dev/null 2>&1 || true

    # data と tailscale-state はコンテナ内 uid 1000 (app) が書く
    chown -R 1000:1000 "$INSTALL_DIR/data" "$INSTALL_DIR/tailscale-state"

    # ------------------------------------------------------------- pull & up
    pull_and_up "$INSTALL_DIR"
    health_wait

    IP="$(hostname -I 2>/dev/null | awk '{print $1}')"
    if [ "$HEALTH_OK" -eq 1 ]; then
        cat <<EOF

========================================================================
 ✅ LaserEditor が起動しました

   ブラウザで開いてください:  http://${IP:-<このマシンのIP>}:$APP_PORT

   管理トークン: $INSTALL_DIR/.env の LASER_ADMIN_TOKEN
   データ実体:   $INSTALL_DIR/data  (バックアップはこのフォルダと .env のコピー)
   更新・修復:   同じ install.sh をもう一度実行するだけです

   インターネット公開(Tailscale Funnel): 管理画面 → 設定タブ → 公開設定
========================================================================
EOF
    else
        warn "起動確認がタイムアウトしました。ログを確認してください:"
        warn "  cd $INSTALL_DIR && docker compose logs app"
        exit 1
    fi
}

# ============================================================== dispatch =====
# LASER_INSTALL_LIB=1 で source すると、関数を定義するだけで何も実行しない。
# テストが resolve_docker_cli を偽の Docker.app に対して直接叩けるようにするための
# 縫い目 — インストーラの分岐を「読んで確かめる」のではなく実際に走らせて確かめる
# ためにある(実機で 1 回踏んだ欠陥を、次からはテストで捕まえる)。
if [ "${LASER_INSTALL_LIB:-0}" = "1" ]; then
    return 0 2>/dev/null || exit 0
fi

case "$(uname -s)" in
    Darwin) macos_install "$@" ;;
    Linux)  linux_install "$@" ;;
    MINGW*|MSYS*|CYGWIN*)
        fail "Windows では install.bat をダブルクリックしてください(このスクリプトは macOS / Linux 用です)" ;;
    *)      fail "未対応 OS です(検出: $(uname -s))。macOS / Linux はこのスクリプト、Windows は install.bat を使ってください" ;;
esac
