# LaserEditor uninstaller — Windows 11.
#
#   uninstall.bat をダブルクリックしてください。
#   PowerShell から: powershell -ExecutionPolicy Bypass -File uninstall.ps1 [-DryRun] [-Purge]
#
# 方針は uninstall.sh と同じです。「LaserEditor が置いたもの」だけを外し、
# Docker Desktop・ScanSnap の保存先・参加者のデザインには触りません。
#
# 何が誰のものかの一覧 = prompt/maintenance/local/docs/install-footprint.md
#
# 削除は許可リストからしか行いません。プラン（何を消すか）を先に組み立て、
# 実行はそのプランだけを回す 1 箇所で行います — 表示したものと消したものが
# 食い違う形を作れないようにするためです。

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Purge,
    [switch]$RemoveImages,
    [switch]$Yes,
    [string]$Dir
)

$ErrorActionPreference = 'Stop'

$ImageRepo     = 'ghcr.io/fablab-westharima/laser-editor'
$ComposeMarker = 'name: laser-editor'

function Say  { param($m) Write-Host "`n[laser-editor] $m" -ForegroundColor Green }
function Warn { param($m) Write-Host "`n[laser-editor WARN] $m" -ForegroundColor Yellow }
function Fail { param($m) Write-Host "`n[laser-editor ERROR] $m" -ForegroundColor Red; exit 1 }

$InstallDir = if ($Dir) { $Dir } else { Join-Path $env:USERPROFILE 'laser-editor' }

# --------------------------------------------------------------- 対象の確認
if (-not (Test-Path $InstallDir)) {
    Say "インストール先が見つかりません: $InstallDir"
    Say 'すでにアンインストール済みのようです。何もしませんでした。'
    exit 0
}
# 目印は 2 つ見る。通常アンインストールの後は compose.yaml が消えているので、
# それだけを条件にすると 2 回目の実行が「別のフォルダだ」と誤判定して止まる。
$composePath = Join-Path $InstallDir 'compose.yaml'
$envPath     = Join-Path $InstallDir '.env'
$HaveCompose = (Test-Path $composePath) -and (Select-String -Path $composePath -SimpleMatch $ComposeMarker -Quiet)
$IsOurs      = $HaveCompose -or ((Test-Path $envPath) -and (Select-String -Path $envPath -Pattern '^LASER_ADMIN_TOKEN=' -Quiet))
if (-not $IsOurs) {
    Fail "$InstallDir は LaserEditor のインストール先ではないようです（compose.yaml の '$ComposeMarker' も .env の LASER_ADMIN_TOKEN も見つかりません）。安全のため中止します。"
}

# 外部Inbox は導入者の資産。どのモードでもプランに入れない。
$ExternalInbox = ''
if (Test-Path $envPath) {
    $hit = Select-String -Path $envPath -Pattern '^LASER_EXTERNAL_INBOX_HOST=(.*)$' | Select-Object -First 1
    if ($hit) { $ExternalInbox = $hit.Matches[0].Groups[1].Value }
}

