---
name: fline-connect
description: Use when the person wants to connect Claude Code, Codex, Cursor or another AI coding app to fline, when no fline tools are available yet, or when fline tool calls fail with 401, "waiting for approval", "never asked for access", "token owner is not provisioned", "not been granted access", or the app keeps asking to sign in to fline again.
---

# Connecting an AI coding app to fline

fline is driven through a remote MCP server at `https://mcp.dev.fline.sh/mcp` (HTTP, OAuth in the browser). Nothing works until it is connected and the person's account is open.

## Before connecting

The person needs all three, in this order:

1. A fline account that has been opened. During the private beta accounts are opened by hand; they get an email when theirs is.
2. Their email address confirmed with the code fline emailed them.
3. One visit to their fline dashboard, `https://app.dev.fline.sh`, in a browser. That visit creates their workspace; nothing else does, and you cannot do it for them.

## Connect

| App | Steps |
|---|---|
| Claude Code, and the Claude desktop app's Code tab | Run `claude mcp add --transport http --scope user fline https://mcp.dev.fline.sh/mcp`. The person then starts Claude Code, types `/mcp`, chooses fline, then Authenticate. The Code tab reads the same setup; restart the desktop app if fline doesn't show. |
| Codex | Append `[mcp_servers.fline]` and `url = "https://mcp.dev.fline.sh/mcp"` to `~/.codex/config.toml` (straight quotes), then `codex mcp login fline`, then `codex mcp list` to confirm. If login doesn't start, add `auth = "oauth"` under the same block. |
| Cursor, VS Code, Grok, Antigravity | Setup steps are on the person's dashboard. Not tested end to end with fline; say so. |
| ChatGPT, Claude on the web, the desktop app's Chat tab, Lovable, Bolt, Replit | Cannot put an app on fline: they can't send it a project folder. |

`claude mcp add` changes the person's settings for every folder. Say what it does, then run it, or give it to them to paste. `/mcp` is theirs to type: you cannot.

In the browser the person signs in to fline, then sees an approval page with a box per permission. Tell them to approve only if they started this a moment ago, tick every box (fline needs all of them), and press Allow. The page looks plainer than the rest of fline; that's expected.

Check the connection with `list_projects`. An empty list means it works.

## When tool calls are refused

Every call returns 401 until the account is ready. Read the message and relay it plainly. Do not loop on signing in again: it changes nothing.

| Message begins | Tell the person |
|---|---|
| `this account is waiting for approval` | Their account isn't open yet. They'll get an email when it is. |
| `this account has never asked for access` | Sign in at the dashboard once and confirm their email with the emailed code. |
| `token owner is not provisioned` | Open `https://app.dev.fline.sh` once in a browser, then try again. |
| `this account has not been granted access` | fline declined it; they can write via the contact links at `https://fline.sh/#contact`. |
| `insufficient_scope` | A permission box was unticked. Authenticate again and tick every box. |

Other causes of "keeps asking to sign in": an old dashboard line connected fline to one folder only (re-add with `--scope user`), or the browser approval was closed before it finished.

## After connecting

The person can disconnect any AI app from the Agents page of their dashboard; it takes effect within 30 seconds and their app keeps running. To put a project online next, use fline-launch.
