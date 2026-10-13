#!/bin/bash
set -euo pipefail
exec "$(dirname "$0")/../macos/scripts/build-macos.sh" "$@"
