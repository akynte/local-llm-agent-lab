#!/bin/sh
# CPU-only validation entry point for local-llm-agent-lab.
#
#   sh scripts/validate.sh              full validation of the published record
#   sh scripts/validate.sh --reextract <private-archive-dir>
#
# The plain form needs only: git, awk (mawk or gawk), python3, and the repository checkout.
# It runs no model, no engine, no benchmark and no network call. --reextract reads a private log
# directory you name; it is never part of CI and it writes only under .tmp/ (gitignored).
#
# Exit status mirrors scripts/validate.py: 0 clean, 1 a check failed, 2 usage error.

set -eu
cd "$(dirname "$0")/.."

if ! command -v python3 >/dev/null 2>&1; then
  echo "validate.sh: python3 is required" >&2
  exit 2
fi
if ! command -v awk >/dev/null 2>&1; then
  echo "validate.sh: awk is required (this host's default is mawk 1.3.4)" >&2
  exit 2
fi

echo "awk flavour: $(awk --version 2>/dev/null | head -1 || awk -W version 2>&1 | head -1)"
echo "python: $(python3 --version)"

# 1. published-record validation, claim recomputation, publication-safety scan,
#    and the synthetic extraction regression tests (run inside validate.py, check [8])
python3 scripts/validate.py "$@"
