# Reproducibility

Three different things are reproducible here, and they are not the same activity. Read the section
that matches what you are trying to do.

| Goal | What you need | Section |
| --- | --- | --- |
| Re-derive the published result tables from published data | the TSV files in `results/` only | §1 |
| Re-verify the coding-agent exercise | Go 1.27+ and the source | §2 |
| Reproduce a measurement on your own machine | your own hardware, engine and model | §3, §4 |

Reproducing a *table* never requires model weights. Reproducing a *measurement* does.

---

## 1. Re-deriving published numbers from published data

The Strata result tables in `docs/findings.md` §1.1–§1.4 are derived from
`results/strata/2026-11-02-config-sweep/engine-metrics.tsv`; the §2.1 morning figures and the
189 737-token **longest completed cold prefill** come from
`results/strata/2026-11-02-mtp-attempts/engine-metrics.tsv`; the launch and configuration census in
§2.1 and §5 comes from `results/strata/2026-10-30-11-02-engine-diagnostics/engine-diagnostics.tsv`. The
derivation is a filter and a parse, so it is reproducible without the private log:

```sh
cd results/strata/2026-11-02-config-sweep
python3 - <<'EOF'
import re, statistics
pat = re.compile(r"prompt (\d+) tokens = (\d+) reused \+ (\d+) read in (\d+) ms \(([\d.]+) tok/s\),"
                 r" (\d+) generated in (\d+) ms \(([\d.]+) tok/s\), drafts accepted (\d+) of (\d+)")
cold, dec = [], []
for line in open("engine-metrics.tsv"):
    m = pat.search(line)
    if not m: continue
    P, R, G, pp, dp = int(m[1]), int(m[2]), int(m[6]), float(m[5]), float(m[8])
    if R == 0 and P >= 1000: cold.append(pp)
    if G >= 1000: dec.append(dp)
for name, v in (("cold prefill", cold), ("decode", dec)):
    print(f"{name}: n={len(v)} min={min(v):.1f} max={max(v):.1f} mean={statistics.mean(v):.1f}")
EOF
```

Expected output (it is a real measurement, not a target):

```
cold prefill: n=11 min=245.8 max=606.0 mean=520.4
decode: n=10 min=26.0 max=29.2 mean=27.5
```

Note the trap in that output: `n=11` mixes the MTP and no-MTP conditions, which is why
`docs/findings.md` §1.1 restricts its comparison to the five no-MTP runs of the identical 12 719-token
prompt — and why it further splits those five by argument vector, because only two of them share both one
argument vector **and** the same prompt.

A second trap sits in the `decode` line, and it contradicts the warm-exclusion rule stated in
`docs/methodology.md` §3.1: the filter is `generated >= 1000`, **not** `reused == 0`, so **four of the ten
decode rates come from warm reused-prompt records**, all four from the 20:54:54 launch (log lines 13380,
13400, 13412 and 13418, with 13 910 / 38 734 / 39 989 / 43 034 prompt tokens reused). Dropping them gives
`decode: n=6 min=26.0 max=29.2 mean=27.8`. The five no-MTP cold runs quoted in `docs/findings.md` §1.1 are
a third set again (26.5–29.2 tok/s, the 26.0 record belonging to the MTP launch). As published, the mean
27.5 tok/s is a mixed-condition figure and must not be quoted as "the decode rate".

A Phase 2 deliverable is a validator that refuses to average across mismatched conditions
instead of leaving that to the reader.

### Checking the launch census from published data

The census claims in `docs/findings.md` §2.1 and §5 and in `docs/hardware.md` can be re-derived the same
way:

```sh
cd results/strata/2026-10-30-11-02-engine-diagnostics

awk -F'\t' '$1=="engine_start"{v=($4 ~ /0\.1\.54-/ ? "0.1.54" : "0.1.55"); c[v]++} END{for(x in c) print x, c[x]}' engine-diagnostics.tsv
awk -F'\t' '$4 ~ /do not fit in VRAM/{n=split($4,a,"("); split(a[2],b," "); c[b[1]]++} END{for(x in c) print x" MiB free:", c[x]}' engine-diagnostics.tsv
awk -F'\t' '$4 ~ /draft layer loaded/{split($4,a,"loaded, "); split(a[2],b," "); c[b[1]]++} END{for(x in c) print x, c[x]}' engine-diagnostics.tsv
awk -F'\t' '$1=="engine_start"{v=($4 ~ /--vision/ ? "vision on" : "vision off"); c[v]++} END{for(x in c) print x, c[x]}' engine-diagnostics.tsv
awk -F'\t' '$4 ~ /^unknown argument/{c[$4]++} END{for(x in c) print x, c[x]}' engine-diagnostics.tsv
```

