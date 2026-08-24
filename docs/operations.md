# 運用ガイド

一般向けの操作は、MacとWindowsのダブルクリック用ランチャーから行います。

## 更新する

**同じインストーラーをもう一度実行**します。設定と参加者のデータは引き継がれます。

| パソコン | 実行するもの |
|---|---|
| Mac | `LaserEditor をインストール.command` |
| Windows | `LaserEditor をインストール.bat` |

## バックアップする

LaserEditorを止めてから、ホームフォルダの `laser-editor` フォルダを外付けドライブなどへ
丸ごとコピーします。この中に参加者のデータと設定が入っています。

ScanSnap Homeの保存先である `Downloads/LaserEditor/Scan-Inbox` は受信フォルダで、
LaserEditorのバックアップとは別です。

## 別のパソコンへ移す

1. 新しいパソコンへDocker Desktopを入れ、**Engine running**まで準備する
2. バックアップした `laser-editor` フォルダを新しいパソコンのホームフォルダへ置く
3. 新しいパソコン用のインストーラーを実行する

同じバックアップを使って2台へ増やすと参加者アクセスURLが衝突するため、増設ではなく
1台ずつ新規インストールしてください。

## アンインストールする

通常のアンインストールでは、参加者のデータを残します。

| パソコン | 実行するもの |
|---|---|
| Mac | `LaserEditor をアンインストール.command` |
| Windows | `LaserEditor をアンインストール.bat` |

LaserEditorのコンテナと管理用ファイルは外れますが、参加者のデータ、ScanSnap Homeの保存先、
Docker Desktopは削除しません。もう一度インストーラーを実行すれば、残したデータで再開できます。

### データも含めて完全に削除する

これは通常のダブルクリック操作とは別の上級者向け操作で、取り消せません。必要な場合は先に
バックアップを取り、Macでは `uninstall.sh --purge`、Windowsでは `uninstall.bat -Purge` を
コマンドラインから実行します。通常のアンインストーラーをダブルクリックしただけでは、
この完全削除は実行されません。

## 1 台につき 1 つ

正式対応は、1 台のパソコンにつき 1 つのLaserEditorです。複数台で使う場合は、それぞれへ
新規インストールしてください。

[Macの手順](setup-macos.md) / [Windowsの手順](setup-windows.md) /
[困ったとき](troubleshooting.md)
