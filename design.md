# 設計文書

## 概要

ソーシャルエンゲージメント統合システムは、複数のプラットフォーム（X（旧Twitter）、note、Qiita、Zenn）からエンゲージメントデータを取得し、統合表示およびNotionデータベースへの自動保存を行う単一のbashスクリプトです。

## アーキテクチャ

### システム構成

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

## コンポーネントと インターフェース

### 1. 設定管理コンポーネント

**責任**: 認証情報とユーザー設定の管理

**機能**:
- `~/.social-engagement-config` ファイルでの設定保存
- 初回実行時の対話的設定
- 認証情報の暗号化保存（base64エンコード）

**設定項目**:
```bash
X_BEARER_TOKEN=""         # X (Twitter) API Bearer Token
QIITA_ACCESS_TOKEN=""     # Qiita Personal Access Token
NOTION_TOKEN=""           # Notion Integration Token (ntn_...)
NOTION_DATABASE_ID=""     # Notion Database UUID
NOTE_USERNAME=""          # note.comのユーザー名
ZENN_USERNAME=""          # Zennのユーザー名
```

### 2. データ取得コンポーネント

**責任**: 各プラットフォームからのデータ取得

#### X (Twitter)取得関数
```bash
fetch_x_data() {
    # X API v2を使用してユーザーのポスト（ツイート）とエンゲージメント取得
    # エンドポイント: /2/users/{id}/tweets
    # Bearer Token認証（OAuth 2.0 app-only）
    # 必要パラメータ: tweet.fields=public_metrics
    # レート制限: 月間上限あり（Free: 500件/月、Basic: 10,000件/月）
}
```

#### note取得関数
```bash
fetch_note_data() {
    # note非公開APIを使用（公式SDKなし）
    # エンドポイント: /api/v2/creators/{urlname}/contents?kind=note&page={page}
    # 認証不要、JSONレスポンスのlike_countフィールドを参照
    # レート制限に注意（1-2秒間隔推奨）
}
```

#### Qiita取得関数
```bash
fetch_qiita_data() {
    # Qiita API v2を使用
    # エンドポイント: /api/v2/users/{user_id}/items
    # Bearer Token認証（Personal tokenまたはOAuth 2.0）
    # レスポンス: likes_count（LGTM数）、stocks_count、reactions_count
    # レート制限: 認証なし60req/h、認証あり1,000req/h
}
```

#### Zenn取得関数
```bash
fetch_zenn_data() {
    # Zenn非公式JSON APIを使用（公式REST APIなし）
    # エンドポイント: /api/articles?username={username}&order=latest&page={page}
    # 認証不要、レスポンスのliked_countフィールドを参照
    # RSSフィード（/feed）も利用可能だがハート数は含まれない
    # レート制限: 1-2req/s推奨
}
```

### 3. データ処理コンポーネント

**責任**: 取得データの正規化と集計

**データ構造**:
```bash
# 各記事のデータ構造
ARTICLE_DATA=(
    "platform:X"
    "title:記事タイトル"
    "url:https://..."
    "engagement_count:123"
    "date:2025-01-18"
)
```

**処理機能**:
- データの正規化（統一フォーマットへの変換）
- エンゲージメント数による降順ソート
- プラットフォーム別集計
- 総合計算

### 4. 出力・保存コンポーネント

**責任**: 結果の表示とNotion保存

#### コンソール出力
```bash
display_results() {
    # テーブル形式での結果表示
    # プラットフォーム別グループ化
    # 総エンゲージメント数の表示
}
```

#### Notion保存
```bash
save_to_notion() {
    # Notion APIを使用（最新版: 2022-06-28）
    # Integration Token認証（Bearer認証、prefix: ntn_...）
    # エンドポイント: POST /v1/pages（データベースページ作成）
    # 重複チェック（URL基準）とアップデート処理
    # 必要権限: Insert content capability
}
```

## データモデル

### 記事データモデル
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
        "エンゲージメント種別": {"type": "select", "options": [
            {"name": "いいね", "color": "pink"},
            {"name": "LGTM", "color": "green"},
            {"name": "スキ", "color": "red"},
            {"name": "ハート", "color": "purple"}
        ]},
        "公開日": {"type": "date"},
        "最終更新": {"type": "date"}
    }
}
```

## エラーハンドリング

### エラー分類と対応

1. **ネットワークエラー**
   - 指数バックオフによるリトライ（最大3回）
   - タイムアウト設定（30秒）

2. **認証エラー**
   - 認証情報の再入力プロンプト
   - 設定ファイルの更新

3. **レート制限エラー**
   - 適切な待機時間の実装
   - ユーザーへの警告表示

4. **データ解析エラー**
   - 部分的なデータでの継続処理
   - エラーログの記録

### エラーログ
```bash
ERROR_LOG="$HOME/.social-engagement-errors.log"
log_error() {
    echo "[$(date)] $1" >> "$ERROR_LOG"
}
```

## テスト戦略

### 単体テスト
- 各API取得関数の個別テスト
- データ解析ロジックのテスト
- エラーハンドリングのテスト

### 統合テスト
- 全プラットフォーム連携テスト
- Notion保存機能のテスト
- 設定管理のテスト

### テスト用モックデータ
```bash
# テスト用のサンプルレスポンス
MOCK_X_RESPONSE='{"data":[{"id":"123","text":"test","public_metrics":{"like_count":10}}]}'
MOCK_QIITA_RESPONSE='[{"title":"test","likes_count":5,"url":"https://qiita.com/test","stocks_count":3}]'
MOCK_NOTE_RESPONSE='{"data":{"contents":[{"name":"test","like_count":15,"key":"n123"}]}}'
MOCK_ZENN_RESPONSE='{"articles":[{"title":"test","liked_count":8,"id":123}],"next_page":null}'
```

## セキュリティ考慮事項

1. **認証情報の保護**
   - 設定ファイルの権限制限（600）
   - 環境変数での一時的な認証情報管理

2. **APIキーの管理**
   - 設定ファイルでの暗号化保存
   - スクリプト内でのマスク表示

3. **ネットワークセキュリティ**
   - HTTPS通信の強制
   - SSL証明書の検証

## パフォーマンス最適化

1. **並行処理**
   - 各プラットフォームの並行データ取得
   - バックグラウンドプロセスの活用

2. **キャッシュ機能**
   - 短期間での重複実行時のキャッシュ利用
   - キャッシュの有効期限管理（1時間）

3. **レート制限対応**
   - 適切な間隔でのAPI呼び出し
   - バッチ処理での効率化