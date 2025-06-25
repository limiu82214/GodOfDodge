#!/usr/bin/env bash
set -Eeuo pipefail

# =====  取得隨機迷因圖（直鏈） =====
get_meme_url() {
  local url
  url=$(curl -fsSL https://meme-api.com/gimme | jq -r '.url')

  # 部分連結會是 imgur 頁面，檢查副檔名，不對就再抽一次（最多 3 次）
  for _ in {1..3}; do
    if [[ $url =~ \.(jpg|jpeg|png|gif)$ ]]; then
      echo "$url"
      return 0
    fi
    url=$(curl -fsSL https://meme-api.com/gimme | jq -r '.url')
  done

  # 若三次都失敗，回傳空字串，embed 就不帶縮圖
  echo ""
}

# ================= 隨機「生活系」祝福 =================
FOOTERS=(
  "願祂保佑你不會腦中風，只有靈光乍現。"
  "願神聖的 Wi-Fi 讓你訊號滿格，快樂不中斷。"
  "願骰子總翻到你想要的那一面。"
  "願貓咪只打翻水杯，不打翻你的心情。"
  "願台灣高溫 38 °C 只烤雞排，不烤你。"
  "願今晚雲層散去，讓月亮陪你散步。"
  "願你抽卡一次中獎，課金也不心痛。"
  "願娃娃機的夾子今天特別緊。"
  "願你的健保卡只用來領健體獎勵。"
  "願你連續劇只追一集，睡眠不超時。"
  "願早餐店老闆今日免費加蛋。"
  "願你轉角遇到兌換券，而不是停車單。"
  "願你搭捷運永遠都有座位。"
  "願所有的排隊都輪到你時剛好放音樂。"
  "辦網路送神諭，電信沒說但你賺到了。"
)

# =====  隨機挑一筆 quote  =====
TOTAL=$(jq length quotes.json)
(( TOTAL > 0 )) || { echo "quotes.json 無資料"; exit 1; }

INDEX=$(shuf -i 0-$((TOTAL - 1)) -n 1)
RAW_TEXT=$(jq -r ".[$INDEX].text" quotes.json)
RAW_BY=$(jq -r ".[$INDEX].by"  quotes.json | tr -d '\r\n ')

# =====  取作者 ID（安全版，不用 eval） =====
AUTHOR_ID="${!RAW_BY:-}"
[[ -n $AUTHOR_ID ]] || { echo "找不到對應 ID：$RAW_BY"; exit 1; }

export QUOTE="$RAW_TEXT - <@$AUTHOR_ID>"

# =====  產生 DESCRIPTION  =====
if [[ -f template.txt ]]; then
  DESCRIPTION=$(envsubst < template.txt)
else
  DESCRIPTION="$QUOTE"
fi

generate_quote() {
  local quotes_file=${1:-quotes.json}
  local template_file=${2:-template.txt}

  local TOTAL
  TOTAL=$(jq length "$quotes_file")
  (( TOTAL > 0 )) || { echo "$quotes_file 無資料" >&2; return 1; }

  local INDEX
  INDEX=$(shuf -i 0-$((TOTAL - 1)) -n 1)

  local RAW_TEXT RAW_BY AUTHOR_ID
  RAW_TEXT=$(jq -r ".[$INDEX].text" "$quotes_file")
  RAW_BY=$(jq -r ".[$INDEX].by" "$quotes_file" | tr -d '\r\n ')

  AUTHOR_ID="${!RAW_BY:-}"
  [[ -n $AUTHOR_ID ]] || { echo "找不到對應 ID：$RAW_BY" >&2; return 1; }

  local TEXT AUTHOR
  TEXT="$RAW_TEXT"
  AUTHOR="<@$AUTHOR_ID>"

  local DESCRIPTION
  if [[ -f "$template_file" ]]; then
    DESCRIPTION=$(TEXT="$TEXT" AUTHOR="$AUTHOR" envsubst < "$template_file")
  else
    DESCRIPTION="📜「$TEXT」- $AUTHOR"
  fi

  echo "$DESCRIPTION"
}

EMOJIS=("📜" "🛰️" "🎲" "✨" "🧙")
rand_emoji() {
  local idx=$(shuf -i 0-$((${#EMOJIS[@]}-1)) -n 1)
  printf '%s' "${EMOJIS[$idx]}"
}

desc=$(generate_quote "quotes.json" "template.txt") || exit 1
desc2=$(generate_quote "quotes.json" "template.txt") || exit 1
emoji=$(rand_emoji) || exit 1
footer_idx=$(shuf -i 0-$((${#FOOTERS[@]}-1)) -n 1)
footer="${FOOTERS[$footer_idx]}"
THUMB_URL=$(get_meme_url)
color=$(( ((RANDOM<<15)|RANDOM) & 0xFFFFFF ))
 
printf -v combined_desc '%s\n%s' "$desc" "$desc2"
# FIELDS_JSON=$(printf '%s\n' "$combined_desc" |
#   jq -R '{name:"", value:., inline:true}' | jq -s '.')
# --argjson fields "$FIELDS_JSON" \

# =====  組 payload 並發送 =====
EMBED=$(jq -n \
  --arg title  "🕯 Doge之神的每日神諭 🕯" \
  --arg desc "$combined_desc" \
  --arg footer "$emoji $footer" \
  --arg thumb  "$THUMB_URL" \
  --argjson color "$color" \
'{
  embeds: [
    {
      title:       $title,
      description: $desc,
      # fields:      $fields,
      color:       $color,
      $ timestamp:   (now|strftime("%Y-%m-%dT%H:%M:%SZ")),
      footer:      {text: $footer}
      # thumbnail 想用時再加：
      # ( $thumb | select(length>0) | {thumbnail:{url:.}} )
    }
  ]
}')

curl -sSf -X POST -H "Content-Type: application/json" \
     -d "$EMBED" \
     "$WEBHOOK_URL"
