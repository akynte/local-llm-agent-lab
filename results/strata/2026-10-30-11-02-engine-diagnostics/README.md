# Strata engine diagnostics and session census (2026-10-30 → 2026-11-02)

Engine 0.1.54 and 0.1.55 · 57 engine launches · 1 941 records (57 launch records, 1 776 diagnostic records, 108 continuation lines)

This dataset is **not a performance measurement**. It is the engine's own start-up diagnostics and
configuration choices, published for one reason: this repository quotes lines like
`this CPU has no AVX-512`, `MAP_HUGETLB unavailable`, `PCIe probe: 11.5 GB/s`,
`CPU pool: 9 workers by default` and `mtp: the 512 experts do not fit in VRAM`, and a quote from a
private log is not evidence a reader can check.

It also fixes a gap the other two datasets left open: it is the only published record of the
**0.1.54-era** launches and of the sessions that never ran at all.

## The census

| Fact | Value |
| --- | --- |
| Engine launches in the window | 57 (20 on 0.1.54, 37 on 0.1.55) |
| Launches with `--vision` | 42 of 57 |
| Launches that requested `--mtp` | 25 |
| KV quantization per launch | `int8` 29, `k8v4` 17, `q4_0` 11 |
| `--spec` per launch | 4 → 51 launches, 6 → 6 launches |
| `--vram-reserve-mib` per launch | not set 37, 512 → 8, 768 → 7, 600 → 3, 1024 → 2 |
| `--kv-resident` per launch | 8192 → 1, 20480 → 20, 24576 → 8, 32768 → 12, not set → 16 |
| Resident expert cache chosen by the engine, across launches | 463 … 1257 slots |
| Automatic prompt chunk chosen by the engine, across launches | 256 … 2816 tokens |
| `pcie_frac` the engine chose from its own probe | 0.32 (24 launches), 0.31 (17), 0.30 (1) |
| Conversation-cache budget sized from free RAM | 1 280 … 3 840 MiB, in 27 launches. Seven further launches logged `conversation cache off: not enough free RAM to park conversations` and 23 logged neither line (27 + 7 + 23 = 57); the cause of the 23 is **U** |
| CPU pool | 34 launches logged "9 workers by default (10 physical cores, 16 logical processors…)". Eight launches passed `--pool-workers 6`; only two of those eight (11:31:51, 11:34:58) reached the point of logging "6 pool workers on logical processors …", **five** died on unknown arguments (11:13:40, 11:18:22, 11:21:07, 11:33:48, 11:34:19) and one (11:29:40) logged no worker line at all (2 + 5 + 1 = 8) |
| Launches that logged "this CPU has no AVX-512" | 52 of 57 |
| Launches that logged `MAP_HUGETLB unavailable` | 36 |
| `WARNING: only N MiB of VRAM free at the start of this request` | 13 occurrences, N ∈ {259, 341, 396, 438, 467, 496, 508} |
| The reserve value those warnings then advise | 576 MiB ×8, 704 ×2, 832 ×2, 960 ×1 — computed per launch, so the values differ by launch state |
| PCIe probe line | logged by 42 of 57 launches; best-of-four value 11.0–11.6 GB/s host→device (11.4 ×14, 11.5 ×20, 11.6 ×5, others ×1 each). The 15 launches that pass `--pcie-frac` on the command line log **no** probe line: joining the probe lines to the launch vectors gives 42 probe-no-flag + 15 flag-no-probe + 0 both + 0 neither, so probing happens only when the flag is absent |

The 52/57 figure cross-checks with the failure census below: the five launches that died on unknown
arguments never logged the CPU-feature line. The 36 does **not** cross-check the same way — 16 of the 52
launches that logged "this CPU has no AVX-512" logged no `MAP_HUGETLB unavailable` line at all (15 of them
with `--vision`, 1 without, across both engine generations), and no published record explains why. That gap
is **U**, recorded here rather than smoothed over.

## MTP across the whole window, not one experiment

25 launches requested `--mtp`. The engine logged an outcome for 19 of them:

- **10 refusals** — `mtp: the 512 experts do not fit in VRAM`, reporting **246 MiB free** eight times and
  **247 MiB free** twice. Both variants are real; quoting only one of them misstates the record.
- **1 different failure mode** not seen in the two request datasets:
  `mtp: dense weights allocation failed (out of memory), requested 110 MiB, CUDA0 free 57 MiB` (2026-11-02 11:29:40)
- **8 successful draft loads** — 834, 834, 834, 835, 835, 835, 835 and 822 MiB. The four 834/835 values
  belong to 0.1.54-era launches on 2026-10-30 and 2026-10-31; the 835 × 3 and 822 values belong to
  0.1.55 launches on 2026-11-02.

