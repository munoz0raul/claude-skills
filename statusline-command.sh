#!/usr/bin/env bash
# Claude Code status line: model | % left (tokens) | ctx% | $ | Opus 4.8 (tokens left)

input=$(cat)

# ── Model name (shortened) ────────────────────────────────────────────────────
raw_model=$(echo "$input" | jq -r '.model.display_name // .model.id // "Unknown"')
model=$(echo "$raw_model" \
  | sed 's/Claude //' \
  | sed 's/ (1M context)/ 1M/' \
  | sed 's/ (200K context)/ 200K/' \
  | sed 's/ context//')

# ── Context window ────────────────────────────────────────────────────────────
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
window_size=$(echo "$input" | jq -r '.context_window.window_size // 0')

if [ -n "$used_pct" ] && [ "$window_size" -gt 0 ] 2>/dev/null; then
  left_pct=$(echo "$used_pct $window_size" | awk '{printf "%.0f", 100 - $1}')
  tokens_left=$(echo "$used_pct $window_size" | awk '{
    left = $2 * (1 - $1/100)
    if (left >= 1000000) printf "%.1fM", left/1000000
    else if (left >= 1000) printf "%.0fk", left/1000
    else printf "%d", left
  }')
  ctx_used=$(echo "$used_pct" | awk '{printf "%.0f%%", $1}')
  left="${left_pct}% left (${tokens_left})"
elif [ -n "$used_pct" ]; then
  left_pct=$(echo "$used_pct" | awk '{printf "%.0f", 100 - $1}')
  ctx_used=$(echo "$used_pct" | awk '{printf "%.0f%%", $1}')
  left="${left_pct}% left"
else
  ctx_used="-"
  left="ctx:-"
fi

# ── Cost estimate ─────────────────────────────────────────────────────────────
#   Input tokens (non-cache): $3.00 / 1M
#   Cache write tokens:       $3.75 / 1M
#   Cache read tokens:        $0.30 / 1M
#   Output tokens:            $15.00 / 1M
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
cache_write=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')

cost=$(echo "$total_input $total_output $cache_write $cache_read" | awk '{
  total_in = $1; total_out = $2; cw = $3; cr = $4
  plain_in = total_in - cw - cr
  if (plain_in < 0) plain_in = 0
  cost = (plain_in * 3.00 + cw * 3.75 + cr * 0.30 + total_out * 15.00) / 1000000
  printf "$%.4f", cost
}')

# ── Opus 4.8 remaining (200K window) ─────────────────────────────────────────
# Shows how much of Opus 4.8's 200K context the current session has consumed.
OPUS_WINDOW=200000
opus_left=$(echo "$total_input $OPUS_WINDOW" | awk '{
  left = $2 - $1
  if (left < 0) left = 0
  if (left >= 1000) printf "%.0fk", left/1000
  else printf "%d", left
}')
opus_left_pct=$(echo "$total_input $OPUS_WINDOW" | awk '{
  pct = ($2 - $1) / $2 * 100
  if (pct < 0) pct = 0
  printf "%.0f%%", pct
}')

printf "%s | %s | ctx:%s | %s | Opus 4.8: %s left (%s)" \
  "$model" "$left" "$ctx_used" "$cost" "$opus_left_pct" "$opus_left"
