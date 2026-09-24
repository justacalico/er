#!/usr/bin/env bash
# Fail if line coverage in an lcov.info file is below the given percent.
# Usage: check-coverage.sh [lcov.info] [min-percent]
set -euo pipefail

INFO="${1:-coverage/lcov.info}"
MIN="${2:-100}"

awk -v min="$MIN" '
  /^SF:/ {
    if (file != "" && total > 0) {
      printf "%s: %.1f%% (%d/%d)\n", file, hit * 100 / total, hit, total
      if (hit < total) bad++
    }
    file = substr($0, 4); total = 0; hit = 0
  }
  /^DA:/ {
    split(substr($0, 4), a, ",")
    total++
    if (a[2] + 0 > 0) hit++
  }
  END {
    if (file != "" && total > 0) {
      printf "%s: %.1f%% (%d/%d)\n", file, hit * 100 / total, hit, total
      if (hit < total) bad++
    }
    if (bad > 0) {
      printf "coverage below %d%% in %d file(s)\n", min, bad > "/dev/stderr"
      exit 1
    }
    print "coverage ok"
  }
' "$INFO"
