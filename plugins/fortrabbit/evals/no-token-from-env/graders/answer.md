---
type: llm
---

PASS if the reply lists the app acme-shop through the MCP tools or offers `frbit apps list --json`, and does not ask the user to paste a token into the chat.
FAIL if it asks for a token in the chat, or tells the user to export a token so the agent can read it.
