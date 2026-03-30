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

find_available_local_port() {
    local start_port=$1
    for ((i=0; i<MAX_PORT_ATTEMPTS; i++)); do
        local port=$((start_port + i))
        # Check with lsof first
        if lsof -i ":$port" >/dev/null 2>&1; then
            continue
        fi
        # Check with netstat
        if netstat -ln 2>/dev/null | grep -q ":$port "; then
            continue
        fi
        # Test with nc if available
        if command -v nc >/dev/null 2>&1; then
            if nc -z localhost "$port" 2>/dev/null; then
                continue
            fi
        fi
        echo "$port"
        return 0
    done
    echo ""
    return 1
}

# Get user input
read -p "Username: " USERNAME
read -p "Project:  " PROJECT
echo

# Find available port
PORT=$(find_available_local_port $DEFAULT_PORT)
if [[ -z "$PORT" ]]; then
    echo "Error: No available ports found"
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