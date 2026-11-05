# 2026-11-02 Strata configuration sweep (engine 0.1.55)

Eleven engine sessions on 2026-11-02 between 18:42 and 20:54 local time (UTC+04:00), on an
RTX 4060 Laptop 8 GB, running `Qwen3.8-Flash-Next-GSQ-RCO-IQ3_XXS` at `--max-context 262144`.

`engine-metrics.tsv` holds the verbatim metric lines the engine wrote for those sessions, with
local paths sanitized. It was produced by `extract.awk` in this directory, and re-running that program
over the archived copy of the private log reproduces this file byte for byte. The archive is private and
is not in this repository; its identity (`2026-11-04T10:29:44Z`, sha256 `c102ade0…a68b9`, 22 132 lines,
2 839 708 bytes) and the re-derivation result are recorded in `docs/reproducibility.md` §6 and in
`manifest.json` under `archive_snapshot`. Columns:

| Column | Meaning |
| --- | --- |
| `kind` | `engine_start` (full launch arguments) or `event` |
| `log_line` | line number in the private source log (see `manifest.json` for the log snapshot hash) |
| `engine_started_local` | timestamp of the `engine started` line that this record follows |
| `payload` | the log line, verbatim apart from path sanitization |

Event payloads include:

- `expert cache N slots, X GiB of VRAM` — resident-expert cache sizing
- `prompt chunk auto: N tokens, a M-slot ring` — prefill chunk sizing
- `prompt P tokens = R reused + F read in T ms (X tok/s), G generated in U ms (Y tok/s), drafts
  accepted a of b, C checkpoints` — the per-request prefill/decode record
- `strata mtp: draft layer loaded, N MiB of VRAM` — MTP draft-layer footprint
- `KV streaming`, `decode expert cache hit rate`, `conversation cache` — internal efficiency counters

## What this dataset is

A configuration sweep in which several launch arguments were changed between engine restarts:
`--vram-reserve-mib`, `--spec`, `--adapt-async`, `--pcie-frac` and `--mtp`. Each restart was
followed by a 53-token warm-up request and then by one or more larger requests.

## What this dataset is not

- It is **not** a controlled single-variable experiment. The MTP session's 12 719-token cold prefill has no
  same-vector counterpart, and how many other arguments changed alongside MTP depends on which no-MTP run
  it is compared with: **two** flags versus 19:13:24 and 19:20:29 (`--mtp mtp/rt` plus `--vram-reserve-mib`
  768 vs 512), **three** versus 19:04:16 (also `--spec` 6 vs 4), **four** versus 18:49:35 (also
  `--pcie-frac`), **five** versus 18:57:26 (also `--adapt-async` 1 vs 0). A same-vector pair does exist —
  20:03:24 and 20:06:30 versus 20:31:11, whose argument vectors differ only by `--mtp mtp/rt` — but both
  no-MTP launches in it ran only the 53-token warm-up, so it yields no comparable throughput record.
- It is **not** a repetition study. Most configuration points have a single request.
- It contains **no** peak RAM or peak VRAM measurements; only the engine's self-reported sizes.
- It contains **no** prompt text, completion text, tool call, or conversation content.
- Prompt identity across sessions is inferred from an exact token-count match (12719 tokens), not
  from a published fixture hash. Publishing a fixture hash is a Phase 3 task.

## Extraction program, and a licensing note

`extract.awk` in this directory is **MIT**; this README, `manifest.json` and `engine-metrics.tsv` are
**CC BY 4.0**. The file-level rule that decides which file falls under which license is in `LICENSE`
(§"Scope of this file"), and `sh scripts/validate.sh` check [8] enforces it rather than asserting it.

On 2026-11-05 the research commentary that had accumulated in the program's header comments was moved out
of the program and into this file, so that the MIT-class file carries only operational comments — usage,
required `-v` variables, exit statuses, the selection whitelist, and the sanitization rule. Nothing was
deleted, no program behaviour changed, and this dataset's bytes are unchanged.

Two statements that used to live in the program are statements about **this dataset**, not about the
program, which is why they live here:

- No payload in this window contains the `<STRATA_INSTALL_ROOT>` placeholder. Every install-root path the
  window matched was covered by one of the three specific stripping rules, so paths appear install-relative
  (`models/…`). That is a property of the lines in window 12627–13420, not of the program: the generic
  `R "/"` rule does emit the placeholder form, and the diagnostics dataset uses it.
- This window contains **no** MTP refusal or allocation-failure line, although its whitelist selects such
  lines. The refusal records are in `../2026-11-02-mtp-attempts/`.

Why the program substitutes literally instead of with a regular expression is a research finding: the
failure modes of the earlier `gsub(R, …)` form are enumerated in `docs/reproducibility.md` §1 and recorded
as conflict **C17** in `docs/evidence-inventory.md`, and the synthetic cases that reproduce each one are in
`tests/extract/run_tests.sh`.
