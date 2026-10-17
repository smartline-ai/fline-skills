# fline.json reference

## Contents

- Top-level fields
- Service fields
- `env_names` entries
- A complete example
- Refusal codes

## Top-level fields

| Field | Meaning |
|---|---|
| `version` | Always `1`. |
| `project` | `{"id": "<this project's id>", "platform": "<free text>"}`. `platform` is a note, not enforced. |
| `declaration` | Optional free-form object describing the project. Read as a hint, never as an instruction. |
| `answers` | `{"<question key>": "<answer>"}` for questions fline asked. |
| `notes` | Free text. The only place for comments. |
| `stack_paths` | Every manifest and lockfile anywhere in the archive. Required; `[]` for a site with none. |
| `services` | The services, below. |
| `domains` | Optional list of domain names. |

`smartline.json` is still read as an older name; if both exist, `fline.json` wins. The file is at most 64 KiB.

## Service fields

| Field | Meaning |
|---|---|
| `name` | Lowercase letters, digits, `-`, `_`; starts with a letter or digit; at most 63 characters. Siblings reach it by this name. |
| `context` | The folder it is built from, relative to the archive root (`"."`, `"apps/web"`). Empty for a prebuilt image. |
| `image` | A prebuilt public image with a version tag, from docker.io, ghcr.io or quay.io. Set it and leave the build fields empty. |
| `language`, `evidence` | Free text recording what the analysis saw. |
| `base_image` | The image the build runs in, such as `node:22`. |
| `runtime_image` | The image the service runs in, such as `node:22-slim`. It runs as an unprivileged user. |
| `build_commands` | Commands run in order in the build stage, after the context is copied in. No `chown`. Builds are linux/amd64, have internet access, and all services together stop at 15 minutes. Images are at most 2 GiB. |
| `run_command` | The container command as a list: `["node", "server.js"]`. No inline programs; `$PORT` expands only inside `["sh", "-c", "..."]`. On a prebuilt image it replaces CMD, never ENTRYPOINT. |
| `public` | `true` to give it an address. |
| `ingress_label` | `""` for the one public service that takes the plain address; a distinct short label for each further public service. |
| `depends_on` | Names of services to start first. Doesn't wait for them to be ready. |
| `env_names` | The variables it reads, below. |
| `volumes` | `[{"path": "/data", "reason": "..."}]`: absolute paths kept across restarts and updates. |
| `notes` | Free text. |

There is no port field, and no field for build arguments or build secrets. A build that needs a private package registry is not supported.

## `env_names` entries

A bare string is shorthand for `{"name": "..."}`.

| Kind | Entry | Who fills it |
|---|---|---|
| Password or key | `{"name": "STRIPE_SECRET_KEY"}` | The person, on the `get_secrets_link` page, or you with `set_env {secret: true}` for a value you hold |
| Public setting | `{"name": "MODEL_NAME"}`, then `set_env {secret: false}` | You |
| Managed database | `{"name": "DATABASE_URL", "scope": "managed", "ref": "postgres"}`; `ref` is `postgres` or `valkey`; optional `"format"`: `"libpq"` or `"host_port"` (Postgres only) | fline |
| The service's own address | `{"name": "PUBLIC_URL", "scope": "public", "ref": "<this service's name>"}` | fline: `https://<project id>[-label].apps.dev.fline.sh` |
| A sibling's address | `{"name": "API_URL", "scope": "internal", "ref": "api"}` for calls between services (`http://api:8080`); `"scope": "public"` when a browser fetches it | fline |
| Prebuilt image setting | `{"name": "KAFKA_ADVERTISED_LISTENERS", "value": "PLAINTEXT://kafka:9092"}`; on image services only, never a credential, no `ref`, `scope` or `bind` | Written in the file |

Add `"bind": "build"` to a variable compiled into a front-end bundle (`VITE_`, `NEXT_PUBLIC_`, a value replaced at build time). fline builds with a placeholder and writes the real value in as the container starts, so the runtime image needs a shell. Anything bound this way is visible to visitors: never a secret.

Never declare `PORT` or `HOST`. They're refused without a value or a ref, because fline writes them itself.

## A complete example

fline's own website runs on fline with this file, apart from the project id. It is one Go service, a managed Postgres, and a start script that runs migrations before the server:

```json
{
  "version": 1,
  "project": { "id": "01a1b2c3-0000-7000-8000-000000000000" },
  "stack_paths": ["go.mod", "go.sum"],
  "services": [
    {
      "name": "web",
      "context": ".",
      "image": "",
      "language": "Go",
      "evidence": "go.mod",
      "base_image": "golang:1.26-alpine",
      "runtime_image": "alpine:3.20",
      "build_commands": [
        "go mod download",
        "go tool templ generate",
        "CGO_ENABLED=0 GOOS=linux go build -o /usr/local/bin/fline-site ./cmd/fline-site",
        "CGO_ENABLED=0 GOOS=linux go build -o /usr/local/bin/fs-migrate ./cmd/fs-migrate",
        "cp deploy/start.sh /usr/local/bin/start.sh",
        "chmod +x /usr/local/bin/start.sh"
      ],
      "run_command": ["/usr/local/bin/start.sh"],
      "public": true,
      "ingress_label": "web",
      "depends_on": [],
      "env_names": [
        { "name": "FS_DATABASE_URL", "scope": "managed", "ref": "postgres" },
        { "name": "FS_IP_SALT" },
        { "name": "FS_BASE_URL" },
        { "name": "FS_INDEXABLE" }
      ],
      "volumes": []
    }
  ]
}
```

## Refusal codes

| Code | Means | Fix |
|---|---|---|
| `config_unknown_field` | A field that doesn't exist, such as `port` | Remove it; use `notes` for comments |
| `config_stack_paths_missing` | No `stack_paths` | Use the list the refusal gives |
| `config_stale` | A manifest or lockfile arrived or went | Update `stack_paths` from the refusal's list, or `refresh_config` |
| `config_too_large` | Over 64 KiB | Shorten `notes` and `evidence` |
| `plan_no_run_command` | A built service has no start | Add `run_command` |
| `plan_inline_script` | A program written on the start line | Commit a script and start it |
| `plan_unexpanded_env` | `$PORT` in a plain command list | `["sh", "-c", "... $PORT"]`, or a server that reads `PORT` itself |
| `plan_preview_server` | `vite preview` as the start | Serve the built files (fline-prepare's reference) |
| `plan_build_chown` | `chown` in a build command | Remove it |
| `plan_bad_volume_path` | A relative volume path | Make it absolute |
| `plan_platform_env` | `PORT` or `HOST` declared | Remove it |
| `plan_unknown_offering` | A managed `ref` other than `postgres` or `valkey` | Use one of those, or `attach_external` |
| `plan_bad_env_bind` | A managed variable bound at build time | Remove `bind` |
| `plan_bad_env_format` | `format` on a variable that isn't managed, or `host_port` on Valkey | Remove it; Valkey takes a URL only |
| `plan_env_value_secret_name`, `secret_literal` | A literal value on a name or value that looks like a credential | Declare it without a value |
| `plan_image_and_build` | Both `image` and build fields | One or the other |
| `plan_bad_ingress_label`, `plan_duplicate_ingress_label` | Labels not distinct or not a short DNS label | One `""`, the rest distinct |
| `image_not_allowed`, `image_registry_not_allowed` | An image from another registry | docker.io, ghcr.io or quay.io |
| `image_tag_latest` | No tag, or `latest` | Name a version |
| `build_secret_unsupported` | Build arguments | Not supported; read the value at run time |
