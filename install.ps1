# LaserEditor installer — Windows 11 (Docker Desktop).
#
#   install.bat をダブルクリックしてください（これを直接実行する必要はありません）。
#   PowerShell から直接: powershell -ExecutionPolicy Bypass -File install.ps1
#
# 何度実行しても壊れません。2 回目以降は「更新・修復」になり、.env と data は
# そのまま引き継ぎます。
#
# Docker Desktop 本体はこのスクリプトでは導入しません（公式 GUI インストーラ一択）。
# スクリプト導入で途中終了すると「インストール済み」の誤認で詰まり、手動除去まで
# 復旧できなくなるためです（windows-guide-design-premises.md 拘束 1・case 81）。
#
# NOTE: 下の $EmbeddedCompose は repo の compose.yaml の複製です。片方だけ直すと
# Windows 配布にだけ効かない差分ができます（テスト t112 が両方を突き合わせます）。

$ErrorActionPreference = 'Stop'

$ImageRepo  = 'ghcr.io/fablab-westharima/laser-editor'
$AppPort    = 8000
$InstallDir = Join-Path $env:USERPROFILE 'laser-editor'

function Say  { param($m) Write-Host "`n[laser-editor] $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "`n[laser-editor WARN] $m" -ForegroundColor Yellow }
function Fail {
    param($m)
    Write-Host "`n[laser-editor ERROR] $m" -ForegroundColor Red
    Write-Host "`nこの画面のまま、内容を担当者に伝えてください。" -ForegroundColor Red
    Write-Host "うまくいかないときに Docker Desktop の再インストールを繰り返すと、"
    Write-Host "かえって復旧が難しくなります。まずご連絡ください。"
    exit 1
}

# 前提ソフトが整っていないのは LaserEditor の失敗ではないので、終了コードを分ける。
# 3 = 前提が未整備（Docker Desktop 側で作業してから再実行）/ 1 = 本体のインストール失敗。
# acceptance 側がこの 2 つを取り違えないために必要。
function NeedPrereq {
    param($m)
    Write-Host "`n[laser-editor 準備が必要] $m" -ForegroundColor Yellow
    exit 3
}

# 秘密情報を書き込む先は UTF-8(BOM なし)。Windows PowerShell の Out-File は BOM を
# 付けるため、compose と .env が読めなくなる。ここは必ず .NET 側で書く。
function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    [System.IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding $false))
}

Write-Host ''
Write-Host '========================================================================'
Write-Host ' LaserEditor セットアップ (Windows)'
Write-Host '========================================================================'

# ===================================================== §0 はじめる前の確認 ===
# 「起動しない」の主因は BIOS の仮想化無効で、再インストールでは直りません。
# 1 分・非破壊で先に確かめます（拘束 3・4）。

Say 'この PC で動作するか確認しています'

$os = Get-CimInstance Win32_OperatingSystem
$caption = $os.Caption
$build   = [int]$os.BuildNumber
if ($build -lt 22000) {
    Warn "この PC は $caption (build $build) です。"
    Warn 'サポート対象は Windows 11 がプリインストールされた PC です。'
    Warn 'このまま進めることはできますが、動作は保証されません。'
} else {
    Say "OS: $caption (build $build)"
}

$virtOk = $null
try {
    $cs = Get-CimInstance Win32_ComputerSystem
    if ($cs.HypervisorPresent) { $virtOk = $true }
} catch { }
if ($virtOk -ne $true) {
    try {
        $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
        if ($cpu.VirtualizationFirmwareEnabled -eq $false) { $virtOk = $false }
    } catch { }
}
if ($virtOk -eq $false) {
    Fail @"
CPU の仮想化が無効になっています。この状態では Docker Desktop は
「インストールは終わるのに起動しない」という形になります。

  確認: Ctrl+Shift+Esc → パフォーマンス → CPU → 「仮想化」

  「無効」と出ている場合、これは PC 本体の BIOS/UEFI 設定であり、
  Docker Desktop を入れ直しても直りません。インストールは始めないでください。

  進め方の選択肢:
    1) 対応 PC（Windows 11 プリインストール機、または Mac）を使う
    2) セットアップ済みの機器を購入する
    3) 有償の導入支援を利用する
    4) PC に詳しい方向け: メーカー名 + 「仮想化 有効化」で検索（自己責任）
