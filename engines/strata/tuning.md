# Strata: tuning notes on an 8 GB card

Everything here is either a logged observation from the owner's machine or a quoted engine statement.
Tags refer to `docs/methodology.md` §1. Nothing in this file is a recommended configuration; it is a
record of what was changed and what happened when it was changed.

## 1. The automatic tuner does not work while the model is loaded

**V, from a private local record rather than a published dataset.** The recorded tuning attempt returned:

```
outcome: base_failed   reason_code: start_failed   mode: quick   seconds: 8.6   runs: 1
"Your current settings could not be measured: the graphics card could not be opened by the
 measuring engine; it is probably in use by the loaded model. Unload the model and tune again
 (ggml_cuda_init: failed to initialize CUDA: no CUDA-capable device is detected)"
```

The plan was 6 runs / ~15 minutes — the record's own top-level plan fields are `runs_planned 6`,
`eta_s 900`, `minutes_left 15`, `runs_done 0` — and it produced 0 measured pairs. The `tune skip` in the
working configuration is the **consequence** of this failure, not a tuning decision. Practical rule on a
single-GPU laptop: the tuner and the served model contend for the same device, so tuning must run with
the model unloaded — which means the agent or application using the model must be stopped first.

The `ggml_cuda_init: failed to initialize CUDA` line inside that message **is** published (42 occurrences
in `results/strata/2026-10-30-11-02-engine-diagnostics/`); the `outcome` / `reason_code` verdict itself is
not, because it lives in the control layer's tuning record. The record and the read command are inventory
entry **E8** (source **S9**) in `docs/evidence-inventory.md`.

## 2. VRAM headroom propagates into prefill batch size

**V** for each logged quantity, **X** for the causal chain.

| `--vram-reserve-mib` | expert cache | automatic prompt chunk | one cold prefill observed |
| --- | --- | --- | --- |
| 512 | 1257 slots / 2.07 GiB | 2816 tokens | 606.0 tok/s @ 16 994 tokens; 529.9–537.5 tok/s @ 12 719 tokens |
| 768 | 1107 slots / 1.82 GiB | 2048 tokens | 474.5 tok/s @ 16 992 tokens |
| 768 + `--mtp` | 504 slots / 0.83 GiB | 512 tokens | 245.8 tok/s @ 12 719 tokens |

The engine logs its own headroom arithmetic, e.g.

```
expert cache auto: 2.82 GiB free, 512 MiB reserved (+0 MiB for the draft head, +256 MiB for what is
allocated after the cache) -> 955 slots
expert cache 1257 slots, 2.07 GiB of VRAM
```

and, with the draft head resident,

```
expert cache auto: 2.02 GiB free, 768 MiB reserved (+186 MiB for the draft head, +256 MiB for what is
allocated after the cache) -> 384 slots
expert cache 504 slots, 0.83 GiB of VRAM
```

The auto estimate and the final allocation differ (955 vs 1257, 384 vs 504). That is engine-internal
behaviour; this project reports both numbers and does not explain the gap (**U**).

The prompt path also borrows cache slots (`the prompt path borrows 1107 CUDA0 cache slots (1.82 GiB)`
without MTP, `358 … (0.59 GiB)` with it), which is why prefill batch size is the first thing to move
when VRAM gets tight.

**Practical reading for an 8 GB card:** on this machine the lever that matters most is not a knob
value but the total VRAM budget left for the resident expert cache. Anything that consumes VRAM —
a draft layer, a larger reserve, a larger KV resident set — reduces the cache, which reduces the
automatic prefill chunk, which is where prefill throughput comes from.

**The reading is not complete, though.** The morning window of the same day contains a pair that runs
against it: 616 expert slots with a 768-token chunk measured 388.7–390.7 tok/s at ~16.4K prompt tokens,
while 1039 slots with a 1536-token chunk measured 376.9–378.8 tok/s at ~17.0K tokens. Those sessions
also differ in MTP state, `--kv-resident`, vision state and prompt-cache settings, so the pair is
confounded — but it is confounded in the direction that contradicts the simple monotonic story, and the
explanation is **U**, not settled.

## 3. Other knobs that were varied

