# 2026-11-02 Strata MTP attempt history (09:33 → 15:17 local)

Engine 0.1.55 · model Qwen3.8-Flash-Next-GSQ-RCO-IQ3_XXS · 24 engine sessions · 183 prompt records
(20 of them short warm-ups under 1 000 prompt tokens, 8 of those literally `prompt 53 tokens`; 178
completed, 5 cut-off)

This dataset is the **morning and afternoon of the same day** as
[`../2026-11-02-config-sweep/`](../2026-11-02-config-sweep/). It was extracted after the evening
dataset, and it exists because it contradicts the easiest reading of the evening MTP number.

`engine-metrics.tsv` was produced by `extract.awk` in this directory, whose whitelist is **narrower**
than the evening dataset's: it omits the `KV streaming:`, `decode expert cache hit rate:` and
`conversation cache:` request counters. Re-running that program over the archived copy of the private log
(snapshot `2026-11-04T10:29:44Z`, recorded in `docs/reproducibility.md` §6 and in `manifest.json` under
`archive_snapshot`) reproduces this file byte for byte.

## What is in it

24 engine sessions on engine 0.1.55, in two configuration families that are **not** the evening sweep's
configuration:

| Family | Sessions | Vision | KV quant | `--spec` |
| --- | --- | --- | --- | --- |
| A | 09:33 → 14:49 (20 sessions) | **on** | `int8` or `k8v4` | 4 |
| B | 15:01 → 15:17 (4 sessions) | off | `int8` | 4 |

The evening sweep used `--kv q4_0`, no `--vision`, and `--spec 6` in six of its eleven launches (`--spec 4`
in the other five). So morning numbers and evening numbers
differ on at least three variables simultaneously and must not be placed in the same table.

## The MTP history, which is not one experiment

**16 of the 24 launches in this window carried `--mtp`.** Ten MTP outcomes were logged:

- **six refusals** — `mtp: the 512 experts do not fit in VRAM`, at 09:33, 09:38, 09:40 and 09:48
  reporting **246 MiB** free and at 14:41 and 14:42 reporting **247 MiB** free. Both message variants are
  in the TSV; quoting only one misstates the record.
- **one different failure mode**: `mtp: dense weights allocation failed (out of memory), requested
  110 MiB, CUDA0 free 57 MiB` at 11:29:40 — the experts were judged to fit and the dense weights were
  not. This line is published in the
  [engine diagnostics census](../2026-10-30-11-02-engine-diagnostics/) **and in this TSV at log line
  10 761**.
- **three successful loads**, each 835 MiB: 10:00 (expert cache 616 slots, prompt chunk 768),
  11:31 (588 slots, 768), 11:34:58 (536 slots, 512)
- **six launches carried `--mtp` with no logged MTP outcome.** Five of them are the unknown-argument
  failures below; one (11:00:09) started and logged no MTP line. Absence of a line is not proof the draft
  layer was absent.
- one further load at 822 MiB at 20:31, which is in the evening dataset

The 11:34:58 session is the substantive one: **141 prompt records, 140 of them completed** (the 141st, at
208 846 prompt tokens, is a cut-off prefill that generated nothing), draft acceptance **124 947 of
164 954 proposed (75.7%)**, 51 decode records of ≥1 000 generated tokens in the range **22.6–28.6 tok/s**,
and completed cold prefills at eight different prompt lengths from 1 222 to **189 737 tokens**.

## The records that matter

**Repeated identical prompts, MTP on, 616 expert slots, chunk 768 (10:00 session):**

| Prompt tokens | Cold prefill tok/s |
| --- | --- |
| 4 089 (×2) | 362.4, 382.5 |
| 4 093 (×3) | 360.2, 375.1, 377.3 |
| 16 387 (×3) | 388.7, 390.4, 390.7 |
| 16 382 / 16 390 | 389.0 / 388.5 |

**No MTP, `int8` KV, 1 039 expert slots, chunk 1536 (15:17 session):**

| Prompt tokens | Cold prefill tok/s |
| --- | --- |
| 12 606 | 356.8 |
| 16 991 / 16 993 | 376.9 / 378.8 |

At a prompt length within 3.7% of the MTP session's, the no-MTP session measured **377–379 tok/s**
against the MTP session's **389–391 tok/s**. Those two sessions differ in expert cache size (616 vs
1039 slots), chunk size (768 vs 1536), `--kv-resident` (20480 vs 8192), vision state (on vs off) and
prompt-cache settings. The difference is therefore not an MTP effect, and the direction is the opposite
of what the evening dataset's single MTP run suggests.

**Long context with MTP on (11:34:58 session), eight cold prefills:**

| Prompt tokens | 1 222 | 14 237 | 41 814 | 48 333 | 52 297 | 89 744 | 99 021 | 189 737 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| tok/s | 231.9 | 252.2 | 273.2 | 279.6 | 267.6 | 260.2 | 267.6 | 254.3 |

189 737 tokens is the longest **completed cold** prefill in this dataset, and it is a single
unreplicated run. It is not the longest prompt in the window: this TSV also contains **five** cut-off
prefills that generated nothing — 111 085 tokens (15:06:31), 16 093 and 16 992 (both 15:17:33; the 16 093
record was cancelled after reading 1 280 of the 1 285 tokens it had not reused, the 16 992 record after
reading 9 216 of 16 992 with nothing reused), 190 804 (10:00:17) and 208 846 (11:34:58) — and warm requests
up to 197 272 tokens. Any "longest prompt" claim needs the words *completed* and *cold*. Note that 16 992
also appears as a **completed** cold prefill (474.5 tok/s) in the evening dataset at 18:42:06; the two
records are different requests and must not be merged.

## Five launches failed on argument names the engine no longer accepts

```
unknown argument: --kv-streaming     (11:13, 11:18, 11:21)
unknown argument: --draft-vocab      (11:33:48, 11:34:19)
```

The engine printed its usage text and exited. **These five lines are not in this TSV** — the whitelist
used for this dataset did not select `unknown argument:` records — they are published in
[`../2026-10-30-11-02-engine-diagnostics/`](../2026-10-30-11-02-engine-diagnostics/). They are recorded
here because they are evidence about the conditions of the day: the configuration was being edited by
hand against a moving engine interface, which is part of why neither window on 2026-11-02 is a controlled
experiment.

## Limits of this dataset

- Not a controlled experiment. It is the recorded history of interactive configuration attempts during
  a working day, and five of the launches failed outright.
- Cross-session comparisons are confounded on KV quantization, vision state, `--spec`, expert cache
  size, prompt chunk size and `--kv-resident`.
- Prompt identity across sessions is inferred from token counts, not from published fixture hashes.
- No peak RAM or VRAM sample exists.
- Draft-acceptance totals are sums of the engine's own per-request counters.
- `--vram-reserve-mib` was not set in some sessions, which is recorded as "not set" rather than as a
  value.