"@
}
if ($virtOk -eq $true) { Say '仮想化: 有効' }
else { Warn '仮想化の状態を自動判定できませんでした。先へ進みますが、Docker が起動しない場合は BIOS の仮想化設定を確認してください' }

# ================================================ Docker Desktop の確認 =====
# 本体は導入しません。無ければダウンロードページを開いて、いったん終了します。

# Docker Desktop は外部の前提ソフト。LaserEditor は導入も初回設定も代行せず、
# 状態を見分けて、何をすればよいかを伝えて止まる。ここを通過するまで LaserEditor の
# 痕跡は 1 つも作らない。
$dockerCmd = Get-Command docker -ErrorAction SilentlyContinue
$dockerApp = Test-Path (Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe')

if (-not $dockerCmd -and -not $dockerApp) {
    Say 'Docker Desktop が見つかりません。ダウンロードページを開きます'
    Start-Process 'https://www.docker.com/products/docker-desktop/'
    NeedPrereq @"
Docker Desktop がインストールされていません。

  LaserEditor を動かすには Docker Desktop が必要です。
  「公式のインストーラ（Docker Desktop Installer.exe）」でインストールしてから、

    1. Docker Desktop を起動する
    2. 画面の案内に従って初回セットアップを完了する
    3. タスクバー右下のクジラのアイコンが動きを止めて安定するまで待つ
       （隠れている場合は「^」を押すと出てきます）

  を済ませたうえで、install.bat をもう一度ダブルクリックしてください。
"@
}

if (-not $dockerCmd) {
    NeedPrereq @"
Docker Desktop はインストールされていますが、まだ使える状態になっていません。

  Docker Desktop を開き、画面の案内に従って初回セットアップを完了してください。
  クジラのアイコンが動きを止めて安定したことを確認してから、
  install.bat をもう一度ダブルクリックしてください。

  ※ Docker Desktop を入れ直す必要はありません。入れ直しても直りませんし、
    かえって復旧が難しくなります。
"@
}

# 「インストールが終わった」ではなく「エンジンが安定した」を成功判定にする（拘束 2）
Say 'Docker エンジンの状態を確認しています'
$engineOk = $false
try { docker info *> $null; if ($LASTEXITCODE -eq 0) { $engineOk = $true } } catch { }
if (-not $engineOk) {
    NeedPrereq @"
Docker Desktop は入っていますが、エンジンが動いていません。

  Docker Desktop を起動し、クジラのアイコンが動きを止めて安定してから、
  install.bat をもう一度ダブルクリックしてください。

  何度やっても起動しない場合、原因の多くは BIOS の仮想化設定です。
  入れ直しでは直らないので、繰り返さずにご連絡ください。
"@
}
Say "Docker: 稼働中 ($(docker --version))"

# ============================================================ 配置 ==========

Say "配置先: $InstallDir"
New-Item -ItemType Directory -Force -Path $InstallDir              | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $InstallDir 'data')            | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $InstallDir 'tailscale-state') | Out-Null

$EmbeddedCompose = @'
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
'@

Write-Utf8NoBom (Join-Path $InstallDir 'compose.yaml') $EmbeddedCompose

$envPath = Join-Path $InstallDir '.env'
if (Test-Path $envPath) {
    Say '.env: 既存を維持（トークン・設定は変更しません）'
} else {
    $bytes = New-Object byte[] 24
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    $token = -join ($bytes | ForEach-Object { $_.ToString('x2') })
    # トークンは画面にもログにも出さない。ファイルにだけ書く。
    $envText = @"
LASER_ADMIN_TOKEN=$token
LASER_WORKERS=4
LASER_IMAGE_TAG=latest
# 正式リリースを固定する場合は、版名(v1.0.0 等)を上の TAG に、その版の digest を
# 下に書きます。digest を書いた側が実体を決め、tag は人が読むための名前になります。
#LASER_IMAGE_DIGEST=sha256:...
# ScanSnap Home の保存先フォルダ(この PC の実パス)。設定すると自動取込が動きます。
# **区切りは / で書いてください**（\ ではありません）。空白を含むパスもそのままで可。
#LASER_EXTERNAL_INBOX_HOST=C:/Users/you/Documents/ScanSnap Home folder
"@
    Write-Utf8NoBom $envPath $envText
    Say '.env を生成しました（管理トークンは自動生成しました）'
}

