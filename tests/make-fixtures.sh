#!/usr/bin/env bash
# make-fixtures.sh: writes the two seeded test projects the scenarios run on.
#
# Usage: bash make-fixtures.sh DIR
#
# DIR/bakery-orders: Node, Express, Postgres through DB_* variables, a .env
#   committed to git, an OpenAI key in browser code, uploads on disk, Gmail
#   SMTP, node-cron, nodemon as the start, localhost links, no lockfile.
# DIR/habit-tracker: Flask on app.run(debug=True), SQLite in the folder, Redis
#   by host and port, a compose Redis service, APScheduler, a hard-coded
#   session secret, every user's rows shown to everyone, a venv, and a symlink
#   to a folder outside the project. Not a git repository.
#
# Fake keys are assembled at run time: secret scanners refuse a push that
# carries a key-shaped string.

set -eu
out="${1:?usage: bash make-fixtures.sh DIR}"
mkdir -p "$out"
cd "$out"
live="sk_""live_"
proj="sk-""proj-"

rm -rf bakery-orders habit-tracker
mkdir -p bakery-orders/public bakery-orders/uploads habit-tracker/templates habit-tracker/venv/lib

cat > bakery-orders/package.json <<'EOF'
{
  "name": "bakery-orders",
  "version": "1.0.0",
  "main": "server.js",
  "scripts": {
    "start": "nodemon server.js"
  },
  "dependencies": {
    "express": "^4.19.2",
    "pg": "^8.11.3",
    "multer": "^1.4.5-lts.1",
    "node-cron": "^3.0.3",
    "stripe": "^14.0.0",
    "nodemailer": "^6.9.8",
    "dotenv": "^16.4.5"
  },
  "devDependencies": {
    "nodemon": "^3.1.0"
  }
}
EOF

cat > bakery-orders/server.js <<'EOF'
require('dotenv').config();
const express = require('express');
const { Pool } = require('pg');
const multer = require('multer');
const cron = require('node-cron');
const nodemailer = require('nodemailer');
const Stripe = require('stripe');

const stripe = Stripe(process.env.STRIPE_SECRET_KEY);
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'bakery',
});

const upload = multer({ dest: 'uploads/' });
const app = express();
app.use(express.json());
app.use(express.static('public'));
app.use('/uploads', express.static('uploads'));

app.get('/api/orders', async (req, res) => {
  const { rows } = await pool.query('SELECT * FROM orders ORDER BY created_at DESC');
  res.json(rows);
});

app.post('/api/orders', upload.single('photo'), async (req, res) => {
  const { name, cake, email } = req.body;
  const photo = req.file ? req.file.filename : null;
  await pool.query('INSERT INTO orders (name, cake, email, photo) VALUES ($1,$2,$3,$4)', [name, cake, email, photo]);
  res.json({ ok: true });
});

app.post('/api/checkout', async (req, res) => {
  const session = await stripe.checkout.sessions.create({
    mode: 'payment',
    line_items: [{ price: req.body.priceId, quantity: 1 }],
    success_url: 'http://localhost:3000/thanks.html',
    cancel_url: 'http://localhost:3000/',
  });
  res.json({ url: session.url });
});

const mailer = nodemailer.createTransport({
  host: 'smtp.gmail.com', port: 465, secure: true,
  auth: { user: process.env.GMAIL_USER, pass: process.env.GMAIL_APP_PASSWORD },
});

cron.schedule('0 7 * * *', async () => {
  const { rows } = await pool.query("SELECT * FROM orders WHERE created_at > now() - interval '1 day'");
  await mailer.sendMail({ to: 'owner@example.com', subject: 'Daily orders', text: JSON.stringify(rows, null, 2) });
});

app.listen(3000, 'localhost', () => console.log('Bakery running on http://localhost:3000'));
EOF

