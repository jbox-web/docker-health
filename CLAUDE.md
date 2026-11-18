# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A single-file Crystal HTTP server (`src/docker-health.cr`) whose only purpose is to answer `PONG`, so a Docker container without a shell (distroless/scratch) still has something to expose to a `HEALTHCHECK`. Routing is minimal and lives in `DockerHealth.handle`: the paths listed in `HEALTH_PATHS` (`/ping`, `/health` and `/`) return `PONG`, everything else returns a 404. `/` is kept only for backward compatibility with healthchecks written when the server answered every path.

The whole program is ~110 lines: option parsing, optional TLS, `HTTP::Server`, plus `src/docker_health/licenses.cr`, which embeds the third-party notices that `docker-health --licenses` prints. Anything that grows beyond that is a scope change, not a refactor.

## Toolchain

`mise` drives everything — never invoke `crystal`/`shards` directly, the tasks carry the compile flags (`--threads 4`, `--release --error-trace`, TTY-conditional `--progress`).

```sh
mise dev:deps          # shards install
mise dev:build         # dev binary -> bin/docker-health
mise dev:spec          # crystal spec (--verbose when on a TTY)
mise dev:spec-mt       # same, -Dpreview_mt with CRYSTAL_WORKERS=4
mise dev:ameba         # static analysis (ameba is a mise tool), hard-bounded by the task timeout (180s)
mise dev:format        # crystal tool format src/ spec/
mise dev:format-check  # crystal tool format --check src/ spec/ (what CI runs)
mise dev:docs          # regenerate docs/
mise dev:coverage      # spec line coverage with kcov -> coverage/index.html
mise dev:licenses      # assemble licenses/ from licenses.manifest (every compiling task depends on it)
mise dev:clean         # rm -rf bin/* lib/
mise release:static    # release snapshot into dist/, nothing published
```

Run a single spec file: `mise dev:spec spec/<file>_spec.cr` (mise forwards the arguments). A single example: `mise dev:spec spec/<file>_spec.cr:<line>`. Never bare `crystal spec`: it skips the pinned toolchain and the `dev:licenses` dependency.

On macOS, `shards` is missing from the mise Crystal install (upstream crystal-lang/crystal#16746). Run `mise dev:fix-shards-command` once after installing/upgrading the Crystal tool version, otherwise `dev:deps` fails.

## Testing

Specs use **Spectator** (not the stdlib `Spec` DSL) plus `crystal-env/spec` — see `spec/spec_helper.cr`. Routing is covered by `spec/docker-health_spec.cr`, which drives `DockerHealth.handle` through the `probe` helper: it builds a request/response pair over an in-memory IO, so no socket is ever bound. `spec/licenses_spec.cr` covers the embedded notices and the `--licenses` output.

The CLI auto-starts at the bottom of `src/docker-health.cr`, guarded by `unless Crystal.env.test?`. `crystal-env/spec` is what forces the env to `test`; requiring the source in a spec without that guard in place would start a listening server instead of running the suite.

## Build & release pipeline

Releases are built by [crystalreleaser](https://github.com/jbox-web/crystalreleaser), pinned in `mise.toml` and configured by `.crystalreleaser.yml` (the canonical template, only the project name differs):

- `mise release:static` rehearses the release on one machine: `crystalreleaser build --split --snapshot` (static linux amd64 + arm64 in the Alpine image crystalreleaser generates, plus the native darwin binary on a Mac), then `release --merge --snapshot --skip=publish`. Everything lands in `dist/`. CI runs it on every push (`build_static_binaries`).
- A `v*` tag runs `.github/workflows/release.yml`: `build --split` on ubuntu, macos-26 and macos-26-intel, then `release --merge` publishes `docker-health-<os>-<arch>` and its `.sha256`. The darwin binaries link Homebrew's `openssl@4` statically (`static_libs`), and crystalreleaser fails the build if one still loads a library macOS does not ship.

`VERSION`/`GIT_REF` are computed at compile time by macro shell-outs (`shards version`, `git log`): the release builds mount the whole checkout, `.git/` included.

The notices of what the static binary links (`licenses.manifest`, `licenses-spdx/`, `licenses-upstream/`) are assembled into the gitignored `licenses/` by `scripts/harvest-licenses.sh`, a before hook of `.crystalreleaser.yml` and a dependency of every compiling mise task; compiling without it fails on purpose. Version bumps live in `shard.yml`.

## Conventions

- The workflows (`ci.yml`, `release.yml`) are verbatim copies of the canonical templates: they keep `permissions: {}` at workflow level and `persist-credentials: false` on every checkout. CI steps go through `mise` tasks; `release.yml` calls `crystalreleaser` and `brew install openssl@4` directly, as the template does.
- Ameba suppressions are inline and scoped (`# ameba:disable Lint/NotNil`); there is no `.ameba.yml`.
- `server.crt` / `server.key` at the repo root are gitignored local TLS test material — pass them with `-c` / `-k` to exercise the `bind_tls` path.
