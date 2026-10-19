---
name: fline-diagnose
description: Use when a launch or update on fline failed, an app on fline shows errors, a blank page or won't load, keeps restarting, stopped answering (an email from fline, or `not_answering` in `app_health`), or says a key is missing, or when the person pastes text copied from their fline dashboard ("Copy for your AI", "failed at stage ...", healthcheck_failed, no_capacity).
---

# Finding out why a fline app failed

**Find the cause before changing anything.** Read in this order and stop when something explains the symptom; each step is cheaper than the next. fline's `diagnose_a_deployment` prompt is a slash command for the person, not something you can fetch; these are its steps.

1. `get_project`: `failure.stage` and the reason; for a live app, `app_health`.
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
| Stage `analyze` with a reason starting "the analysis answered, but its answer could not be used" | The model's answer couldn't be used | Upload again, which counts as a new analysis, or write `fline.json` (fline-build-plan) |
| A reason, or a `refresh_config` refusal, containing "This fline account has had its" | The account's fresh analyses for the month are spent | Don't retry or `refresh_config`. Write `fline.json`, or save it from `get_config` (fline-build-plan), and upload again: an upload carrying one that `check_config` accepts skips the analysis and isn't counted |
| Stage `provision`, a paused service | The database is paused | Ask the person, `resume_service`, upload again |
| Stage `build`: `build_command_failed`, `dependency_fetch_failed`, `dockerfile_syntax` | `build_commands`, the lockfile, or a path the start command doesn't match. fline has already rewritten its own build files once with this error and built again, so what's left is in the project | Read the first error in the build log. `COPY` source not found means a path in the plan doesn't exist in the folder |
| `build_timeout`, `image_too_large` | All services together took over 15 minutes, or an image is over 2 GiB. `image_too_large` has had fline's one automatic rebuild too | Fewer or lighter dependencies; no models or datasets in the image |
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
| Reason starts "fline is full right now", or stage `submit` with a reason starting `no_capacity` | fline is full | Stop. Don't retry now. Tell the person fline's sentence; suggest https://fline.sh/#contact |
| Reason starts "fline can't take new apps" or "fline can't put new versions online", or stage `submit` with a reason starting `node_not_ready` | fline is taking no new work | Stop. Don't retry now. Tell the person fline's sentence; suggest https://fline.sh/#contact |
| Class `internal_error`, `invalid_manifest`, `secrets_unavailable` or `converge_timeout` | fline's own side | Don't loop. Tell the person it's on fline's side and suggest the contact link |

## A live app that isn't answering

`app_health` (on `get_project` and `get_deploy_status`) is fline's check of the live app, a `GET` on `checked_path` from the machine it runs on. `not_answering` means a public service failed 3 checks in a row over at least 2 minutes. Text the person pastes from the email names the app, what fline saw, since when, and the path checked.

| `status` or `problem` | Means | Do |
|---|---|---|
| `paused` | fline is working on a new version, a restart or a move, or can't see the machine | nothing; check later |
| `checking` | no verdict yet | wait |
| "it keeps restarting", "it isn't running" | the process crashes at start or soon after | `get_project_detail` restart count, then the runtime log; often a missing setting or an unreachable database |
| "it didn't answer within 10 seconds" | it hangs: a blocked event loop, a slow call in the checked route, too few workers, or no memory | the runtime log while it lasts; keep the checked route free of database and outside calls |
| "it answered with an error (…)" | a server error | the runtime log has it |
| "it refused the connection" | nothing listens where fline routes | `0.0.0.0` and `PORT` (fline-prepare) |
| "it dropped the connection" | the process closed the connection before it answered, often a crash while handling the request | `get_project_detail` restart count, then the runtime log at that time |
| "it couldn't be reached" | fline couldn't connect for another reason, or couldn't tell why | `get_project_detail` to see it runs, then the runtime log; if both look fine, tell the person it may be on fline's side and suggest the contact link |
| `path_missing: true` | the `health_path` answered 404, 405 or 410, so fline checks `/` | fix the route, or correct `health_path` in `fline.json` (fline-build-plan) |

Fix it in the folder and upload again. A `restart` can clear a hang for a while; it doesn't fix the cause.

fline's check restarts and rolls back nothing; Docker restarts a crashed process as before.

## Tell the person

Once you know, say in one or two plain sentences what went wrong and what you're changing: "Your app was looking for its database on its own machine, so it stopped as it started. I'm changing it to use a database of its own on fline." Don't paste raw errors; offer the details if they want them. If an update broke a working app, offer to put the earlier version back while you fix it (fline-launch). Never promise the fix works before `get_deploy_status` shows it live and the address answers. If it was not answering, tell them fline emails them once more when it answers again.
