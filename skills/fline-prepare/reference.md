# Start commands and bind addresses by framework

fline sets `PORT=8080` and, on services it builds, `HOST=0.0.0.0`, and routes whichever non-loopback port the process opens. A start command that listens on all interfaces works even with a fixed port; one bound to `localhost` never does.

| Framework | Listens correctly when | Production start | Also check |
|---|---|---|---|
| Node, Express, Fastify, Koa | `listen(process.env.PORT \|\| 3000)` with no host, or host `0.0.0.0`. Fastify defaults to localhost: pass `host: '0.0.0.0'` | `node server.js` | `app.set('trust proxy', 1)` for secure cookies and correct `https` links |
| Next.js | `next start` reads `PORT` and listens on all interfaces | build `next build`, start `next start` | Secrets only in server code; anything `NEXT_PUBLIC_` is visible to visitors |
| Vite, React, Vue single-page apps | No server of its own: never `vite dev` or `vite preview` | build to `dist/`, start a small committed server file that serves `dist/` and falls back to `index.html` | `VITE_` variables are baked into the bundle and visible to visitors |
| SvelteKit (adapter-node), Nuxt, Astro (node standalone) | They read `HOST` and `PORT` | `node build`, `node .output/server/index.mjs`, `node ./dist/server/entry.mjs` | The adapter must be the Node one, not a serverless one |
| Flask | `gunicorn` binds `0.0.0.0:$PORT` when `PORT` is set | `gunicorn app:app` (add `gunicorn` to requirements) | No `debug=True`; secret key from a variable |
| FastAPI | `uvicorn main:app --host 0.0.0.0 --port 8080` | the same | Add `uvicorn` to requirements |
| Django | `gunicorn <project>.wsgi` | the same; `collectstatic` as a build command | `DEBUG=False`; `ALLOWED_HOSTS` includes `.apps.dev.fline.sh` and the person's own domain; `CSRF_TRUSTED_ORIGINS` with `https://`; `SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")`; static files served by WhiteNoise |
| Rails | `bundle exec puma` reads `PORT` and listens on all interfaces | the same, `RAILS_ENV=production` | `SECRET_KEY_BASE` generated and stored with `set_env {secret: true}`; assets precompiled as a build command |
| Go `net/http` | `http.ListenAndServe(":"+os.Getenv("PORT"), h)` | the built binary | Fall back to `8080` when `PORT` is empty |
| Streamlit | `--server.address 0.0.0.0 --server.port 8080` | `streamlit run app.py --server.address 0.0.0.0 --server.port 8080` | Keys in `st.secrets` files move to variables |
| Gradio | `launch(server_name="0.0.0.0", server_port=int(os.environ.get("PORT", 7860)))` | `python app.py` | `share=True` is not needed online |

A small static server for a single-page app, committed as `server.mjs`, with `express` added to `dependencies`:

```js
import express from 'express';
import path from 'node:path';

const dist = path.resolve('dist');
const app = express();
app.use(express.static(dist));
app.use((req, res) => res.sendFile(path.join(dist, 'index.html')));
app.listen(process.env.PORT || 8080);
```

Build command `npm run build`, start `node server.mjs`.

## A health route by framework

Once the app is live, fline sends a `GET` to the public service's health path, or to `/` when it has none, with `User-Agent: fline-app-check/1`, `X-Forwarded-Proto: https` and the app's own fline address as `Host`. 2xx, 3xx and 4xx other than 404, 405 or 410 count as answering. A 404, 405 or 410 makes fline check `/` instead. A 5xx, or no answer within 10 seconds, counts as not answering. Register it before any sign-in or rate-limit middleware.

| Framework | Route | Path |
|---|---|---|
| Express | `app.get('/healthz', (req, res) => res.type('text').send('ok'))` | `/healthz` |
| Fastify | `app.get('/healthz', async () => 'ok')` | `/healthz` |
| Koa (`@koa/router`) | `router.get('/healthz', ctx => { ctx.body = 'ok' })` | `/healthz` |
| Hono | `app.get('/healthz', c => c.text('ok'))` | `/healthz` |
| Next.js app router | `app/healthz/route.ts` with `export const dynamic = 'force-dynamic'` (needed on 14 or earlier) and `export function GET() { return new Response('ok') }` | `/healthz` |
| Next.js pages router | `pages/api/health.ts` | `/api/health` |
| SvelteKit | `src/routes/healthz/+server.ts` with `export const GET = () => new Response('ok')` | `/healthz` |
| Flask | `@app.get('/healthz')` returning `'ok'` | `/healthz` |
| FastAPI | the same, with `PlainTextResponse('ok')` | `/healthz` |
| Django | `path('healthz', lambda request: HttpResponse('ok'))` in `urls.py`; `ALLOWED_HOSTS` as in the table above | `/healthz` |
| Rails 7.1+ | the generated `get "up" => "rails/health#show"`; keep it | `/up` |
| Laravel 11 | `health: '/up'` in `bootstrap/app.php`; keep it | `/up` |
| Spring Boot | the actuator's `/actuator/health` also checks the database by default, so set `management.endpoint.health.probes.enabled=true` and `"health_path": "/actuator/health/liveness"` in fline.json | `/actuator/health/liveness` |
| ASP.NET | `builder.Services.AddHealthChecks();` and `app.MapHealthChecks("/healthz");` with no checks added | `/healthz` |
| Go `net/http` | `mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) { w.Write([]byte("ok")) })` | `/healthz` |
