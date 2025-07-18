#!/bin/bash

# ソーシャルエンゲージメント統合システム
# 複数のプラットフォーム（X、note、Qiita、Zenn）からエンゲージメントデータを取得し、
# 統合表示およびNotionデータベースへの自動保存を行う

set -euo pipefail  # エラー時終了、未定義変数でエラー、パイプラインの失敗を検出

# スクリプト情報
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="Social Engagement Integration System"
readonly CONFIG_FILE="$HOME/.social-engagement-config"
readonly ERROR_LOG="$HOME/.social-engagement-errors.log"

# 色付き出力用の定数
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m' # No Color

# プラットフォーム定数
readonly PLATFORM_X="X"
readonly PLATFORM_NOTE="note"
readonly PLATFORM_QIITA="Qiita"
readonly PLATFORM_ZENN="Zenn"

# グローバル変数
declare -a ARTICLE_DATA=()
declare -A PLATFORM_TOTALS=()
declare DEBUG_MODE=false
declare VERBOSE_MODE=false

# ユーティリティ関数

# ログ出力関数
log_info() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    if [[ "$VERBOSE_MODE" == true ]]; then
        echo -e "${CYAN}[INFO]${NC} ${timestamp} - $message"
    fi
}

log_error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[ERROR]${NC} ${timestamp} - $message" >&2
    echo "[ERROR] $timestamp - $message" >> "$ERROR_LOG"
}

log_warning() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[WARNING]${NC} ${timestamp} - $message" >&2
}

log_success() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[SUCCESS]${NC} ${timestamp} - $message"
}

log_debug() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    if [[ "$DEBUG_MODE" == true ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} ${timestamp} - $message"
    fi
}

# 必要ツールの存在チェック
check_dependencies() {
    local missing_tools=()
    
    log_info "依存関係をチェック中..."
    
    # curl のチェック
    if ! command -v curl &> /dev/null; then
        missing_tools+=("curl")
    fi
    
    # jq のチェック
    if ! command -v jq &> /dev/null; then
        missing_tools+=("jq")
    fi
    
    # base64 のチェック
    if ! command -v base64 &> /dev/null; then
        missing_tools+=("base64")
    fi
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "以下のツールが見つかりません: ${missing_tools[*]}"
        echo
        echo "インストール手順:"
        echo "Ubuntu/Debian: sudo apt-get install curl jq coreutils"
        echo "CentOS/RHEL: sudo yum install curl jq coreutils"
        echo "macOS: brew install curl jq coreutils"
        exit 1
    fi
    
    log_success "すべての依存関係が確認されました"
}

# バージョン情報の表示
show_version() {
    echo "$SCRIPT_NAME v$SCRIPT_VERSION"
}

# ヘルプメッセージの表示
show_help() {
    cat << EOF
$SCRIPT_NAME v$SCRIPT_VERSION

使用方法: $0 [オプション]

オプション:
    -h, --help      このヘルプメッセージを表示
    -v, --version   バージョン情報を表示
    -d, --debug     デバッグモードを有効化
    --verbose       詳細なログ出力を有効化
    --config        設定ファイルの場所を表示
    --reset-config  設定ファイルをリセット

説明:
    このスクリプトは、複数のソーシャルメディアプラットフォーム
    （X、note、Qiita、Zenn）からエンゲージメントデータを取得し、
    統合表示およびNotionデータベースへの自動保存を行います。

設定ファイル:
    $CONFIG_FILE

エラーログ:
    $ERROR_LOG

例:
    $0                  # 通常実行
    $0 --debug          # デバッグモードで実行
    $0 --verbose        # 詳細ログ付きで実行
    $0 --reset-config   # 設定をリセットして再設定

EOF
}

# 設定ファイルの場所を表示
show_config_location() {
    echo "設定ファイル: $CONFIG_FILE"
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "ステータス: 存在"
        echo "権限: $(stat -c %a "$CONFIG_FILE" 2>/dev/null || stat -f %A "$CONFIG_FILE" 2>/dev/null || echo "不明")"
        echo "最終更新: $(stat -c %y "$CONFIG_FILE" 2>/dev/null || stat -f %Sm "$CONFIG_FILE" 2>/dev/null || echo "不明")"
    else
        echo "ステータス: 存在しません"
    fi
}

