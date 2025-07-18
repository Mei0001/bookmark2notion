# ソーシャルエンゲージメント統合システム

複数のソーシャルメディアプラットフォーム（X、note、Qiita、Zenn）からエンゲージメントデータを取得し、統合表示およびNotionデータベースへの自動保存を行う単一のbashスクリプトです。

## 概要

このシステムは、コンテンツクリエイターが複数のプラットフォームでのエンゲージメント指標を一箇所で確認できるよう設計されています。単一のbashスクリプトを実行するだけで、すべてのプラットフォームからのエンゲージメント情報を統合して表示し、Notionデータベースに自動保存します。

## セットアップ手順

### 1. 設定ファイルの準備

```bash
# 設定テンプレートをコピー
cp config.template ~/.social-engagement-config

# 設定ファイルの権限を設定
chmod 600 ~/.social-engagement-config
```

### 2. API設定の取得

各プラットフォームのAPIキーを取得し、設定ファイルに記入してください：

#### X (Twitter) API
1. [X Developer Portal](https://developer.twitter.com/) でアプリケーションを作成
2. 「Keys and Tokens」タブでBearer Tokenを取得
3. 設定ファイルの `X_BEARER_TOKEN` に記入
4. あなたのXユーザー名を `X_USERNAME` に記入

#### Qiita API
1. [Qiita設定画面](https://qiita.com/settings/applications) でPersonal Access Tokenを作成
2. スコープで「read_qiita」を選択
3. 設定ファイルの `QIITA_ACCESS_TOKEN` に記入
4. あなたのQiitaユーザーIDを `QIITA_USER_ID` に記入

#### note設定
1. あなたのnoteプロフィールURL（`https://note.com/[ユーザー名]`）を確認
2. ユーザー名部分を `NOTE_USERNAME` に記入

#### Zenn設定
1. あなたのZennプロフィールURL（`https://zenn.dev/[ユーザー名]`）を確認
2. ユーザー名部分を `ZENN_USERNAME` に記入

#### Notion API
1. [Notion Integrations](https://www.notion.so/my-integrations) でIntegrationを作成
2. Integration Tokenを `NOTION_TOKEN` に記入
3. Notionでデータベースを作成し、以下のプロパティを設定：
   - タイトル（Title）
   - プラットフォーム（Select）
   - URL（URL）
   - エンゲージメント数（Number）
   - エンゲージメント種別（Select）
   - 公開日（Date）
   - 最終更新（Date）
4. データベースIDを `NOTION_DATABASE_ID` に記入
5. 作成したIntegrationをデータベースに招待

### 3. 設定ファイルの例

```bash
# ~/.social-engagement-config の例
X_BEARER_TOKEN="your_bearer_token_here"
X_USERNAME="your_twitter_username"
QIITA_ACCESS_TOKEN="your_qiita_token_here"
QIITA_USER_ID="your_qiita_user_id"
NOTION_TOKEN="ntn_your_notion_token_here"
NOTION_DATABASE_ID="your_database_id_here"
NOTE_USERNAME="your_note_username"
ZENN_USERNAME="your_zenn_username"
```

## 使用方法

1. スクリプトを実行
```bash
./social-engagement.sh
```

2. 各プラットフォームからのデータを自動取得
3. コンソールに統合結果を表示
4. Notionデータベースに自動保存

### オプション

```bash
./social-engagement.sh --help      # ヘルプを表示
./social-engagement.sh --debug     # デバッグモードで実行
./social-engagement.sh --verbose   # 詳細ログで実行
./social-engagement.sh --config    # 設定ファイルの場所を確認
```

### 実行結果

スクリプトは以下の情報を表示します：

1. **記事一覧（エンゲージメント数順）**
   - プラットフォーム名
   - 記事タイトル
   - エンゲージメント数
   - 記事URL

2. **プラットフォーム別サマリー**
   - 各プラットフォームの記事数
   - 総エンゲージメント数
   - 全体の合計値

3. **Notionデータベースへの自動保存**
   - 新規記事の保存
   - 既存記事の重複チェック
   - 保存結果の表示

## 主な機能

- **複数プラットフォーム対応**: X（旧Twitter）、note、Qiita、Zennからデータを取得
- **統合表示**: 全プラットフォームのエンゲージメント指標を一覧表示
- **Notion自動保存**: 取得したデータを自動的にNotionデータベースに保存
- **設定管理**: 認証情報の暗号化保存と設定の永続化
- **エラーハンドリング**: 堅牢なエラー処理とリトライ機能

## 要件

### 機能要件

1. **統合エンゲージメント表示**
   - 全プラットフォームのエンゲージメント指標を統合表示
   - プラットフォーム名、コンテンツタイトル/URL、エンゲージメント数を表示
   - データが利用できない場合の適切なメッセージ表示

2. **認証設定管理**
   - 初回実行時の対話的設定
   - 認証情報の安全な保存
   - 無効な認証情報の自動検出と更新プロンプト

3. **マルチプラットフォーム対応**
   - X: いいね/ブックマーク数の取得
   - note: いいね・ブックマーク数の取得
   - Qiita: LGTM数・ブックマーク数の取得
   - Zenn: いいね・ブックマーク数の取得

4. **出力フォーマット**
   - 読みやすいテーブル/リスト形式
   - プラットフォーム別グループ化
   - 総エンゲージメント数の表示
   - エンゲージメント数による降順ソート

5. **エラーハンドリング**
   - APIリクエスト失敗時の適切な処理
   - 指数バックオフによるリトライロジック
   - レート制限対応
   - 詳細なエラーログ記録

6. **Notion連携**
   - 指定されたNotionデータベースへの自動保存
   - 各記事を個別ページとして作成
   - 既存記事のエンゲージメント数更新
   - APIエラー時のローカル表示継続

7. **単一ファイル実行**
   - 外部依存関係なしの単一bashファイル
   - 標準Unixツール（curl、jq）のみ使用
   - 不足ツールの自動検出とインストール手順表示

## アーキテクチャ

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   設定管理      │    │  データ取得      │    │  出力・保存     │
│                 │    │                  │    │                 │
│ ・認証情報管理  │───▶│ ・X API v2       │───▶│ ・コンソール出力│
│ ・設定ファイル  │    │ ・note API       │    │ ・Notion保存    │
│ ・初期化処理    │    │ ・Qiita API v2   │    │ ・エラーハンドリング│
│                 │    │ ・Zenn API       │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### データフロー

1. **初期化フェーズ**: 設定ファイルの確認・作成、認証情報の取得
2. **データ取得フェーズ**: 各プラットフォームからの並行データ取得
3. **データ処理フェーズ**: データの正規化、集計、ソート
4. **出力フェーズ**: コンソール表示とNotion保存

## 設定項目

設定ファイル（`~/.social-engagement-config`）で管理される項目:

```bash
X_BEARER_TOKEN=""         # X (Twitter) API Bearer Token
QIITA_ACCESS_TOKEN=""     # Qiita Personal Access Token
NOTION_TOKEN=""           # Notion Integration Token (ntn_...)
NOTION_DATABASE_ID=""     # Notion Database UUID
NOTE_USERNAME=""          # note.comのユーザー名
ZENN_USERNAME=""          # Zennのユーザー名
```

## データモデル

### 記事データ構造
```json
{
    "platform": "string",      // プラットフォーム名
    "title": "string",         // 記事タイトル
    "url": "string",          // 記事URL
    "engagement_count": "int", // エンゲージメント数
    "engagement_type": "string", // いいね/LGTM/スター等
    "published_date": "string", // 公開日
    "fetched_date": "string"   // 取得日時
}
```

### Notionデータベーススキーマ
```json
{
    "properties": {
        "タイトル": {"type": "title"},
        "プラットフォーム": {"type": "select", "options": [
            {"name": "X", "color": "blue"},
            {"name": "note", "color": "green"},
            {"name": "Qiita", "color": "yellow"},
            {"name": "Zenn", "color": "purple"}
        ]},
        "URL": {"type": "url"},
        "エンゲージメント数": {"type": "number"},
        "エンゲージメント種別": {"type": "select"},
        "公開日": {"type": "date"},
        "最終更新": {"type": "date"}
    }
}
```

## 実装計画

実装は以下の段階で進行します：

1. **基本構造**: スクリプト基本構造とユーティリティ関数
2. **設定管理**: 認証情報の保存と管理システム
3. **API連携**: 各プラットフォームとの連携機能
   - X API v2
   - Qiita API v2
   - note API
   - Zenn API
4. **データ処理**: 正規化、集計、ソート機能
5. **出力機能**: コンソール表示とNotion保存
6. **最適化**: 並行処理とパフォーマンス改善
7. **エラー処理**: 堅牢なエラーハンドリング
8. **統合テスト**: 全機能のテストとデバッグ

## セキュリティ考慮事項

- 認証情報の暗号化保存（base64エンコード）
- 設定ファイルの権限制限（600）
- HTTPS通信の強制
- SSL証明書の検証

## パフォーマンス最適化

- 各プラットフォームの並行データ取得
- バックグラウンドプロセスの活用
- レート制限対応と適切な待機時間
- キャッシュ機能（1時間有効期限）

## 使用方法

1. スクリプトを実行
2. 初回実行時に必要な認証情報を入力
3. 各プラットフォームからのデータを自動取得
4. コンソールに統合結果を表示
5. Notionデータベースに自動保存

## 必要な依存関係

- curl（HTTPリクエスト）
- jq（JSON解析）
- bash 4.0以上
- Unix/Linuxシステム

## ライセンス

このプロジェクトは防御的なセキュリティ目的で開発されています。