#!/usr/bin/env bash
# Run once on the server after cloning the repo.
# Usage: ./setup-server.sh [--jwt-key "your-secret"]
set -euo pipefail

# ── Parse args ────────────────────────────────────────────────────────────────

JWT_KEY=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --jwt-key) JWT_KEY="$2"; shift 2 ;;
        *) echo "Unknown arg: $1"; exit 1 ;;
    esac
done

# ── Check dependencies ────────────────────────────────────────────────────────

echo "Checking dependencies..."

if ! command -v docker &>/dev/null; then
    echo "Error: Docker not found. Install Docker first: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! docker compose version &>/dev/null; then
    echo "Error: Docker Compose not found. Make sure Docker Desktop or docker-compose-plugin is installed."
    exit 1
fi

# ── Create .env if missing ────────────────────────────────────────────────────

if [[ ! -f .env ]]; then
    if [[ -z "$JWT_KEY" ]]; then
        # Generate a random 48-char key
        JWT_KEY=$(LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*' </dev/urandom | head -c 48 || true)
        if [[ -z "$JWT_KEY" ]]; then
            JWT_KEY=$(date +%s | sha256sum | base64 | head -c 48)
        fi
    fi

    cat > .env <<EOF
JWT_KEY=${JWT_KEY}
EOF
    echo "Created .env with generated JWT key."
    echo "  ⚠  Back up .env — losing it invalidates all existing login tokens."
else
    echo ".env already exists, skipping key generation."
fi

# ── Create Library directory ──────────────────────────────────────────────────

mkdir -p Library updates
echo "Library/ and updates/ directories ready."
echo ""
echo "Drop audiobooks in Library/ as:"
echo "  Library/Author Name - Book Title/audiobook.mp3"
echo "  Library/Author Name - Book Title/cover.jpg  (optional)"
echo ""

# ── Start the server ──────────────────────────────────────────────────────────

echo "Building and starting Chronicler..."
docker compose up -d --build

echo ""
echo "Waiting for health check..."
for i in $(seq 1 10); do
    if curl -fsS http://localhost:5160/api/health &>/dev/null; then
        echo "Server is healthy!"
        break
    fi
    if [[ $i -eq 10 ]]; then
        echo "Health check failed after 10 attempts. Check: docker compose logs"
        exit 1
    fi
    sleep 2
done

# ── Print next steps ──────────────────────────────────────────────────────────

LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}' || echo "YOUR_SERVER_IP")

echo ""
echo "════════════════════════════════════════════════════"
echo "  Chronicler is running"
echo "════════════════════════════════════════════════════"
echo ""
echo "  Web app:      http://localhost:5160"
echo "  Install APK:  http://${LOCAL_IP}:5160/install"
echo "  Health:       http://localhost:5160/api/health"
echo ""
echo "Next steps:"
echo "  1. Add audiobooks to Library/"
echo "  2. Run ./deploy.sh to build the Android APK"
echo "  3. On your Android device, open http://${LOCAL_IP}:5160/install"
echo ""
echo "To stop:   docker compose down"
echo "To update: git pull && docker compose up -d --build"
echo "════════════════════════════════════════════════════"
