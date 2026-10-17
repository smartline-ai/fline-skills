---
name: fline-build-plan
description: Use when writing, saving or editing fline.json, when check_config refuses it (config_stale, config_unknown_field, plan_* codes), when fline's analysis chose the wrong start or build command, for a project with several services, a worker, a monorepo or a prebuilt image such as a broker, when files must be kept on a volume, or right after a first successful launch on fline.
---

# fline.json: the build plan

fline's analysis turns the source into a plan: services, build commands, start command, variables, volumes. `get_config` returns that plan as `fline.json`. Saved at the top of the uploaded folder, it is used instead of re-analysing, so every update builds the same way. A short content check still screens each upload, and the build files are still generated each time. You never write or see the Dockerfile.

## Freeze it after the first launch

1. `get_config {project_id}`.
2. Save the answer as `fline.json` at the root of the folder you pack. Only the archive's root counts.
3. Tell the person: "I saved fline's build plan in your project, so later updates are built the same way."

## Edit it

1. Change the file. Unknown fields are refused; use `notes` for comments.
2. `check_config {project_id, config}`. It is free and checks against the last uploaded archive. Repeat until it answers ok. If this upload adds or removes a manifest or lockfile, a `stack_paths` complaint naming exactly those files is expected: write the list the new archive will have, since the upload is checked against itself.
3. Upload (fline-launch).

To shape a first launch (a volume, a different start command), `create_project` first, then write the file with that project's id before packing.

`refresh_config` throws the file away and re-analyses. Use it only when the stack has moved on in ways you can't reason about. It costs an analysis and runs in the background: poll `get_project` until it leaves `analyzing`, then `get_config`.

## Rules the checker enforces

- `version` is 1. `project.id` is this project's id.
- `stack_paths` lists every manifest and lockfile in the archive (`package.json`, lockfiles, `requirements.txt`, `pyproject.toml`, `go.mod`, `go.sum`, `Gemfile.lock`, `Dockerfile`, compose files). Adding or removing one makes the file stale. The refusal says what's gone and what arrived; update the list.
- No port field. Don't declare `PORT` or `HOST`.
- `build_commands` run in order in the build stage. `run_command` is the container's command, as a list. They must agree about paths: a build ending `-o /out/server` starts `/out/server`.
- No program written inline in `run_command` (`node -e`, `python -c`), and no `$PORT` outside `sh -c`. Commit a script and start that.
- No `chown` in `build_commands`.
- No Postgres, Redis or Valkey service. Mark the variable managed instead (fline-database).

## Services, volumes and images

- **Several services.** Each has its own `context` folder. Lowercase names, letters, digits, `-` and `_`. Siblings reach an internal service at `http://<name>:8080`, so it must listen on `PORT`. `depends_on` only orders their start, so retry connections.
- **Public services.** `public: true` gets an address. With more than one, each needs its own `ingress_label` (lowercase letters, digits, hyphens, at most 26 characters). At most one keeps `""`; internal services keep `""`.
- **Volumes.** `{"path": "/data", "reason": "uploaded photos"}`. The path is absolute. The app writes only there and in `/tmp`. Volumes survive restarts and updates, are removed with the project, and count toward its 8 GiB.
- **Prebuilt images.** `image` from docker.io, ghcr.io or quay.io, with a version tag, never `latest`, at most five per build. Nothing is built. `run_command` replaces the image's CMD, never its ENTRYPOINT. Configure it through `env_names` entries with a literal `value`: `{"name": "KAFKA_ADVERTISED_LISTENERS", "value": "PLAINTEXT://kafka:9092"}`. A literal is never a credential. A password the image needs is an entry without a value, which the person fills on the private page.
- **Public settings on built services.** Use `set_env {secret: false}`, not a literal in the file.

[reference.md](reference.md) has every field, a complete example, and the refusal codes.
