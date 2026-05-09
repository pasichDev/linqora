#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR/.."
OUT="$SCRIPT_DIR"

cd "$ROOT/LinqoraHost"

echo "Building CLI (headless)..."
go build -tags cli -o "$OUT/linqora" ./cmd/
echo "  -> $OUT/linqora"

echo "Building GUI (full)..."
go build -o "$OUT/linqorahost" ./cmd/
echo "  -> $OUT/linqorahost"

echo "Done."
