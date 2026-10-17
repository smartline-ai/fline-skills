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