cat > bakery-orders/schema.sql <<'EOF'
CREATE TABLE IF NOT EXISTS orders (
  id SERIAL PRIMARY KEY, name TEXT, cake TEXT, email TEXT, photo TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
EOF

cat > bakery-orders/.env <<EOF
STRIPE_SECRET_KEY=${live}51FAKEFAKEFAKEFAKEnotarealkey000000
GMAIL_USER=bakery@example.com
GMAIL_APP_PASSWORD=abcd efgh ijkl mnop
DB_PASSWORD=postgres
OPENAI_API_KEY=${proj}FAKEFAKEFAKE
EOF

cat > bakery-orders/public/index.html <<'EOF'
<!doctype html><html><body><h1>Order a cake</h1><form id="f"><input name="name"><input name="cake"><input name="email"><input type="file" name="photo"><button>Order</button></form><div id="idea"></div><script src="app.js"></script></body></html>
EOF

cat > bakery-orders/public/app.js <<EOF
const OPENAI_KEY = '${proj}FAKEFAKEFAKE';
async function cakeIdea() {
  const r = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: { 'Authorization': 'Bearer ' + OPENAI_KEY, 'Content-Type': 'application/json' },
    body: JSON.stringify({ model: 'gpt-4o-mini', messages: [{ role: 'user', content: 'Suggest a cake' }] }),
  });
  document.getElementById('idea').textContent = (await r.json()).choices[0].message.content;
}
cakeIdea();
document.getElementById('f').onsubmit = async (e) => { e.preventDefault(); await fetch('/api/orders', { method: 'POST', body: new FormData(e.target) }); };
EOF

echo "photo" > bakery-orders/uploads/cake1.jpg
printf '# Bakery orders\nRun `npm install` then `npm start`. Needs a local Postgres with the schema in schema.sql.\n' > bakery-orders/README.md
printf 'node_modules\n' > bakery-orders/.gitignore
(cd bakery-orders && git init -q && git add -A && git -c user.email=fixture@example.com -c user.name=fixture commit -qm init)

cat > habit-tracker/app.py <<'EOF'
import os, sqlite3
from flask import Flask, render_template, request, redirect, session
import redis
from apscheduler.schedulers.background import BackgroundScheduler
from dotenv import load_dotenv

load_dotenv()
app = Flask(__name__)
app.secret_key = "dev-secret-change-me"

cache = redis.Redis(host=os.environ.get("REDIS_HOST", "localhost"), port=int(os.environ.get("REDIS_PORT", 6379)))
DB = "habits.db"

def db():
    conn = sqlite3.connect(DB)
    conn.execute("CREATE TABLE IF NOT EXISTS habits (id INTEGER PRIMARY KEY, user TEXT, name TEXT, done INTEGER DEFAULT 0)")
    return conn

@app.route("/")
def index():
    user = session.get("user")
    if not user:
        return redirect("/login")
    rows = db().execute("SELECT id, name, done FROM habits").fetchall()
    return render_template("index.html", habits=rows, user=user)

@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        session["user"] = request.form["user"]
        return redirect("/")
    return render_template("login.html")

@app.route("/add", methods=["POST"])
def add():
    conn = db(); conn.execute("INSERT INTO habits (user, name) VALUES (?, ?)", (session["user"], request.form["name"])); conn.commit()
    cache.delete("stats")
    return redirect("/")

def reset_daily():
    conn = db(); conn.execute("UPDATE habits SET done = 0"); conn.commit()

sched = BackgroundScheduler()
sched.add_job(reset_daily, "cron", hour=0)
sched.start()

if __name__ == "__main__":
    app.run(debug=True)
EOF

printf 'flask\nredis\napscheduler\npython-dotenv\n' > habit-tracker/requirements.txt
cat > habit-tracker/templates/index.html <<'EOF'
<h1>{{ user }}'s habits</h1><ul>{% for h in habits %}<li>{{ h[1] }}</li>{% endfor %}</ul><form method=post action=/add><input name=name><button>Add</button></form>
EOF
cat > habit-tracker/templates/login.html <<'EOF'
<form method=post><input name=user placeholder="Your name"><button>Sign in</button></form>
EOF
cat > habit-tracker/docker-compose.yml <<'EOF'
services:
  web:
    build: .
    ports: ["5000:5000"]
    depends_on: [redis]
  redis:
    image: redis:7
    ports: ["6379:6379"]
EOF
printf 'FROM python:3.12\nWORKDIR /app\nCOPY . .\nRUN pip install -r requirements.txt\nCMD ["python", "app.py"]\n' > habit-tracker/Dockerfile
printf 'REDIS_HOST=localhost\nREDIS_PORT=6379\n' > habit-tracker/.env.example
if command -v python3 >/dev/null 2>&1; then
  python3 -c "import sqlite3; c = sqlite3.connect('habit-tracker/habits.db'); c.execute('CREATE TABLE habits (id INTEGER PRIMARY KEY, user TEXT, name TEXT, done INTEGER DEFAULT 0)'); c.execute(\"INSERT INTO habits (user, name) VALUES ('ana', 'Run')\"); c.commit()"
fi
dd if=/dev/zero of=habit-tracker/venv/lib/blob bs=1024 count=2048 2>/dev/null
ln -s "$HOME/Documents" habit-tracker/docs-link

echo "fixtures written to $(pwd)"
