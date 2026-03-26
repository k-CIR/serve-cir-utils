#!/bin/bash

read -p "Username: " USERNAME
read -p "Project:  " PROJECT
read -p "Serve HTML in browser? (y/N): " SERVE

if [[ "$SERVE" =~ ^[Yy]$ ]]; then
    read -p "Local port [8080]: " PORT
    PORT="${PORT:-8080}"
    echo "Forwarding remote port $PORT -> http://localhost:$PORT"
    echo "Open your browser at: http://localhost:$PORT"
    echo "Press Ctrl+C to disconnect."
    ssh -t \
        -o PubkeyAuthentication=no \
        -o PreferredAuthentications=password \
        -L "${PORT}:localhost:${PORT}" \
        "${USERNAME}@compute.kcir.se" \
        "cd /data/projects/${PROJECT} && PORT=${PORT} python3 server.py"
else
    ssh -t \
        -o PubkeyAuthentication=no \
        -o PreferredAuthentications=password \
        "${USERNAME}@compute.kcir.se" \
        "cd /data/projects/${PROJECT} && exec \$SHELL"
fi
