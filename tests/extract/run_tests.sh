#!/bin/sh
# Regression tests for the three committed extract.awk programs.
#
# Everything here is synthetic. No real engine log, no real install root, no real home directory,
# no credential and no personal path appears in any fixture or expectation in this file.
#
# Run:  sh tests/extract/run_tests.sh        (from the repository root)
# Exit: 0 all cases passed, 1 at least one failed.
#
# What these tests pin down, in response to the defects found in the 2026-11-05 audit:
#   A  an invalid invocation fails with a nonzero status instead of silently producing no records
#   B  a supplied root or home directory is matched literally and only at a path boundary, never as
#      a regular expression, and never inside a longer path component
#   C  an absolute personal path that survives sanitization is refused rather than published
#   D  a zero-record window is an error unless explicitly allowed
#   E  the published datasets' own behaviour is unchanged (checked separately by
#      scripts/validate.sh --reextract, which needs the private archive)

set -u
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
DIAG="$ROOT/results/strata/2026-10-30-11-02-engine-diagnostics/extract.awk"
EVE="$ROOT/results/strata/2026-11-02-config-sweep/extract.awk"
MOR="$ROOT/results/strata/2026-11-02-mtp-attempts/extract.awk"

AWK=${AWK:-awk}
WORK=$(mktemp -d 2>/dev/null || echo /tmp/extract-tests.$$)
mkdir -p "$WORK"; trap 'rm -rf "$WORK"' EXIT INT TERM

pass=0; fail=0
HDR='kind	log_line	engine_started_local	payload'

# Synthetic values only.
SR='/opt/example-strata'                    # a plain install root
SM='/opt/build+strata(v2)'                  # a root full of regex metacharacters
SH='/home/example'                          # a synthetic home directory
SRV2='/opt/example-strata-v2'               # a similar-but-different prefix

