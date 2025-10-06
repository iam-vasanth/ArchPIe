#!/bin/bash

# Common functions and utilities used across all modules

# Error log location
ERROR_LOG="/var/log/script_errors.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Trap errors and log them
trap 'echo "Error occurred at line $LINENO. Exit code: $?" | tee -a "$ERROR_LOG"; cleanup' ERR
trap 'cleanup' EXIT INT TERM

cleanup() {
    echo "Cleaning up..." | tee -a "$ERROR_LOG"
    stop_sudo_keeper
}

# Log messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Refresh sudo timestamp and keep it alive
keep_sudo_alive() {
    sudo -v
    while true; do
        sudo -n true
        sleep 50
        kill -0 "$$" || exit
    done 2>/dev/null &
    SUDO_KEEPER_PID=$!
}

# Stop the sudo keeper background process
stop_sudo_keeper() {
    if [[ -n "$SUDO_KEEPER_PID" ]]; then
        kill "$SUDO_KEEPER_PID" 2>/dev/null || true
    fi
}

# Progress bar function
show_progress() {
    local current=$1
    local total=$2
    local width=50
    local percentage=$((current * 100 / total))
    local completed=$((width * current / total))
    local remaining=$((width - completed))
    
    printf "\r${GREEN}[${NC}"
    printf "%${completed}s" | tr ' ' '█'
    printf "%${remaining}s" | tr ' ' '░'
    printf "${GREEN}]${NC} %3d%% (%d/%d)" "$percentage" "$current" "$total"
}