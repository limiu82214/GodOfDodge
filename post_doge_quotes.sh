#!/usr/bin/env bash
set -Eeuo pipefail

# ===== 神學詮釋 API 函數 =====
get_theology() {
  local d1="$1"
  local d2="$2"

  # 這是你指定的 Prompt，已調整為直接接收 desc 內容
  local prompt="你現在是「Doge 之神」的首席大祭司，專門一本正經的講廢話。

你的任務：
將兩段語錄揉合為一段相關的諭言故事或神諭。

風格指南：
1. **無痕融合**：絕對禁止使用「」或任何括號來標註原話。請將原話直接作為句子的成分（如：主詞或動作）。
2. **關鍵字留存原則**：絕對不可抹除原句中的核心關鍵字（如：翊翔、台主、屁眼、甲、錢、或是特定的動作）。你必須「封神化」這些詞，例如「屁眼」不是變換掉，而是稱為「那不可言說的後方聖殿門戶（屁眼）」。
4. **一本正經地胡說八道**
5. 擴張性描述：遇到不雅或平凡的詞彙，必須使用至少五個字的華麗詞藻來包裹，但括號內須保留原詞以供識別。
6. 必須使用繁體中文。

輸出限制：
1. 50 字以內。
2. 嚴禁出現括號或引號。

示範：
輸入 1：翊翔在吃泡麵
輸入 2：台主很甲
輸出：受選者翊翔吞納著廉價的生命靈糧泡麵，這引動了位格極其男色傾向甲的台主降下恩寵。

輸入：
1. 「${d1}」
2. 「${d2}」"

# 2. 使用 jq 建構 JSON，包含降低安全過濾層級的設定 (Safety Settings)
  local payload
  payload=$(jq -n --arg msg "$prompt" '{
    contents: [{parts: [{text: $msg}]}],
    safetySettings: [
      { category: "HARM_CATEGORY_HARASSMENT", threshold: "BLOCK_NONE" },
      { category: "HARM_CATEGORY_HATE_SPEECH", threshold: "BLOCK_NONE" },
      { category: "HARM_CATEGORY_SEXUALLY_EXPLICIT", threshold: "BLOCK_NONE" },
      { category: "HARM_CATEGORY_DANGEROUS_CONTENT", threshold: "BLOCK_NONE" }
    ]
  }')

  # 3. 呼叫 API (使用 gemini-3-flash-preview)
  local response
  response=$(curl -s -X POST "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent?key=${SYS_GEMINI_API_KEY}" \
    -H 'Content-Type: application/json' \
    -d "$payload")

  # 呼叫 API 並直接用 jq 處理前綴
  echo "$response" | jq -r '
    if .candidates[0].content.parts[0].text then 
      .candidates[0].content.parts[0].text 
    else 
      冥思中，神諭未竟。" 
    end'
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
  "辦網路送神諭，電信沒說但你賺到了。"
  "願你 Google 打錯字也神準找出你想問的問題。"
  "願今天的你只中樂透，不中暑。"
  "願你的螢幕永遠無藍光，肩膀不酸痛。"
  "願每次打開冰箱，都有飲料在等你。"
  "願今晚的冷氣不只涼，還有一點浪漫。"
  "願你永遠搶得到演唱會門票。"
  "願你玩 Switch 不斷電，手把不滑手。"
  "願你手搖杯不加價，自動變大杯。"
  "願今日會議短到你都懷疑是不是取消了。"
  "願你一睡睡到自然醒，醒來還有一天假。"
  "願你的髮線永遠不後退，努力不白費。"
  "願路上的紅燈為你轉綠，人生也一路順。"
  "願外送員比你還急，食物永遠熱騰騰。"
  "願你開會只開五分鐘，薪水照領整天。"
  "願每次打開 YouTube，都是你想看的演算法。"
  "願你手機剩 1% 電也撐完一整集影集。"
  "願你點餐永不踩雷，每一口都像初戀。"
)

# =====  隨機挑一筆 quote  =====
TOTAL=$(jq length quotes.json)
(( TOTAL > 0 )) || { echo "quotes.json 無資料"; exit 1; }

# INDEX=$(shuf -i 0-$((TOTAL - 1)) -n 1)
INDEX=$(( ( $(date +%s) + $(od -An -N2 -i /dev/urandom) ) % TOTAL ))
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
  # INDEX=$(shuf -i 0-$((TOTAL - 1)) -n 1)
  INDEX=$(( ( $(date +%s) + $(od -An -N2 -i /dev/urandom) ) % TOTAL ))

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
# THUMB_URL=$(get_meme_url)
THUMB_URL=https://raw.githubusercontent.com/limiu82214/GodOfDodge/refs/heads/main/doge_thumbnail_80x80.png
color=$(( ((RANDOM<<15)|RANDOM) & 0xFFFFFF ))
theology=$(get_theology "$desc" "$desc2")

printf -v combined_desc '%s\n%s\n\n%s' "$desc" "$desc2" "$theology"
#printf -v combined_desc '%s\n%s' "$desc" "$desc2"
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
      # timestamp:   (now|strftime("%Y-%m-%dT%H:%M:%SZ")),
      footer:      {text: $footer}
      # thumbnail 想用時再加：      
    } + (if $thumb != "" then {thumbnail: {url: $thumb}} else {} end)
  ]
}')

curl -sSf -X POST -H "Content-Type: application/json" \
     -d "$EMBED" \
     "$WEBHOOK_URL"
