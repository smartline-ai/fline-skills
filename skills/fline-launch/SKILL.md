---
name: fline-launch
description: Use when the person asks to put a project online with fline ("put this online with fline", "deploy to fline", "publish it", "make it live"), to update an app already on fline with new changes, to restart it so a new key or setting takes effect, or to put an earlier version back after a bad update.
---

# Putting an app online with fline, and keeping it there

**Rules that hold every time:** never ask which port the app uses (fline sets `PORT`); never ask the person to paste a password or key into the chat (use `get_secrets_link`); never write a Dockerfile for fline (it writes its own); never invent a database address.

fline builds and runs a project from a `.tar.gz` of its folder. You pack and upload it, then follow the project's state until it has an address. The step-by-step prompts fline's server names (`deploy_a_repository`, `update_a_live_app`) are slash commands for the person, not something you can fetch; this skill carries their steps.

Project never checked against fline? Use fline-prepare first. A failed build costs more than five minutes of checking.

## First launch

1. Tell the person: "I'm sending a copy of your project folder to fline. The original stays on your computer."
2. `create_project {name}`. Keep `project_id`, `upload_url`, `blob_key`.
3. Pack with the script bundled with this skill: `bash ${CLAUDE_SKILL_DIR}/scripts/pack.sh <project folder>` (outside Claude Code, `scripts/pack.sh` in this skill's folder). Its last line is `ARCHIVE=<path>`. Exit 1 means fline would refuse the archive; fix each `BLOCKED` line and run it again. A `WARNING` names a file with a live key in it: tell the person, move the key out, and suggest they replace it.
4. `curl -sS -T "<archive>" "<upload_url>"`, with no extra headers. The link lasts 15 minutes; `get_upload_url {project_id}` gives a fresh one.
5. `complete_upload {project_id, blob_key}`. Until then fline doesn't see the upload.
6. Poll `get_project` every few seconds. Its `next_action` says what to do; in short:

| State | Do |
|---|---|
| `analyzing`, `provisioning`, `rendering`, `building` | Wait. Nothing is asked of anyone. |
| `awaiting_answers` | `answer_questions` from the sources. Ask the person only what only they know. |
| `awaiting_secrets` | See Passwords and keys below. |
| `locked` | `deploy {project_id}`. |
| `submitted` | Poll `get_deploy_status` until runtime is live/healthy and `url` is set. |
| `failed` | Use fline-diagnose. `deploy` does not restart a failed project; a new upload does. |
| warning `committed_secret` on `.env.example`, `.env.sample`, `.env.template` or `.env.defaults` | The file holds a key, or is over 8 KiB. One with only names or placeholders gets no warning. Take the real values out, keep the file, upload again, and treat those keys as exposed. |
| warning `committed_secret` on any other file | That file held a key and still went into the build. Tell the person which file, take the key out, upload again, and suggest they replace the key with a fresh one. |
| error `fline_full`, or a message or failure reason starting "fline is full right now", or failure `no_capacity` at stage `submit` | fline is full. Don't retry now. Tell the person fline's sentence and suggest writing via https://fline.sh/#contact. |
| error `fline_not_taking_apps`, or a message or failure reason starting "fline can't take new apps" or "fline can't put new versions online", or failure `node_not_ready` at stage `submit` | fline is taking no new work. Don't retry now. Tell the person fline's sentence and suggest writing via https://fline.sh/#contact. |

7. Fetch the url yourself (`curl -sS -o /dev/null -w '%{http_code}' <url>`) to see it answers. Then give it to the person; it's also on their fline dashboard.
8. `get_config` and save the answer as `fline.json` at the top of the project folder, so later updates follow the same plan. See fline-build-plan.

## Passwords and keys

At `awaiting_secrets`, sort each missing name (`list_env_names`), and add any the analysis missed with `declare_env_names`:

- **A key only the person has** (Stripe, OpenAI, an email service): `get_secrets_link`, and give them the url exactly as returned, without opening it. Say what goes in each box and where they find it ("your Stripe secret key: in Stripe, under Developers, API keys"). It works once, for 10 minutes, while they're signed in to fline. Used or expired: make another.
- **A value you can make yourself** (a session secret): generate it (`openssl rand -hex 32`), store it with `set_env {secret: true}`, and never show it. A key the person already pasted into the chat goes in the same way; suggest they replace it with a fresh one through the link.
- **A public setting** (a folder path, a model name, the owner's email address once they've told you): `set_env {secret: false}`. Names ending in KEY, TOKEN, SECRET, PASSWORD, PASS, PWD, CREDENTIAL(S) or DSN are refused as plain settings.
- Never set `PORT`, `HOST` or a variable fline fills for a managed database.
- A value set while the app is live reaches it only after `restart {project_id}`.

## Updating an app that is online

1. Make the change. If `fline.json` exists and the change affects how the app is built or started, edit it and `check_config` until ok.
2. `get_upload_url`, pack, PUT, `complete_upload`. While a build is running `complete_upload` is refused: poll `get_deploy_status` until it leaves building, then retry with the same `blob_key`.
3. Follow the same states as a first launch. The live version keeps running while the new one is prepared. In code an update that can't be built leaves it running too, but that hasn't been tested live, so don't promise it. A new version that is built but fails to start stays failed: nothing puts the old one back by itself, so offer to put the earlier version back (below) while you fix it.

A setting only, no new code: `set_env`, then `restart`. `restart` never picks up new code; only an upload does.

## Putting an earlier version back

`list_versions`, pick the last good `state_version`, `rollback {project_id, to}`, poll `get_deploy_status`. Tell the person "I put the earlier version back", and get these right: the version number goes up, not back (rolling back to 3 can make version 12); current passwords and keys stay; the database is not rolled back; their project folder still holds the newer code, so fix it there before the next update. The person can do the same themselves: on their dashboard, the app's History tab has "Put this version back" on every version but the one online.

## Say it plainly

"Put it online", not deploy. "Passwords and keys your app uses", not secrets or env vars. "Your fline dashboard", not console. "What went wrong", not logs. "Put an earlier version back", not rollback. One or two sentences at each step that matters. Never promise uptime, backups, how long it takes, or that a fix will work. Something only they can do (a value on the private page, a dashboard visit): say exactly what and where, then wait.

## Common mistakes

| Mistake | Instead |
|---|---|
| Hand-rolled `tar` that includes `.env`, `node_modules` or macOS `._` files, or follows a link out of the folder | `scripts/pack.sh` |
| `create_service` before launch "so the app has a database" | fline-database: the plan wires it |
| Setting `PORT` because the person named one | Make the code read `PORT`; set nothing |
| Asking the person to check their dashboard for a fact a tool returns | Call the tool |
| Stopping at `building` or `submitted` | Poll until live, then fetch the url |
| Telling the person it's live before `get_deploy_status` says so | Wait for live/healthy and a url |
