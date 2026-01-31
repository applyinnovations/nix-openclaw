# Plan: OCI Container Image for OpenClaw

Build a batteries-included OCI container image using Nix `dockerTools.buildLayeredImage` for headless server deployment of the OpenClaw gateway.

## Files to Create

### 1. `nix/scripts/docker-entrypoint.sh`
Entrypoint script that:
- Creates `/data/workspace` and `/tmp/openclaw` directories
- Reads secret files from `/run/secrets/*` and exports as env vars:
  - `anthropic-api-key` → `ANTHROPIC_API_KEY`
  - `openai-api-key` → `OPENAI_API_KEY`
  - `google-api-key` → `GOOGLE_API_KEY`
  - (telegram token handled via config `tokenFile`, not env var)
- Resolves config in priority order:
  1. Mounted config at `/config/openclaw.json` (use as-is)
  2. Auto-generate minimal config from `/run/secrets/telegram-token` + `OPENCLAW_TELEGRAM_ALLOW_FROM` env var
  3. Fall back to gateway defaults
- Execs `openclaw gateway --port ${OPENCLAW_GATEWAY_PORT:-18789} "$@"`

### 2. `nix/packages/openclaw-container.nix`
The `dockerTools.buildLayeredImage` derivation:
- **Inputs:** `openclaw-gateway`, `extendedTools` (tool list), `bash`, `coreutils`, `jq`, `cacert`, `dockerTools.fakeNss`
- **Entrypoint derivation:** Uses existing `docker-entrypoint-install.sh` pattern to package the entrypoint script (consistent with project conventions — no inline scripts)
- **Image config:**
  - `name = "openclaw"`, `tag = openclaw-gateway.version`
  - `maxLayers = 100` (automatic layer splitting per Nix store path)
  - `contents` = gateway + entrypoint + tools + bash + coreutils + jq + cacert + fakeNss
  - `fakeRootCommands` creates `/tmp` (chmod 1777), `/data`, `/config`, `/home/openclaw`, `/run/secrets`
  - `Cmd` = entrypoint, `ExposedPorts` = 18789/tcp
  - `Volumes` = `/data`, `/config`, `/run/secrets`
  - `Env` = `MOLTBOT_NIX_MODE=1`, `MOLTBOT_STATE_DIR=/data`, `HOME=/home/openclaw`, `SSL_CERT_FILE=...cacert...`, `TMPDIR=/tmp`
  - `WorkingDir = "/data"`
- **meta:** Linux-only platforms

## Files to Modify

### 3. `nix/packages/default.nix`
Add `openclaw-container` to the package set, gated to Linux (following the same pattern as `openclaw-app` is gated to Darwin):
```nix
openclawContainer = if !isDarwin then pkgs.callPackage ./openclaw-container.nix {
  openclaw-gateway = openclawGateway;
  extendedTools = toolSets.tools;
} else null;
```
Add to return set:
```nix
// (if !isDarwin then { openclaw-container = openclawContainer; } else {})
```

### 4. `garnix.yaml`
Add one line to the include list:
```yaml
- "packages.x86_64-linux.openclaw-container"
```

## No changes needed to `flake.nix`
The existing `packages = packageSetStable // { ... }` pattern already exposes everything from `default.nix` automatically.

## Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Image builder | `buildLayeredImage` | Garnix-cacheable output; simpler than `streamLayeredImage` |
| Layer strategy | `maxLayers = 100`, automatic | Each Nix store path becomes a layer candidate; gateway and tools naturally separate |
| User | `nobody` via `fakeNss` | Simple, Kubernetes-compatible (pod security context controls UID) |
| Secrets | Mounted files at `/run/secrets/` | Docker Swarm / Kubernetes native pattern |
| Config | Mount at `/config/openclaw.json` or auto-generate from secrets | Flexible — works for both full config and minimal setups |
| `HOME` | `/home/openclaw` | Node.js needs a writable home for caches; created in `fakeRootCommands` |

## Usage

```bash
# Build
nix build .#openclaw-container
docker load < result

# Run
docker run -d --name openclaw \
  -p 18789:18789 \
  -v /path/to/openclaw.json:/config/openclaw.json:ro \
  -v /path/to/secrets:/run/secrets:ro \
  -v openclaw-data:/data \
  openclaw:2026.1.8-2
```

## Verification

1. `nix build .#openclaw-container` succeeds on x86_64-linux
2. `docker load < result` loads the image
3. `docker run --rm openclaw:<tag> openclaw --help` prints gateway help
4. `docker run -d` with mounted config + telegram token secret starts the gateway and responds to Telegram messages
5. Verify tools are available: `docker run --rm openclaw:<tag> ffmpeg -version`, `docker run --rm openclaw:<tag> python3 --version`
