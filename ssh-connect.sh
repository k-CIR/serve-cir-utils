#!/bin/bash
set -euo pipefail

# Configuration
DEFAULT_PORT=8080
MAX_PORT_ATTEMPTS=20
REMOTE_HOST="compute.kcir.se"

# Colors
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
NC='\033[0m' # No Color

is_local_port_free() {
    local port=$1
    if lsof -i ":$port" >/dev/null 2>&1; then return 1; fi
    if netstat -ln 2>/dev/null | grep -q ":$port "; then return 1; fi
    if command -v nc >/dev/null 2>&1; then
        if nc -z localhost "$port" 2>/dev/null; then return 1; fi
    fi
    return 0
}

# Ask the remote for all free ports in range via a single SSH call, then pick
# the first one that is also free locally. This prevents a mismatch where the
# tunnel is opened on one port but server.py ends up binding to a different one.
find_shared_port() {
    local start_port=$1
    local end_port=$((start_port + MAX_PORT_ATTEMPTS - 1))

    local remote_free
    remote_free=$(ssh \
        -o ConnectTimeout=30 \
        -o BatchMode=no \
        "${USERNAME}@${REMOTE_HOST}" \
        "python3 - $start_port $end_port" <<'PYEOF'
import socket, sys
start, end = int(sys.argv[1]), int(sys.argv[2])
free = []
for p in range(start, end + 1):
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        s.bind(("localhost", p))
        s.close()
        free.append(str(p))
    except OSError:
        pass
print(" ".join(free))
PYEOF
    ) || { echo ""; return 1; }

    for port in $remote_free; do
        if is_local_port_free "$port"; then
            echo "$port"
            return 0
        fi
    done
    echo ""
    return 1
}

# Get user input
read -p "Username: " USERNAME
read -p "Project:  " PROJECT
echo

# Find a port that is free on BOTH local machine and remote server
echo "Finding available port..."
PORT=$(find_shared_port $DEFAULT_PORT)
if [[ -z "$PORT" ]]; then
    echo "Error: No available ports found on both local and remote"
    exit 1
fi

echo "Setting up SSH tunnel on port $PORT..."
echo
echo -e "${YELLOW}Note: If restarting this process, it takes a minute to clean up ports before you can open a new server.${NC}"
echo
echo "Connecting to ${USERNAME}@${REMOTE_HOST}..."
echo

# Connect and run server - simplified without automatic cleanup
ssh -t \
    -o ConnectTimeout=30 \
    -o ServerAliveInterval=60 \
    -o ServerAliveCountMax=3 \
    -o ExitOnForwardFailure=yes \
    -o BatchMode=no \
    -L "${PORT}:localhost:${PORT}" \
    "${USERNAME}@${REMOTE_HOST}" \
    "cd /data/projects/${PROJECT}/bids-utils-mr && PORT=${PORT} python3 server.py" 