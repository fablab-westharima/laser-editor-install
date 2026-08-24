# Mac に LaserEditor をインストールする

この手順では、ターミナルへコマンドを入力しません。

## 1. Docker Desktop を準備する

LaserEditor は Docker Desktop 自体を入れません。最初の1回だけ、
[Docker Desktop 公式サイト](https://www.docker.com/products/docker-desktop/)から
Mac版をインストールしてください。

1. Docker Desktop をインストールして起動する
2. 画面の初回設定を最後まで進める
3. **Engine running** と表示されるまで待つ

Docker Desktop のアカウント登録やサインインは不要です。
Docker Desktopの設定で、ログイン時に起動する項目をONにしておくと、Mac再起動後も
LaserEditorが自動で復帰します。

## 2. Mac版ZIPを開く

1. [Mac版をダウンロード](https://github.com/fablab-westharima/laser-editor-install/releases/latest/download/LaserEditor-Installer-macOS.zip)
2. ダウンロードした `LaserEditor-Installer-macOS.zip` をダブルクリックして展開する
3. 展開したフォルダを開く

ZIPの中のファイルを個別にダウンロードしないでください。ZIPには、インストーラーが必要とする
ファイルと実行権限がまとめて入っています。

## 3. インストーラーを実行する

**`LaserEditor をインストール.command`** をダブルクリックします。

初回のみ、未署名版を開く際のmacOS Gatekeeperの確認で、インストーラーが
ブロックされる場合があります。その場合は次の手順で開きます。

1. **システム設定**を開く
2. **プライバシーとセキュリティ**を開く
3. LaserEditorのインストーラーについて**このまま開く**を選ぶ
4. 確認画面で**開く**を選ぶ

解除後にインストーラーが始まります。Terminalへのコマンド入力は不要です。

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

- 更新・修復: **`LaserEditor をインストール.command`**をもう一度ダブルクリック
- 通常アンインストール: **`LaserEditor をアンインストール.command`**をダブルクリック

通常アンインストールでは参加者のデータを残します。詳しくは
[運用ガイド](operations.md)を確認してください。
