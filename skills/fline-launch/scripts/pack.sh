#!/usr/bin/env bash
# pack.sh: packs a project folder into the .tar.gz that fline's upload accepts.
#
# Usage: bash pack.sh [PROJECT_DIR] [--out FILE] [--exclude GLOB]...
#
# Prints a report, then a last line "ARCHIVE=<path>" on success.
# Exit 0: archive written. Exit 1: a rule fline enforces would refuse it.
# Exit 2: bad usage.
#
# Runs on the bash 3.2 and bsdtar that ship with macOS, and on Linux and
# Git Bash with GNU tar. git is used when the folder is a repository and is
# optional otherwise.

set -u

MAX_BYTES=104857600      # 100 MiB compressed
MAX_FILES=20000
MAX_FILE_MIB=32
MAX_CONFIG_BYTES=65536   # fline.json
MAX_RATIO=100

project="."
out=""
extra_excludes=()

while [ $# -gt 0 ]; do
  case "$1" in
    --out) out="${2:-}"; shift 2 ;;
    --exclude) extra_excludes+=("${2:-}"); shift 2 ;;
    -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
    -*) echo "unknown option: $1" >&2; exit 2 ;;
    *) project="$1"; shift ;;
  esac
done

if [ ! -d "$project" ]; then
  echo "not a folder: $project" >&2
  exit 2
fi
root="$(cd "$project" && pwd -P)"
name="$(basename "$root" | tr -c 'A-Za-z0-9._\n-' '-')"
if [ -z "$out" ]; then
  out="${TMPDIR:-/tmp}"
  out="${out%/}/fline-${name}-$(date +%Y%m%d-%H%M%S).tar.gz"
