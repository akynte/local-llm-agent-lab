# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 akynte (see the copyright line in LICENSE)
#
# Extraction program for results/strata/2026-11-02-config-sweep/engine-metrics.tsv
#
# Usage (lo, hi and R are required; the program refuses to run without them):
#   ENGINE_LOG=<path to your private engine log>                 # never committed
#   INSTALL_ROOT=<absolute path to your local Strata install root>   # never committed
#   HOME_DIR=<absolute path to your home directory>              # optional here, recommended
#   awk -v lo=12627 -v hi=13420 -v R="$INSTALL_ROOT" -v H="$HOME_DIR" -f extract.awk "$ENGINE_LOG"
#
# Write the header line first, exactly as the dataset README shows:
#   printf 'kind\tlog_line\tengine_started_local\tpayload\n' > engine-metrics.tsv
#   awk … -f extract.awk "$ENGINE_LOG" >> engine-metrics.tsv
#
# Optional: -v expect=134 asserts the exact record count this window must produce.
# Optional: -v allow_empty=1 permits a zero-record window (off by default).
#
# R is passed in rather than written into this file, so the published program contains no absolute
# personal path. R is removed by four literal rules, longest first: three specific rules make paths under
# the install root install-relative — "<root>/Strata-data/models/x.gguf" becomes "models/x.gguf" — and the
# generic R + "/" rule produces <STRATA_INSTALL_ROOT> for a path under the root that none of the three
# specific rules matched. Which form a dataset shows depends on the lines in that window, not on this
# program; see this directory's README.md. The diagnostics program sanitizes differently; see
# results/strata/2026-10-30-11-02-engine-diagnostics/extract.awk.
#
# Exit status: 0 records produced and no unsanitized path survived; 64 bad invocation (missing or
# malformed -v variable, no file argument); 65 zero records selected; 66 an absolute personal path
# survived sanitization. A failure prints a reason on stderr. It never writes a partial dataset and it
# never exits 0 having produced nothing.
#
# Sanitization is literal and boundary-aware, not regular-expression based: R (and H, if supplied) are
# supplied by a caller, so they are matched with index() and only where they begin a path and end at a
# path boundary. A caller-supplied value is never handed to the regular-expression engine. The history of
# why that rule exists, and the failure modes it prevents, are research findings and are recorded in this
# directory's README.md and in docs/evidence-inventory.md conflict C17.
#
# The published-path guard is (a) a defensive assertion that neither supplied root still stands as a
# complete path in a payload, and (b) a fixed list of home-directory roots (/home/, /Users/, /root/, /mnt/,
# /srv/, /export/, /run/, /var/home/). A personal path outside both is NOT detected — see
# docs/evidence-inventory.md §6.1. See tests/extract/ for synthetic regression cases.
#
# Syntax note: every condition is kept on one line, because the default awk on this host is mawk,
# which rejects a condition continued across lines with "missing ) near end of line".

# Selection whitelist — BROADER than the morning dataset's
# (results/strata/2026-11-02-mtp-attempts/extract.awk): this window DOES select the request-level counters
# "KV streaming:", "decode expert cache hit rate:" and "conversation cache:", which the morning dataset
# deliberately excludes. It also allows MTP refusal lines ("strata generate: mtp: …").
# Selected: engine start lines, expert-cache sizing, automatic prompt chunk, MTP load lines,
# MTP refusal/allocation-failure lines, prompt request records, KV-streaming / decode-hit-rate /
# conversation-cache counters.
# Not selected: usage text, ggml_cuda_init lines, load_hparams warnings, route-tail-skip counters.
#
# Payload rewriting is not only path substitution: san() also strips the "strata generate: " and
# "strata serve: " line prefixes and the "[strata] <date> <time> engine started: " prefix, so a payload
# is the log line with those prefixes and the install-root paths removed, not a byte-for-byte copy.

function die(msg) { print "extract.awk: " msg > "/dev/stderr"; bad = 1; exit 64 }
function need(name, val) { if (val == "") die("required -v " name "=<value> is missing or empty") }
function strip_slashes(v) { while (length(v) > 1 && substr(v, length(v)) == "/") v = substr(v, 1, length(v) - 1); return v }
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

function san(s) {
  s = litrep(s, R "/components/engine/0.1.55-linux-x86_64-cuda-cuda13/strata", "strata", 0);
  s = litrep(s, R "/Strata-data/", "", 0);
  s = litrep(s, R "/components/control/0.1.55/data/", "", 0);
  s = litrep(s, R "/", "<STRATA_INSTALL_ROOT>/", 0);
  if (H != "") s = litrep(s, H, "<HOME>", 1);
  sub(/^\[strata\] [0-9-]+ [0-9:]+ engine started: /, "", s);
  sub(/^strata generate: /, "", s);
  sub(/^strata serve: /, "", s);
  return s;
}
function emit(kind, s,   p) {
  p = san(s)
  n++
  buf[n] = kind "\t" NR "\t" ts "\t" p;
  if (has_root(p, R) || (H != "" && has_root(p, H)) || p ~ /\/(home|Users|root|mnt|srv|export|run|var\/home)[\/.]/) leak++
}

NR >= lo && NR <= hi {
  if ($0 ~ /^\[strata\] [0-9-]+ [0-9:]+ engine started/) { ts = substr($0, 10, 19); emit("engine_start", $0) }
  else if ($0 ~ /^strata generate: expert cache [0-9]+ slots/ || $0 ~ /^strata serve: prompt chunk auto/ || $0 ~ /^strata mtp: draft layer loaded/ || $0 ~ /^strata generate: mtp:/ || $0 ~ /^strata serve: prompt [0-9]+ tokens = / || $0 ~ /^strata serve: (KV streaming|decode expert cache hit rate|conversation cache):/) { emit("event", $0) }
}

BEGIN {
  if (ARGC != 2) die("no log file argument; pass \"$ENGINE_LOG\" after the -v assignments")
  need("lo", lo); need("hi", hi); need("R", R)
  if (lo !~ /^[0-9]+$/ || hi !~ /^[0-9]+$/) die("lo and hi must be decimal line numbers (got lo=" lo " hi=" hi ")")
  lo += 0; hi += 0
  if (lo < 1) die("lo must be >= 1 (got " lo ")")
  if (hi < lo) die("hi must be >= lo (got lo=" lo " hi=" hi ")")
  if (substr(R, 1, 1) != "/") die("-v R= must be an absolute path (got " R ")")
  R = strip_slashes(R)
  if (H != "") { if (substr(H, 1, 1) != "/") die("-v H= must be an absolute path (got " H ")"); H = strip_slashes(H) }
  if (expect != "") { if (expect !~ /^[0-9]+$/) die("expect must be a decimal record count (got " expect ")"); expect += 0 }
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
