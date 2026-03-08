#!/usr/bin/env bash
# deploy-pi.sh — Build zeroclaw for Raspberry Pi Zero 2W (aarch64) and deploy via SSH.
#
# Requirements (first-time setup):
#   cargo install cargo-zigbuild --locked
#   brew install zig
#   rustup target add aarch64-unknown-linux-gnu
#
# Usage:
#   ./deploy-pi.sh [user@host] [remote_path]
#
# Defaults:
#   user@host    = boti@boti
#   remote_path  = /usr/local/bin/zeroclaw

set -euo pipefail

TARGET="aarch64-unknown-linux-gnu"
PROFILE="release"
BINARY="zeroclaw"
PI_HOST="${1:-boti@boti}"
PI_PATH="${2:-/usr/local/bin/zeroclaw}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BINARY_PATH="$SCRIPT_DIR/target/$TARGET/$PROFILE/$BINARY"

# ── Preflight checks ──────────────────────────────────────────────────────────

check_tool() {
    if ! command -v "$1" &>/dev/null; then
        echo "ERROR: '$1' not found. Install with: $2"
        exit 1
    fi
}

check_tool cargo        "curl https://sh.rustup.rs | sh"
check_tool cargo-zigbuild "cargo install cargo-zigbuild --locked"
check_tool zig          "brew install zig"

if ! rustup target list --installed | grep -q "$TARGET"; then
    echo "Adding rustup target $TARGET ..."
    rustup target add "$TARGET"
fi

# ── Build ─────────────────────────────────────────────────────────────────────

echo "Building $BINARY for $TARGET (profile: $PROFILE) ..."
cd "$SCRIPT_DIR"
cargo zigbuild --target "$TARGET" --"$PROFILE" --features whatsapp-web

echo "Binary: $BINARY_PATH ($(du -sh "$BINARY_PATH" | cut -f1))"

# ── Deploy ────────────────────────────────────────────────────────────────────

echo "Copying to $PI_HOST:$PI_PATH ..."
scp "$BINARY_PATH" "$PI_HOST:/tmp/$BINARY"

echo "Installing to $PI_PATH ..."
ssh "$PI_HOST" "sudo mv /tmp/$BINARY $PI_PATH && sudo chmod +x $PI_PATH"

echo "Verifying ..."
ssh "$PI_HOST" "$PI_PATH --version"

echo "Done. $BINARY deployed to $PI_HOST:$PI_PATH"
