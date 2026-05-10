# Changelog

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
