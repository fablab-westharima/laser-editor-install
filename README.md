# LaserEditor インストーラー

LaserEditor を Mac または Windows に導入するための公式配布ページです。
初めて Docker を使う方も、コマンド入力は必要ありません。

<!-- Installer sources and the named launchers are synchronized from the private
     LaserEditor repository. This public repository owns README.md and docs/.
     The synchronized source is recorded in .source-commit. -->

## 1. Docker Desktop を準備する

[Docker Desktop 公式サイト](https://www.docker.com/products/docker-desktop/)から、お使いの
Mac または Windows 用をインストールします。Docker Desktop を起動し、画面に
**Engine running** と表示されるまで初回設定を進めてください。

## 2. お使いのパソコン用をダウンロードする

### [⬇️ Mac版をダウンロード](https://github.com/fablab-westharima/laser-editor-install/releases/latest/download/LaserEditor-Installer-macOS.zip)

### [⬇️ Windows版をダウンロード](https://github.com/fablab-westharima/laser-editor-install/releases/latest/download/LaserEditor-Installer-Windows.zip)

ダウンロードした ZIP を展開し、次のファイルをダブルクリックします。

| パソコン | ダブルクリックするファイル |
|---|---|
| Mac | **`LaserEditor をインストール.command`** |
| Windows | **`LaserEditor をインストール.bat`** |

Macでは初回のみ、macOSがインストーラーをブロックする場合があります。その場合は
[Macの導入手順](docs/setup-macos.md)にある「プライバシーとセキュリティ」から開いてください。

インストールが終わると、LaserEditor がブラウザで開きます。設定は
`http://localhost:8000/LaserEditor-settings` を開き、
**参加者アクセスURL・QR**と**参加受付**を確認してください。

詳しい画面付き手順:

- [Mac の導入手順](docs/setup-macos.md)
- [Windows の導入手順](docs/setup-windows.md)

## 更新・アンインストール

更新するときも、同じインストーラーをもう一度実行します。通常のアンインストールでは、
参加者のデータを消しません。

| パソコン | アンインストール |
|---|---|
| Mac | **`LaserEditor をアンインストール.command`** |
| Windows | **`LaserEditor をアンインストール.bat`** |

[更新・バックアップ・アンインストール](docs/operations.md) /
[困ったとき](docs/troubleshooting.md)

## 対応範囲

一般向けの正式な導入対象は、Docker Desktop を使う Mac と Windows です。
Windows版は実装・自動検査まで完了していますが、Windows実機での最終確認は残っています。

Raspberry Pi / Linux での既存機能は、経験者向けの
[高度な手順](docs/setup-raspberry-pi.md)に分けています。
