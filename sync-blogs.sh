#!/usr/bin/env bash
# sync-blogs.sh — 掃描 Projects 下所有 blog/ 目錄，同步到 Quartz content/DevLog/
# 設計為可被任何外部系統（AI 排程、Task Scheduler、npm script）直接呼叫
# 退出碼：0 = 有變更、1 = 錯誤、2 = 無變更

set -euo pipefail

# --- 路徑設定 ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEVLOG_DIR="$SCRIPT_DIR/content/DevLog"
LOG_FILE="$SCRIPT_DIR/sync-blogs.log"

# --- 狀態追蹤 ---
COPIED=0
SKIPPED=0
ERRORS=0
CHANGES=()
ERROR_DETAILS=()

log() {
  local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
  echo "$msg" >> "$LOG_FILE"
}

# --- 從 blog.json 讀取目標名稱，fallback 用資料夾名 ---
resolve_target_name() {
  local blog_dir="$1"
  local project_dir="$(dirname "$blog_dir")"
  local blog_json="$blog_dir/blog.json"
  local folder_name="$(basename "$project_dir")"

  if [[ -f "$blog_json" ]]; then
    local name
    name=$(grep -o '"name"[[:space:]]*:[[:space:]]*"[^"]*"' "$blog_json" | head -1 | sed 's/.*"name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
    if [[ -n "$name" ]]; then
      echo "$name"
      return
    fi
  fi

  # fallback: 用資料夾名
  echo "$folder_name"
}

# --- 同步單一 blog 目錄 ---
sync_blog_dir() {
  local blog_dir="$1"
  local target_name
  target_name=$(resolve_target_name "$blog_dir")
  local target_dir="$DEVLOG_DIR/$target_name"

  # 確保目標目錄存在
  mkdir -p "$target_dir"

  # 遍歷所有 .md 檔案
  for src_file in "$blog_dir"/*.md; do
    [[ -f "$src_file" ]] || continue

    local filename="$(basename "$src_file")"
    local dst_file="$target_dir/$filename"

    # 比對：目標不存在 或 來源較新才複製
    if [[ ! -f "$dst_file" ]] || [[ "$src_file" -nt "$dst_file" ]]; then
      if cp "$src_file" "$dst_file" 2>/dev/null; then
        COPIED=$((COPIED + 1))
        CHANGES+=("{\"action\":\"copied\",\"from\":\"$src_file\",\"to\":\"$dst_file\"}")
        log "COPIED: $src_file -> $dst_file"
      else
        ERRORS=$((ERRORS + 1))
        ERROR_DETAILS+=("{\"file\":\"$src_file\",\"error\":\"copy failed\"}")
        log "ERROR: failed to copy $src_file"
      fi
    else
      SKIPPED=$((SKIPPED + 1))
    fi
  done
}

# --- 主流程 ---
main() {
  log "=== sync-blogs started ==="

  # 掃描所有 blog/ 目錄（最多 3 層深）
  local blog_dirs=()
  while IFS= read -r dir; do
    blog_dirs+=("$dir")
  done < <(find "$PROJECTS_ROOT" -maxdepth 4 -type d -name "blog" ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/quartz/*" 2>/dev/null)

  if [[ ${#blog_dirs[@]} -eq 0 ]]; then
    log "No blog directories found"
    output_result
    exit 2
  fi

  log "Found ${#blog_dirs[@]} blog directories"

  for blog_dir in "${blog_dirs[@]}"; do
    # 跳過沒有 .md 檔的目錄
    if ! ls "$blog_dir"/*.md &>/dev/null; then
      continue
    fi
    sync_blog_dir "$blog_dir"
  done

  log "=== sync-blogs finished: copied=$COPIED skipped=$SKIPPED errors=$ERRORS ==="

  output_result

  if [[ $ERRORS -gt 0 ]]; then
    exit 1
  elif [[ $COPIED -eq 0 ]]; then
    exit 2
  else
    exit 0
  fi
}

# --- 輸出結構化 JSON 結果 ---
output_result() {
  local changes_json="[]"
  if [[ ${#CHANGES[@]} -gt 0 ]]; then
    changes_json="[$(IFS=,; echo "${CHANGES[*]}")]"
  fi

  local errors_json="[]"
  if [[ ${#ERROR_DETAILS[@]} -gt 0 ]]; then
    errors_json="[$(IFS=,; echo "${ERROR_DETAILS[*]}")]"
  fi

  cat <<EOF
{
  "timestamp": "$(date -Iseconds)",
  "copied": $COPIED,
  "skipped": $SKIPPED,
  "errors": $ERRORS,
  "changes": $changes_json,
  "errorDetails": $errors_json
}
EOF
}

main "$@"
