# groups.io MCP server

Read-only MCP server for the crozetbikepolo groups.io archive.

Tools:
- `list_topics`: recent threads, newest activity first
- `get_thread`: all messages in a thread with quoted history stripped (defaults to the latest thread)
- `search_messages`: full-text archive search

Setup:
1. Create an API key at https://groups.io/settings/apikeys and add it to the repo-root `.env` (gitignored):
   `GROUPSIO_API_KEY=<key>`
2. `cd mcp/groupsio && npm install`
3. Restart Claude Code in the repo root; it picks up `.mcp.json` (approve the server when prompted).

Optional `.env` / env vars: `GROUPSIO_GROUP` (default `crozetbikepolo`), `GROUPSIO_TZ` (default `America/New_York`).
