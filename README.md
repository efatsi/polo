# Crozet Bike Polo

Public site for the group's pickup games: the next game at `/` and past games at `/games`.

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
fly launch --no-deploy           # keep the existing fly.toml; attach a Postgres database
fly secrets set RAILS_MASTER_KEY=$(cat config/master.key) \
  GROUPSIO_API_KEY=... ANTHROPIC_API_KEY=... ADMIN_PASSWORD=...
fly deploy
fly ssh console -C "bin/rails groupsio:sync TOPICS=50"   # optional backfill
```

`fly.toml` runs Solid Queue inside Puma and keeps one machine always on, so the schedule keeps running.