Output captured on 2026-11-03:

```
0.1.55 37
0.1.54 20
247 MiB free: 2
246 MiB free: 8
835 4
822 1
834 3
vision on 42
vision off 15
unknown argument: --kv-streaming 3
unknown argument: --draft-vocab 2
```

The `835 4` line is worth noticing: four of the eight successful draft loads report 835 MiB, one of them
on a 0.1.54-era launch. A claim like "the draft layer costs 835 MiB" or "it costs 822 MiB" is a
selection from this list, not a property.

### Census claims that need a slightly sharper command

The claims below were added during the 2026-11-03 correction pass. Each is re-derivable from the same
TSV, but the field position matters, so the exact commands and their captured output are given. All of
them are written for **mawk** (this host's default awk): they use `split()` and `RSTART`/`RLENGTH`
rather than gawk's three-argument `match()`.

```sh
awk -F'\t' '$4 ~ /PCIe probe:/{split($4,a," "); c[a[5]]++} END{for(x in c) print x, c[x]}' engine-diagnostics.tsv | sort -n
awk -F'\t' '$4 ~ /pcie_frac [0-9.]/{split($4,a,"pcie_frac "); split(a[2],b," "); c[b[1]]++} END{for(x in c) print x, c[x]}' engine-diagnostics.tsv | sort
awk -F'\t' '$1=="engine_start"{if(match($4,/--kv-resident [0-9]+/)) {split(substr($4,RSTART,RLENGTH),p," "); c[p[2]]++} else c["not-set"]++} END{for(x in c) print x, c[x]}' engine-diagnostics.tsv | sort -n
awk -F'\t' '$4 ~ /pool workers on logical/{split($4,a," "); c[a[3]]++} END{for(x in c) print x, c[x]}' engine-diagnostics.tsv | sort -n
awk -F'\t' '$4 ~ /Add --vram-reserve-mib/{split($4,a,"--vram-reserve-mib "); split(a[2],b," "); c[b[1]]++} END{for(x in c) print x, c[x]}' engine-diagnostics.tsv | sort -n
awk -F'\t' '$4 ~ /only [0-9]+ MiB of VRAM free/{split($4,a," "); c[a[5]]++} END{for(x in c) print x, c[x]}' engine-diagnostics.tsv | sort -n
awk -F'\t' '$4 ~ /window up to [0-9]+ tokens/{split($4,a," "); c[a[6]" tokens, "a[8]" MiB"]++} END{for(x in c) print x, c[x]}' engine-diagnostics.tsv | sort
awk -F'\t' '$1=="engine_start"{if(match($4,/--kv ([a-z0-9_]+)/)) {split(substr($4,RSTART,RLENGTH),p," "); c[p[2]]++} else c["not-set"]++} END{for(x in c) print x, c[x]}' engine-diagnostics.tsv | sort -n
awk -F'\t' '$1=="engine_start"{c[($4 ~ /--mtp/ ? "requests mtp" : "no mtp flag")]++} END{for(x in c) print x, c[x]}' engine-diagnostics.tsv
awk -F'\t' '$1=="engine_start"{c[($4 ~ /--vision/ ? "vision on" : "vision off")]++} END{for(x in c) print x, c[x]}' engine-diagnostics.tsv
awk -F'\t' '$1=="engine_start"{s[$3]=($4 ~ /--pcie-frac/ ? 1 : 0)} $4 ~ /PCIe probe:/{p[$3]=1} END{for(t in s){if(s[t]&&t in p)a++; else if(s[t])b++; else if(t in p)c++; else d++} print "probe+flag",a+0,"flag-no-probe",b+0,"probe-no-flag",c+0,"neither",d+0}' engine-diagnostics.tsv
awk -F'\t' '$1=="engine_start" && $4 ~ /--pool-workers 6/{s[$3]=1} $4 ~ /^unknown argument/{u[$3]=1} $4 ~ /pool workers on logical/{w[$3]=1} END{n5=0;n2=0;n1=0; for(t in s){if(t in u){n5++} else if(t in w){n2++} else {n1++}} print "pool-workers 6: died-on-unknown="n5+0" logged-worker-line="n2+0" no-worker-line="n1+0" launches="length(s)+0}' engine-diagnostics.tsv
awk -F'\t' '$4 ~ /conversation cache sized/{sz[$3]=1} $4 ~ /conversation cache off:/{off[$3]=1} $1=="engine_start"{s[$3]=1} END{n=0; for(t in s){c=0; if(t in sz)c++; if(t in off)c++; if(c==0)n++} print "conversation cache: sized="length(sz)+0" off="length(off)+0" neither-line="n+0" launches="length(s)+0}' engine-diagnostics.tsv
awk -F'\t' '$4 ~ /this CPU has no AVX-512/{a[$3]=1} $4 ~ /MAP_HUGETLB unavailable/{h[$3]=1} END{g=0; for(t in a) if(!(t in h)) g++; print "avx-line="length(a)+0" hugetlb-line="length(h)+0" avx-line-without-hugetlb-line="g+0}' engine-diagnostics.tsv
```

Output captured on 2026-11-03 (last three lines captured on 2026-11-04, after the claims they back were
corrected):

```
11.0 1          PCIe probe bandwidth, GB/s, best-of-four per launch
11.1 1          11.5 is the modal value, not a machine constant
11.2 1
11.4 14
11.5 20
11.6 5
0.30 1          pcie_frac the engine chose from the probe
0.31 17
0.32 24
8192 1          --kv-resident per launch (16 launches set none)
20480 20
24576 8
32768 12
not-set 16
6 2             pool-worker counts the engine actually logged
9 34
576 8           reserve value the engine advised in its VRAM-free warnings
704 2
832 2
960 1
259 1           MiB of VRAM free at request start, 13 warnings
341 1
396 1
438 1
467 1
496 3
508 5
6 tokens, 70.1 MiB 1     verify window size and device-buffer cost
6 tokens, 70.8 MiB 21
6 tokens, 75.9 MiB 8
8 tokens, 82.5 MiB 6
int8 29         --kv per launch
k8v4 17
q4_0 11
no mtp flag 32  launches whose argument vector has no --mtp
requests mtp 25
vision on 42
vision off 15
probe+flag 0     launches that both logged a probe line and passed --pcie-frac
flag-no-probe 15 launches that passed --pcie-frac and logged no probe line
probe-no-flag 42 launches that logged a probe and passed no --pcie-frac
neither 0
pool-workers 6: died-on-unknown=5 logged-worker-line=2 no-worker-line=1 launches=8
conversation cache: sized=27 off=7 neither-line=23 launches=57
avx-line=52 hugetlb-line=36 avx-line-without-hugetlb-line=16
```

Two cautions these outputs enforce. First, the pool-worker line count (34 + 2 = 36) is smaller than 57:
eight launches passed `--pool-workers 6`, only two of them logged a worker line, **five** died on unknown
arguments and one logged no worker line at all (2 + 5 + 1 = 8). Second, the warning-advice values
(576 / 704 / 832 / 960)
come from 13 separate warnings computed against different launch states; they are not a contradiction and
they are not one recommended number. Third, the probe census above shows the two populations are disjoint:
the engine probes the link only when `--pcie-frac` is absent, so "42 launches measured the link" and "15
launches overrode it" are complements, not overlapping groups.

**Three more claims rest on those last three commands**, all corrected on 2026-11-04 after an earlier
version of this file or of the dataset files stated them wrongly:

- the `--pool-workers 6` fate census (5 + 2 + 1 = 8), which the diagnostics manifest had given as
  "three died";
- the conversation-cache census: 27 launches sized a budget from free RAM, **7** logged
  `conversation cache off: not enough free RAM to park conversations`, 23 logged neither line, and the
  cause of those 23 is **U**;
- the CPU-feature gap: 52 launches logged "this CPU has no AVX-512", 36 of them also logged
  `MAP_HUGETLB unavailable`, so **16** logged the CPU line without the huge-page line. The two counts are
  not one start-up stage and the gap is **U**, not a difference explained by the five failed launches.

**Captured blocks are value-equal, not byte-equal.** Every command above aggregates with
`for (x in c)`, and mawk does not specify the iteration order of an array. The captured outputs are
therefore the counts this host produced on 2026-11-03, in the order mawk happened to emit them; the
`sort` / `sort -n` pipes are part of each command for that reason. A reader re-running them should compare
counts, not line order.

A first correction of my own belongs here: the `--kv` command above was published once in a form that
**fails under mawk** (`awk: line 1: missing } near END`) because the `if` block was left unclosed. The
version printed here is the one that was actually run. It is the same class of mistake recorded in
`docs/methodology.md` §2.1, and it is why every published command here is re-run before it is written down.

### Counting how many arguments actually changed around the MTP run

The evening dataset's manifest and README both said, until 2026-11-04, that the MTP session "differs from
every no-MTP session that ran the same 12 719-token cold prompt by two arguments". That was **wrong for
three of the five** no-MTP sessions. The claim is re-derivable, so the derivation is published here:

```python
import csv, collections, re
rows = list(csv.DictReader(open("results/strata/2026-11-02-config-sweep/engine-metrics.tsv"), delimiter="\t"))
V = {r["engine_started_local"]: r["payload"] for r in rows if r["kind"] == "engine_start"}

def flags(payload):
    t, m, i = payload.split(), {}, 1
    while i < len(t):
        if t[i].startswith("--"):
            if i + 1 < len(t) and not t[i + 1].startswith("--"):
                m[t[i]] = t[i + 1]; i += 2
            else:
                m[t[i]] = None; i += 1
        else:
            i += 1
    return m

V = {k: flags(v) for k, v in V.items()}
runs = {r["engine_started_local"] for r in rows if re.search(r"prompt 12719 tokens = 0 reused", r["payload"])}
mtp = "2026-11-02 20:31:11"
for t in sorted(runs - {mtp}):
    d = sorted(k for k in set(V[t]) | set(V[mtp]) if V[t].get(k) != V[mtp].get(k))
    print(len(d), t, d)
```

Captured output, 2026-11-04:

```
4 2026-11-02 18:49:35 ['--mtp', '--pcie-frac', '--spec', '--vram-reserve-mib']
5 2026-11-02 18:57:26 ['--adapt-async', '--mtp', '--pcie-frac', '--spec', '--vram-reserve-mib']
3 2026-11-02 19:04:16 ['--mtp', '--spec', '--vram-reserve-mib']
2 2026-11-02 19:13:24 ['--mtp', '--vram-reserve-mib']
2 2026-11-02 19:20:29 ['--mtp', '--vram-reserve-mib']
```

What the counts mean, precisely: a flag present in one launch vector and absent in the other counts as one
differing argument, and the count is over **arguments the engine was given**, not over engine behaviour. The
parser assumes each flag appears at most once and takes exactly one value token; that holds for every
payload in all three published datasets, which was checked separately (no duplicated flag names, no
`--set key=value` style payloads). The practical consequence is the one the dataset README now states: the
MTP run is least confounded against 19:13:24 and 19:20:29 and most confounded against 18:57:26, and no
comparison in this family isolates MTP.

### Deriving the same-prompt repetitions from published data

The repetition table in `docs/methodology.md` §3 comes from this snippet, run in
`results/strata/2026-11-02-mtp-attempts/`:

```python
import re, collections
groups = collections.defaultdict(list)
for line in open("engine-metrics.tsv"):
    f = line.rstrip("\n").split("\t")
    if len(f) < 4 or f[0] != "event": continue
    m = re.search(r"prompt (\d+) tokens = 0 reused \+ \d+ read in \d+ ms \(([\d.]+) tok/s\)", f[3])
    if not m: continue
    groups[(f[2], int(m.group(1)))].append(float(m.group(2)))
for (session, prompt), rates in sorted(groups.items()):
    if len(rates) > 1:
        spread = (max(rates) - min(rates)) / min(rates) * 100
        print(f"n={len(rates)} session={session} prompt={prompt} "
              f"rates={sorted(rates, reverse=True)} spread={spread:.2f}%")
```

Output captured on 2026-11-03:

```
n=3 session=2026-11-02 10:00:17 prompt=77   rates=[87.2, 54.0, 52.2]   spread=67.05%
n=2 session=2026-11-02 10:00:17 prompt=4089 rates=[382.5, 362.4]       spread=5.55%
n=3 session=2026-11-02 10:00:17 prompt=4093 rates=[377.3, 375.1, 360.2] spread=4.75%
n=3 session=2026-11-02 10:00:17 prompt=16387 rates=[390.7, 390.4, 388.7] spread=0.51%
```

The evening dataset produces no such group at 12 719 tokens, because 19:13 and 19:20 are two different
launches rather than two requests in one launch; the 0.02% pair is a same-vector, not a same-session,
repetition. Both kinds are reported, and they are not the same kind of control.

### Re-extracting from the private log (owner only)

Since 2026-11-04 the source of record is the **archived copy** of that log (snapshot
`2026-11-04T10:29:44Z`, engine log sha256 `c102ade0…a68b9`), not the live file; §6 explains why and gives the
commands against the archive. The window table below is unchanged by that move.

Each dataset's selection program is committed **next to the data it produced**, so the selection is
auditable rather than asserted:

| Dataset | Committed program | Line window |
| --- | --- | --- |
| `2026-11-02-config-sweep` | `results/strata/2026-11-02-config-sweep/extract.awk` | 12627–13420 |
| `2026-11-02-mtp-attempts` | `results/strata/2026-11-02-mtp-attempts/extract.awk` | 9470–12626 |
| `2026-10-30-11-02-engine-diagnostics` | `results/strata/2026-10-30-11-02-engine-diagnostics/extract.awk` | 1–13420 |

```sh
ENGINE_LOG=…            # your private engine log; never committed
INSTALL_ROOT=…          # your Strata install root; never committed
HOME_DIR=…              # only the diagnostics program needs this

printf 'kind\tlog_line\tengine_started_local\tpayload\n' > engine-metrics.tsv
awk -v lo=12627 -v hi=13420 -v R="$INSTALL_ROOT" \
    -f results/strata/2026-11-02-config-sweep/extract.awk "$ENGINE_LOG" >> engine-metrics.tsv
```

The two request programs use different whitelists — the morning one omits the KV-streaming,
decode-hit-rate and conversation-cache counters — stated in each program's header and in each manifest.
Personal paths are passed in as `-v R=` / `-v H=`, so no published program contains an absolute personal
path.

**awk flavour matters.** The default `awk` on this host is **mawk**, and mawk rejects an `if` / `else if`
condition continued across lines (`missing ) near end of line`). All three committed programs keep every
condition on one line for that reason; an earlier version of this page published a multi-line version that
failed under mawk on 2026-11-03. That failure is recorded in `docs/methodology.md` §2.1.

**Line numbers are anchors, not stable identifiers.** The log's size did not change monotonically during
the audit (15 426 → 16 105 → 15 693 → 17 233 → 18 689 → 19 664 → 20 648 lines; conflict C11 in
`docs/evidence-inventory.md`), so the log cannot be assumed append-only. Before trusting any line window,
re-verify it. **This check belongs to the owner, because it reads the private log** and because the
published extracts do not reach the window ends: the highest published `log_line` is 12 623 in the morning
request dataset and 13 419 in the evening one (13 366 in the diagnostics census), while the extraction
windows end at 12 626 and 13 420.

```sh
sed -n '12627p;13419p;13420p;9470p' "$ENGINE_LOG"
# observed on 2026-11-03, in the private log:
#   12627  an "engine started" line timestamped 2026-11-02 18:42:06
#   13419  a "decode expert cache hit rate" record  <- the last record published in the evening TSV
#   13420  a "route tail skip" record               <- inside the window, but not selected by the whitelist
#   9470   an "engine started" line timestamped 2026-11-02 09:33:06
```

This was done on 2026-11-03 at 15 693, 17 233, 18 689 and 19 664 log lines, and again on 2026-11-04 at
20 648 lines: all three published datasets re-extracted byte-for-byte identically to the committed TSV
files at every one of those sizes.

**The sanitiser substitutes with dynamic regular expressions.** Each program rewrites paths with
`gsub(R, …)` and `gsub(H, …)`, where `R` and `H` are the values handed in by `-v R=` and `-v H=`. Two
consequences follow. The published programs contain no absolute personal path, which is the point. But the
substitution is only as correct as the value supplied: pass a wrong `-v R=` and the program does not fail,
it falls through to the `-v H=` rule and emits payloads shaped `<HOME>/…` where the committed TSVs carry
`<STRATA_INSTALL_ROOT>/…` or the fully stripped form. That happened on 2026-11-04 and produced a false
"DIFFERS" for all three datasets while their record counts matched exactly (134 / 233 / 1941); the count
match is what identified it as a tooling fault rather than log drift. Compare record counts **and**
placeholder shape before concluding anything about the log.

---

## 2. Re-verifying the Go exercise

The Go project is **not imported** into this repository, and will not be imported: gap G2 was decided by the
owner on 2026-11-04 as **reference-only**, with a clean-room reimplementation scheduled instead (tasks T3.7 and
T3.8 in `docs/implementation-plan.md`). This section therefore describes how the owner re-verifies the local
copy today, and what a reader should expect from the future clean-room rebuild rather than from this source.

```sh
cd <the ratelimit package>
gofmt -l . && go vet ./... && go build ./...
go test -count=1 ./...
go test -race -count=3 ./...
go test -count=5 -shuffle=on ./...
go test -cover -coverprofile=/tmp/cover.out ./... && go tool cover -func=/tmp/cover.out | tail -1
staticcheck ./... && golangci-lint run ./...
grep -hc '^func Test' *_test.go | paste -sd+ | bc     # expected 60
```

Results recorded on 2026-11-03 on this machine (Go 1.27.3, `GOMAXPROCS=4`): all clean, 100.0%
statement coverage, no flakes. See `docs/evidence-inventory.md` §3 E4 for the count of repetitions
actually run, which is deliberately lower than the evaluated agent's own counts.

**Do not run the benchmark suite on a machine that is currently serving inference.** Benchmark output
is only comparable within the same run and the same load conditions.

---

## 3. What every run must record

Copy this as the skeleton of a `manifest.json`. Fields that were not captured must appear as
`not captured`; an absent field is a documentation defect, not an omission.

```json
{
  "dataset_id": "<engine>-<YYYYMMDD>-<HHMMSS>-<variant>",
  "captured_at_utc": "...",
  "timezone": "...",
  "hardware": { "cpu": "...", "cores_physical": 0, "threads": 0, "ram_bytes": 0,
                "gpu": "...", "vram_bytes": 0, "pci_link": "...", "storage": "..." },
  "host": { "os": "...", "kernel": "...", "gpu_driver": "...", "cuda_variant": "..." },
  "power_state": { "profile": "...", "load_avg_before": [], "load_avg_after": [] },
  "model": { "name": "...", "quantization": "...", "source": "...",
             "files": [{ "name": "...", "bytes": 0, "sha256": "..." }] },
  "engine": { "name": "...", "version": "...", "build_id": "...", "backend": "..." },
  "configuration": { "args": {}, "env": {}, "context_tokens": 0, "kv_quant": "..." },
  "fixture": { "description": "...", "sha256": "...", "prompt_tokens": 0 },
  "repetitions": 0,
  "requests": [{ "prompt_tokens": 0, "reused_tokens": 0, "output_tokens": 0,
                 "prefill_ms": 0, "prefill_tokens_per_s": 0,
                 "decode_ms": 0, "decode_tokens_per_s": 0, "ttft_ms": 0 }],
  "peak": { "ram_bytes": 0, "vram_bytes": 0, "sampled_every_s": 0 },
  "exit_status": 0,
  "commands": [],
  "limitations": []
}
```

## 4. Procedure for a clean timing run

1. **Nothing else may use the GPU.** No agent session served by the same engine, no other inference
   process, no benchmarking from inside the workload you are measuring. This project's own audit
   violated this and the consequence is documented in `docs/evidence-inventory.md` §5.1.
2. Record load average before and after, and record the power profile.
3. Start the engine once per condition and let it report its own sizing (expert cache slots, prompt
   chunk). Those numbers are part of the condition, not incidental.
4. Run a warm-up request and discard it.
5. Run the same published fixture, from a cold cache, at least three times per condition. Restart the
   engine between conditions, not between repetitions, unless engine restart is what you are measuring.
6. Sample RAM and VRAM on an interval during the run and record the interval.
7. Record the engine's own per-request line, not a wrapper's wall clock, and record which one you
   used.
8. Write the manifest while the run is fresh, including what went wrong.

For Go performance work: run benchmarks on an otherwise idle machine, pin `-cpu`, use `-count` ≥ 5
for anything you intend to compare, and never compare a number from one run against a number from
another run.

## 5. What is **not** reproducible today, and why

| Item | Status | Reason |
| --- | --- | --- |
| The 2026-11-02 Strata sweeps as controlled experiments | no | they were produced by interactive agent sessions, not by a benchmark harness, and variables changed together in ways that confound the MTP comparison in both directions |
| Peak RAM/VRAM for any historical run | no | never sampled |
| The long-context fixture | no | no generator published; only the produced file and its hash exist |
| The RED failures behind the six reported Go defects | no | the runs were not captured as artifacts |
| The mutation-testing evidence | no | performed by the evaluated agent, no retained artifact |
| MTP effect isolated from `--vram-reserve-mib` | no | no no-MTP session with the same reserve ran a comparable request |
| Anything about ExLlamaV3 or llama.cpp | no | never run |
| Why the engine log's line count decreased during the audit | no | observed and unexplained (conflict C11); the log was archived on 2026-11-04 (gap G10 closed), so the explanation now has to be sought in the archived snapshot rather than in the live file |

## 6. Archiving the private engine log (owner action, decided 2026-11-04)

The three published datasets were extracted from a **live private log** that the same engine was writing
while this audit ran. Its size is not monotonic (conflict C11), so every line-number anchor in the manifests
is a re-verifiable pointer rather than a stable identifier. The owner's decision on 2026-11-04 was to archive
that log **now**, privately and off-repo, instead of continuing to re-verify against a file that is still
being written.

**This is not a publication step.** Nothing archived is ever added to this repository, in any branch, in any
pull request, or in any issue attachment: the log interleaves request metrics with private prompt and
completion content from agent sessions. The archive exists so that the published datasets have a fixed
artifact to be re-derived from.

### Procedure, in order

1. Note whether the engine is live at copy time. If it is, the snapshot is mid-write and the record must say
   so; if it is not, the snapshot is a clean stop point and the record should say that instead.
2. Copy (never move) the log and the engine's own state files into a private archive directory outside this
   repository.
3. Hash every archived file and record the hashes, the line count, the byte count, the UTC time, and the
   engine build that was writing it in a private `ARCHIVE.md` beside them.
4. Re-extract all three published datasets **from the archived copy** with the committed `extract.awk` and
   the same window variables, and diff against the committed TSVs. If all three reproduce byte for byte, the
   archive becomes the anchor of record and the live log becomes disposable for audit purposes.
5. Keep the archive off public remotes, off public bucket access, and out of any support or issue thread. If
   it is ever handed to a collaborator, that handoff is a private act under the same restriction that
   produced it.

### Commands

Paths are passed at run time; nothing here writes inside the repository, and no personal absolute path is
written into any published file.

```sh
ARCHIVE=<private directory chosen by the owner>          # never inside this repository
ENGINE_LOG="$HOME/.local/state/strata/launch/iq3_xxs-256k.engine.log"

mkdir -p "$ARCHIVE"
cp -p "$ENGINE_LOG" "$ARCHIVE/"
sha256sum "$ARCHIVE"/*.engine.log > "$ARCHIVE/hashes.txt"
printf 'lines=%s bytes=%s\n' "$(wc -l < "$ARCHIVE/iq3_xxs-256k.engine.log")" "$(wc -c < "$ARCHIVE/iq3_xxs-256k.engine.log")" >> "$ARCHIVE/hashes.txt"
```

Then re-extract from the archived copy instead of from the live log, once per dataset, with the window each
dataset was published from:

```sh
REPO=<this repository's root>

# 2026-11-02-config-sweep: window 12627..13420, expect 134 records
awk -v lo=12627 -v hi=13420 -v R="$INSTALL_ROOT" -v H="$HOME" \
    -f "$REPO/results/strata/2026-11-02-config-sweep/extract.awk" \
    "$ARCHIVE/iq3_xxs-256k.engine.log" > /tmp/re-sweep.tsv
diff <(tail -n +2 "$REPO/results/strata/2026-11-02-config-sweep/engine-metrics.tsv") /tmp/re-sweep.tsv

# 2026-11-02-mtp-attempts: window 9470..12626, expect 233 records
awk -v lo=9470 -v hi=12626 -v R="$INSTALL_ROOT" -v H="$HOME" \
    -f "$REPO/results/strata/2026-11-02-mtp-attempts/extract.awk" \
    "$ARCHIVE/iq3_xxs-256k.engine.log" > /tmp/re-mtp.tsv
diff <(tail -n +2 "$REPO/results/strata/2026-11-02-mtp-attempts/engine-metrics.tsv") /tmp/re-mtp.tsv

# 2026-10-30-11-02-engine-diagnostics: window 1..13420, expect 1 941 records
awk -v lo=1 -v hi=13420 -v R="$INSTALL_ROOT" -v H="$HOME" \
    -f "$REPO/results/strata/2026-10-30-11-02-engine-diagnostics/extract.awk" \
    "$ARCHIVE/iq3_xxs-256k.engine.log" > /tmp/re-diag.tsv
diff <(tail -n +2 "$REPO/results/strata/2026-10-30-11-02-engine-diagnostics/engine-diagnostics.tsv") /tmp/re-diag.tsv
```

Each `diff` must print nothing. A diff that changes **only placeholder form** (`<STRATA_INSTALL_ROOT>`,
`<HOME>`) is a wrong `-v R=` or `-v H=` value, not evidence that the log changed; the two ways this happened
during the audit are recorded in `docs/methodology.md` §2.1. A zero-row output means the window variables
were omitted.

### What was true at the time this procedure was written

At 2026-11-04T00:48:21Z the live log stood at 20 648 lines, 2 644 061 bytes, sha256 prefix `147bb441…`, and
all three datasets re-extracted byte for byte from it. Later checks the same day saw 21 696 lines and the
same identical re-extraction.

### The snapshot that was taken

The procedure above was carried out on 2026-11-04. The snapshot's identity is recorded here because it is what
the published datasets are now re-derived from; the private directory it lives in, and the private `ARCHIVE.md`
beside it, are not published and never enter this repository.

| Item | Value |
| --- | --- |
| Snapshot id (UTC) | `2026-11-04T10:29:44Z` |
| Archived engine log, sha256 | `c102ade097769c9bc5e101039cbda4eab269ce23543cc2924684dd172e3a68b9` |
| Archived engine log, size | 22 132 lines, 2 839 708 bytes |
| Live status at copy time | **mid-write** — the engine was running and the log grew from 2 837 948 to 2 839 708 bytes during the copy window, so this is a snapshot of a live file, not a clean stop point (procedure step 1) |
| Engine build writing the log at snapshot time | `0.1.56-linux-x86_64-cuda-cuda13`. The archived log contains build-path mentions of `0.1.54` ×20, `0.1.55` ×37 and `0.1.56` ×1; the published measurements come from the 0.1.54 and 0.1.55 sessions |
| Also archived | the engine's server log (137 608 lines, 10 610 277 bytes), the launch profile and its choices file, a failed tuning record, historical profile backups, the component `active.json`, the tuning `recheck.json`, the 2026-11-02 agent session transcripts, and copies of the two temporary working directories behind sources S13 and S14 |
| Re-derivation from the archived copy | window 12627–13420 → 134 rows; window 9470–12626 → 233 rows; window 1–13420 → 1 941 rows; all three `diff` outputs empty and byte-for-byte identical to the committed TSV files |
| Integrity | sha256 recorded for every archived file, verified after the snapshot was made read-only; 25 of 25 checks pass |

**The archive is now the anchor of record and the live log is disposable for audit purposes.** All three
manifests cite this snapshot, and every line-number anchor in this repository should be re-verified against the
archived copy rather than against the live file.
