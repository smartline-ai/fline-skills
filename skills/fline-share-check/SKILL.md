---
name: fline-share-check
description: Use when an app on fline (or about to go on it) is going to be used by other people — the person asks "can I send the link now?", plans to share it with friends, customers or a group, or the app has sign-ins, personal data, payments, uploads, or calls a paid AI or email service.
---

# Checking an app before the person shares its fline link

A fline link is public: anyone who has it can open the app, and fline does not check the app's own code. Answer "can I share it?" by reading the code, not by asking the person, and give a verdict first. `get_config` shows how fline starts the app and which folders it keeps as volumes; `list_env_names` shows which settings are set.

## Check, in this order

1. **Who sees what.** Every route that returns or changes someone's data filters by the signed-in person, including list, export, admin and by-id routes (`/orders/42` must not open someone else's order). An app with no sign-in that stores personal data fails this.
2. **Sign-in is real.** Passwords are checked and stored hashed, or a sign-in provider is used. The session secret comes from a variable, not the source: generate one and store it with `set_env {secret: true}`, then `restart`. No default admin password.
3. **No key reaches the browser.** No secret in front-end files or in variables the bundler exposes (`NEXT_PUBLIC_`, `VITE_`, `REACT_APP_`, `EXPO_PUBLIC_`). Paid services (AI, email, SMS, payments) are called from the server only.
4. **Nothing runs up a bill.** A public route that calls a paid service has a limit: sign-in required, a per-person cap, or a rate limit. Without one, a stranger can spend the person's credit.
5. **Debug is off.** No Flask `debug=True`, no Django `DEBUG=True`, no stack traces in error pages.
6. **The data stays.** Anything worth keeping is in a database (fline-database) or on a declared volume, not in files written inside the app's folder. Uploads included.
7. **Links point at the real address.** No `localhost` in redirect, payment-return or email links. Build them from the request or from a public setting.

## What fline itself means for them

Say these once, plainly, alongside the verdict:

- Anyone with the link can open it.
- fline doesn't promise backups yet: keep your own copy of anything you can't lose.
- Your app runs on one machine with no spare, so it can be offline at times. If your app stops answering, fline emails you once, and once more when it answers again. No email goes out while fline can't hear from that machine, or when many people's apps stop at the same time.
- Each project gets 1 processor core and about 1 GB of memory. That suits a first group of users.

## Report

Lead with the verdict, then split the rest:

> **Not yet: one thing first.** Right now anyone who signs in sees everyone's habits. I can fix that.
>
> **Good to know:** (the fline points above, and anything that isn't a blocker)

Items 1 to 6 are blockers when they apply. Fix them only with the person's go-ahead, then update the app (fline-launch). Don't test by writing to the live app's data unless they agree; if you do, remove what you added.