ok()   { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
bad()  { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }

# expect_status <want> <label> -- command...
expect_status() {
  want=$1; label=$2; shift 3
  out=$("$@" >"$WORK/o" 2>"$WORK/e"); st=$?
  if [ "$st" -eq "$want" ]; then ok "$label (exit $st)"; else
    bad "$label (exit $st, wanted $want)"; sed 's/^/       /' "$WORK/e" | head -3
  fi
}

# expect_payload <label> <program> <log> <lo> <hi> <R> [extra -v ...]
# Prints the payload column of the first record.
payload_of() {
  label=$1; prog=$2; log=$3; lo=$4; hi=$5; R=$6; shift 6
  printf '%s\n' "$HDR" > "$WORK/p.tsv"
  $AWK -v lo="$lo" -v hi="$hi" -v R="$R" "$@" -f "$prog" "$log" >> "$WORK/p.tsv" 2>"$WORK/e"
  sed -n '2p' "$WORK/p.tsv" | cut -f4-
}

# ---------------------------------------------------------------- fixtures
cat > "$WORK/plain.log" <<EOF
[strata] 2026-01-01 00:00:00 engine started: $SR/components/engine/0.1.55-linux-x86_64-cuda-cuda13/strata --serve --native $SR/Strata-data/models/x.gguf --profile $SR/components/control/0.1.55/data/expert-profile.bin
strata generate: expert cache 100 slots, 1.00 GiB of VRAM; policy is
strata serve: prompt 5000 tokens = 0 reused + 5000 read in 10 ms (500.0 tok/s), 1000 generated in 40 ms (25.0 tok/s), drafts accepted 0 of 0
EOF

cat > "$WORK/meta.log" <<EOF
[strata] 2026-01-01 00:00:00 engine started: $SM/components/engine/0.1.55-linux-x86_64-cuda-cuda13/strata --serve --native $SM/Strata-data/models/x.gguf --profile $SM/components/control/0.1.55/data/expert-profile.bin
strata serve: prompt 5000 tokens = 0 reused + 5000 read in 10 ms (500.0 tok/s), 1000 generated in 40 ms (25.0 tok/s), drafts accepted 0 of 0
EOF

# A log whose paths look like the metacharacter root only because "." matched any character, and one
# whose component is the root's prefix plus extra characters. Both must survive untouched, because
# neither is the supplied root.
cat > "$WORK/near.log" <<EOF
[strata] 2026-01-01 00:00:00 engine started: $SR/components/engine/0.1.55-linux-x86_64-cuda-cuda13/strata --serve --native $SR-v2/models/other.gguf --decoy /opt/exampleXstrata/models/decoy.gguf
strata serve: prompt 5000 tokens = 0 reused + 5000 read in 10 ms (500.0 tok/s), 1000 generated in 40 ms (25.0 tok/s), drafts accepted 0 of 0
EOF

# A home path that is not under the install root at all.
cat > "$WORK/home.log" <<EOF
[strata] 2026-01-01 00:00:00 engine started: $SR/components/engine/0.1.55-linux-x86_64-cuda-cuda13/strata --serve --cache $SH/.cache/thing --native $SR/Strata-data/models/x.gguf
strata serve: prompt 5000 tokens = 0 reused + 5000 read in 10 ms (500.0 tok/s), 1000 generated in 40 ms (25.0 tok/s), drafts accepted 0 of 0
EOF

# Diagnostics fixture: a selected line followed by two chained continuation lines; after a blank line,
# an indented line that follows nothing selected must not be published.
cat > "$WORK/diag.log" <<EOF
strata generate: expert cache 100 slots, 1.00 GiB of VRAM; policy is
   first continuation
   second continuation

   orphan after empty line
unknown argument: --not-a-real-flag
EOF

# Diagnostics fixture whose selected line carries a home-directory path, for the leak-detection case.
cat > "$WORK/diagpath.log" <<EOF
strata generate: expert arena $SH/.cache/arena.bin (2048 MiB)
EOF

echo "== A. invalid invocations must fail, not produce an empty dataset =="
for prog in "$EVE" "$MOR"; do
  expect_status 64 "missing lo/hi"      -- $AWK -v R="$SR" -f "$prog" "$WORK/plain.log"
  expect_status 64 "swapped lo>hi"      -- $AWK -v lo=9 -v hi=1 -v R="$SR" -f "$prog" "$WORK/plain.log"
  expect_status 64 "non-numeric lo"     -- $AWK -v lo=abc -v hi=9 -v R="$SR" -f "$prog" "$WORK/plain.log"
  expect_status 64 "lo=0"               -- $AWK -v lo=0 -v hi=9 -v R="$SR" -f "$prog" "$WORK/plain.log"
  expect_status 64 "empty R"            -- $AWK -v lo=1 -v hi=9 -v R= -f "$prog" "$WORK/plain.log"
  expect_status 64 "relative R"         -- $AWK -v lo=1 -v hi=9 -v R=opt/strata -f "$prog" "$WORK/plain.log"
  expect_status 64 "no file argument"   -- $AWK -v lo=1 -v hi=9 -v R="$SR" -f "$prog" < "$WORK/plain.log"
  expect_status 64 "bad expect value"   -- $AWK -v lo=1 -v hi=9 -v R="$SR" -v expect=many -f "$prog" "$WORK/plain.log"
done
expect_status 64 "diagnostics: missing lo/hi" -- $AWK -v R="$SR" -v H="$SH" -f "$DIAG" "$WORK/diag.log"
expect_status 64 "diagnostics: missing H"     -- $AWK -v lo=1 -v hi=9 -v R="$SR" -f "$DIAG" "$WORK/diag.log"
expect_status 64 "diagnostics: empty H"       -- $AWK -v lo=1 -v hi=9 -v R="$SR" -v H= -f "$DIAG" "$WORK/diag.log"

echo "== D. a zero-record window is an error unless allowed =="
expect_status 65 "window past end of file" -- $AWK -v lo=999 -v hi=1000 -v R="$SR" -f "$EVE" "$WORK/plain.log"
expect_status 0  "allow_empty=1 override"  -- $AWK -v lo=999 -v hi=1000 -v R="$SR" -v allow_empty=1 -f "$EVE" "$WORK/plain.log"
expect_status 65 "expect count mismatch"   -- $AWK -v lo=1 -v hi=9 -v R="$SR" -v expect=99 -f "$EVE" "$WORK/plain.log"
expect_status 0  "expect count match"      -- $AWK -v lo=1 -v hi=9 -v R="$SR" -v expect=3 -f "$EVE" "$WORK/plain.log"

echo "== C. an unsanitized personal path is refused rather than published =="
# R is a root that does not appear in this log, so the paths in it cannot be sanitized. The guard is
# then the generic home-directory shape check, which catches $SH/... even though the program was told
# about a different root.
expect_status 66 "wrong R leaves a home path" -- $AWK -v lo=1 -v hi=9 -v R=/opt/some-other-root -f "$EVE" "$WORK/home.log"
expect_status 66 "diagnostics: wrong H leaves a home path" -- $AWK -v lo=1 -v hi=9 -v R="$SR" -v H=/home/wrong-example -f "$DIAG" "$WORK/diagpath.log"
expect_status 0  "diagnostics: correct H sanitizes it"     -- $AWK -v lo=1 -v hi=9 -v R="$SR" -v H="$SH" -f "$DIAG" "$WORK/diagpath.log"
expect_status 0  "correct R sanitizes the same fixture"   -- $AWK -v lo=1 -v hi=9 -v R="$SR" -v H="$SH" -f "$EVE" "$WORK/home.log"

echo "== B. supplied roots are matched literally, at a path boundary only =="
p=$(payload_of x "$EVE" "$WORK/meta.log" 1 2 "$SM"); case "$p" in
  *"build+strata(v2)"*) bad "metacharacter root still present in payload: $p";;
  *"<STRATA_INSTALL_ROOT>"*) bad "metacharacter root left a placeholder path: $p";;
  *"models/x.gguf"*) ok "metacharacter root sanitized literally: $p";;
  *) bad "unexpected payload: $p";;
