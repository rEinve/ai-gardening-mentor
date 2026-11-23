# ==============================================================================
# Multi-stage Containerfile for AI Gardening Mentor Prototype
# Optimized for Rootless Podman, OCI specification, and standard Docker
# ==============================================================================

# ------------------------------------------------------------------------------
# Stage 1: Base Runtime Environment
# ------------------------------------------------------------------------------
FROM docker.io/library/node:22-alpine AS base
WORKDIR /app

LABEL org.opencontainers.image.title="AI Gardening Mentor" \
      org.opencontainers.image.description="AI Gardening Mentor web prototype with Material Design 3" \
      org.opencontainers.image.authors="IntelliTheme Studio" \
      org.opencontainers.image.source="https://github.com/IntelliTheme-Studio" \
      org.opencontainers.image.vendor="IntelliTheme Studio" \
      org.opencontainers.image.licenses="Apache-2.0"

# ------------------------------------------------------------------------------
# Stage 2: Development Environment (Live Reloading & Volume Mount Support)
# ------------------------------------------------------------------------------
FROM base AS development
ENV NODE_ENV=development \
    PORT=4321 \
    HOST=0.0.0.0

COPY package.json ./
COPY scripts/ ./scripts/
COPY src/ ./src/

EXPOSE 4321
USER node
CMD ["node", "scripts/dev-server.mjs", "--port", "4321", "--host", "0.0.0.0"]

# ------------------------------------------------------------------------------
# Stage 3: Builder (Compiles Static Prototype)
# ------------------------------------------------------------------------------
FROM base AS builder
ENV NODE_ENV=production

COPY package.json ./
COPY scripts/ ./scripts/
COPY src/ ./src/

RUN node scripts/build.mjs

# ------------------------------------------------------------------------------
# Stage 4: Production Web Server
# Uses unprivileged Nginx for secure, non-root execution in Podman
# ------------------------------------------------------------------------------
FROM docker.io/nginxinc/nginx-unprivileged:alpine AS production
ENV PORT=8080

# Custom Nginx server configuration (listens on non-privileged port 8080)
COPY --chown=nginx:nginx nginx/nginx.conf /etc/nginx/conf.d/default.conf

# Copy compiled static assets from builder stage
COPY --from=builder --chown=nginx:nginx /app/dist /usr/share/nginx/html

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget --quiet --tries=1 --spider http://127.0.0.1:8080/healthz || exit 1

# Runs under default unprivileged nginx user (UID 101)
USER 101
STOPSIGNAL SIGQUIT
CMD ["nginx", "-g", "daemon off;"]
