# Raspberry Pi / Linux（経験者向け）

一般向けの正式配布はMacとWindowsです。このページは、既存のLinuxインストーラーを使う
経験者向けの高度な手順です。

> **公開前の実機確認が残っています。** 現在の版は、Raspberry Pi / Linux実機での
> 最終確認前です。

## 前提

- 64bit Linux
- Docker Engineを導入できる管理権限
- shellとSSHを使ったサーバー運用の知識
- x86_64またはarm64

導入には公開リポジトリの `install.sh`、削除には `uninstall.sh` を使います。
Mac / Windowsのダブルクリック用パッケージとは別の上級者向け経路です。

SSHでログインし、公開リポジトリの `install.sh` をroot権限で実行します。

```bash
curl -fsSL https://raw.githubusercontent.com/fablab-westharima/laser-editor-install/main/install.sh | sudo bash
```

Linuxでは、このインストーラーがDocker Engineも準備します。
更新するときも同じ `install.sh` を実行します。通常削除は `uninstall.sh`、データを含む削除は
`uninstall.sh --purge` です。操作前にスクリプト本文を確認し、参加者データをバックアップしてください。

起動後の設定画面は
`http://<このサーバーのIP>:8000/LaserEditor-settings` です。
**参加者アクセスURL・QR**と**参加受付**を設定します。

ScanSnap Homeが別のMac / Windowsで動く構成では、そのパソコンのフォルダをLinuxサーバーから
直接監視しません。設定画面の**画像依頼・取込**で、画像をドラッグ＆ドロップしてください。

日常の一般操作は[運用ガイド](operations.md)、問題の切り分けは
[困ったとき](troubleshooting.md)を参照してください。
