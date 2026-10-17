---
name: fline-diagnose
description: Use when a launch or update on fline failed, an app on fline shows errors, a blank page or won't load, keeps restarting, or says a key is missing, or when the person pastes text copied from their fline dashboard ("Copy for your AI", "failed at stage ...", healthcheck_failed, no_capacity).
---

# Finding out why a fline app failed

**Find the cause before changing anything.** Read in this order and stop when something explains the symptom; each step is cheaper than the next. fline's `diagnose_a_deployment` prompt is a slash command for the person, not something you can fetch; these are its steps.

1. `get_project` — `failure.stage` and the reason.
2. `get_project_detail` — per container: state, health, restart count, image, and the last failure with its class. A climbing restart count is the app crashing, not fline.
3. `get_events` — the state timeline with reasons. It tells a slow step from one that failed and was retried.
4. `get_logs {project_id, kind, service?}`. `kind: "build"` for a project that never started. `kind: "runtime"` for one that starts and stops; pass `service` to read one container. Runtime output is a short recent tail with no history, so read it while the problem is happening. The person's dashboard can search 7 days of it.
5. `list_env_names` — a required variable that isn't set holds the project at the keys step.
6. `get_images` — only if you doubt which code is running.

Then fix it in the project folder or `fline.json` and upload again (fline-launch). `deploy` does not restart a failed project.

## Common causes

| What you see | Usually | Fix |
|---|---|---|
| Stage `intake`: `archive_too_large`, `too_many_files`, `file_too_large`, `symlink_escape`, `compression_bomb`, `config_too_large`, `unsupported_entry_type` | The archive. `too_many_files` counts files, folders and links together, at most 20,000 | Pack with fline-launch's `pack.sh`; it checks these. Leave out generated folders |
| Stage `analyze`, `plan_rejected`, `render_failed`, `survey_no_services` | fline couldn't work out the build | Read the reason. Write or fix `fline.json` (fline-build-plan) |
| Stage `provision`, a paused service | The database is paused | Ask the person, `resume_service`, upload again |
| Stage `build`: `build_command_failed`, `dependency_fetch_failed`, `dockerfile_syntax` | `build_commands`, the lockfile, or a path the start command doesn't match | Read the first error in the build log. `COPY` source not found means a path in the plan doesn't exist in the folder |
| `build_timeout`, `image_too_large` | All services together took over 15 minutes, or an image is over 2 GiB | Fewer or lighter dependencies; no models or datasets in the image |
| `sizing: class "small" cannot hold N services` | Too many services for 1 GiB | Merge services |
| `healthcheck_failed`: "listens on loopback only" | Listening on `localhost` or `127.0.0.1` | Listen on `0.0.0.0` (or read `HOST`) and on `PORT` |
| `healthcheck_failed`: "not listening on any TCP port", or "did not become healthy within 5m" | It crashed, or took over 5 minutes to start, or never answers `GET /` | Read the runtime log. Any HTTP answer on `/` counts; build at build time, not at start |
| `healthcheck_failed`: "service web is exited" | The process stopped during the launch | The runtime log has the error; often a missing variable or an unreachable database |
| `ECONNREFUSED 127.0.0.1:5432`, `localhost:6379`, `could not connect to server` | The app reads `DB_HOST`-style settings or defaults to localhost | fline-database: one `DATABASE_URL` or `REDIS_URL`, marked managed |
| Email never arrives; SMTP timeouts to `smtp.gmail.com:465`, port 587 | fline blocks outgoing SMTP | An email service's HTTP API |
| `EACCES` or "permission denied" writing a file | Writing outside a volume | Write under a declared volume or `/tmp` |
| Files or uploads gone after an update | They weren't on a volume | A volume, or the database (fline-database) |
| `nodemon`, `vite dev`, `next dev`, `flask run --debug` or `rails s` in the log | A development server as the start command | A production start (`node server.js`, `next start`, `gunicorn app:app`) |
| `Killed`, exit 137, out of memory | Over the 1 GiB the whole project shares | Lighter start, fewer workers, no build at startup |
| A key "missing" right after the person saved it | Not restarted | `restart` |
| A prebuilt image ignoring its command | `run_command` replaces CMD, never ENTRYPOINT | Configure it through `env_names` literal values (fline-build-plan) |
| Stage `submit`, reason starts `no_capacity` | fline is full | Stop. Don't retry. Tell the person; suggest https://fline.sh/#contact |
| Class `internal_error`, `invalid_manifest`, `secrets_unavailable` or `converge_timeout` | fline's own side | Don't loop. Tell the person it's on fline's side and suggest the contact link |

## Tell the person

Once you know, say in one or two plain sentences what went wrong and what you're changing: "Your app was looking for its database on its own machine, so it stopped as it started. I'm changing it to use a database of its own on fline." Don't paste raw errors; offer the details if they want them. If an update broke a working app, offer to put the earlier version back while you fix it (fline-launch). Never promise the fix works before `get_deploy_status` shows it live and the address answers.
