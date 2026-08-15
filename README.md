# LaserEditor 導入リポジトリ

レーザー加工ワークショップ用のデザイン Web アプリ **LaserEditor** を、自分の PC やサーバーに
入れて使うためのインストーラと手順書です。

参加者はスマホでブラウザを開くだけ。アプリのインストールもアカウント登録も要りません。

<!-- install.sh / install.ps1 / install.bat / uninstall.* / env.example は LaserEditor 本体
     リポジトリから自動同期されています。ここで直接編集しても次の同期で上書きされます。
     修正は本体側で行ってください（由来 = .source-commit）。
     README.md と docs/ はこのリポジトリで管理しており、同期の対象外です。 -->

---

## どれを使えばいいか

| 動かす機械 | 手順書 | 入口ファイル |
|---|---|---|
| **Mac**（Apple Silicon / Intel） | **[Mac で動かす](docs/setup-macos.md)** | `install.sh`（ターミナルに 1 行） |
| **Windows 11** | **[Windows で動かす](docs/setup-windows.md)** | `install.bat`（ダブルクリック） |
| **Raspberry Pi / Linux サーバー** | **[Raspberry Pi で動かす](docs/setup-raspberry-pi.md)** | `install.sh`（SSH で 1 行） |

導入したあとの操作（更新・バックアップ・復元・アンインストール）は
**[運用ガイド](docs/operations.md)**、うまくいかないときは
**[困ったとき](docs/troubleshooting.md)** を見てください。

レーザー加工機との連携は **[LightBurn 連携](docs/lightburn.md)**。

---

## 入れる前に必要なもの

LaserEditor は Docker のうえで動きます。**Docker はご自身で用意していただく前提**です。

| 機械 | 必要なもの |
|---|---|
| Mac / Windows | **Docker Desktop**（公式サイトから入れて、初回セットアップまで済ませておく） |
| Raspberry Pi / Linux | 特になし（インストーラが Docker Engine を導入します） |

**LaserEditor のインストーラは Docker Desktop をダウンロードも導入も設定もしません。**
足りないものがあれば、何をすればよいかを画面に出して、**何も変更せずに止まります**。
準備ができてからもう一度実行してください — この「準備 → 再実行」は失敗ではなく正規の流れです。

---

## LaserEditor が入れるもの・入れないもの

| | |
|---|---|
| **入れる** | LaserEditor 本体（Docker イメージ）、設定ファイル、データの置き場所 |
| **入れない** | Docker Desktop / Docker Engine、Tailscale、LightBurn |
| **消さない** | 参加者のデザイン、スキャンの原本、ScanSnap の保存先フォルダ、上記の外部ソフト |

アンインストールしても**データは残ります**（消したい場合は明示的な操作が必要）。
詳しくは [運用ガイド](docs/operations.md#アンインストール)。

---

## 対応状況

| 機械 | 状態 |
|---|---|
| **Mac（Apple Silicon）** | 実機で確認済み |
| **Mac（Intel）** | 実機で確認済み |
| **Windows 11** | 正式対応。**実機での最終確認は公開前に実施予定** |
| **Raspberry Pi** | 正式対応。**現行版での実機確認は公開前に実施予定** |

- **1 台につき 1 つ**の LaserEditor を正式対応とします（1 台に複数入れる構成は対象外）。
- スキャナ（ScanSnap）からの**自動取込は、スキャナと LaserEditor が同じ機械にある場合**に動きます。
  Raspberry Pi など別の機械で動かす場合は、管理画面へ画像をドラッグ＆ドロップして取り込みます
  （自動化は次の版で対応予定）。
- LightBurn は別のソフトです。LaserEditor は LightBurn を入れません。

**正式版（v1）はまだ公開していません。** 上記の未確認項目が終わってからになります。
