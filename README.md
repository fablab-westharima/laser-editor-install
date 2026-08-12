# LaserEditor インストーラ

レーザー加工ワークショップ用デザイン Web アプリ **LaserEditor** の導入用リポジトリです。
(アプリ本体のイメージは ghcr.io/fablab-westharima/laser-editor として公開されています)

## 動作要件

- Raspberry Pi 4B/5(**4GB 以上推奨**・2GB 未満はワーカー数が自動で縮小されます)または x86_64 の Linux サーバー
- 64bit OS(Raspberry Pi OS **Lite (64-bit)** 推奨)・USB SSD 起動推奨
- インターネット接続

## インストール(1 行)

SSH でログインして:

```bash
curl -fsSL https://raw.githubusercontent.com/fablab-westharima/laser-editor-install/main/install.sh | sudo bash
```

- 再実行 = 修復・アップデートです(何かに失敗したら同じ 1 行をもう一度)
- 完了画面に表示される `http://<このマシンのIP>:8000` をブラウザで開けば使えます

## インストール後の最初の一歩

1. **管理トークン**: `/opt/laser-editor/.env` の `LASER_ADMIN_TOKEN`(管理画面ログインに使用)
2. **インターネット公開**(参加者がスマホでアクセスできる固定 URL+QR): 管理画面 → 設定タブ → **公開設定** — Tailscale の auth key を入れるだけ(キーの発行リンクも画面内にあります)
3. **サーバーの停止**: 管理画面 → 設定タブ → **サーバー操作** — シャットダウンボタンで安全に停止できます(SSH 不要)

## データとバックアップ

データは `/opt/laser-editor/data` に集約されています。バックアップはこのフォルダと `.env` のコピーで完結します。

## セキュリティについて

インストーラは root 権限で Docker の導入とサービス配置を行います。実行前に中身を確認したい場合は、同じ URL をブラウザで開けばスクリプト全文を読めます。
