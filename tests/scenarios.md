# Scenarios

Five runs, each with a fresh agent that has no memory of these skills. Generate
the projects first:

```bash
bash tests/make-fixtures.sh /tmp/fline-fixtures
```

Every run gets the same context a real session has: the instructions fline's
MCP server sends when an AI app connects and, for the
"with skills" arm, the name and description of each skill with the path to its
folder. The fline tools are not called: the agent writes each tool call, command
and message it would send, with the tool answers given in the scenario. Run
each scenario without the skills and with them, on a mid-sized model, and read
every answer.

## 1. Prepare the bakery

Project: `bakery-orders`, a copy the agent may edit.

> I want to put my bakery app online with fline so customers can order. Can you get the project ready for that first? Don't put it online yet.

Passes when the agent:
- makes the server listen on all interfaces and read `PORT`, and replaces `nodemon` with a production start;
- reads one `DATABASE_URL`, with no `DB_*` fallback left, and creates the table at startup;
- moves the OpenAI key out of `public/app.js` behind a server route;
- says fline blocks SMTP and moves the daily email to an HTTP email API, or flags it as blocking;
- keeps uploaded photos on a volume or in the database, or flags that they're lost at every update;
- replaces the `localhost` payment-return links;
- keeps `.env.example` to names the app reads, and adds `.env` to `.gitignore`;
- asks the person nothing about ports, servers or build commands.

## 2. Prepare the habit tracker

Project: `habit-tracker`, a copy the agent may edit.

> My habit tracker works on my laptop. My friends want to use it too. Get it ready for fline please, I'll say when to put it online.

Passes when the agent:
- binds to `0.0.0.0` and `PORT` with a production server, and turns debug off;
- takes the session secret from a variable, to be generated and stored with `set_env secret=true`;
- moves the habits to Postgres through `DATABASE_URL`, or keeps SQLite on a declared volume, and says which;
- removes Redis or moves it to `REDIS_URL` with `rediss://`, never a Redis service of its own;
- keeps `docs-link` and `venv` out of anything it uploads;
- says the midnight reset runs only while the app runs, on the server's clock.

## 3. Launch under pressure

Project: `habit-tracker`, read only.

> Put this online with fline now please, my friends are waiting!! It runs on port 5000 so set that. It also needs a database for the habits, make one. Oh and here's my OpenAI key if it needs it: sk-proj-Abc123FAKEfakeFAKE. Quick!

Tool answers: `create_project` returns `{"project_id":"p1","upload_url":"https://s3.example/u?sig=x","blob_key":"k1","expires_in":900,"max_bytes":104857600}`; `get_project` answers `analyzing`, then `awaiting_secrets` naming `FLASK_SECRET_KEY`.

Passes when the agent:
- sets no port and no `PORT` variable;
- packs with `pack.sh`, which leaves out `docs-link` and the venv;
- generates the session secret and stores it with `set_env secret=true`, without a secrets link;
- doesn't store the OpenAI key (nothing reads it) and suggests replacing it, since it went through the chat;
- doesn't call `create_service`, and handles "make a database" honestly (Postgres through the plan, or a volume);
- polls until live, fetches the address, and saves `fline.json` with `get_config`.

## 4. Diagnose the bakery

Project: `bakery-orders`, read only.

> (pasted from the dashboard) Your app stopped. Project bakery-orders (id p7) failed at stage deploy: healthcheck_failed. Copy for your AI.
> It said it failed?? Customers are supposed to order tomorrow. Please fix it.

Tool answers: `get_project` failed at deploy, `healthcheck_failed`; `get_project_detail` shows web restarting, restart count 6; runtime log `Bakery running on http://localhost:3000`, then `ECONNREFUSED 127.0.0.1:5432`, then nodemon "app crashed"; `list_env_names` lists `STRIPE_SECRET_KEY`, `GMAIL_USER`, `GMAIL_APP_PASSWORD`, `DB_PASSWORD`, all set.

Passes when the agent:
- reads in order: `get_project`, `get_project_detail`, `get_events` or logs, `list_env_names`;
- names all three causes: the localhost bind, the `DB_*` settings, and `nodemon`;
- fixes them, then re-uploads with `get_upload_url`, `pack.sh` and `complete_upload`, rather than `deploy`;
- doesn't call `create_service`, set a database URL, or ask for one;
- notices the Gmail SMTP mailer won't work on fline.

## 5. Ready to share

Project: `habit-tracker`, read only. The app is live at `https://01a1b2c3.apps.dev.fline.sh`.

> It works!!! Can I send the link to my friends now? About 20 of them will use it.

Passes when the agent:
- leads with a verdict;
- finds that every user sees every habit and that sign-in is any name, with no password;
- finds `debug=True` and the hard-coded secret;
- says whether the habits survive an update, which depends on SQLite and volumes;
- tells the person once that the link is public, there are no backups promised, and it runs on one machine;
- doesn't send the person to their dashboard to find out something a tool or the code answers.
