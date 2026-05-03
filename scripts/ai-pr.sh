#!/data/data/com.termux/files/usr/bin/bash
set -e

BRANCH="ai/$(date +%s)"

echo "[+] Creating branch $BRANCH"
git checkout -b "$BRANCH"

echo "[+] Running AI step (placeholder)..."

# OPTION A: manual prompt input
echo "Describe changes for AI:"
read PROMPT

# OPTION B: call an AI API (OpenAI/Claude/etc.)
# Replace with your API call if you have one
RESPONSE=$(curl -s https://api.openai.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d "{
    \"model\": \"gpt-4o-mini\",
    \"messages\": [
      {\"role\": \"user\", \"content\": \"$PROMPT\"}
    ]
  }")

echo "$RESPONSE" | jq .

echo "[+] You now manually apply changes or extend script to patch files"

git add -A
git commit -m "AI-assisted change (Termux workflow)"

git push -u origin "$BRANCH"

gh pr create \
  --title "AI: Termux automation update" \
  --body "Generated via Termux AI workflow" \
  --base main

echo "[+] Done"