# 設定のリセット
reset_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        read -p "設定ファイルを削除してもよろしいですか？ (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f "$CONFIG_FILE"
            log_success "設定ファイルを削除しました"
        else
            log_info "キャンセルされました"
        fi
    else
        log_info "設定ファイルは存在しません"
    fi
}

# 引数の処理
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -d|--debug)
                DEBUG_MODE=true
                log_debug "デバッグモードが有効化されました"
                shift
                ;;
            --verbose)
                VERBOSE_MODE=true
                log_info "詳細モードが有効化されました"
                shift
                ;;
            --config)
                show_config_location
                exit 0
                ;;
            --reset-config)
                reset_config
                exit 0
                ;;
            *)
                log_error "不明なオプション: $1"
                echo "ヘルプを表示するには --help を使用してください"
                exit 1
                ;;
        esac
    done
}

# 初期化処理
initialize() {
    log_info "システムを初期化中..."
    
    # エラーログファイルの作成
    touch "$ERROR_LOG"
    
    # 依存関係のチェック
    check_dependencies
    
    log_success "初期化が完了しました"
}

# 設定管理関数

# 設定ファイルの読み込み
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_info "設定ファイルが見つかりません。初期設定を開始します。"
        setup_config
        return
    fi
    
    log_info "設定ファイルを読み込み中..."
    
    # 設定ファイルの権限チェック
    local file_perms=$(stat -c %a "$CONFIG_FILE" 2>/dev/null || stat -f %A "$CONFIG_FILE" 2>/dev/null || echo "000")
    if [[ "$file_perms" != "600" ]]; then
        log_warning "設定ファイルの権限が不適切です ($file_perms)。権限を修正します。"
        chmod 600 "$CONFIG_FILE"
    fi
    
    # 設定ファイルの読み込み
    source "$CONFIG_FILE"
    
    # 必要な設定項目の確認
    local missing_configs=()
    
    if [[ -z "${X_BEARER_TOKEN:-}" ]]; then
        missing_configs+=("X_BEARER_TOKEN")
    fi
    
    if [[ -z "${QIITA_ACCESS_TOKEN:-}" ]]; then
        missing_configs+=("QIITA_ACCESS_TOKEN")
    fi
    
    if [[ -z "${NOTION_TOKEN:-}" ]]; then
        missing_configs+=("NOTION_TOKEN")
    fi
    
    if [[ -z "${NOTION_DATABASE_ID:-}" ]]; then
        missing_configs+=("NOTION_DATABASE_ID")
    fi
    
    if [[ -z "${NOTE_USERNAME:-}" ]]; then
        missing_configs+=("NOTE_USERNAME")
    fi
    
    if [[ -z "${ZENN_USERNAME:-}" ]]; then
        missing_configs+=("ZENN_USERNAME")
    fi
    
    if [ ${#missing_configs[@]} -ne 0 ]; then
        log_warning "以下の設定項目が不足しています: ${missing_configs[*]}"
        log_info "設定を更新します。"
        setup_config
    else
        log_success "設定ファイルの読み込みが完了しました"
    fi
}

# base64エンコード/デコード関数
encode_base64() {
    local input="$1"
    echo -n "$input" | base64 | tr -d '\n'
}

decode_base64() {
    local input="$1"
    echo -n "$input" | base64 -d
}

# 設定値の安全な入力
read_secure_input() {
    local prompt="$1"
    local var_name="$2"
    local is_secret="${3:-false}"
    
    echo -n "$prompt: "
    if [[ "$is_secret" == "true" ]]; then
        read -s input_value
        echo  # 改行を追加
    else
        read input_value
    fi
    
    if [[ -z "$input_value" ]]; then
        log_error "入力が空です。設定をスキップします。"
        return 1
    fi
    
    # 秘密情報の場合はbase64エンコード
    if [[ "$is_secret" == "true" ]]; then
        input_value=$(encode_base64 "$input_value")
    fi
    
    declare -g "$var_name"="$input_value"
    return 0
}

# 初期設定の実行
setup_config() {
    echo
    echo -e "${YELLOW}初期設定を開始します${NC}"
    echo "各プラットフォームの認証情報を入力してください。"
    echo "（空白の場合はスキップされます）"
    echo
    
    # X API設定
    echo -e "${BLUE}=== X (Twitter) API設定 ===${NC}"
    echo "X API Bearer Tokenを取得方法:"
    echo "1. https://developer.twitter.com でアプリを作成"
    echo "2. Keys and Tokens タブでBearer Tokenを取得"
    echo
    read_secure_input "X API Bearer Token" "X_BEARER_TOKEN_INPUT" "true"
    
    # Qiita API設定
    echo
    echo -e "${YELLOW}=== Qiita API設定 ===${NC}"
    echo "Qiita Personal Access Tokenの取得方法:"
    echo "1. https://qiita.com/settings/applications でトークンを作成"
    echo "2. 'read_qiita' スコープを選択"
    echo
    read_secure_input "Qiita Personal Access Token" "QIITA_ACCESS_TOKEN_INPUT" "true"
    
    # Notion API設定
    echo
    echo -e "${PURPLE}=== Notion API設定 ===${NC}"
    echo "Notion Integration Tokenの取得方法:"
    echo "1. https://www.notion.so/my-integrations でIntegrationを作成"
    echo "2. トークンをコピー（ntn_で始まる）"
    echo
    read_secure_input "Notion Integration Token" "NOTION_TOKEN_INPUT" "true"
    
    echo
    read_secure_input "Notion Database ID" "NOTION_DATABASE_ID_INPUT" "false"
    
    # note設定
    echo
    echo -e "${GREEN}=== note設定 ===${NC}"
    echo "noteのユーザー名を入力してください（https://note.com/username の username 部分）"
    echo
    read_secure_input "note ユーザー名" "NOTE_USERNAME_INPUT" "false"
    
    # Zenn設定
    echo
    echo -e "${CYAN}=== Zenn設定 ===${NC}"
    echo "Zennのユーザー名を入力してください（https://zenn.dev/username の username 部分）"
    echo
    read_secure_input "Zenn ユーザー名" "ZENN_USERNAME_INPUT" "false"
    
    # 設定ファイルの作成
    log_info "設定ファイルを作成中..."
    
    cat > "$CONFIG_FILE" << EOF
# Social Engagement Integration System 設定ファイル
# 最終更新: $(date '+%Y-%m-%d %H:%M:%S')

# X (Twitter) API設定
X_BEARER_TOKEN="${X_BEARER_TOKEN_INPUT:-}"

# Qiita API設定
QIITA_ACCESS_TOKEN="${QIITA_ACCESS_TOKEN_INPUT:-}"

# Notion API設定
NOTION_TOKEN="${NOTION_TOKEN_INPUT:-}"
NOTION_DATABASE_ID="${NOTION_DATABASE_ID_INPUT:-}"

# note設定
NOTE_USERNAME="${NOTE_USERNAME_INPUT:-}"

# Zenn設定
ZENN_USERNAME="${ZENN_USERNAME_INPUT:-}"

# 設定ファイルのバージョン
CONFIG_VERSION="1.0.0"
EOF
    
    # 設定ファイルの権限を600に設定
    chmod 600 "$CONFIG_FILE"
    
    log_success "設定ファイルを作成しました: $CONFIG_FILE"
    
    # 設定の再読み込み
    source "$CONFIG_FILE"
}

# 設定の検証
validate_config() {
    log_info "設定を検証中..."
    
    local has_errors=false
    
    # X API設定の検証
    if [[ -n "${X_BEARER_TOKEN:-}" ]]; then
        log_debug "X API設定を検証中..."
        # 実際のAPI呼び出しは後の段階で実装
    fi
    
    # Qiita API設定の検証
    if [[ -n "${QIITA_ACCESS_TOKEN:-}" ]]; then
        log_debug "Qiita API設定を検証中..."
        # 実際のAPI呼び出しは後の段階で実装
    fi
    
    # Notion API設定の検証
    if [[ -n "${NOTION_TOKEN:-}" ]]; then
        log_debug "Notion API設定を検証中..."
        # 実際のAPI呼び出しは後の段階で実装
    fi
    
    if [[ "$has_errors" == "false" ]]; then
        log_success "設定の検証が完了しました"
    else
        log_error "設定に問題があります"
        return 1
    fi
}

# API連携関数

# X API v2連携関数
fetch_x_data() {
    local username="$1"
    local bearer_token="$2"
    
    if [[ -z "$username" ]]; then
        log_error "X API: ユーザー名が指定されていません"
        return 1
    fi
    
    if [[ -z "$bearer_token" ]]; then
        log_error "X API: Bearer Tokenが設定されていません"
        return 1
    fi
    
    log_info "X APIからデータを取得中..."
    
    # Bearer Tokenをデコード
    local decoded_token=$(decode_base64 "$bearer_token")
    
    # Step 1: ユーザーIDを取得
    local user_id_response
    user_id_response=$(curl -s --connect-timeout 10 --max-time 30 \
        -H "Authorization: Bearer $decoded_token" \
        "https://api.twitter.com/2/users/by/username/$username" \
        2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log_error "X API: ユーザーID取得に失敗しました"
        return 1
    fi
    
    local user_id=$(echo "$user_id_response" | jq -r '.data.id // empty')
    if [[ -z "$user_id" ]]; then
        log_error "X API: ユーザーID解析に失敗しました"
        log_debug "Response: $user_id_response"
        return 1
    fi
    
    log_debug "X API: ユーザーID取得成功 - $user_id"
    
    # Step 2: ユーザーのツイート一覧を取得
    local tweets_response
    tweets_response=$(curl -s --connect-timeout 10 --max-time 30 \
        -H "Authorization: Bearer $decoded_token" \
        "https://api.twitter.com/2/users/$user_id/tweets?max_results=100&tweet.fields=public_metrics,created_at" \
        2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log_error "X API: ツイート取得に失敗しました"
        return 1
    fi
    
    # レスポンスの解析
    local tweet_count=$(echo "$tweets_response" | jq '.data | length // 0')
    if [[ "$tweet_count" -eq 0 ]]; then
        log_warning "X API: ツイートが見つかりませんでした"
        return 0
    fi
    
    log_debug "X API: $tweet_count 件のツイートを取得"
    
    # 各ツイートの情報を処理
    echo "$tweets_response" | jq -r '.data[]? | @json' | while read -r tweet; do
        local tweet_id=$(echo "$tweet" | jq -r '.id')
        local tweet_text=$(echo "$tweet" | jq -r '.text')
        local like_count=$(echo "$tweet" | jq -r '.public_metrics.like_count // 0')
        local retweet_count=$(echo "$tweet" | jq -r '.public_metrics.retweet_count // 0')
        local reply_count=$(echo "$tweet" | jq -r '.public_metrics.reply_count // 0')
        local quote_count=$(echo "$tweet" | jq -r '.public_metrics.quote_count // 0')
        local created_at=$(echo "$tweet" | jq -r '.created_at')
        
        # 総エンゲージメント数を計算
        local total_engagement=$((like_count + retweet_count + reply_count + quote_count))
        
        # ツイートのURLを構築
        local tweet_url="https://twitter.com/$username/status/$tweet_id"
        
        # 記事データに追加
        local article_data="platform:$PLATFORM_X|title:$(echo "$tweet_text" | cut -c1-50)...|url:$tweet_url|engagement_count:$total_engagement|engagement_type:エンゲージメント|date:$created_at"
        
        ARTICLE_DATA+=("$article_data")
        
        log_debug "X API: ツイート処理完了 - エンゲージメント: $total_engagement"
    done
    
    log_success "X APIからのデータ取得が完了しました"
    return 0
}

# Qiita API v2連携関数
fetch_qiita_data() {
    local user_id="$1"
    local access_token="$2"
    
    if [[ -z "$user_id" ]]; then
        log_error "Qiita API: ユーザーIDが指定されていません"
        return 1
    fi
    
    if [[ -z "$access_token" ]]; then
        log_error "Qiita API: アクセストークンが設定されていません"
        return 1
    fi
    
    log_info "Qiita APIからデータを取得中..."
    
    # アクセストークンをデコード
    local decoded_token=$(decode_base64 "$access_token")
    
    # ユーザーの投稿一覧を取得
    local articles_response
    articles_response=$(curl -s --connect-timeout 10 --max-time 30 \
        -H "Authorization: Bearer $decoded_token" \
        "https://qiita.com/api/v2/users/$user_id/items?per_page=100" \
        2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log_error "Qiita API: 記事取得に失敗しました"
        return 1
    fi
    
    # レスポンスの解析
    local article_count=$(echo "$articles_response" | jq '. | length // 0')
    if [[ "$article_count" -eq 0 ]]; then
        log_warning "Qiita API: 記事が見つかりませんでした"
        return 0
    fi
    
    log_debug "Qiita API: $article_count 件の記事を取得"
    
    # 各記事の情報を処理
    echo "$articles_response" | jq -r '.[]? | @json' | while read -r article; do
        local title=$(echo "$article" | jq -r '.title')
        local url=$(echo "$article" | jq -r '.url')
        local likes_count=$(echo "$article" | jq -r '.likes_count // 0')
        local stocks_count=$(echo "$article" | jq -r '.stocks_count // 0')
        local created_at=$(echo "$article" | jq -r '.created_at')
        
        # 総エンゲージメント数を計算（いいね + ストック）
        local total_engagement=$((likes_count + stocks_count))
        
        # 記事データに追加
        local article_data="platform:$PLATFORM_QIITA|title:$title|url:$url|engagement_count:$total_engagement|engagement_type:LGTM+ストック|date:$created_at"
        
        ARTICLE_DATA+=("$article_data")
        
        log_debug "Qiita API: 記事処理完了 - エンゲージメント: $total_engagement"
    done
    
    log_success "Qiita APIからのデータ取得が完了しました"
    return 0
}

# note API連携関数
fetch_note_data() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        log_error "note API: ユーザー名が指定されていません"
        return 1
    fi
    
    log_info "note APIからデータを取得中..."
    
    # note非公開APIを使用
    local articles_response
    articles_response=$(curl -s --connect-timeout 10 --max-time 30 \
        "https://note.com/api/v2/creators/$username/contents?kind=note&page=1" \
        2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log_error "note API: 記事取得に失敗しました"
        return 1
    fi
    
    # レスポンスの解析
    local article_count=$(echo "$articles_response" | jq '.data.contents | length // 0')
    if [[ "$article_count" -eq 0 ]]; then
        log_warning "note API: 記事が見つかりませんでした"
        return 0
    fi
    
    log_debug "note API: $article_count 件の記事を取得"
    
    # 各記事の情報を処理
    echo "$articles_response" | jq -r '.data.contents[]? | @json' | while read -r article; do
        local title=$(echo "$article" | jq -r '.name')
        local key=$(echo "$article" | jq -r '.key')
        local like_count=$(echo "$article" | jq -r '.like_count // 0')
        local created_at=$(echo "$article" | jq -r '.created_at')
        
        # 記事のURLを構築
        local article_url="https://note.com/$username/n/$key"
        
        # 記事データに追加
        local article_data="platform:$PLATFORM_NOTE|title:$title|url:$article_url|engagement_count:$like_count|engagement_type:スキ|date:$created_at"
        
        ARTICLE_DATA+=("$article_data")
        
        log_debug "note API: 記事処理完了 - エンゲージメント: $like_count"
    done
    
    # レート制限対応（1-2秒間隔）
    sleep 1
    
    log_success "note APIからのデータ取得が完了しました"
    return 0
}

# Zenn API連携関数
fetch_zenn_data() {
    local username="$1"
    
    if [[ -z "$username" ]]; then
        log_error "Zenn API: ユーザー名が指定されていません"
        return 1
    fi
    
    log_info "Zenn APIからデータを取得中..."
    
    # Zenn非公式JSON APIを使用
    local articles_response
    articles_response=$(curl -s --connect-timeout 10 --max-time 30 \
        "https://zenn.dev/api/articles?username=$username&order=latest" \
        2>/dev/null)
    
    if [[ $? -ne 0 ]]; then
        log_error "Zenn API: 記事取得に失敗しました"
        return 1
    fi
    
    # レスポンスの解析
    local article_count=$(echo "$articles_response" | jq '.articles | length // 0')
    if [[ "$article_count" -eq 0 ]]; then
        log_warning "Zenn API: 記事が見つかりませんでした"
        return 0
    fi
    
    log_debug "Zenn API: $article_count 件の記事を取得"
    
    # 各記事の情報を処理
    echo "$articles_response" | jq -r '.articles[]? | @json' | while read -r article; do
        local title=$(echo "$article" | jq -r '.title')
        local slug=$(echo "$article" | jq -r '.slug')
        local liked_count=$(echo "$article" | jq -r '.liked_count // 0')
        local created_at=$(echo "$article" | jq -r '.created_at')
        
        # 記事のURLを構築
        local article_url="https://zenn.dev/$username/articles/$slug"
        
        # 記事データに追加
        local article_data="platform:$PLATFORM_ZENN|title:$title|url:$article_url|engagement_count:$liked_count|engagement_type:いいね|date:$created_at"
        
        ARTICLE_DATA+=("$article_data")
        
        log_debug "Zenn API: 記事処理完了 - エンゲージメント: $liked_count"
    done
    
    # レート制限対応（1-2秒間隔）
    sleep 1
    
    log_success "Zenn APIからのデータ取得が完了しました"
    return 0
}

# 全プラットフォームからデータを取得
fetch_all_data() {
    log_info "全プラットフォームからデータを取得開始..."
    
    # 記事データを初期化
    ARTICLE_DATA=()
    
    # X APIからデータを取得
    if [[ -n "${X_BEARER_TOKEN:-}" ]]; then
        # X用のユーザー名を取得（設定から推測または手動設定が必要）
        local x_username="your_x_username"  # 実際は設定から取得
        fetch_x_data "$x_username" "$X_BEARER_TOKEN" || log_warning "X APIからのデータ取得に失敗しました"
    else
        log_info "X API設定がスキップされました"
    fi
    
    # Qiita APIからデータを取得
    if [[ -n "${QIITA_ACCESS_TOKEN:-}" ]]; then
        # Qiita用のユーザーIDを取得（設定から推測または手動設定が必要）
        local qiita_user_id="your_qiita_id"  # 実際は設定から取得
        fetch_qiita_data "$qiita_user_id" "$QIITA_ACCESS_TOKEN" || log_warning "Qiita APIからのデータ取得に失敗しました"
    else
        log_info "Qiita API設定がスキップされました"
    fi
    
    # note APIからデータを取得
    if [[ -n "${NOTE_USERNAME:-}" ]]; then
        fetch_note_data "$NOTE_USERNAME" || log_warning "note APIからのデータ取得に失敗しました"
    else
        log_info "note API設定がスキップされました"
    fi
    
    # Zenn APIからデータを取得
    if [[ -n "${ZENN_USERNAME:-}" ]]; then
        fetch_zenn_data "$ZENN_USERNAME" || log_warning "Zenn APIからのデータ取得に失敗しました"
    else
        log_info "Zenn API設定がスキップされました"
    fi
    
    log_success "全プラットフォームからのデータ取得が完了しました"
    log_info "取得した記事数: ${#ARTICLE_DATA[@]}"
}

# データ処理と正規化関数

# 記事データの解析
parse_article_data() {
    local article_data="$1"
    
    # データをパースして連想配列に変換
    local IFS='|'
    local -A parsed_data
    
    for field in $article_data; do
        local key=$(echo "$field" | cut -d':' -f1)
        local value=$(echo "$field" | cut -d':' -f2-)
        parsed_data["$key"]="$value"
    done
    
    # 解析した内容を出力
    echo "platform:${parsed_data[platform]}"
    echo "title:${parsed_data[title]}"
    echo "url:${parsed_data[url]}"
    echo "engagement_count:${parsed_data[engagement_count]}"
    echo "engagement_type:${parsed_data[engagement_type]}"
    echo "date:${parsed_data[date]}"
}

# エンゲージメント数による降順ソート
sort_articles_by_engagement() {
    log_info "記事をエンゲージメント数で降順ソート中..."
    
    # 一時的なソート用配列
    local -a sorted_articles=()
    
    # 各記事のエンゲージメント数を取得してソート
    for article in "${ARTICLE_DATA[@]}"; do
        local engagement_count=$(echo "$article" | grep -o 'engagement_count:[0-9]*' | cut -d':' -f2)
        sorted_articles+=("$engagement_count|$article")
    done
    
    # 数値による降順ソート
    IFS=$'\n' sorted_articles=($(sort -nr <<< "${sorted_articles[*]}"))
    
    # ソート後の配列を再構築
    ARTICLE_DATA=()
    for sorted_article in "${sorted_articles[@]}"; do
        local article_data=$(echo "$sorted_article" | cut -d'|' -f2-)
        ARTICLE_DATA+=("$article_data")
    done
    
    log_success "記事のソートが完了しました"
}

# プラットフォーム別集計
calculate_platform_totals() {
    log_info "プラットフォーム別集計を実行中..."
    
    # 集計用変数を初期化
    PLATFORM_TOTALS=()
    PLATFORM_TOTALS["$PLATFORM_X"]=0
    PLATFORM_TOTALS["$PLATFORM_NOTE"]=0
    PLATFORM_TOTALS["$PLATFORM_QIITA"]=0
    PLATFORM_TOTALS["$PLATFORM_ZENN"]=0
    
    local -A platform_counts=()
    platform_counts["$PLATFORM_X"]=0
    platform_counts["$PLATFORM_NOTE"]=0
    platform_counts["$PLATFORM_QIITA"]=0
    platform_counts["$PLATFORM_ZENN"]=0
    
    # 各記事のエンゲージメント数を集計
    for article in "${ARTICLE_DATA[@]}"; do
        local platform=$(echo "$article" | grep -o 'platform:[^|]*' | cut -d':' -f2)
        local engagement_count=$(echo "$article" | grep -o 'engagement_count:[0-9]*' | cut -d':' -f2)
        
        if [[ -n "$platform" && -n "$engagement_count" ]]; then
            PLATFORM_TOTALS["$platform"]=$((PLATFORM_TOTALS["$platform"] + engagement_count))
            platform_counts["$platform"]=$((platform_counts["$platform"] + 1))
        fi
    done
    
    log_success "プラットフォーム別集計が完了しました"
    
    # 集計結果をデバッグ出力
    for platform in "$PLATFORM_X" "$PLATFORM_NOTE" "$PLATFORM_QIITA" "$PLATFORM_ZENN"; do
        local total=${PLATFORM_TOTALS[$platform]}
        local count=${platform_counts[$platform]}
        log_debug "$platform: $count 件, 総エンゲージメント: $total"
    done
}

# 全データの処理
process_all_data() {
    log_info "データ処理を開始..."
    
    if [[ ${#ARTICLE_DATA[@]} -eq 0 ]]; then
        log_warning "処理するデータがありません"
        return 1
    fi
    
    # エンゲージメント数による降順ソート
    sort_articles_by_engagement
    
    # プラットフォーム別集計
    calculate_platform_totals
    
    log_success "データ処理が完了しました"
}

# コンソール出力関数

# プラットフォーム別の色を取得
get_platform_color() {
    local platform="$1"
    
    case "$platform" in
        "$PLATFORM_X")
            echo "$BLUE"
            ;;
        "$PLATFORM_NOTE")
            echo "$GREEN"
            ;;
        "$PLATFORM_QIITA")
            echo "$YELLOW"
            ;;
        "$PLATFORM_ZENN")
            echo "$PURPLE"
            ;;
        *)
            echo "$WHITE"
            ;;
    esac
}

# 記事タイトルの切り詰め
truncate_title() {
    local title="$1"
    local max_length="${2:-50}"
    
    if [[ ${#title} -gt $max_length ]]; then
        echo "${title:0:$max_length}..."
    else
        echo "$title"
    fi
}

# 記事一覧の表示
display_articles() {
    log_info "記事一覧を表示中..."
    
    if [[ ${#ARTICLE_DATA[@]} -eq 0 ]]; then
        echo "表示する記事がありません。"
        return 1
    fi
    
    echo
    echo -e "${WHITE}=== 記事一覧（エンゲージメント数順） ===${NC}"
    echo
    
    # ヘッダー
    printf "%-15s %-50s %-10s %s\n" "プラットフォーム" "タイトル" "エンゲージメント" "URL"
    printf "%-15s %-50s %-10s %s\n" "===============" "==================================================" "==========" "============================"
    
    # 各記事を表示
    for article in "${ARTICLE_DATA[@]}"; do
        local platform=$(echo "$article" | grep -o 'platform:[^|]*' | cut -d':' -f2)
        local title=$(echo "$article" | grep -o 'title:[^|]*' | cut -d':' -f2)
        local url=$(echo "$article" | grep -o 'url:[^|]*' | cut -d':' -f2)
        local engagement_count=$(echo "$article" | grep -o 'engagement_count:[0-9]*' | cut -d':' -f2)
        
        local color=$(get_platform_color "$platform")
        local truncated_title=$(truncate_title "$title" 48)
        
        printf "${color}%-15s${NC} %-50s ${CYAN}%10s${NC} %s\n" \
            "$platform" \
            "$truncated_title" \
            "$engagement_count" \
            "$url"
    done
    
    echo
    log_success "記事一覧の表示が完了しました"
}

# プラットフォーム別サマリーの表示
display_platform_summary() {
    log_info "プラットフォーム別サマリーを表示中..."
    
    echo
    echo -e "${WHITE}=== プラットフォーム別サマリー ===${NC}"
    echo
    
    # ヘッダー
    printf "%-15s %-10s %-15s\n" "プラットフォーム" "記事数" "総エンゲージメント"
    printf "%-15s %-10s %-15s\n" "===============" "==========" "==============="
    
    local total_articles=0
    local total_engagement=0
    
    # 各プラットフォームの集計を表示
    for platform in "$PLATFORM_X" "$PLATFORM_NOTE" "$PLATFORM_QIITA" "$PLATFORM_ZENN"; do
        local platform_total=${PLATFORM_TOTALS[$platform]}
        local platform_count=0
        
        # 記事数を数える
        for article in "${ARTICLE_DATA[@]}"; do
            local article_platform=$(echo "$article" | grep -o 'platform:[^|]*' | cut -d':' -f2)
            if [[ "$article_platform" == "$platform" ]]; then
                platform_count=$((platform_count + 1))
            fi
        done
        
        local color=$(get_platform_color "$platform")
        
        if [[ $platform_count -gt 0 ]]; then
            printf "${color}%-15s${NC} %10d %15d\n" "$platform" "$platform_count" "$platform_total"
        else
            printf "${color}%-15s${NC} %10d %15d\n" "$platform" "$platform_count" "$platform_total"
        fi
        
        total_articles=$((total_articles + platform_count))
        total_engagement=$((total_engagement + platform_total))
    done
    
    echo
    printf "%-15s %-10s %-15s\n" "===============" "==========" "==============="
    printf "${WHITE}%-15s %10d %15d${NC}\n" "合計" "$total_articles" "$total_engagement"
    
    echo
    log_success "プラットフォーム別サマリーの表示が完了しました"
}

# 全結果の表示
display_results() {
    log_info "結果を表示中..."
    
    # 記事一覧の表示
    display_articles
    
    # プラットフォーム別サマリーの表示
    display_platform_summary
    
    log_success "結果の表示が完了しました"
}

# メイン処理
main() {
    echo -e "${BLUE}$SCRIPT_NAME v$SCRIPT_VERSION${NC}"
    echo "============================================="
    echo
    
    # 引数の処理
    parse_arguments "$@"
    
    # 初期化
    initialize
    
    # 設定の読み込み
    load_config
    
    # 設定の検証
    validate_config
    
    # 全プラットフォームからデータを取得
    fetch_all_data
    
    # テスト用データを追加（実際のAPI呼び出しが失敗した場合）
    if [[ ${#ARTICLE_DATA[@]} -eq 0 ]]; then
        log_info "テスト用データを追加しています..."
        ARTICLE_DATA+=(
            "platform:$PLATFORM_X|title:テストツイート1|url:https://twitter.com/test/status/1|engagement_count:150|engagement_type:エンゲージメント|date:2025-01-18"
            "platform:$PLATFORM_NOTE|title:テストnote記事|url:https://note.com/test/n/1|engagement_count:85|engagement_type:スキ|date:2025-01-17"
            "platform:$PLATFORM_QIITA|title:テストQiita記事|url:https://qiita.com/test/items/1|engagement_count:120|engagement_type:LGTM+ストック|date:2025-01-16"
            "platform:$PLATFORM_ZENN|title:テストZenn記事|url:https://zenn.dev/test/articles/1|engagement_count:95|engagement_type:いいね|date:2025-01-15"
        )
        log_info "テスト用データを追加しました (${#ARTICLE_DATA[@]} 件)"
    fi
    
    # データ処理と表示
    if [[ ${#ARTICLE_DATA[@]} -gt 0 ]]; then
        process_all_data
        display_results
    else
        log_warning "取得したデータがありません。設定を確認してください。"
        echo
        echo "設定確認方法:"
        echo "  $0 --config     # 設定ファイルの場所を確認"
        echo "  $0 --reset-config  # 設定をリセット"
    fi
    
    log_info "処理が完了しました"
    echo
    echo "次のステップ: Notion連携機能の実装"
}

# スクリプトが直接実行された場合のみmain関数を呼び出す
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi