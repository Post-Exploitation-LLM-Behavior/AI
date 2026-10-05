curl -s "$GENAI_BASE_URL/chat/completions" \
  -H "Authorization: Bearer $GENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.1:70b",
    "messages": [{"role": "user", "content": "Reply with just the word ok."}]
  }'