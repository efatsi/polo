# Crozet Bike Polo

Public site for the group's pickup games. It shows only whether there's a game and, if so, where
and when: "GAME ON, 6 in", "Pending, 3 in", or "No Game". No names or messages appear publicly.

Games are organized on the [crozetbikepolo groups.io list](https://groups.io/g/crozetbikepolo).
Every 15 minutes `SyncGroupsioJob` pulls recent threads from the groups.io API into Postgres.
When a thread has new messages, Claude (`GameExtractor`) reads it and fills in the date, time,
location (default Crozet Park, backup Beaver Creek Reservoir), status, and who's in or out.

Admins can correct anything at `/admin` (HTTP basic auth). An edited field is locked, and
Claude won't overwrite it until it's unlocked.

## Configuration

| Variable | Purpose |
|---|---|
| `GROUPSIO_API_KEY` | groups.io API key (https://groups.io/settings/apikeys) |
| `ANTHROPIC_API_KEY` | Claude API key, used to read threads |
| `ADMIN_PASSWORD` | Password for `/admin`; admin is disabled when unset |
| `ADMIN_USERNAME` | Optional, defaults to `admin` |
| `GROUPSIO_GROUP` | Optional, defaults to `crozetbikepolo` |
| `MCP_TOKEN` | Bearer token for the `/mcp` endpoint; MCP is disabled when unset (`ruby -rsecurerandom -e 'puts SecureRandom.hex(32)'`) |

Locally these go in `.env` (gitignored, loaded by dotenv).

## Development

```sh
bin/setup
bin/dev                          # web + tailwind + jobs (runs the 15-minute sync)
bin/rails groupsio:sync          # sync now (TOPICS=50 to go further back, EXTRACT=false to skip Claude)
bin/rails groupsio:reextract     # re-run Claude on every thread (GAME_ID=n for one)
```

## Deploying to Fly

```sh
# First time only (already done for crozet-bike-polo):
fly apps create crozet-bike-polo
fly postgres create --name crozet-bike-polo-db --region iad --initial-cluster-size 1 --vm-size shared-cpu-1x --volume-size 1
fly postgres attach crozet-bike-polo-db --app crozet-bike-polo --database-name polo_production
fly secrets set RAILS_MASTER_KEY=$(cat config/master.key) \
  GROUPSIO_API_KEY=... ANTHROPIC_API_KEY=... ADMIN_PASSWORD=... MCP_TOKEN=...
fly deploy --ha=false
fly ssh console -C "bin/rails groupsio:sync TOPICS=50"   # optional backfill
```

`fly.toml` runs Solid Queue inside Puma and keeps one machine always on, so the schedule keeps running.

## Asking Claude (MCP)

`/mcp` is an MCP server (Streamable HTTP, bearer-token auth) over the synced data, with the tools
`next_game`, `get_game`, `list_games`, `search_messages` and `sync_now`. Tool classes are in `app/mcp/`.

Add it to Claude Code at local scope, which keeps the token in `~/.claude.json` and out of the repo:

```sh
claude mcp add --transport http --scope local crozet-polo http://localhost:3000/mcp \
  --header "Authorization: Bearer $MCP_TOKEN"
```

For production, use the app's Fly URL and the `MCP_TOKEN` set in Fly secrets.
