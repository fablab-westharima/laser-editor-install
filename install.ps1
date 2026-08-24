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

function Get-CanonicalDownloads {
    $signature = @'
using System;
using System.Runtime.InteropServices;
public static class LaserKnownFolders {
    [DllImport("shell32.dll")]
    public static extern int SHGetKnownFolderPath(
        [MarshalAs(UnmanagedType.LPStruct)] Guid rfid,
        uint dwFlags,
        IntPtr hToken,
        out IntPtr ppszPath);
}
'@
    try {
        if (-not ('LaserKnownFolders' -as [type])) {
            Add-Type -TypeDefinition $signature
        }
        $ptr = [IntPtr]::Zero
        $downloadsId = New-Object Guid '374DE290-123F-4565-9164-39C4925E467B'
        $result = [LaserKnownFolders]::SHGetKnownFolderPath(
            $downloadsId, 0, [IntPtr]::Zero, [ref]$ptr)
        if ($result -eq 0 -and $ptr -ne [IntPtr]::Zero) {
            try { return [Runtime.InteropServices.Marshal]::PtrToStringUni($ptr) }
            finally { [Runtime.InteropServices.Marshal]::FreeCoTaskMem($ptr) }
        }
    } catch { }

    try {
        $shell = New-Object -ComObject Shell.Application
        $folder = $shell.NameSpace('shell:Downloads')
        if ($folder -and $folder.Self -and $folder.Self.Path) {
            return $folder.Self.Path
        }
    } catch { }

    $fallback = Join-Path $env:USERPROFILE 'Downloads'
    Warn "標準のダウンロードフォルダを取得できなかったため、$fallback を使います"
    return $fallback
}

function Normalize-InboxPath {
    param([string]$Value)
    if ($null -eq $Value) { return '' }
    return (($Value.Trim() -replace '\\', '/').TrimEnd('/'))
}

function Set-ExternalInboxKey {
    param([string]$Path, [string]$Key, [string]$Value)
    $lines = [System.IO.File]::ReadAllLines($Path)
    $out = New-Object System.Collections.Generic.List[string]
    $replaced = $false
    foreach ($line in $lines) {
        if (-not $replaced -and $line.StartsWith($Key + '=')) {
            $out.Add($Key + '=' + $Value)
            $replaced = $true
        } else {
            $out.Add($line)
        }
    }
    if (-not $replaced) { $out.Add($Key + '=' + $Value) }
    Write-Utf8NoBom $Path (($out -join "`n") + "`n")
}

function Set-ExternalInboxEnv {
    param([string]$Path, [string]$Value)
    Set-ExternalInboxKey $Path 'LASER_EXTERNAL_INBOX_HOST' $Value
}

function Remove-ExternalInboxKey {
    param([string]$Path, [string]$Key)
    $lines = [System.IO.File]::ReadAllLines($Path)
    $kept = @($lines | Where-Object { -not $_.StartsWith($Key + '=') })
    if ($kept.Count -ne $lines.Count) {
        Write-Utf8NoBom $Path (($kept -join "`n") + "`n")
    }
}

function Update-ExternalInboxEnv {
    param([string]$Path, [string]$StandardInbox, [string]$LegacyInbox)
    $active = $null
    foreach ($line in [System.IO.File]::ReadAllLines($Path)) {
        if ($line.StartsWith('LASER_EXTERNAL_INBOX_HOST=')) {
            $active = $line.Substring('LASER_EXTERNAL_INBOX_HOST='.Length)
            break
        }
    }
    $current = Normalize-InboxPath $active
    $standard = Normalize-InboxPath $StandardInbox
    $legacy = Normalize-InboxPath $LegacyInbox
    $standardRoot = Normalize-InboxPath (Split-Path -Parent (Split-Path -Parent $StandardInbox))
    if ([string]::IsNullOrWhiteSpace($current)) {
        Set-ExternalInboxEnv $Path $standard
        Set-ExternalInboxKey $Path 'LASER_EXTERNAL_INBOX_ROOT' $standardRoot
        Remove-ExternalInboxKey $Path 'LASER_EXTERNAL_INBOX_MOUNT'
        Say "標準の監視フォルダを設定しました: $standard"
    } elseif ($current -eq $standard) {
        Set-ExternalInboxKey $Path 'LASER_EXTERNAL_INBOX_ROOT' $standardRoot
        Remove-ExternalInboxKey $Path 'LASER_EXTERNAL_INBOX_MOUNT'
        return
    } elseif ($current -eq $legacy) {
        Set-ExternalInboxEnv $Path $standard
        Set-ExternalInboxKey $Path 'LASER_EXTERNAL_INBOX_ROOT' $standardRoot
        Remove-ExternalInboxKey $Path 'LASER_EXTERNAL_INBOX_MOUNT'
        Say "監視フォルダを標準の場所へ更新しました: $standard"
        $remaining = @(Get-ChildItem -LiteralPath $LegacyInbox -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -match '^\.(jpg|jpeg|png|webp)$' }).Count
        if ($remaining -gt 0) {
            Warn "以前の監視フォルダに画像が $remaining 件残っています: $LegacyInbox"
            Warn '画像は移動・削除していません。必要に応じて内容を確認してください'
        }
    } else {
        Remove-ExternalInboxKey $Path 'LASER_EXTERNAL_INBOX_ROOT'
        Set-ExternalInboxKey $Path 'LASER_EXTERNAL_INBOX_MOUNT' $current
        if ($active -match '\\') {
            $normalizedCustom = $active -replace '\\', '/'
            Set-ExternalInboxEnv $Path $normalizedCustom
            Say 'スキャン保存先のパス区切りを / に直しました'
        }
        Say "この機械は設定済みのフォルダを使い続けます: $active"
        Say "標準へ切り替えるには $Path の LASER_EXTERNAL_INBOX_HOST 1 行を書き換えてください"
    }
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
    3. タスクバー右下のクジラのアイコンが動きを止め、Docker Desktop が「Engine running」になるまで待つ
       （隠れている場合は「^」を押すと出てきます）

  を済ませたうえで、install.bat をもう一度ダブルクリックしてください。