esac
# The old behaviour, for contrast: gsub(R "/") with R containing + and ( treated them as regex.
if printf '%s\n' "$p" | grep -q 'strata(v2)'; then bad "regex metacharacters leaked"; else ok "no regex metacharacters in output"; fi

p=$(payload_of x "$EVE" "$WORK/near.log" 1 2 "$SR")
case "$p" in
  *"$SR-v2"*|*"example-strata-v2"*) ok "similar-but-different prefix preserved: $p";;
  *"<STRATA_INSTALL_ROOT>-v2"*) bad "prefix-similar path was rewritten into a fake path: $p";;
  *) bad "unexpected payload: $p";;
esac
case "$p" in
  *"exampleXstrata"*) ok "regex-style decoy left untouched (it is not the root): $p";;
  *) bad "decoy path was rewritten: $p";;
esac

# Trailing slash on R must not silently disable sanitization.
a=$(payload_of x "$EVE" "$WORK/plain.log" 1 3 "$SR")
b=$(payload_of x "$EVE" "$WORK/plain.log" 1 3 "$SR/")
[ "$a" = "$b" ] && ok "trailing slash on R gives the same payload" || bad "trailing slash changed sanitization: [$a] vs [$b]"

# Empty-pattern corruption: the placeholder must never appear between every character of a payload.
if printf '%s\n' "$a" | grep -q '<STRATA_INSTALL_ROOT>.*<STRATA_INSTALL_ROOT>.*<STRATA_INSTALL_ROOT>'; then
  bad "placeholder inserted repeatedly (empty-pattern corruption)"
else
  ok "no empty-pattern corruption"
fi

# Home directory outside the install root is replaced, and only where it starts a path.
p=$(printf '%s\n' "$HDR" > "$WORK/h.tsv"; $AWK -v lo=1 -v hi=2 -v R="$SR" -v H="$SH" -f "$EVE" "$WORK/home.log" >> "$WORK/h.tsv"; sed -n '2p' "$WORK/h.tsv" | cut -f4-)
case "$p" in
  *"<HOME>/.cache/thing"*"models/x.gguf"*) ok "home path outside the root replaced: $p";;
  *"/home/example"*) bad "home path survived sanitization: $p";;
  *) bad "unexpected payload: $p";;
esac
# Without -v H the install-root rules must still give identical output for a log with no home paths.
c=$(payload_of x "$EVE" "$WORK/plain.log" 1 3 "$SR")
d=$(printf '%s\n' "$HDR" > "$WORK/n.tsv"; $AWK -v lo=1 -v hi=3 -v R="$SR" -v H="$SH" -f "$EVE" "$WORK/plain.log" >> "$WORK/n.tsv"; sed -n '2p' "$WORK/n.tsv" | cut -f4-)
[ "$c" = "$d" ] && ok "supplying -v H is a no-op when the log has no home paths" || bad "-v H changed the payload: [$c] vs [$d]"

echo "== E. selection behaviour is unchanged =="
# Continuation lines chain after a selected line, and an indented line that follows nothing selected
# is not published.
$AWK -v lo=1 -v hi=9 -v R="$SR" -v H="$SH" -v expect=4 -f "$DIAG" "$WORK/diag.log" > "$WORK/d.tsv" 2>"$WORK/e"
st=$?
kinds=$(cut -f1 "$WORK/d.tsv" | tr '\n' ' ')
if [ "$st" -eq 0 ] && [ "$kinds" = "event continuation continuation event " ]; then
  ok "diagnostics continuation chain preserved: $kinds"
