#!/usr/bin/env bash
# LaserEditor bootstrap installer (containerization Phase 2, P1-6(a)).
#
#   Linux (Raspberry Pi / VPS):
#     curl -fsSL https://raw.githubusercontent.com/fablab-westharima/laser-editor-install/main/install.sh | sudo bash
#   macOS (Docker Desktop):
#     curl -fsSL https://raw.githubusercontent.com/fablab-westharima/laser-editor-install/main/install.sh | bash
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

# NOTE: mirror of the repo's compose.yaml — keep the two in sync (see header).
write_compose() {  # $1 = install dir
    cat > "$1/compose.yaml" <<'EMBEDDED_COMPOSE'
name: laser-editor

services:
  tailscale:
    image: tailscale/tailscale:latest
    hostname: laser-editor
    entrypoint: ["/bin/sh", "-c", "adduser -D -u 1000 app 2>/dev/null; tailscaled --state=/var/lib/tailscale/tailscaled.state --statedir=/var/lib/tailscale --socket=/var/run/tailscale/tailscaled.sock --tun=userspace-networking & TPID=$$!; i=0; while [ ! -S /var/run/tailscale/tailscaled.sock ] && [ $$i -lt 30 ]; do sleep 1; i=$$((i+1)); done; tailscale --socket=/var/run/tailscale/tailscaled.sock set --operator=app || echo 'WARN: operator set failed'; trap 'kill $$TPID' TERM INT; wait $$TPID"]
    volumes:
      - ./tailscale-state:/var/lib/tailscale
      - tailscale-socket:/var/run/tailscale
    ports:
      - "8000:8000"
    restart: unless-stopped

  app:
    image: ghcr.io/fablab-westharima/laser-editor:${LASER_IMAGE_TAG:-latest}
    network_mode: service:tailscale
    env_file: .env
    environment:
      - TZ=${TZ:-Asia/Tokyo}
    volumes:
      - ./data:/app/data
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
EMBEDDED_COMPOSE
}

write_env_if_missing() {  # $1 = install dir, $2 = workers default
    if [ -f "$1/.env" ]; then
        say ".env: 既存を維持(トークン・設定は変更しません)"
    else
        TOKEN="$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')"
        cat > "$1/.env" <<EOF
LASER_ADMIN_TOKEN=$TOKEN
LASER_WORKERS=$2
LASER_IMAGE_TAG=latest
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
    if ! command -v docker >/dev/null 2>&1 && [ ! -d "/Applications/Docker.app" ]; then
        say "Docker Desktop が見つかりません。ダウンロードページを開きます"
        open "https://www.docker.com/products/docker-desktop/" 2>/dev/null || true
        fail "Docker Desktop をインストールして一度起動したあと、同じ 1 行をもう一度実行してください"
    fi
    if ! docker info >/dev/null 2>&1; then
        say "Docker Desktop を起動します(初回は起動完了まで 1 分ほどかかります)"
        open -a Docker 2>/dev/null || true
        DOCKER_OK=0
        for _ in $(seq 1 30); do
            if docker info >/dev/null 2>&1; then DOCKER_OK=1; break; fi
            sleep 3
        done
        [ "$DOCKER_OK" -eq 1 ] || fail "Docker Desktop の起動を確認できませんでした。クジラのアイコンが安定したら、同じ 1 行をもう一度実行してください"
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
case "$(uname -s)" in
    Darwin) macos_install "$@" ;;
    Linux)  linux_install "$@" ;;
    *)      fail "未対応 OS です(検出: $(uname -s))。Linux または macOS で実行してください" ;;
esac
