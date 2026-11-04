# Extraction program for results/strata/2026-11-02-config-sweep/engine-metrics.tsv
#
# Usage:
#   ENGINE_LOG=<path to your private engine log>      # never committed
#   INSTALL_ROOT=<path to your local Strata install root>   # never committed
#   awk -v lo=12627 -v hi=13420 -v R="$INSTALL_ROOT" -f extract.awk "$ENGINE_LOG"
#
# Write the header line first, exactly as the dataset README shows:
#   printf 'kind\tlog_line\tengine_started_local\tpayload\n' > engine-metrics.tsv
#   awk … -f extract.awk "$ENGINE_LOG" >> engine-metrics.tsv
#
# R is passed in rather than written into this file, so the published program contains no absolute
# personal path. R is replaced without adding a separator, so "<root>/Strata-data/…" becomes
# "<STRATA_INSTALL_ROOT>/Strata-data/…".
#
# Syntax note: every condition is kept on one line, because the default awk on this host is mawk,
# which rejects a condition continued across lines with "missing ) near end of line".

# Selection whitelist — BROADER than the morning dataset's
# (results/strata/2026-11-02-mtp-attempts/extract.awk): this window DOES select the request-level counters
# "KV streaming:", "decode expert cache hit rate:" and "conversation cache:", which the morning dataset
# deliberately excludes. It also allows MTP refusal lines ("strata generate: mtp: …"), though this window
# contains none.
# Selected: engine start lines, expert-cache sizing, automatic prompt chunk, MTP load lines,
# MTP refusal/allocation-failure lines, prompt request records, KV-streaming / decode-hit-rate /
# conversation-cache counters.
# Not selected: usage text, ggml_cuda_init lines, load_hparams warnings, route-tail-skip counters.

NR >= lo && NR <= hi {
  if ($0 ~ /^\[strata\] [0-9-]+ [0-9:]+ engine started/) { ts = substr($0, 10, 19); print "engine_start\t" NR "\t" ts "\t" san($0) }
  else if ($0 ~ /^strata generate: expert cache [0-9]+ slots/ || $0 ~ /^strata serve: prompt chunk auto/ || $0 ~ /^strata mtp: draft layer loaded/ || $0 ~ /^strata generate: mtp:/ || $0 ~ /^strata serve: prompt [0-9]+ tokens = / || $0 ~ /^strata serve: (KV streaming|decode expert cache hit rate|conversation cache):/) { print "event\t" NR "\t" ts "\t" san($0) }
}

function san(s) {
  gsub(R "/components/engine/0\\.1\\.55-linux-x86_64-cuda-cuda13/strata", "strata", s);
  gsub(R "/Strata-data/", "", s);
  gsub(R "/components/control/0\\.1\\.55/data/", "", s);
  gsub(R "/", "<STRATA_INSTALL_ROOT>/", s);
  sub(/^\[strata\] [0-9-]+ [0-9:]+ engine started: /, "", s);
  sub(/^strata generate: /, "", s);
  sub(/^strata serve: /, "", s);
  return s;
}
