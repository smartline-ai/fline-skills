---
name: fline-database
description: Use when an app going on fline needs a database or cache, reads DATABASE_URL, REDIS_URL, DB_HOST or REDIS_HOST, keeps its data in SQLite or files on disk, uses Redis, Postgres, MySQL or MongoDB, already uses a hosted database elsewhere, or when fline stops at provisioning or says a managed service is paused.
---

# Giving a fline app a database

**Never invent a database address, never ask the person for one, and never `create_service` for a project before its launch.**

fline runs PostgreSQL 16 (offering `postgres`) and Valkey 8, a Redis-compatible cache (offering `valkey`). Each comes in one size, 1 GiB of memory and about 8 GiB of data. A database belongs to the person's account, outlives any project, and is reachable over TLS with its password. No tool ever returns its address or password.

## The path that wires itself

1. **Make the app read one connection-string variable**: `DATABASE_URL` for Postgres, `REDIS_URL` for Valkey. Remove separate host, port, user and password variables, fallbacks included. A leftover `DB_PASSWORD` is a name the analysis may ask the person to fill in, and they have nothing to type.
2. **Valkey accepts TLS only** and its URL starts `rediss://`. Pass the URL straight to the client (`createClient({ url })`, `new Redis(url)`, `redis.from_url(url)`). A client built from host and port must change to read the URL.
3. **The app creates its own tables.** Nobody can run SQL by hand. Run migrations or `CREATE TABLE IF NOT EXISTS` at startup, before the app starts listening. For more than one command, commit a start script (`start.sh` running the migration, then `exec` the server) and make that the start command.
4. **Mark the variable managed.** The analysis does this when the code hands the variable to a database client. In `fline.json` it is an `env_names` entry on the service that reads it, with no value:
   `{"name": "DATABASE_URL", "scope": "managed", "ref": "postgres"}`.
   Optional `"format"`, Postgres only: `"libpq"` (keyword string) or `"host_port"`; empty is the URL. Do not `declare_env_names` or `set_env` it.
5. **Launch or update as usual** (fline-launch). The project passes `provisioning`: fline reuses this project's database, or one in the account named `<project name>-postgres` (or `-valkey`), or creates one with that name, and writes the connection string into the variable.
6. **Check before you claim.** After provisioning, `list_env_names` should show the variable set. Only then tell the person: "Your app has a database of its own, and fline runs it." If it isn't set, or provisioning fails, use fline-diagnose. Don't type a URL in by hand.

## Other cases

| Situation | Do |
|---|---|
| Uses Redis from a compose file or `localhost:6379` | Managed Valkey through `REDIS_URL` (`rediss://`), as above. Never plan a Redis, Valkey or Postgres service of your own. |
| A database they already run elsewhere, such as a hosted Postgres or MongoDB | `attach_external {project_id, offering, variable?}`. Offering is `postgres`, `redis`, `mysql`, `mongodb` or `rabbitmq`; the default variable is `DATABASE_URL`, `REDIS_URL`, `MONGODB_URI` or `AMQP_URL`. Then `get_secrets_link`: they type the address there, never in the chat. |
| SQLite, or data in files | Either move it to Postgres as above, or keep the file on a volume: the app reads its data folder from a setting (`DATA_DIR`), `fline.json` declares a volume at that path (`/data`), and `set_env {name: "DATA_DIR", value: "/data", secret: false}`. A volume survives restarts and updates and is removed only with the project. Anything outside it is lost at every update. |
| MySQL | No managed MySQL. Attach an existing one, run the official image as a prebuilt service with a volume (fline-build-plan), or move the app to Postgres. |
| A database for its own sake, outside any project | `create_service {name, engine}`, then poll `get_service` until `active`. Nothing wires it in: the person copies its connection line from the Services page of their dashboard onto the `get_secrets_link` form. `list_services` first, to avoid making a second one. |
| Launch fails saying the database is paused | Ask the person, then `resume_service`, then upload again. |
| They want it gone | Ask first. Prefer `pause_service` (reversible). `delete_service` keeps the data seven days, then destroys it. |

## Tell the person, plainly

- "A database of its own", not managed Postgres, DSN or connection string. "A fast cache", not Valkey or Redis.
- fline doesn't promise backups, has no restore, and has no download button. Tell them to keep their own copy of anything they can't lose. Putting an earlier version back never changes what's in the database.
- They can limit which addresses may reach it under "Who may reach it" on the Services page.