"@
}

if (-not $dockerCmd) {
    NeedPrereq @"
Docker Desktop はインストールされていますが、まだ使える状態になっていません。

  Docker Desktop を開き、画面の案内に従って初回セットアップを完了してください。
  Docker Desktop が「Engine running」になったことを確認してから、
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

  Docker Desktop を起動し、「Engine running」になってから、
  install.bat をもう一度ダブルクリックしてください。

  何度やっても起動しない場合、原因の多くは BIOS の仮想化設定です。
  入れ直しでは直らないので、繰り返さずにご連絡ください。
"@
}
Say "Docker: 稼働中 ($(docker --version))"

# ============================================================ 配置 ==========

$downloadsPath = Get-CanonicalDownloads
$standardInbox = Join-Path $downloadsPath 'LaserEditor\Scan-Inbox'
$standardInboxNormalized = $standardInbox -replace '\\', '/'
$standardInboxRootNormalized = $downloadsPath -replace '\\', '/'
Say "配置先: $InstallDir"
New-Item -ItemType Directory -Force -Path $InstallDir              | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $InstallDir 'data')            | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $InstallDir 'tailscale-state') | Out-Null
New-Item -ItemType Directory -Force -Path $standardInbox | Out-Null

$EmbeddedCompose = @'
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
      - LASER_EXTERNAL_INBOX=${LASER_EXTERNAL_INBOX_MOUNT:+/scan-inbox}
      - LASER_EXTERNAL_INBOX_ROOT=${LASER_EXTERNAL_INBOX_ROOT:-}
      - LASER_EXTERNAL_INBOX_HOST=${LASER_EXTERNAL_INBOX_HOST:-}
    volumes:
      - ./data:/app/data
      - ${LASER_EXTERNAL_INBOX_ROOT:-./scan-inbox-root}:/scan-inbox-root
      - ${LASER_EXTERNAL_INBOX_MOUNT:-./scan-inbox}:/scan-inbox
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
    # この PC の tailnet 上の名前 = 公開 URL。全インストールが同じ名前を名乗ると
    # 2 台目が同じ公開 identity を主張する（2026-08-16 実測）。生成は初回だけで、
    # 以後は .env の値が正 — 再インストールでも変わらない（この分岐に入らない）。
    $hostBytes = New-Object byte[] 4
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($hostBytes)
    $tsHostname = 'laser-editor-' + (-join ($hostBytes | ForEach-Object { $_.ToString('x2') }))
    # 自動導入（acceptance / リリース検証）が、入れる版を入口から指定するための口。
    # **新規の .env を作るときの初期値にしかならない** — 既存 .env はこの分岐に
    # 入らないので、運用中の設定を環境変数が黙って上書きすることはない。
    # 何も指定しなければ従来どおり latest。
    $imageTag = if ($env:LASER_IMAGE_TAG) { $env:LASER_IMAGE_TAG } else { 'latest' }
    if ($imageTag -notmatch '^[A-Za-z0-9_][A-Za-z0-9._-]{0,127}$') {
        Fail "LASER_IMAGE_TAG の形式が不正です: $imageTag"
    }
    $imageDigest = $env:LASER_IMAGE_DIGEST
    if ($imageDigest -and $imageDigest -notmatch '^sha256:[0-9a-f]{64}$') {
        Fail "LASER_IMAGE_DIGEST の形式が不正です（sha256:<64桁の16進> の形で指定してください）"
    }
    $digestLine = if ($imageDigest) { "LASER_IMAGE_DIGEST=$imageDigest" } else { '#LASER_IMAGE_DIGEST=sha256:...' }
    # トークンは画面にもログにも出さない。ファイルにだけ書く。
    $envText = @"
LASER_ADMIN_TOKEN=$token
LASER_WORKERS=4
LASER_IMAGE_TAG=$imageTag
# 正式リリースを固定する場合は、版名(v1.0.0 等)を上の TAG に、その版の digest を
# 下に書きます。digest を書いた側が実体を決め、tag は人が読むための名前になります。
$digestLine
# この PC の名前です。インターネット公開を使うと、公開 URL は
# https://<この名前>.<あなたの tailnet>.ts.net になります。
# **書き換えると公開 URL が変わり、配布済みの QR は届かなくなります。**
# 2 台目を導入するときは、この行が機械ごとに違うことを確かめてください。
LASER_TS_HOSTNAME=$tsHostname
# 外部画像取り込みの標準受信箱。この PC のダウンロードフォルダから解決します。
LASER_EXTERNAL_INBOX_HOST=$standardInboxNormalized
LASER_EXTERNAL_INBOX_ROOT=$standardInboxRootNormalized
"@
    Write-Utf8NoBom $envPath $envText
    Say '.env を生成しました（管理トークンは自動生成しました）'
}

Update-ExternalInboxEnv $envPath $standardInbox (Join-Path $InstallDir 'scan-inbox')

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
Write-Host '   更新・修復:   「LaserEditor をインストール.bat」をもう一度実行します'
Write-Host '   アンインストール: 「LaserEditor をアンインストール.bat」'
Write-Host ''
Write-Host "   設定画面:     http://localhost:$AppPort/LaserEditor-settings"
Write-Host '   初期設定:     参加者アクセスURL・QR / 参加受付'
Write-Host '========================================================================'