Six launches requested MTP with no logged MTP outcome. Five of them never ran at all (below); one
(2026-11-02 11:00:09) started and logged no MTP line in the selected window. Absence of a line is not
proof that the draft layer did not load.

## Five launches that never ran

```
unknown argument: --kv-streaming     (3 launches, 2026-11-02 11:13, 11:18, 11:21)
unknown argument: --draft-vocab      (2 launches, 2026-11-02 11:33:48, 11:34:19)
```

Five launches on 2026-11-02 passed those two arguments and 0.1.55 rejected them, printing its usage text
and exiting. **Where the two names came from is not recorded here.** The only published carriers of these
flags are the five launches that died on them — their own `engine_start` records contain `--kv-streaming`
(11:13:40, 11:18:22, 11:21:07) or `--draft-vocab` (11:33:48, 11:34:19) — and **no launch that started
successfully** carried either flag, including none of the 20 0.1.54-era launches. Neither name appears in
the control-layer profiles inspected on 2026-11-03. Their origin is **U**, not a fact about 0.1.54.

## What this dataset does not contain

- **No throughput records.** Prefill and decode rates live in
  [`../2026-11-02-config-sweep/`](../2026-11-02-config-sweep/) and
  [`../2026-11-02-mtp-attempts/`](../2026-11-02-mtp-attempts/).
- **No 0.1.54-era request records.** Those launches are covered here at configuration level only.
- **No per-request counters.** Route-tail-skip totals, suffix-draft totals and per-request KV-streaming
  hit rates are deliberately excluded; they are request-level data and belong to the request datasets.
- **No independent confirmation.** Every line here is the engine describing its own decisions. That is
  evidence about what the engine did, not evidence that the decision was correct.

## Extraction (published so the selection is auditable)

The program is committed here as **[`extract.awk`](extract.awk)**. It takes the install root and the home
directory as arguments, so the published program itself contains no absolute personal path:

```sh
ENGINE_LOG=<path to your private engine log>          # never committed
INSTALL_ROOT=<path to your local Strata install root>
HOME_DIR=<path to your home directory>

printf 'kind\tlog_line\tengine_started_local\tpayload\n' > engine-diagnostics.tsv
awk -v lo=1 -v hi=13420 -v R="$INSTALL_ROOT" -v H="$HOME_DIR" \
    -f extract.awk "$ENGINE_LOG" >> engine-diagnostics.tsv
```

Run against the private log on 2026-11-03, when the log stood at 17 233 lines, this produced 1 941
records (57 `engine_start` + 1 776 `event` + 108 `continuation`), 308 718 bytes, with zero occurrences of
a personal absolute path, and reproduced the committed TSV byte for byte. Since 2026-11-04 the source of
record is the archived copy of that log (snapshot `2026-11-04T10:29:44Z`, 22 132 lines, 2 839 708 bytes,
sha256 `c102ade0…a68b9`); the same command with `ENGINE_LOG` pointing at the archived copy reproduces the
committed TSV byte for byte. The archive is private and is not in this repository — see
`docs/reproducibility.md` §6 and `manifest.json` under `archive_snapshot`. The same command had already
reproduced this file byte for byte again at 18 689 and 19 664 lines (2026-11-03) and at 20 648 lines
(2026-11-04).

The whitelist selects engine start-up and engine-internal decision lines. It does not select request
lines, and it does not select per-request counters. Records that appear before the first captured
`engine started` line carry `no-engine-start-seen` in the timestamp column instead of a guessed time —
the log's head belongs to a launch whose start line is no longer in the file (conflict C11 in
`docs/evidence-inventory.md`).

**Licensing note (2026-11-05).** `extract.awk` is **MIT**; this README, `manifest.json` and
`engine-diagnostics.tsv` are **CC BY 4.0**, under the file-level rule in `LICENSE` (§"Scope of this file"),
which `sh scripts/validate.sh` check [8] enforces. On 2026-11-05 the research commentary that had
accumulated in the program's header comments was moved out of the program, so that the MIT-class file
carries only operational comments; the failure modes of the superseded `gsub(R, …)` form are enumerated in
`docs/reproducibility.md` §1, recorded as conflict **C17** in `docs/evidence-inventory.md`, and reproduced
by synthetic cases in `tests/extract/run_tests.sh`. No program behaviour changed and this dataset's bytes
are unchanged.

Two properties of **this dataset** that used to be stated inside the program belong here. This program
substitutes with the placeholder form, unlike the two request programs, which strip the install root into
relative paths:

- 263 of the 1 941 records contain `<STRATA_INSTALL_ROOT>` (516 occurrences in total).
- **No** record contains `<HOME>`. Window 1–13420 contains no home-directory path, so `-v H=`, although the
  program requires it and refuses to run without it, substitutes nothing for this window. A reader who
  re-extracts a different window should not infer from this file that home paths were ever present.
