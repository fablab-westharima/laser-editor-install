# Windows に LaserEditor をインストールする

> **NOT RUNTIME VERIFIED** — パッケージと自動検査は実施済みですが、Windows実機での
> SmartScreen、展開、ダブルクリック実行は最終確認前です。

この手順では、PowerShellへコマンドを入力しません。

## はじめる前に

Windows 11の**タスク マネージャー → パフォーマンス → CPU**を開き、
**仮想化: 有効**であることを確認します。無効の場合はDocker Desktopを入れ直しても直らないため、
インストールを始めず、パソコンの管理者へ相談してください。

## 1. Docker Desktop を準備する

LaserEditor は Docker Desktop 自体を入れません。最初の1回だけ、
[Docker Desktop 公式サイト](https://www.docker.com/products/docker-desktop/)から
Windows版をインストールしてください。

1. Docker Desktopをインストールして起動する
2. 画面の初回設定を最後まで進める
3. **Engine running** と表示されるまで待つ

Docker Desktopのアカウント登録やサインインは不要です。
Docker Desktopの設定で、サインイン時に起動する項目をONにしておくと、パソコン再起動後も
LaserEditorが自動で復帰します。

## 2. Windows版ZIPを開く

1. [Windows版をダウンロード](https://github.com/fablab-westharima/laser-editor-install/releases/latest/download/LaserEditor-Installer-Windows.zip)
2. `LaserEditor-Installer-Windows.zip` を右クリックし、**すべて展開**を選ぶ
3. 展開したフォルダを開く

ZIPの中から実行してください。ZIPを開いたまま実行すると、必要な補助ファイルを見つけられません。

## 3. インストーラーを実行する

**`LaserEditor をインストール.bat`**をダブルクリックします。
内部処理は同梱ファイルが行うため、PowerShellを開いたり文字を入力したりする必要はありません。

- Docker Desktopが無い場合は、ダウンロードページと準備手順が表示されます
- Docker Desktopの準備が途中なら、**Engine running** にしてから同じランチャーを再実行します
- 準備済みなら、LaserEditorを導入してブラウザを開きます

## 4. 最初の設定

ブラウザで `http://localhost:8000/LaserEditor-settings` を開きます。

1. **参加者アクセスURL・QR**で、参加者へ渡すURLとQRを準備する
2. **参加者への解放**で、**参加受付**を確認する

参加者アクセスURLを有効にするときは、画面に表示される案内に従ってTailscaleへログインします。

古いログイン用ファイルを選ぶ操作はありません。

## ScanSnap Homeを使う

標準の監視先は `Downloads/LaserEditor/Scan-Inbox` です。

1. 設定画面の**ラボ構成・AI**を開く
2. **外部画像取り込み**で**監視フォルダを作成**を押す
3. ScanSnap Homeの保存先に、このフォルダを指定する

取り込みに成功した画像は受信フォルダから片付きます。同じ画像を後でもう一度投入できます。

## 更新とアンインストール

- 更新・修復: **`LaserEditor をインストール.bat`**をもう一度ダブルクリック
- 通常アンインストール: **`LaserEditor をアンインストール.bat`**をダブルクリック

通常アンインストールでは参加者のデータを残します。詳しくは
[運用ガイド](operations.md)を確認してください。
