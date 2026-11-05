# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 akynte (see the copyright line in LICENSE)
#
# Extraction program for results/strata/2026-10-30-11-02-engine-diagnostics/engine-diagnostics.tsv
#
# Usage (all four variables are required; the program refuses to run without them):
#   ENGINE_LOG=<path to your private engine log>     # never committed
#   INSTALL_ROOT=<absolute path to your Strata install root>   # never committed
#   HOME_DIR=<absolute path to your home directory>  # never committed
#   awk -v lo=1 -v hi=13420 -v R="$INSTALL_ROOT" -v H="$HOME_DIR" -f extract.awk "$ENGINE_LOG"
#
# Write the header line first, exactly as the dataset README shows:
#   printf 'kind\tlog_line\tengine_started_local\tpayload\n' > engine-diagnostics.tsv
#   awk … -f extract.awk "$ENGINE_LOG" >> engine-diagnostics.tsv
#
# Optional: -v expect=1941 asserts the exact record count this window must produce.
# Optional: -v allow_empty=1 permits a zero-record window (off by default).
#
# The install root and home directory are passed in rather than written into this file, so that the
# published program contains no absolute personal path.
#
# Exit status: 0 records produced and no unsanitized path survived; 64 bad invocation (missing or
# malformed -v variable, no file argument); 65 zero records selected; 66 an absolute personal path
# survived sanitization. A failure prints a reason on stderr. It never writes a partial dataset and it
# never exits 0 having produced nothing.
#
# Sanitization is literal and boundary-aware, not regular-expression based: R and H are supplied by a
# caller, so they are matched with index() and only where they begin a path and end at a path boundary.
# A caller-supplied value is never handed to the regular-expression engine. The history of why that rule
# exists, and the failure modes it prevents, are research findings and are recorded in this directory's
# README.md and in docs/evidence-inventory.md conflict C17.
#
# The published-path guard is (a) a defensive assertion that neither supplied root still stands as a
# complete path in a payload, and (b) a fixed list of home-directory roots (/home/, /Users/, /root/, /mnt/,
# /srv/, /export/, /run/, /var/home/). A personal path outside both is NOT detected — see
# docs/evidence-inventory.md §6.1. See tests/extract/ for synthetic regression cases.
#
# Syntax note: every condition is kept on one line, because the default awk on this host is mawk,
# which rejects a condition continued across lines with "missing ) near end of line".

function die(msg,   code) {
  print "extract.awk: " msg > "/dev/stderr"
  bad = 1
  exit 64
}
function need(name, val) {
  if (val == "") die("required -v " name "=<value> is missing or empty")
}
function strip_slashes(v) {
  while (length(v) > 1 && substr(v, length(v)) == "/") v = substr(v, 1, length(v) - 1)
  return v
}
# A path begins here if the preceding character is start-of-line or a delimiter, never a
# character that could be part of a longer path component.
function pathstart(c) {
  return c == "" || c == " " || c == "\t" || c == "\"" || c == "'" || c == "=" || \
         c == "(" || c == ")" || c == "[" || c == "]" || c == "<" || c == ">" || \
         c == "," || c == ";"
}
# True when the literal `lit` still stands as a complete path in s, i.e. it begins a path and ends at a
# path boundary. Used as a defensive post-sanitization assertion; the primary guard is the generic
# home-directory shape test in emit().
function has_root(s, lit,   i, nxt) {
  if (lit == "") return 0
  while ((i = index(s, lit)) > 0) {
    nxt = substr(s, i + length(lit), 1)
    if (pathstart(i > 1 ? substr(s, i - 1, 1) : "") && (nxt == "" || nxt == "/")) return 1
    s = substr(s, i + length(lit))
  }
  return 0
}
# Literal replacement. `from` is never interpreted as a regular expression.
# right=1 additionally requires the match to end at a path boundary (end of string or "/").
function litrep(s, from, to, right,   i, nxt, out) {
  if (from == "") return s
  out = ""
  while ((i = index(s, from)) > 0) {
    nxt = substr(s, i + length(from), 1)
    if (pathstart(i > 1 ? substr(s, i - 1, 1) : "") && (!right || nxt == "" || nxt == "/")) {
      out = out substr(s, 1, i - 1) to
    } else {
      out = out substr(s, 1, i + length(from) - 1)
    }
    s = substr(s, i + length(from))
  }
  return out s
}