| Knob | What was tried | Observation | Tag |
| --- | --- | --- | --- |
| `--spec` | 4 → 6 | verify window grew from 6 to 8 tokens of device buffers (`window up to 6 tokens, 70.8 MiB` vs `window up to 8 tokens, 82.5 MiB`). Two comparisons exist in the published data: the **one-variable** pair 19:04:16 vs 19:13:24, whose argument vectors differ in exactly one token, gave 531.9 → 537.5 tok/s (+1.05%) on the same 12 719-token cold prompt; and the group band 529.9–533.7 (`--spec 4`) vs 537.4–537.5 (`--spec 6`), which also varies `--pcie-frac` | H, single runs. Three of the six spec-6 launches (19:13, 19:20, 20:54:54 — all at `--vram-reserve-mib 512`) are byte-identical to each other, and the two that ran the same prompt agree to 0.02%; the third ran a 14-token-longer prompt 1 h 41 min later at 527.6. The other three spec-6 launches (20:03:24, 20:06:30, 20:31:11) run at `--vram-reserve-mib 768` and are a different vector. So even the +1.05% one-variable difference is a single observation and is not separable from launch-to-launch variation (**X**) |
| `--adapt-async` | 1 → 0 → 1 | 533.7 (async 1) vs 529.9 (async 0) on the same prompt, the only difference between those two launches being this flag; the engine logs "adaptive overlap: off" and describes the asynchronous tier as up to 96 swaps per round, a round every 4 windows | H, single runs (**X**) |
| `--pcie-frac` | engine-probed 0.32 → set 0.20 | the engine probes the link **only when the flag is absent**: the 42 launches with no `--pcie-frac` logged `PCIe probe: … GB/s host->device (best of four) -> pcie_frac … (default 0.55)`, the 15 that set the flag logged no probe line, and the two sets do not overlap (42 + 15 = 57). Probe values **11.0–11.6 GB/s** (11.5 ×20, 11.4 ×14, 11.6 ×5, 11.0/11.1/11.2 ×1 each) and the fractions chosen from them 0.32 ×24, 0.31 ×17, 0.30 ×1. One single-variable comparison of the override exists in the published evening data: 18:49:35 (flag absent, probe 11.5 GB/s → 0.32) against 19:04:16 (`--pcie-frac 0.20`), argument vectors differing in exactly one flag, the same 12 719-token cold prompt, **533.7 → 531.9 tok/s (−0.34%)** — one run per side | V for the probe lines and the census; **X** for the override comparison (single run per side, and a 0.34% difference is inside this host's own repetition noise, see `docs/methodology.md` §3); the probe value is a measurement spread, not a machine constant |
| `--vram-reserve-mib` | 512 → 768 → 512 | see table 2 | H |
| `--mtp` | off → `mtp/rt` → off | requested by 25 of the 57 logged launches: 10 refusals for lack of VRAM (246 MiB free ×8, 247 MiB ×2), 1 dense-weights allocation failure, 8 successful loads (834/834/834/835 MiB on 0.1.54-era launches; 835/835/835/822 MiB on 2026-11-02); see `docs/findings.md` §2 and both datasets. The evening family contains one same-vector MTP A/B — 20:03:24 and 20:06:30 versus 20:31:11, argument vectors differing only by `--mtp mtp/rt` — but both no-MTP launches ran only the 53-token warm-up (63.2 / 64.1 tok/s against the MTP session's 61.4), so it is a pair worth reusing in a controlled run rather than a result | H, confounded in both directions |
| `--tune` | attempted, failed | section 1 | V |

## 4. Determinism warnings that affect benchmarking

These are engine statements captured in the published diagnostics census, and they matter for any
comparison a reader plans.

- **Resident-expert arithmetic differs from CPU arithmetic.** "the GPU computes the experts in the
  cache; it rounds differently from the CPU, so a reply can differ slightly from a run without the
  cache". The cache policy is `PROFILE, ranked by routing frequency, no eviction`.
- **Small prompt chunks change the compute path.** "the CPU share is ON by default for prompt chunks
  below 1024 tokens (the idle CPU takes some of the experts the GPU would stream; answers can differ
  slightly from 0.1.40.3, mean KL ~0.004)". Since the automatic chunk size depends on the expert cache
  size, **changing VRAM reserve can change model output, not only speed.** A benchmark that changes
  `--vram-reserve-mib` is therefore not measuring the same model behaviour.
- **Route tail skipping is on by default.** `STRATA_ROUTE_TAIL_SKIP=7`, described by the engine as
  "+10..20% decode on 12-16 GB cards that miss experts". A decode number measured with it on is not
  comparable to one measured with it off.
- **The SSD is kept warm deliberately.** "the SSD is kept awake while rows are read: one page of the
  table after 100 ms without a read, until 60 s after the last request (`STRATA_SSD_KEEPALIVE=0` turns
  it off)". Idle gaps between benchmark requests therefore change the storage state under measurement.
- **Conversation parking is a caching layer.** `conversation cache sized from the free RAM: 3840 MiB
  for up to 4 parked conversations, so an agent's next turn reuses its prompt`. Two identical prompts
  submitted back to back are not the same measurement, because the second may hit the parked cache.

Any Phase 2 harness must record these as part of the condition, because they change both speed and,
in some cases, output.

## 5. What has not been tuned at all

- `--kv` alternatives: `int8` and `k8v4` ran on this machine (29 and 17 launches respectively in the
  published census). In the morning request dataset, **144 of its 183 prompt records come from `k8v4`
  launches** — the 11:34:58 session alone contributes 141 — so `k8v4` is the better-represented quantization
  in the published throughput data, not `int8`. No controlled `q4_0` vs `int8` vs `k8v4` comparison exists
  here; `fp16` never ran.
- `--mtp-q4`, `--mtp-hnorm`, `--lookup-chain`, `--suffix-draft`, `--draft dflash2` — present in the
  engine's help, never exercised.
- IQ3_S as a served model: 8 of the 20 0.1.54-era launches in the published census served
  `packs/iq3_s` with the IQ3_S shards, but their request records were never extracted, so no IQ3_S
  throughput or quality figure exists (**G7**). The published engine lines also mention an `IQ3_S`
  token-embedding table inside the IQ3_XXS pack (`native pack: … token embedding IQ3_S in mapped host
  memory (260 MiB)`), which is not the same thing as serving the IQ3_S quantization.
- Context sizes other than 262 144 — never measured.

Listing them here is the honest way of saying that the configuration in
`engines/strata/configuration.md` is one working point, not an optimum.
