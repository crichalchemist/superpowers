#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "=== supercritic tests ==="
for t in "$SCRIPT_DIR"/test-*.sh; do
  echo; echo ">>> $t"; bash "$t"
done
echo; echo "=== All supercritic tests passed ==="