# ------------------------------------------------------------------ プラン
$Plan = New-Object System.Collections.Generic.List[string]
function Add-Target {
    param([string]$Relative)
    $p = Join-Path $InstallDir $Relative
    if (-not (Test-Path $p)) { return }
    if ($ExternalInbox) {
        $norm = $ExternalInbox.Replace('/', '\').TrimEnd('\')
        $pn   = $p.Replace('/', '\').TrimEnd('\')
        if ($norm -eq $pn -or $norm.StartsWith($pn + '\')) {
            Warn "外部Inbox（$ExternalInbox）を含むため $Relative は削除しません"
            return
        }
    }
    $Plan.Add($p) | Out-Null
}

Add-Target 'compose.yaml'
Add-Target '管理トークン.txt'

$Keep = @(
    'data\  … 参加者のデザイン・スキャン・設定',
    '.env  … 管理トークンと設定',
    'tailscale-state\  … 公開 URL を保つノード情報'
)

if ($Purge) {
    Add-Target 'data'
    Add-Target '.env'
    Add-Target 'tailscale-state'
    Add-Target 'scan-inbox'
    Add-Target 'caddy-data'
    Add-Target 'Caddyfile'
    $Keep = @()
}

# ---------------------------------------------------------------- 表示
Write-Host ''
Write-Host '========================================================================'
Write-Host ' LaserEditor アンインストール (Windows)'
if ($DryRun) { Write-Host ' (-DryRun: 何も変更しません)' }
Write-Host '========================================================================'
Write-Host " 対象:   $InstallDir"
Write-Host (' モード: ' + $(if ($Purge) { '-Purge（データも削除）' } else { '通常（データは残す）' }))
Write-Host ''
Write-Host ' 停止・削除するもの:'
Write-Host '   - コンテナ (docker compose down)'
Write-Host '   - 内部ボリューム (laser-ai-work / tailscale-socket … 使い捨て領域)'
if ($RemoveImages) { Write-Host "   - コンテナイメージ ($ImageRepo)" }
foreach ($p in $Plan) { Write-Host "   - $p" }
Write-Host ''
Write-Host ' 残すもの:'
foreach ($k in $Keep) { Write-Host "   - $InstallDir\$k" }
if ($ExternalInbox) { Write-Host "   - $ExternalInbox  … ScanSnap の保存先（導入者の資産）" }
Write-Host '   - Docker Desktop / WSL … 他の用途にも使われる共有ソフト'
if (-not $RemoveImages) { Write-Host '   - コンテナイメージ（消す場合は -RemoveImages）' }
Write-Host ''
Write-Host ' このアンインストーラが解除する自動起動はありません。'
Write-Host ' LaserEditor はタスクスケジューラに何も登録していません（復帰は Docker'
Write-Host ' Desktop のサインイン時起動と compose の restart 設定で成立しています）。'
Write-Host '========================================================================'

if ($DryRun) {
    Say '-DryRun のため、ここで終了します。何も変更していません。'
    exit 0
}

# 2 回目以降。消すものが無く、停止すべきコンテナ定義も無いなら、そのまま終わる。
if ($Plan.Count -eq 0 -and -not $HaveCompose) {
    Say 'アンインストール済みです。残っているのはデータだけなので、何もしませんでした。'
    if ($Purge) { Say "データも消す場合は、$InstallDir をエクスプローラで削除してください。" }
    exit 0
}

if ($Purge -and -not $Yes) {
    Warn "参加者のデザインと管理トークンが失われます。バックアップが必要なら、いま $InstallDir をコピーしてください。"
    $answer = Read-Host 'すべて削除する場合は purge と入力してください'
    if ($answer -ne 'purge') { Say '中止しました。何も変更していません。'; exit 0 }
}

# ------------------------------------------------------------ ランタイム停止
if (-not $HaveCompose) {
    Say 'compose.yaml がないため、コンテナの停止は省略します（前回のアンインストールで削除済み）'
} elseif (Get-Command docker -ErrorAction SilentlyContinue) {
    Say 'コンテナを停止・削除します'
    Push-Location $InstallDir
    try {
        # -v が消すのは compose 所有の名前付きボリューム（使い捨て領域）だけ。
        # data は bind mount なのでこの操作では消えない。
        docker compose down -v --remove-orphans
        if ($LASTEXITCODE -ne 0) { Warn 'docker compose down が完了しませんでした。Docker Desktop が起動しているか確認してください' }
    } finally { Pop-Location }

    if ($RemoveImages) {
        Say "イメージを削除します: $ImageRepo"
        $ids = docker images --filter "reference=$ImageRepo" --format '{{.ID}}'
        foreach ($id in $ids) { if ($id) { docker rmi -f $id *> $null } }
    }
} else {
    Warn 'docker が見つかりません。コンテナの停止は省略します（すでに削除済みの可能性があります）'
}

# ---------------------------------------------------------------- 削除の実行
# 削除箇所はここだけ。上で表示したプランをそのまま回す。
foreach ($target in $Plan) {
    Remove-Item -LiteralPath $target -Recurse -Force -ErrorAction SilentlyContinue
}

if ($Purge) {
    $left = @(Get-ChildItem -LiteralPath $InstallDir -Force -ErrorAction SilentlyContinue)
    if ($left.Count -eq 0) {
        Remove-Item -LiteralPath $InstallDir -Force -ErrorAction SilentlyContinue
        Say "インストール先を削除しました: $InstallDir"
    } else {
        Say "インストール先に他のファイルが残っているため、フォルダは残しました: $InstallDir"
    }
}

Write-Host ''
if ($Purge) {
    Say 'アンインストールが完了しました（データも削除しました）。'
} else {
    Say "アンインストールが完了しました。データは $InstallDir に残っています。"
    Say 'もう一度使うときは install.bat を実行すれば、このデータのまま復帰します。'
}
