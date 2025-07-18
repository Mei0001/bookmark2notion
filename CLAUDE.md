# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Social Engagement Integration System** - a single bash script that fetches engagement data from multiple social media platforms (X, note, Qiita, Zenn) and provides integrated display with automatic saving to Notion database.

## Development Architecture

### Core System Components

The system follows a 3-phase architecture:

1. **Configuration Management** (`~/.social-engagement-config`)
   - Handles authentication tokens and API keys
   - Base64 encoded storage with file permissions (600)
   - Interactive setup on first run

2. **Data Fetching Layer** (Parallel Processing)
   - X API v2: Bearer token authentication, rate limits (500-10K/month)
   - note API: Unofficial API, no auth required, 1-2sec intervals
   - Qiita API v2: Personal token, 1000req/h limit
   - Zenn API: Unofficial JSON API, no auth, 1-2req/s recommended

3. **Output & Storage Layer**
   - Console display with table formatting
   - Notion API integration (2022-06-28 version)
   - Error handling with exponential backoff retry

### Data Flow Pattern

```
Initialize → Fetch (Parallel) → Normalize → Sort → Display + Save
```

### Key Implementation Guidelines

**API Integration Pattern:**
- Each platform has dedicated fetch function
- Unified data structure for normalization
- Rate limiting and error handling per platform
- Parallel execution with background processes

**Data Model:**
```bash
ARTICLE_DATA=(
    "platform:X"
    "title:記事タイトル"
    "url:https://..."
    "engagement_count:123"
    "date:2025-01-18"
)
```

**Notion Integration:**
- Database schema with select fields for platforms
- Duplicate checking by URL
- Update existing entries vs create new ones
- Graceful degradation when Notion API fails

## Implementation Stages

Follow this 12-stage implementation plan from `tasks.md`:

1. **Basic Structure**: Script foundation + utility functions
2. **Config Management**: Authentication storage system
3. **X API Integration**: v2 API with Bearer token
4. **Qiita API Integration**: v2 API with Personal token
5. **note API Integration**: Unofficial API handling
6. **Zenn API Integration**: Unofficial JSON API
7. **Data Processing**: Normalization and sorting
8. **Console Output**: Table formatting and display
9. **Notion Integration**: Database operations
10. **Parallel Processing**: Background execution
11. **Error Handling**: Retry logic and resilience
12. **Integration Testing**: End-to-end validation

## Configuration Requirements

Required environment variables in `~/.social-engagement-config`:
- `X_BEARER_TOKEN`: X API Bearer token
- `QIITA_ACCESS_TOKEN`: Qiita Personal Access token
- `NOTION_TOKEN`: Notion Integration token (ntn_...)
- `NOTION_DATABASE_ID`: Notion Database UUID
- `NOTE_USERNAME`: note.com username
- `ZENN_USERNAME`: Zenn username

## Dependencies

- `curl`: HTTP requests to APIs
- `jq`: JSON parsing and manipulation
- `bash 4.0+`: Script execution environment

## Security Considerations

- No secrets in code or commits
- Base64 encoding for stored credentials
- HTTPS enforcement for all API calls
- File permission restrictions (600) for config
- Rate limiting compliance for all platforms

## Notification System

The repository includes a Slack notification script (`script/slack-notify-detailed.sh`) that tracks Claude Code operations. This is for monitoring purposes and sends structured messages to Slack via webhook when tools are used.

## Testing Strategy

- Mock API responses for unit testing
- Individual platform testing before integration
- Error scenario testing (network failures, invalid tokens)
- Rate limiting behavior verification
- Notion API integration testing