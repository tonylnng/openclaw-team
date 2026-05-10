# Changelog

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