else
  bad "continuation chain changed (exit $st, kinds: $kinds)"; cat "$WORK/e" | sed 's/^/       /'
fi
# The engine-start timestamp column and the no-engine-start-seen sentinel.
$AWK -v lo=1 -v hi=9 -v R="$SR" -v H="$SH" -f "$DIAG" "$WORK/diag.log" | cut -f3 | sort -u > "$WORK/ts"
grep -q 'no-engine-start-seen' "$WORK/ts" && ok "no-engine-start-seen sentinel preserved" || bad "sentinel changed"
# The two request programs must differ exactly as documented: the morning one omits the counters.
printf '%s\n' "$HDR" > "$WORK/c.tsv"
cat > "$WORK/counter.log" <<EOF
strata serve: KV streaming: 20480 of 262144 cells resident
strata serve: decode expert cache hit rate: 31.9% (10 hits / 31 lookups)
strata serve: conversation cache: 262144 tokens kept
strata serve: prompt 5000 tokens = 0 reused + 5000 read in 10 ms (500.0 tok/s), 1000 generated in 40 ms (25.0 tok/s), drafts accepted 0 of 0
EOF
$AWK -v lo=1 -v hi=9 -v R="$SR" -f "$EVE" "$WORK/counter.log" >> "$WORK/c.tsv"
$AWK -v lo=1 -v hi=9 -v R="$SR" -f "$MOR" "$WORK/counter.log" > "$WORK/m.tsv" 2>/dev/null
ne=$(wc -l < "$WORK/c.tsv"); nm=$(wc -l < "$WORK/m.tsv")
if [ "$ne" -eq 5 ] && [ "$nm" -eq 1 ]; then ok "documented whitelist difference reproduced (evening 4 records, morning 1)"
else bad "whitelist difference changed (evening $((ne-1)), morning $((nm-1)))"; fi

echo "== F. a rejected run writes nothing at all =="
$AWK -v lo=1 -v hi=9 -v R=/opt/some-other-root -f "$EVE" "$WORK/home.log" > "$WORK/leak.out" 2>/dev/null
if [ ! -s "$WORK/leak.out" ]; then ok "a run refused for path leakage emitted no records"; else bad "refused run emitted $(wc -l < "$WORK/leak.out") records"; fi
$AWK -v lo=999 -v hi=1000 -v R="$SR" -f "$EVE" "$WORK/plain.log" > "$WORK/zero.out" 2>/dev/null
if [ ! -s "$WORK/zero.out" ]; then ok "a zero-record window emitted no records"; else bad "zero-record run emitted $(wc -l < "$WORK/zero.out") records"; fi
$AWK -v lo=1 -v hi=9 -v R="$SR" -v expect=99 -f "$EVE" "$WORK/plain.log" > "$WORK/exp.out" 2>/dev/null
if [ ! -s "$WORK/exp.out" ]; then ok "an expect-count mismatch emitted no records"; else bad "expect-mismatch run emitted $(wc -l < "$WORK/exp.out") records"; fi
$AWK -v lo=1 -v hi=9 -v R="$SR" -v H="$SH" -v expect=99 -f "$DIAG" "$WORK/diag.log" > "$WORK/dexp.out" 2>/dev/null
if [ ! -s "$WORK/dexp.out" ]; then ok "diagnostics expect-count mismatch emitted no records"; else bad "diagnostics expect-mismatch run emitted $(wc -l < "$WORK/dexp.out") records"; fi

# A successful run emits exactly the selected records, in window order, with the header supplied by the caller.
printf '%s\n' "$HDR" > "$WORK/ok.tsv"
$AWK -v lo=1 -v hi=9 -v R="$SR" -v expect=3 -f "$EVE" "$WORK/plain.log" >> "$WORK/ok.tsv" 2>/dev/null
nrec=$(sed -n '2,$p' "$WORK/ok.tsv" | wc -l)
lines=$(sed -n '2,$p' "$WORK/ok.tsv" | cut -f2 | tr '\n' ' ')
if [ "$nrec" -eq 3 ] && [ "$lines" = "1 2 3 " ]; then ok "accepted run emits records in window order: $lines"
else bad "record order or count changed ($nrec records: $lines)"; fi

echo
echo "passed=$pass failed=$fail"
[ "$fail" -eq 0 ] || exit 1
