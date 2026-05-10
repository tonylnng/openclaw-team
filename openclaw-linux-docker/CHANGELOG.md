# Changelog

## 1.2.1 — 2026-05-10

### Fixed
- **Wrong config filename in every check.** 1.2.0 looked for `/root/.openclaw/config.json`, but the OpenClaw 2026.5.x CLI actually writes its config to `/root/.openclaw/openclaw.json` ([OpenClaw docs](https://docs.openclaw.ai/start/setup)). Result: even after a successful `openclaw setup` the entrypoint, the docker-compose healthcheck, and `./scripts/openclaw.sh gateway status` all reported `NEEDS_SETUP` and the gateway never auto-started. All four locations now check for `openclaw.json` (with `config.json` kept as a tolerated fallback so a future CLI rename won't break us again).
  - `docker/base/entrypoint.sh`
  - `docker/base/Dockerfile` (comment only)
  - `docker-compose.yml` (healthcheck `CMD-SHELL`)
  - `scripts/openclaw.sh` (`setup`, `health`, `gateway status` subcommands)

### Added
- **`./scripts/openclaw.sh setup <role>` now also runs `openclaw configure`** as a second interactive step. `openclaw setup` alone only creates the directory layout and a stub `openclaw.json` — the gateway can't actually start without provider/API-key choices, which `openclaw configure` collects. The CLI itself flags this as the next step ("Next: run `openclaw configure` to choose models, channels, Gateway, plugins, skills, and health checks"). Press Ctrl-C during the configure step if you've already done it manually.
- **`./scripts/openclaw.sh configure <role>`** — standalone subcommand for re-running configure later (e.g. switching providers) without redoing setup.
- **Better post-setup status output.** When the gateway is DOWN after setup, the script now tails the last 20 lines of `/var/log/openclaw/gateway.log` so the failure reason is immediately visible — no more guessing.

### Migration from 1.2.0
No data changes. Just pull, re-extract the zip, rebuild, and re-run setup if you tried it on 1.2.0:

```bash
git pull
cd openclaw-linux-docker
rm -rf openclaw-docker && unzip openclaw-docker.zip -d openclaw-docker
cd openclaw-docker && chmod +x scripts/*.sh docker/base/entrypoint.sh
./scripts/openclaw.sh down && ./scripts/openclaw.sh build && ./scripts/openclaw.sh up
./scripts/openclaw.sh setup pa     # now does setup + configure + restart
./scripts/openclaw.sh gateway status
```

If you already ran `openclaw setup` (and possibly `openclaw configure`) manually inside a 1.2.0 container, your config is preserved in the `openclaw_config_<role>` volume and survives the rebuild — the entrypoint will pick it up automatically once the new image is in place.

## 1.2.0 — 2026-05-10

### Headline
Gateway auto-starts when each role's container starts — once you've run `openclaw setup` once for that role. Matches exactly the manual flow that worked for users in 1.1.x.

### Why this is a breaking-ish (but data-preserving) change
The 1.1.x design tried to be clever:
- Run the gateway as the unprivileged `openclaw` user.
- Isolate per-role state via `openclaw --profile <role>` under `~/.openclaw-<role>`.
- Supervise with a watchdog that detached via `runuser + setsid + nohup`.

In practice this caused two layered bugs (1.1.1 watchdog log permission, 1.1.2 partial fix) and — most importantly — didn't match the on-disk reality of OpenClaw, which writes its config to the home of whoever runs `openclaw setup`. Since users naturally `docker exec -it ... bash` and run setup as root, the config landed in `/root/.openclaw/` and the openclaw-user gateway couldn't read it.

1.2.0 mirrors the proven manual flow:
- The gateway runs as **root** (the same user that runs `openclaw setup`).
- No `--profile` flag. Each role's isolation comes from a **per-role named volume mounted at `/root/.openclaw`**, not from a CLI profile.
- The watchdog is **gone**. The entrypoint just `nohup setsid openclaw gateway &`s in the background, exactly like the user did manually.

### Added
- **Per-role config volumes** `openclaw_config_<role>` mounted at `/root/.openclaw`. First-run `openclaw setup` writes here and survives `down`, `build`, host reboot.
- **`scripts/openclaw.sh setup <role>`** — runs `openclaw setup` interactively in the named role, then restarts that role so the gateway picks up the new config. One command, end-to-end.
- **`gateway status`** now distinguishes `UP` / `DOWN` / `NEEDS_SETUP` so it's obvious which roles still need first-run config.
- **`health`** subcommand reports `config NOT set up — run: ./scripts/openclaw.sh setup <role>` for any role missing `/root/.openclaw/config.json`.
- Healthcheck: a role with no config is treated as healthy (it's intentionally idle, not broken). A role with config must have port 18789 listening to be healthy.

### Changed
- `entrypoint.sh` simplified from ~160 lines to ~90. No watchdog script, no profile dirs, no `runuser`/`setsid` user-switch dance. Gateway launched with `nohup setsid openclaw gateway </dev/null >>...gateway.log 2>&1 &`.
- `Dockerfile`: removed the `oc` and `oc-gw` profile-aware aliases; added simple `oc-gw` (= `openclaw gateway`) and `oc-logs` aliases in `/etc/profile.d/openclaw-aliases.sh` so they work in any shell.
- `gateway restart [role]` now restarts the container (which re-runs the entrypoint and relaunches the gateway). Simpler and more reliable than poking PID files.
- The `OPENCLAW_GATEWAY_PORT` and `OPENCLAW_GATEWAY_RESTART_DELAY` env vars are gone. The gateway always uses 18789 inside the container (host port mapping is unchanged via `GW_PORT_<ROLE>`).

### Removed
- `/usr/local/bin/openclaw-gateway-watchdog` — no longer needed.
- `~/.openclaw-<role>` per-role profile dirs — replaced by `/root/.openclaw` mounted from a per-role volume.
- `openclaw_profile_<role>` named volumes — replaced by `openclaw_config_<role>`.
- `/var/log/openclaw/watchdog.log` — there's no watchdog anymore. Only `gateway.log` remains.

### Migration from 1.1.x
All your role workspaces (`openclaw_<role>`, `openclaw_shared`) are preserved untouched. The OpenClaw config is **not** carried forward automatically because the storage location changed (`~/.openclaw-<role>` → `/root/.openclaw`). You'll re-run setup once per role:

```bash
git pull
cd openclaw-linux-docker
unzip -o openclaw-docker.zip
cd openclaw-docker
./scripts/openclaw.sh down
./scripts/openclaw.sh build
./scripts/openclaw.sh up

# First-run setup per role (once each)
./scripts/openclaw.sh setup pa
./scripts/openclaw.sh setup architect
./scripts/openclaw.sh setup designer
./scripts/openclaw.sh setup developer
./scripts/openclaw.sh setup qc
./scripts/openclaw.sh setup operator

./scripts/openclaw.sh gateway status   # 6x UP
```

From now on the gateway will auto-start any time the container starts (host reboot, `docker compose down/up`, single-role `restart`, etc.). No more terminals to keep open.

### Optional: copy 1.1.x config forward
If you already ran `openclaw setup` inside a 1.1.x container as root and want to skip re-running it, you can copy the existing config file before running `setup`:

```bash
# Per role, before running setup again
docker run --rm \
  -v openclaw_openclaw_config_pa:/dst \
  -v $(docker inspect -f '{{ .GraphDriver.Data.MergedDir }}' openclaw-pa)/root/.openclaw:/src:ro \
  ubuntu:24.04 sh -c 'cp -a /src/. /dst/'
```
(That's only needed if you went through 1.1.x setup as root. If you ran `openclaw --profile <role> setup` as the openclaw user under 1.1.x, the config format / location differs and a re-run of setup is the cleaner path.)

### Rollback
If you need to roll back to 1.1.2: `git revert` the merge commit for this PR. Workspace and shared volumes are untouched. The new `openclaw_config_<role>` volumes will linger — they're harmless, or remove with `docker volume rm` if you want a fully clean rollback.

## 1.1.2 — 2026-05-10

### Fixed
- **Watchdog log file permission bug.** In 1.1.1 the entrypoint launched the watchdog with `nohup setsid runuser -u openclaw -- ... >>/var/log/openclaw/watchdog.log 2>&1 &`. The shell running entrypoint.sh (root) opened `watchdog.log` *before* `runuser` switched user, so the file ended up owned by `root:root` with mode `0644`. The watchdog, running as the `openclaw` user, then failed every `echo ... >> "${WLOG}"` with `Permission denied`, exited immediately, never wrote its PID file, and the entrypoint logged a misleading `watchdog did not register PID` warning. End result: no gateway running.

  Fix:
  - Pre-create `/var/log/openclaw/watchdog.log` and `/var/log/openclaw/gateway.log` owned by `openclaw:openclaw` (mode 0644) at the top of `entrypoint.sh`, before any subshell or redirect could touch them.
  - Move the `>>watchdog.log` redirect *inside* the `runuser`-launched bash, so the fd is opened after the user switch (with openclaw's permissions) instead of by the root shell.
  - Add `disown` after the background launch so the parent shell can't deliver SIGHUP through job control.

### Improved
- **Sanity-check window**: the entrypoint now polls for `/var/run/openclaw/watchdog.pid` for up to 10 seconds (was: a single 1-second check). On failure, the entrypoint dumps the last 50 lines of `watchdog.log` to its own stderr so `docker logs <role>` shows the real error instead of a generic warning.

### How to deploy
```bash
cd openclaw-linux-docker
git pull
unzip -o openclaw-docker.zip
cd openclaw-docker
./scripts/openclaw.sh down
./scripts/openclaw.sh build
./scripts/openclaw.sh up
./scripts/openclaw.sh gateway status   # 6x UP
```

### First-run setup (one-time, per role)
OpenClaw refuses to start the gateway until each role's profile has been
configured (the gateway log will say `Missing config. Run \`openclaw --profile
<role> setup\``). Do this once per role:

```bash
for role in architect designer developer qc operator pa; do
  ./scripts/openclaw.sh shell "$role"
  # inside the container:
  openclaw --profile "$role" setup     # interactive; answer the prompts
  exit
done
```

Within a few seconds (`OPENCLAW_GATEWAY_RESTART_DELAY`, default 5s) of
completing `setup`, the watchdog will respawn the gateway and it will stay
UP. No rebuild required.

### Quick fix for already-running 1.1.1 containers (no rebuild)
```bash
for c in openclaw-architect openclaw-designer openclaw-developer openclaw-qc openclaw-operator openclaw-pa; do
  docker exec "$c" bash -c '
    pkill -f openclaw-gateway-watchdog 2>/dev/null || true
    pkill -f "openclaw .*gateway run" 2>/dev/null || true
    rm -f /var/log/openclaw/watchdog.log /var/log/openclaw/gateway.log
    install -o openclaw -g openclaw -m 0644 /dev/null /var/log/openclaw/watchdog.log
    install -o openclaw -g openclaw -m 0644 /dev/null /var/log/openclaw/gateway.log
    rm -f /var/run/openclaw/watchdog.pid /var/run/openclaw/gateway.pid
    nohup setsid runuser -u openclaw -- bash -c \
      "exec /usr/local/bin/openclaw-gateway-watchdog \$0 \$1 \$2 </dev/null >>/var/log/openclaw/watchdog.log 2>&1" \
      "${OPENCLAW_ROLE}" "${OPENCLAW_GATEWAY_PORT:-18789}" 5 </dev/null >/dev/null 2>&1 &
    disown || true'
done
sleep 5
./scripts/openclaw.sh gateway status
```

## 1.1.1 — 2026-05-10

### Fixed
- **Gateway no longer dies when the entrypoint hands off to `sleep infinity`.** The previous version started the gateway via `su - openclaw -c "... nohup ... &"`, which left it attached to the entrypoint's session/process group; SIGHUP from session teardown could kill it. Now the gateway is supervised by a small watchdog process that:
  - is detached via `runuser` + `setsid` + `nohup` into its own session and process group,
  - records its own PID at `/var/run/openclaw/watchdog.pid` and the gateway's PID at `/var/run/openclaw/gateway.pid`,
  - **automatically respawns the gateway** if it crashes (with a configurable backoff, `OPENCLAW_GATEWAY_RESTART_DELAY`, default 5s),
  - cleanly stops the gateway on SIGTERM/SIGINT.
- **`scripts/openclaw.sh gateway restart`** now sends SIGTERM to the gateway PID and lets the watchdog respawn it (instead of `pkill`-ing the process by name pattern, which was racy).

### Added
- New env var `OPENCLAW_GATEWAY_RESTART_DELAY` (default `5`) to tune watchdog backoff.
- New log file `/var/log/openclaw/watchdog.log` for supervisor events.
- `/var/run/openclaw/` is now created at image build time (was: only at runtime).

### Notes
- Existing volumes and `.env` files keep working unchanged.
- The container CMD is still `sleep infinity`. The watchdog runs as a separate, detached process — it is not PID 1 and a crashed gateway never affects shell-in access.

## 1.1.0 — 2026-05-10

### Added
- **Pre-installed OpenClaw CLI** in the base image (`npm install -g openclaw@${OPENCLAW_VERSION}`, default `latest`). Pinnable via the `OPENCLAW_VERSION` build-arg / `.env` value.
- **Node.js 22.x LTS** from NodeSource (replaces Ubuntu apt's older `nodejs`/`npm`). Pinnable via `NODE_MAJOR`.
- **Per-role gateway**: each of the six role containers (`architect`, `designer`, `developer`, `qc`, `operator`, `pa`) now starts its own OpenClaw gateway under an isolated profile (`~/.openclaw-<role>`).
- **Per-role gateway port mapping** on `127.0.0.1`:
  - architect → 18791
  - designer → 18792
  - developer → 18793
  - qc → 18794
  - operator → 18795
  - pa → 18796
  Inside the container the gateway always binds to `OPENCLAW_GATEWAY_PORT` (default `18789`).
- **Per-role profile volumes** (`openclaw_profile_<role>`) so each role's config, sessions, secrets, and cron jobs persist across rebuilds.
- **`.env` toggles**: `ENABLE_GATEWAY`, `OPENCLAW_VERSION`, `NODE_MAJOR`, `OPENCLAW_GATEWAY_PORT`, `GW_PORT_<ROLE>`.
- **Helper script subcommands**:
  - `scripts/openclaw.sh gateway status` — UP/DOWN per role
  - `scripts/openclaw.sh gateway logs <role>` — tail gateway log
  - `scripts/openclaw.sh gateway restart [role]` — restart gateway in one or all roles
  - `scripts/openclaw.sh version` — print release + node/npm/openclaw versions
- **`oc`, `oc-gw`, `oc-logs` shell aliases** inside containers, pre-bound to the role's profile.
- **MOTD** now includes profile dir, gateway port, and gateway log path.
- `netcat-openbsd` added to the base image (used by healthcheck and helper script).
- **Updated healthcheck** also checks that the gateway port is listening (when `ENABLE_GATEWAY=true`).

### Changed
- Base Dockerfile installs Node.js from NodeSource instead of Ubuntu apt; old `nodejs`/`npm` apt packages are no longer installed.
- Container CMD remains `sleep infinity`. The gateway runs in the background as a child of the entrypoint, NOT as PID 1, so a crashed gateway never takes the container down — you can still `shell` in and inspect.
- `backup` now also archives the per-role profile volumes.
- Healthcheck `start_period` increased from `10s` to `30s` to give the gateway time to bind.

### Backwards compatibility
- All existing volumes (`openclaw_<role>`, `openclaw_shared`) keep their names and contents — no data migration needed.
- All existing `.env` keys still work; new keys are optional with sane defaults.
- If `ENABLE_GATEWAY=false`, behavior is identical to 1.0.0 except Node 22 + a pre-installed `openclaw` binary in PATH.

### Rollback
The previous version is preserved in `backups/openclaw-docker.<timestamp>.zip` and `backups/openclaw-docker.<timestamp>/`. To roll back:

```bash
./scripts/openclaw.sh down
cd ..
mv openclaw-docker openclaw-docker.broken
unzip backups/openclaw-docker.<timestamp>.zip
cd openclaw-docker
./scripts/openclaw.sh build
./scripts/openclaw.sh up
```

Workspace volumes are untouched by the rollback.
