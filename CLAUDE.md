# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single-file Crystal HTTP server (`src/docker-health.cr`) whose only purpose is to answer `PONG`, so a Docker container without a shell (distroless/scratch) still has something to expose to a `HEALTHCHECK`. Routing is minimal and lives in `DockerHealth.handle`: the paths listed in `HEALTH_PATHS` (`/ping`, `/health` and `/`) return `PONG`, everything else returns a 404. `/` is kept only for backward compatibility with healthchecks written when the server answered every path.

The whole program is ~90 lines: option parsing, optional TLS, `HTTP::Server`. Anything that grows beyond that is a scope change, not a refactor.

## Toolchain

`mise` drives everything — never invoke `crystal`/`shards` directly, the tasks carry the compile flags (`--threads 4`, `--release --error-trace`, TTY-conditional `--progress`).

```sh
mise dev:deps          # shards install
mise dev:build         # dev binary -> bin/docker-health
mise dev:spec          # crystal spec (--verbose when on a TTY)
mise dev:spec-mt       # same, -Dpreview_mt with CRYSTAL_WORKERS=4
mise dev:ameba         # static analysis, hard-bounded by `timeout 180`
mise dev:format        # crystal tool format
mise dev:format-check  # crystal tool format --check (what CI runs)
mise dev:docs          # regenerate docs/
mise dev:clean         # rm -rf bin/* lib/
mise dev:docker-image  # local multi-arch image via docker buildx bake
```

Run a single spec file: `crystal spec spec/<file>_spec.cr`. A single example: `crystal spec spec/<file>_spec.cr:<line>`.

On macOS, `shards` is missing from the mise Crystal install (upstream crystal-lang/crystal#16746). Run `mise dev:fix-shards-command` once after installing/upgrading the Crystal tool version, otherwise `dev:deps` fails.

## Testing

Specs use **Spectator** (not the stdlib `Spec` DSL) plus `crystal-env/spec` — see `spec/spec_helper.cr`. Routing is covered by `spec/docker-health_spec.cr`, which drives `DockerHealth.handle` through the `probe` helper: it builds a request/response pair over an in-memory IO, so no socket is ever bound.

The CLI auto-starts at the bottom of `src/docker-health.cr`, guarded by `unless Crystal.env.test?`. `crystal-env/spec` is what forces the env to `test`; requiring the source in a spec without that guard in place would start a listening server instead of running the suite.

## Build & release pipeline

Two distinct build paths — they do not share flags:

- **Dev / macOS release**: `mise.toml` tasks, dynamically linked, output name overridable via the `OUTPUT_FILE` env var (the release workflow uses it to produce `bin/docker-health-darwin-{arm64,amd64}`).
- **Linux static release**: `Makefile.release` + `Dockerfile` + `docker-bake.hcl`. `mise release:static` runs `docker buildx bake binary`, which builds `--static` inside Alpine for `linux/amd64` and `linux/arm64` (native, not cross-compiled), exports the binaries to `packages/` via a `scratch` stage, then flattens the per-platform dirs and regenerates `.sha256` files.

The `Dockerfile` copies `.git/` into the build context on purpose: `VERSION`/`GIT_REF` are computed at compile time by macro shell-outs (`shards version`, `git log`). Removing `.git/` from the `COPY` breaks compilation, not just the version string.

The runtime image is `gcr.io/distroless/static-debian12`, running as `nonroot`. Version bumps live in `shard.yml`; a pushed tag triggers `.github/workflows/release_binaries.yml`.

## Conventions

- CI (`.github/workflows/ci.yml`) must keep `permissions: {}` at workflow level and `persist-credentials: false` on every checkout; all steps go through `mise dev:*` tasks.
- Ameba suppressions are inline and scoped (`# ameba:disable Lint/NotNil`); there is no `.ameba.yml`.
- `server.crt` / `server.key` at the repo root are gitignored local TLS test material — pass them with `-c` / `-k` to exercise the `bind_tls` path.