# Windows のパスは \ 区切りだが、compose のボリューム指定では / でなければならない。
# 導入者が \ で書いてしまった場合はここで直す — 直さないと bind mount が
# 「存在しないパス」として黙って空フォルダになる。
$envLines = [System.IO.File]::ReadAllLines($envPath)
$changed = $false
for ($i = 0; $i -lt $envLines.Length; $i++) {
    if ($envLines[$i] -match '^LASER_EXTERNAL_INBOX_HOST=(.+)$') {
        $raw = $Matches[1]
        if ($raw -match '\\') {
            $envLines[$i] = 'LASER_EXTERNAL_INBOX_HOST=' + ($raw -replace '\\', '/')
            $changed = $true
        }
    }
}
if ($changed) {
    Write-Utf8NoBom $envPath (($envLines -join "`n") + "`n")
    Say 'スキャン保存先のパス区切りを / に直しました'
}

# Finder/エクスプローラから読める閲覧用コピー（.env が正）
$tokenVal = (Select-String -Path $envPath -Pattern '^LASER_ADMIN_TOKEN=(.*)$').Matches[0].Groups[1].Value
Write-Utf8NoBom (Join-Path $InstallDir '管理トークン.txt') "$tokenVal`n"

# ======================================================= 取得と起動 =========

Push-Location $InstallDir
try {
    Say "イメージを取得します: $ImageRepo （公開イメージ・ログイン不要）"
    docker compose pull
    if ($LASTEXITCODE -ne 0) {
        Fail 'イメージの取得に失敗しました。ネットワーク接続を確認して、install.bat をもう一度実行してください。'
    }
    Say '起動します'
    docker compose up -d
    if ($LASTEXITCODE -ne 0) { Fail 'コンテナの起動に失敗しました。この画面の内容を担当者に伝えてください。' }
} finally {
    Pop-Location
}

Say 'ヘルスチェック中（最大 90 秒）'
$healthy = $false
for ($i = 0; $i -lt 30; $i++) {
    try {
        Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 "http://localhost:$AppPort/" | Out-Null
        $healthy = $true
        break
    } catch { Start-Sleep -Seconds 3 }
}

if (-not $healthy) {
    Warn '起動確認がタイムアウトしました。ログを確認してください:'
    Warn "  cd `"$InstallDir`" ; docker compose logs app"
    exit 1
}

# ==================================================== 再起動後の復帰 ========
# 自動起動の実体は「Docker Desktop がサインイン時に起動する」+ compose の
# restart: unless-stopped。LaserEditor 側でタスク登録は行わない（登録すると
# アンインストール時に外し忘れる footprint が増えるだけで、得るものがない）。
$autoStart = $null
foreach ($f in @("$env:APPDATA\Docker\settings-store.json", "$env:APPDATA\Docker\settings.json")) {
    if (Test-Path $f) {
        try {
            $s = Get-Content -Raw $f | ConvertFrom-Json
            foreach ($p in $s.PSObject.Properties) {
                if ($p.Name -match 'autoStart|AutoStart|openUIOnStartup') { $autoStart = $p.Value; break }
            }
        } catch { }
        if ($null -ne $autoStart) { break }
    }
}
if ($autoStart -eq $false) {
    Warn 'Docker Desktop の「サインイン時に起動する」がオフです。オフのままだと PC 再起動後に LaserEditor が上がりません。'
    Warn '  クジラのアイコン → Settings → General → Start Docker Desktop when you sign in をオンにしてください。'
}

Start-Process "http://localhost:$AppPort/"

Write-Host ''
Write-Host '========================================================================'
Write-Host ' LaserEditor が起動しました（ブラウザを開きました）'
Write-Host ''
Write-Host "   アプリ:       http://localhost:$AppPort"
Write-Host "   管理トークン: $InstallDir の「管理トークン.txt」"
Write-Host "   データ実体:   $InstallDir  （バックアップはこのフォルダごとコピー）"
Write-Host ''
Write-Host '   停止:         Docker Desktop を終了（クジラ → Quit Docker Desktop）'
Write-Host '   起動:         Docker Desktop を起動するだけ（自動で復帰します）'
Write-Host '   更新・修復:   install.bat をもう一度実行するだけです'
Write-Host '   アンインストール: uninstall.bat'
Write-Host ''
Write-Host '   インターネット公開: 管理画面 → 設定タブ → 公開設定'
Write-Host '========================================================================'
