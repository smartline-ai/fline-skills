---
name: fline-prepare
description: Use before a project's first launch on fline, when the person asks to get an app ready for fline, hosting or "going online", or when an app that works on their computer needs checking for what will break once it runs on a server (localhost, ports, database settings, files saved to disk, scheduled jobs, email, keys in the code).
---

# Getting a project ready for fline

**Read the project; don't ask the person.** They usually can't answer questions about ports, servers or build commands, and the folder can. Fix what stops it running on fline, then tell them in plain words what changed and what they'll need to have ready.

## How fline runs an app

- fline reads the source with an AI model and writes its own build files. A Dockerfile or compose file in the project is read as a hint only and never run.
- Each service is either built from a folder and started with one command, or a prebuilt public image. A service may be public (gets the address) or internal (a worker, an API its siblings call by name).
- Every container gets `PORT=8080`; built ones also get `HOST=0.0.0.0`. fline routes whichever non-loopback port the process opens.
- A public service is healthy once `GET /` gets any HTTP answer (404 and 500 count) within 5 minutes. A process that exits is restarted; one that exits during a launch fails it.
- Once live, fline checks each public service again every 30 seconds: `GET` on its health path, or `/` when it has none. If the app stops answering, fline emails the person once, and once more when it answers again.
- The app runs as an unprivileged user and each launch starts a fresh copy. Write only to a declared volume or `/tmp`; only volumes are kept.
- The whole project shares 1 CPU core, 1 GiB of memory and 8 GiB of disk.

## Check each of these

| Check | Look for | Fix |
|---|---|---|
| Listens outward | `listen(..., 'localhost')`, `127.0.0.1`, Flask `app.run()` without `host`, `vite preview` | Listen on `0.0.0.0` (or read `HOST`) and on `PORT`. Internal services siblings call must listen on `PORT`: fline points them at port 8080. |
| Production start | `nodemon`, `vite dev`, `next dev`, `flask run --debug`, `debug=True` | A production start: `node server.js`, `next start`, `gunicorn app:app`. A single-page app is built, then served as static files by a small committed server file or a static server it already depends on. |
| Starts on its own | A start that needs a person, a migration someone runs by hand, `sleep` waiting for a database | Migrations run at startup. Connections to a database retry, because sibling services are only started first, not waited for. |
| Health check | A route such as `/healthz`, `/health`, `/up`, `/ping`, and what it calls | One cheap `GET /healthz` on the public service, or the framework's own path (Rails 7.1+ and Laravel 11 `/up`, ASP.NET `MapHealthChecks`, Spring Boot in reference.md). It answers 200 with `ok` well under a second. No sign-in, rate limit, host allowlist or forced HTTPS redirect on that path, and no database or outside call. fline finds it in the code; an unusual path goes in `fline.json` as `health_path` (fline-build-plan). reference.md has one per framework. |
| One start command | `sh -c "...$PORT..."` written by hand, `node -e "..."` | Commit a script (`start.sh`) and start that. `$PORT` doesn't expand in a plain command list. Keep scripts executable. |
| Lockfile | `package.json` with no lockfile, unpinned `requirements.txt` | Generate the lockfile locally (`npm install --package-lock-only`, `uv lock`, `poetry lock`). fline picks the package manager from the lockfile's name. |
| Database and cache | `DB_HOST`/`DB_USER`/`DB_PASSWORD`, `REDIS_HOST`, a Postgres or Redis service in compose, `localhost:5432` | One `DATABASE_URL` or `REDIS_URL`; Redis must accept a `rediss://` URL. See fline-database. |
| Files it keeps | SQLite files, `uploads/`, writes beside the code | Store it in a database, or write under one directory fline keeps as a volume (fline-build-plan). Read the directory from a setting such as `DATA_DIR`, then `set_env {name: "DATA_DIR", value: "/data", secret: false}`. |
| Email | SMTP: `nodemailer` with `smtp.gmail.com`, `smtplib`, ports 25, 465, 587, 2525 | fline blocks outgoing SMTP. Use an email service's HTTP API (Resend, Postmark, SendGrid, Mailgun) with its key. |
| Scheduled work | `node-cron`, APScheduler, `celery beat`, a crontab | fline runs nothing on a timer. A scheduler inside the always-running app works while it runs, on the server's clock. Say so; never promise exact timing. |
| Settings it reads | Every `process.env.X`, `os.environ[...]`, `.env.example` | Each name the app reads becomes something fline must fill or ask for. Delete reads it no longer uses. Keep `.env.example` to names only, no real values, nothing the app doesn't read. |
| Keys in the code | Keys in source, a committed `.env`, keys in browser files (`NEXT_PUBLIC_`, `VITE_`) | Move them to variables. Front-end code calls the app's own server, which holds the key. Add `.env` to `.gitignore`. Tell the person which keys to replace. |
| Links to itself | `http://localhost:3000` in redirect, payment-return, email or OAuth-callback links | Read the app's address from one variable (`PUBLIC_URL`, `BASE_URL`, `NEXTAUTH_URL`) used only for that; fline fills it with the app's address (fline-build-plan). Or build links from the request, trusting `X-Forwarded-Proto`: fline's proxy handles HTTPS and the app sees plain HTTP. |
| Cookie names | Cookies named `ory_kratos_session`, `ory_kratos_continuity` or `csrf_token_<hex>` | Rename them: fline's proxy strips those on its own addresses. |
| Size | Media, datasets or models over 32 MiB, or over 100 MiB in all | Leave them out or host them elsewhere. The pack script refuses them. |
| Unusual stack | `composer.json`, `Pipfile`, `setup.py`, Gradle, .NET, Elixir, Deno | fline reads these poorly. Plan to write `fline.json` by hand (fline-build-plan). |

Run the app locally after changing it, if you can. Then use fline-launch.

## Tell the person

One short list of what changed, in their words ("it now answers visitors from the internet", "photos are now kept between updates"). Then what they'll need when it goes online: each key by name, the service it comes from, and where in that service it lives. No ports, no build commands, no questions you could answer from the folder.

[reference.md](reference.md) has the start command and bind address for common frameworks.
