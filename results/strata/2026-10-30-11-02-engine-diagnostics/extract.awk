# Extraction program for results/strata/2026-10-30-11-02-engine-diagnostics/engine-diagnostics.tsv
#
# Usage:
#   ENGINE_LOG=<path to your private engine log>      # never committed
#   INSTALL_ROOT=<path to your local install root>    # never committed
#   HOME_DIR=<path to your home directory>            # never committed
#   awk -v lo=1 -v hi=13420 -v R="$INSTALL_ROOT" -v H="$HOME_DIR" -f extract.awk "$ENGINE_LOG"
#
# Write the header line first, exactly as the dataset README shows:
#   printf 'kind\tlog_line\tengine_started_local\tpayload\n' > engine-diagnostics.tsv
#   awk … -f extract.awk "$ENGINE_LOG" >> engine-diagnostics.tsv
#
# The install root and home directory are passed in rather than written into this file, so that the
# published program contains no absolute personal path. R is replaced without adding a separator, so
# "<root>/Strata-data/…" becomes "<STRATA_INSTALL_ROOT>/Strata-data/…".

function san(s){
  gsub(R, "<STRATA_INSTALL_ROOT>", s);
  gsub(H, "<HOME>", s);
  sub(/^\[strata\] [0-9-]+ [0-9:]+ engine started: /, "", s);
  return s
}
function emit(kind, s){
  print kind "\t" NR "\t" (ts == "" ? "no-engine-start-seen" : ts) "\t" san(s);
  hit = 1
}
{
  if (NR < lo || NR > hi) next
  hit = 0
  if ($0 ~ /^[ \t]/) { if (prev_hit) emit("continuation", $0); prev_hit = hit; next }
  prev_hit = 0
  if ($0 ~ /^\[strata\] [0-9-]+ [0-9:]+ engine started/) { ts = substr($0, 10, 19); emit("engine_start", $0) }
  else if ($0 ~ /^strata generate: (memory guard:|PCIe probe:|this CPU has no AVX-512|expert arena|expert cache auto|expert cache [0-9]+ slots|CPU pool|CPU workers on|CPU pool tasks|[0-9]+ (expert-pool|pool) workers|[0-9]+ MiB of weights loaded|[0-9]+ native projection|loaded [0-9.]+ GiB|PLE |profile |KV streaming: [0-9]+ of|the SSD is kept awake|session is up|mtp:|pre-filled |R4 hit path|token graph hit path|GPU 0:|GPU host-callback|experimental native|native pack|the GPU computes the experts)/ ||
           $0 ~ /^strata mtp: (draft layer loaded|draft head over)/ ||
           $0 ~ /^strata verify: window up to/ ||
           $0 ~ /^strata serve: (prompt chunk auto|the prompt path borrows|WARNING: only|conversation cache sized from|conversation cache off|adaptive overlap|adaptive tier|cancelled request keeps|STRATA_)/ ||
           $0 ~ /^prefill: the CPU share is ON/ ||
           $0 ~ /^strata aux cpus:/ || $0 ~ /^unknown argument:/ || $0 ~ /^strata-vision:/ ||
           $0 ~ /^ggml_cuda_init:/ || $0 ~ /^load_hparams: (Qwen-VL models require|if you encounter problems)/) emit("event", $0)
  prev_hit = hit
}
