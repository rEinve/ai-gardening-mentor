# Podman Container Deployment Guide: AI Gardening Mentor

This guide explains how to build, run, and orchestrate the **AI Gardening Mentor** prototype using **Podman** (or Docker).

---

## Architecture Overview

The container configuration uses a **multi-stage build** defined in `Containerfile` (and mirrored in `Dockerfile` for universal tooling compatibility):

| Stage | Base Image | Role | Port | User |
| :--- | :--- | :--- | :--- | :--- |
| **`development`** | `node:22-alpine` | Live development server with hot reload and host volume mounting | `4321` | `node` (UID 1000) |
| **`builder`** | `node:22-alpine` | Compiles static prototype assets into `dist/` | N/A | Root |
| **`production`** | `nginx-unprivileged:alpine` | High-performance, secure, static web server with Gzip and security headers | `8080` (mapped to `4321`) | `nginx` (UID 101) |

> [!NOTE]
> The production container runs strictly as an **unprivileged non-root user** (`UID 101`) on port `8080`, adhering to best practices for rootless Podman environments.

---

## Quick Start (Podman CLI)

### 1. Build the Production Container
```bash
# Using the helper script:
./scripts/podman-build.sh

# Or directly with Podman:
podman build -t ai-gardening-mentor:latest -f Containerfile .
```

### 2. Run the Production Container
```bash
# Using the helper script:
./scripts/podman-run.sh 4321

# Or directly with Podman:
podman run --rm -d \
  --name ai-gardening-mentor \
  -p 4321:8080 \
  ai-gardening-mentor:latest
```
Visit **[http://localhost:4321](http://localhost:4321)** in your browser.

### 3. Check Health Status
```bash
curl http://localhost:4321/healthz
# Returns: OK
```

### 4. Stop the Container
```bash
./scripts/podman-stop.sh
# Or: podman stop ai-gardening-mentor
```

---

## Live Development with Volume Mounts

To develop locally with files synced into the container:

```bash
# Using the helper script:
./scripts/podman-dev.sh

# Or directly with Podman (note the :Z flag for SELinux rootless volume isolation):
podman run --rm -it \
  --name ai-gardening-mentor-dev \
  -p 4321:4321 \
  -v "$(pwd):/app:Z" \
  -w /app \
  ai-gardening-mentor:dev
```

---

## Orchestration with Podman Compose

You can manage the prototype with `podman compose` (or `podman-compose` / `docker compose`):

```bash
# Launch production container in the background:
podman compose up -d app

# View logs:
podman compose logs -f app

# Launch development environment:
podman compose --profile dev up dev

# Shut down all services:
podman compose down
```

---

## Rootless Podman & SELinux Notes

- **Unprivileged Ports**: Podman rootless runs without sudo and prefers ports above `1024`. The container's internal Nginx listens on port `8080`, mapped externally to host port `4321` (or any port you choose).
- **SELinux Mounts**: On Fedora/RHEL/CentOS systems, volume mounts require the `:Z` suffix (`-v "$(pwd):/app:Z"`) so Podman configures appropriate SELinux security contexts.
- **Docker CLI Alias**: Because Podman is OCI-compliant and command-compatible, `alias docker=podman` allows all scripts and commands to function identically.
