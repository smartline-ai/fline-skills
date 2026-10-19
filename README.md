# fline skills

Skills that teach your AI coding app (Claude Code, Codex, Cursor and the other
apps that read Agent Skills) how to put your project online with
[fline](https://fline.sh). For Claude Code, the repository is also a plugin
that connects fline's MCP server.

## Install

| App | How |
|---|---|
| Claude Code, including the Claude desktop app's Code tab | `/plugin marketplace add smartline-ai/fline-skills`, then `/plugin install fline@fline` |
| Codex, Cursor, Gemini CLI, VS Code and others | `npx skills add smartline-ai/fline-skills` |
| By hand | Copy `skills/*` into `~/.claude/skills/` (Claude Code) or `~/.agents/skills/` (Codex and others) |

The Claude Code plugin brings fline's MCP server with it: type `/mcp`, choose
fline, then Authenticate, and approve fline in your browser. Installed any other
way, the skills carry no server; connect fline as the
[fline docs](https://fline.sh/docs) describe, or ask your AI app to, which
loads `fline-connect`.

You need a fline account. fline is in private beta: see
[Getting your account](https://fline.sh/docs/get-access).

## What it sends, and where

The skills are instructions; on their own they send nothing anywhere. What
leaves the computer goes through fline's MCP server at `https://mcp.fline.sh/mcp`,
and only when the person asks for something fline does:

- **The project folder.** `scripts/pack.sh` packs a copy of it as a `.tar.gz`,
  leaving out `.git`, `node_modules`, what the project's `.gitignore` ignores,
  and `.env` and key files, and the agent uploads it to fline's storage. fline keeps that copy so it can build and
  run the app. The original stays in the folder.
- **Parts of the code, to an AI model made by OpenAI,** so fline can work out how
  to build and run the app. Passwords and keys saved on fline never go to it.
- **Tool calls.** Project names, settings names, web addresses and the other
  arguments of fline's tools. Passwords and keys are typed by the person on a
  private fline page, not sent through the chat. The exception is a key the
  agent already holds, one it generated or one the person pasted into the
  chat: `set_env` sends that value to fline, which stores it and never shows
  it again.
- **What comes back.** Project state, build output and the app's recent log
  lines, which hold whatever the app prints.

Sign-in is OAuth in the browser; the plugin holds no key. Disconnecting in the
fline dashboard takes effect within 30 seconds. Details:
[privacy policy](https://fline.sh/privacy), [terms](https://fline.sh/terms),
[what fline does today](https://fline.sh/facts).

## Skills

| Skill | What it covers |
|---|---|
| [`fline-connect`](skills/fline-connect/SKILL.md) | Adding fline's MCP server to the AI app, the browser approval, and the account states that refuse every call |
| [`fline-prepare`](skills/fline-prepare/SKILL.md) | Reading a project for what stops it running on fline, and fixing it before the first upload |
| [`fline-launch`](skills/fline-launch/SKILL.md) | First launch, updates, settings, restarts and putting an earlier version back; bundles `scripts/pack.sh` |
| [`fline-database`](skills/fline-database/SKILL.md) | A Postgres or Valkey that fline creates and runs, a database the person already runs, SQLite and files on disk |
| [`fline-domain`](skills/fline-domain/SKILL.md) | A web address the person owns: the record, the checks, the 48-hour limit |
| [`fline-diagnose`](skills/fline-diagnose/SKILL.md) | What to read, in order, when a launch fails or a live app misbehaves, and the usual causes |
| [`fline-build-plan`](skills/fline-build-plan/SKILL.md) | `fline.json`: freezing the plan, editing it, `check_config`, several services, prebuilt images, volumes |
| [`fline-share-check`](skills/fline-share-check/SKILL.md) | What to check in the app before the person sends its public link to anyone |

They fall into three groups: using fline (connect, launch, database, domain,
diagnose), preparing a project for it (prepare, build-plan), and making it safe
to share (share-check).

## Why skills when the MCP server has prompts

fline's server ships seven prompts with these procedures. In Claude Code an MCP
prompt is a slash command the person types; the model has no tool to fetch one,
so the server's instructions point at procedures the agent cannot open. A skill
is loaded by the model itself when its description matches the task.

Skills name fline's tools without a prefix (`create_project`, not
`mcp__fline__create_project`): the prefix differs between a plugin-provided
server and one the person added.

## Layout

```
.claude-plugin/plugin.json        the plugin, including fline's MCP server
.claude-plugin/marketplace.json   a marketplace holding that one plugin
skills/<name>/SKILL.md            one directory per skill (Agent Skills format)
skills/fline-launch/scripts/      pack.sh, run by the agent, never read
tests/                            scenarios and the projects they run on
```

## Testing

- `claude plugin validate --strict .` checks the manifests.
- `bash skills/fline-launch/scripts/pack.sh <folder>` runs on the bash 3.2 and
  bsdtar that macOS ships, and on GNU tar.
- [`tests/scenarios.md`](tests/scenarios.md) holds five scenarios with what a
  passing answer does, run by a fresh agent with and without the skills.
  [`tests/make-fixtures.sh`](tests/make-fixtures.sh) writes the two seeded
  projects they run on: a Node shop and a Flask tracker.

## Where this comes from

Every fact here restates fline's own documentation, in particular
[for-ai.md](https://fline.sh/docs/for-ai.md). This repository is published
from fline's main repository; a change made only here is replaced by the next
publish.

## License

[MIT](LICENSE)