function san(s){
  s = litrep(s, R, "<STRATA_INSTALL_ROOT>", 1);
  s = litrep(s, H, "<HOME>", 1);
  sub(/^\[strata\] [0-9-]+ [0-9:]+ engine started: /, "", s);
  return s
}
function emit(kind, s,   p){
  p = san(s)
  n++
  buf[n] = kind "\t" NR "\t" (ts == "" ? "no-engine-start-seen" : ts) "\t" p;
  hit = 1
  if (has_root(p, R) || has_root(p, H) || p ~ /\/(home|Users|root|mnt|srv|export|run|var\/home)[\/.]/) leak++
}

BEGIN {
  if (ARGC != 2) die("no log file argument; pass \"$ENGINE_LOG\" after the -v assignments")
  need("lo", lo); need("hi", hi); need("R", R); need("H", H)
  if (lo !~ /^[0-9]+$/ || hi !~ /^[0-9]+$/) die("lo and hi must be decimal line numbers (got lo=" lo " hi=" hi ")")
  lo += 0; hi += 0
  if (lo < 1) die("lo must be >= 1 (got " lo ")")
  if (hi < lo) die("hi must be >= lo (got lo=" lo " hi=" hi ")")
  if (substr(R, 1, 1) != "/") die("-v R= must be an absolute path (got " R ")")
  if (substr(H, 1, 1) != "/") die("-v H= must be an absolute path (got " H ")")
  R = strip_slashes(R); H = strip_slashes(H)
  if (expect != "") { if (expect !~ /^[0-9]+$/) die("expect must be a decimal record count (got " expect ")"); expect += 0 }
}

{
  if (NR < lo || NR > hi) next
  hit = 0
  if ($0 ~ /^[ \t]/) { if (prev_hit) emit("continuation", $0); prev_hit = hit; next }
  prev_hit = 0
  if ($0 ~ /^\[strata\] [0-9-]+ [0-9:]+ engine started/) { ts = substr($0, 10, 19); emit("engine_start", $0) }
  else if ($0 ~ /^strata generate: (memory guard:|PCIe probe:|this CPU has no AVX-512|expert arena|expert cache auto|expert cache [0-9]+ slots|CPU pool|CPU workers on|CPU pool tasks|[0-9]+ (expert-pool|pool) workers|[0-9]+ MiB of weights loaded|[0-9]+ native projection|loaded [0-9.]+ GiB|PLE |profile |KV streaming: [0-9]+ of|the SSD is kept awake|session is up|mtp:|pre-filled |R4 hit path|token graph hit path|GPU 0:|GPU host-callback|experimental native|native pack|the GPU computes the experts)/ || $0 ~ /^strata mtp: (draft layer loaded|draft head over)/ || $0 ~ /^strata verify: window up to/ || $0 ~ /^strata serve: (prompt chunk auto|the prompt path borrows|WARNING: only|conversation cache sized from|conversation cache off|adaptive overlap|adaptive tier|cancelled request keeps|STRATA_)/ || $0 ~ /^prefill: the CPU share is ON/ || $0 ~ /^strata aux cpus:/ || $0 ~ /^unknown argument:/ || $0 ~ /^strata-vision:/ || $0 ~ /^ggml_cuda_init:/ || $0 ~ /^load_hparams: (Qwen-VL models require|if you encounter problems)/) emit("event", $0)
  prev_hit = hit
}

END {
  if (bad) exit
  if (leak) { print "extract.awk: " leak " record(s) still contain an absolute personal path after sanitization — refusing to publish, nothing written" > "/dev/stderr"; exit 66 }
  if (n == 0 && !allow_empty) {
    print "extract.awk: window " lo ".." hi " selected 0 records. Either the window variables are wrong, or that window of this log contains no whitelisted line (the log is not provably append-only, so a zero-row output is not proof of either). Nothing was written." > "/dev/stderr"
    exit 65
  }
  if (expect != "" && n != expect) { print "extract.awk: window " lo ".." hi " produced " n " records, expected " expect " — refusing to publish, nothing written" > "/dev/stderr"; exit 65 }
  # Output is buffered until this point so that a rejected run writes nothing at all, not a partial dataset.
  for (i = 1; i <= n; i++) print buf[i]
}
