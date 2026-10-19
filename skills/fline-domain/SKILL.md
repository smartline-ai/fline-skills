---
name: fline-domain
description: Use when the person wants an app on fline at a web address they own (www.example.com, app.example.com, a bare example.com), asks which DNS record to add, or a domain on fline stays unverified, shows last_error, or is marked failed.
---

# Putting a fline app at the person's own web address

Every app already has a long address ending in `apps.dev.fline.sh`; that keeps working. A domain the person owns is attached to a live project, proven by one DNS record they add themselves, and then served with a certificate fline obtains and renews.

## Steps

1. Prefer a subdomain: `www` or `app`. A bare `example.com` is confirmed only when the domain is on Cloudflare; anywhere else, use `www`.
2. `attach_domain {project_id, domain}` with the full name.
3. `list_domains {project_id}`. Note `platform_name` (what the record points at), `challenge_name`, `challenge_token`.
4. Give the person one record, as a table, to add where they bought the name:

   | Type | Name | Value |
   |---|---|---|
   | CNAME | `www` | `<platform_name>` |

   - The Name is usually just `www`, without the domain after it. Typing the whole name gives a doubled one that leads nowhere.
   - On Cloudflare the record must be "DNS only" (grey cloud), not proxied.
   - If `platform_name` is null, or they can't add a CNAME: Type TXT, Name `<challenge_name>` without the domain after it, Value `<challenge_token>`. A TXT proves ownership but sends no visitors.
   - A name starting `_smartline-challenge` is fline's older name. Use it exactly as given.
   - On their fline dashboard, the app's Web address and usage tab shows the same record under the address, in their provider's own field names (Cloudflare, GoDaddy, Namecheap, Squarespace Domains, AWS Route 53, Another provider). Point them there rather than guessing a provider's screens.

   You cannot add the record. Ask them to tell you when it's saved, then wait.
5. fline checks by itself for 48 hours. After they say it's in, call `check_domain {project_id, hostname}`, then again every few minutes. Never in a tight loop: it is rate-limited. `last_error` says what the check saw. A new record taking a while to show up is normal; tell them so.
6. Status `active`: the padlock is set up. Give them the address and ask them to open it.

## When it doesn't verify

| Symptom | Do |
|---|---|
| `last_error` shows a different value | The record's Name or Value is off. Compare with step 4 and the dashboard's version for their provider. |
| Cloudflare domain, record present, not found | Proxy is on. Switch to DNS only. |
| Status `failed` (48 hours passed) | It never recovers. Fix the record, then `delete_domain` and `attach_domain` for another 48 hours. Don't call `check_domain` on a failed domain: it can't revive it, and it answers `domain_failed` or, from an older fline, an error that reads like an outage. |
| Bare domain not on Cloudflare | Use `www` instead. |

`delete_domain` takes the address off the project after asking the person; the long address keeps working.

## Say it plainly

"Your web address" until they need the record; then "one record at the company where you bought your address". Never promise how long it takes to show up.