fi
case "$out" in /*) ;; *) out="$(pwd -P)/$out" ;; esac

work="$(mktemp -d "${TMPDIR:-/tmp}/fline-pack.XXXXXX")"
trap 'rm -rf "$work"' EXIT
listed="$work/listed"; kept="$work/kept"; dropped="$work/dropped"; warned="$work/warned"
: > "$kept"; : > "$dropped"; : > "$warned"
blocked=0

# Directories that hold installed dependencies, caches or virtualenvs. Used
# only when the folder is not a git repository; a repository's own ignore
# rules decide otherwise.
prune_dirs=".git node_modules bower_components .venv venv env __pycache__ .pytest_cache .mypy_cache .ruff_cache .tox .next .nuxt .svelte-kit .turbo .parcel-cache .cache .vercel .netlify .serverless .terraform target .gradle .idea .vscode coverage .DS_Store"

cd "$root" || exit 2

if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  mode="git (tracked and untracked files, minus .gitignore)"
  git ls-files -z --cached --others --exclude-standard > "$listed"
else
  mode="folder (dependency, cache and virtualenv folders left out)"
  prune_expr=""
  for d in $prune_dirs; do
    prune_expr="$prune_expr -name $d -o"
  done
  prune_expr="${prune_expr% -o}"
  # shellcheck disable=SC2086
  find . \( -type d \( $prune_expr \) -prune \) -o \( \( -type f -o -type l \) -print0 \) > "$listed"
fi

is_example_env() {
  case "$1" in
    .env.example|.env.sample|.env.template|.env.defaults|*.env.example|*.env.sample|*.env.template|*.env.defaults) return 0 ;;
  esac
  return 1
}

# Names fline treats as credentials. They are left out of the archive.
credential_name() {
  b="$(basename "$1")"
  if is_example_env "$b"; then return 1; fi
  case "$b" in
    .env|.env.*|*.env|*.pem|id_rsa|id_rsa.*|id_ed25519|id_ed25519.*|credentials.json|.npmrc|.netrc|*.p12|*.pfx|serviceaccount*.json|service-account*.json) return 0 ;;
  esac
  return 1
}

# Escapes reports whether a relative symlink target, joined to the link's own
# folder, climbs above the project root.
escapes() {
  joined="$1"; depth=0
  old_ifs="$IFS"; IFS=/
  for part in $joined; do
    case "$part" in
      ''|.) ;;
      ..) depth=$((depth - 1)); if [ $depth -lt 0 ]; then IFS="$old_ifs"; return 0; fi ;;
      *) depth=$((depth + 1)) ;;
    esac
  done
  IFS="$old_ifs"
  return 1
}

while IFS= read -r -d '' f; do
  f="${f#./}"
  [ -n "$f" ] || continue
  # A file git still tracks but that was deleted from the folder.
  if [ ! -e "$f" ] && [ ! -L "$f" ]; then continue; fi
  base="$(basename "$f")"
  case "$base" in .DS_Store|._*) continue ;; esac
  skip=0
  if [ ${#extra_excludes[@]} -gt 0 ]; then
    for g in "${extra_excludes[@]}"; do
      # shellcheck disable=SC2254
      case "$f" in $g|$g/*) skip=1 ;; esac
    done
  fi
  if [ $skip -eq 1 ]; then printf '%s\t%s\n' "$f" "excluded by --exclude" >> "$dropped"; continue; fi
  if credential_name "$f"; then
    printf '%s\t%s\n' "$f" "named like a password or key file" >> "$dropped"; continue
  fi
  if [ -L "$f" ]; then
    target="$(readlink "$f")"
    case "$target" in
      /*) printf '%s\t%s\n' "$f" "link to $target, outside the folder" >> "$dropped"; continue ;;
    esac
    if escapes "$(dirname "$f")/$target"; then
      printf '%s\t%s\n' "$f" "link to $target, outside the folder" >> "$dropped"; continue
    fi
  fi
  printf '%s\0' "$f" >> "$kept"
done < "$listed"

count=0; total=0
: > "$work/sizes"
while IFS= read -r -d '' f; do
  count=$((count + 1))
  [ -L "$f" ] && continue
  sz=$(wc -c < "$f" | tr -d ' ')
  total=$((total + sz))
  printf '%s\t%s\n' "$sz" "$f" >> "$work/sizes"
done < "$kept"

if [ "$count" -eq 0 ]; then
  echo "Nothing to pack in $root."
  exit 1
fi
if [ "$count" -gt "$MAX_FILES" ]; then
  echo "BLOCKED: $count files; fline accepts at most $MAX_FILES. Leave out dependency or generated folders."
  blocked=1
fi

limit=$((MAX_FILE_MIB * 1048576))
while IFS="$(printf '\t')" read -r sz f; do
  if [ "$sz" -gt "$limit" ]; then
    echo "BLOCKED: $f is $((sz / 1048576)) MiB; fline refuses any file over $MAX_FILE_MIB MiB."
    blocked=1
  fi
done < "$work/sizes"

if [ -f fline.json ]; then
  csz=$(wc -c < fline.json | tr -d ' ')
  if [ "$csz" -gt "$MAX_CONFIG_BYTES" ]; then
    echo "BLOCKED: fline.json is $csz bytes; the limit is $MAX_CONFIG_BYTES."
    blocked=1
  fi
fi
if [ ! -f fline.json ] && [ -f smartline.json ]; then
  echo "NOTE: smartline.json found; fline still reads it, fline.json is the current name."
fi
local_data="$(tr '\0' '\n' < "$kept" | grep -E '\.(db|sqlite|sqlite3)$' | head -5)"
if [ -n "$local_data" ]; then
  echo "NOTE: database files from this computer are included; leave them out with --exclude unless the app needs them as they are:"
  echo "$local_data" | sed 's/^/  /'
fi
nested_config="$(tr '\0' '\n' < "$kept" | grep -E '/(fline|smartline)\.json$' | head -3)"
if [ -n "$nested_config" ]; then
  echo "NOTE: fline reads fline.json only at the top of the folder; these are ignored:"
  echo "$nested_config" | sed 's/^/  /'
fi

# Contents fline flags as a committed key. Reported, not removed.
while IFS= read -r -d '' f; do
  [ -L "$f" ] && continue
  if grep -IlqE -e '-----BEGIN [A-Z ]*PRIVATE KEY-----' -e 'sk_live_[0-9A-Za-z]{8,}' -e 'AKIA[0-9A-Z]{16}' -e 'ghp_[0-9A-Za-z]{30,}' "$f" 2>/dev/null; then
    echo "$f" >> "$warned"
  fi
done < "$kept"

if [ "$blocked" -eq 0 ]; then
  if ! COPYFILE_DISABLE=1 tar --null --no-recursion -czf "$out" -T "$kept" 2>"$work/tar.err"; then
    echo "BLOCKED: tar failed:"; sed 's/^/  /' "$work/tar.err"
    exit 1
  fi
  csize=$(wc -c < "$out" | tr -d ' ')
  if [ "$csize" -gt "$MAX_BYTES" ]; then
    echo "BLOCKED: the archive is $((csize / 1048576)) MiB; fline accepts at most 100 MiB. Largest files:"
    sort -rn "$work/sizes" | head -10 | awk -F'\t' '{ printf "  %6.1f MiB  %s\n", $1/1048576, $2 }'
    blocked=1
  elif [ "$csize" -gt 0 ] && [ $((total / csize)) -gt "$MAX_RATIO" ]; then
    echo "BLOCKED: the files are more than $MAX_RATIO times the archive's size; fline refuses that as a compression bomb."
    blocked=1
  fi
fi

echo "fline pack report for $root"
echo "  mode:     $mode"
echo "  files:    $count ($((total / 1024)) KiB before compression)"
if [ -s "$dropped" ]; then
  echo "  left out:"
  awk -F'\t' '{ printf "    %s (%s)\n", $1, $2 }' "$dropped"
fi
if [ -s "$warned" ]; then
  echo "  WARNING: these files contain what looks like a live key. fline holds them back"
  echo "  from its analysis but they still go into the build. Move the key out:"
  sed 's/^/    /' "$warned"
fi
if [ -f fline.json ]; then echo "  fline.json: present at the top of the folder"; else echo "  fline.json: none (fline will analyse the project)"; fi

if [ "$blocked" -ne 0 ]; then
  rm -f "$out"
  echo "RESULT: not packed. Fix the BLOCKED lines above and run again."
  exit 1
fi
echo "  archive:  $out ($(( $(wc -c < "$out" | tr -d ' ') / 1024 )) KiB)"
echo "ARCHIVE=$out"
