# Strata: troubleshooting notes

Every item below is a problem that actually occurred on this host and is quoted from the engine log.
Quoted text is the engine's own wording, and **each quote below is present in a published dataset**
(`results/strata/2026-10-30-11-02-engine-diagnostics/` for engine start-up and failure lines,
`results/strata/2026-11-02-config-sweep/` and `results/strata/2026-11-02-mtp-attempts/` for request
lines). Line numbers refer to the private log snapshot those datasets were extracted from; they are
anchors, not stable identifiers (see conflict C11 in `docs/evidence-inventory.md`).

## 1. VRAM headroom exhaustion — the dominant failure mode on 8 GB

```
strata serve: WARNING: only 508 MiB of VRAM free at the start of this request (below 512 MiB): when
the card is this full the driver can page GPU memory to system RAM, decode falls to a few tok/s and a
window may never finish (#2065). Add --vram-reserve-mib 576 to the config's args, or lower
--max-context / --batch
```

and, in another session:

```
WARNING: only 396 MiB of VRAM free at the start of this request (below 512 MiB): … Add
--vram-reserve-mib 832 to the config's args, or lower --max-context / --batch
```

Across the published census this warning appears **13 times**, at 259, 341, 396, 438, 467, 496 (×3) and
508 MiB (×5) free. Note that the engine's own advice differs between occurrences — 576 MiB in one, 832
MiB in another — because the advice is computed from the state of that launch.

What this means in practice: on this card the engine's own advice is to **raise** the reserve, while
raising the reserve shrinks the resident expert cache and the automatic prompt chunk (see
`tuning.md` §2). The two symptoms are the same shortage approached from opposite sides. A reader who
sees "decode falls to a few tok/s" should treat it as a VRAM-budget problem, not as an engine
performance problem.

Evidence recorded in the sweep: 512 MiB reserve → 1257 expert slots; 768 MiB reserve → 1107 slots;
768 MiB reserve **plus** an 822 MiB MTP draft layer → 504 slots.

## 2. The engine refuses MTP when the draft experts do not fit

```
strata generate: mtp: the 512 experts do not fit in VRAM (247 MiB of 7807 MiB VRAM free on this GPU)
```

Recorded **ten times** in the published census. Both free-VRAM variants occur: the line reports **246 MiB
free eight times** and **247 MiB free twice**. Split by engine era: four refusals in 0.1.54-era sessions
(2026-10-30 19:22, 19:28, 23:48, 23:49 local, each reporting 246 MiB) and six in 0.1.55 sessions
(2026-11-02 09:33, 09:38, 09:40, 09:48 reporting 246 MiB; 14:41, 14:42 reporting 247 MiB).

There is a **second MTP failure mode** that the refusal line hides:

```
strata generate: mtp: dense weights allocation failed (out of memory), requested 110 MiB, CUDA0 free
57 MiB (57 MiB of 7807 MiB VRAM free on this GPU)
```

(2026-11-02 11:29:40. Its published argument vector in the diagnostics census is abridged here; its flags
are `--conversation-cache-mib 2048 --expert-cache auto --kv k8v4 --kv-resident 24576 --max-context 262144
--mtp <STRATA_INSTALL_ROOT>/Strata-data/mtp/rt --pcie-frac 0.15 --vram-reserve-mib 768 --pool-workers 6
--prefill auto --prompt-cache-every 16384 --prompt-cache-tail --spec 4 --spec-min-p 0.5 --vision --batch 4`,
plus the pack, native-model, PLE and expert-profile file arguments. It **is** an MTP launch: it asked for
the draft layer and the dense weights are what failed. No `--kv-streaming` flag appears in that launch.)
Here the experts
were judged to fit and the dense weights were not. Counting only "experts do not fit" undercounts MTP
failures.

On 0.1.55 the draft layer also **did** load successfully four times — 835 MiB at 10:00, 11:31 and
11:34:58 and 822 MiB at 20:31 — after which the resident expert cache fell to 616, 588, 536 and 504
slots respectively. Four earlier 0.1.54-era launches loaded it at 834/834/834/835 MiB. The failure mode
therefore alternated between *refusal* and *successful load with a much smaller expert cache*, and the
second is the more dangerous one because it looks like success.
See `results/strata/2026-11-02-mtp-attempts/` and
`results/strata/2026-10-30-11-02-engine-diagnostics/`.

## 3. The engine clamps an over-large reserve

```
strata generate: expert cache auto: the 700 MiB reserve leaves too few slots on this card (a working
cache needs 422): a 660 MiB reserve instead -> 422 slots
```

The engine will reduce a reserve that leaves an unusable cache. A reader who sets `--vram-reserve-mib`
high and sees no effect should look for this line rather than assuming the setting was applied.

## 4. The automatic tuner cannot get a CUDA context while the model is loaded

```
ggml_cuda_init: failed to initialize CUDA: no CUDA-capable device is detected
```

appears **42 times** in the published diagnostics census. Where those 42 lines sit matters: each one is
attributed to a distinct `engine_started_local` bucket, **41** of those buckets are launches whose argument
vector contains `--vision` (and in each case the vision model then reports "on the CPU, 8 threads, no
warm-up"), and **one** line belongs to the orphan block at the head of the log that has no engine-start line
at all (conflict C11 in `docs/evidence-inventory.md`). Exactly **one** vision launch — `2026-11-02 14:49:02`
— has no such line. (The two-launch list, `2026-11-01 01:18:43` and `2026-11-02 14:49:02`, belongs to the
`load_hparams:` Qwen-VL warning in §8, which is a different line.) **No published line can be attributed to
the automatic tuner.**
The tuner's
`base_failed` / `start_failed` verdict and its explanation (quoted in `tuning.md` §1) come from a private
local record, not from a published dataset; the record and the command that reads it are inventory entry
**E8** (source **S9**) in `docs/evidence-inventory.md`. The published evidence for the mechanism is the
engine's own 42 `ggml_cuda_init: failed to initialize CUDA: no CUDA-capable device is detected` lines and
the tuner's wording; **the causal claim** that a second process could not hold the device because a single
laptop GPU cannot be shared by two contexts is the engine's explanation, not an independently established
fact (**X**), and nothing published here rules out a driver or CUDA-variant cause.

## 5. Host RAM guard

```
strata generate: memory guard: limit 61.3 GiB (source: meminfo), current 7.6 GiB, reclaimable cache
credited 0.0 GiB; available 53.7 GiB (MemAvailable 53.7 GiB), floor 2560 MiB
```

The engine sizes itself against `MemAvailable` with a 2560 MiB floor. This matters for a machine that
is also running a desktop session and an agent: 61.3 GiB total does not mean 61.3 GiB available, and
the engine will not use what is not available. A recorded reading from 2026-11-03T16:07:06Z, while the
engine was serving this audit, put `MemAvailable` at **7.73 GiB** against 61.27 GiB total (output in
`docs/hardware.md`, "Recorded outputs"); an earlier draft of this file quoted 8.3 GiB, which was the same
kind of point-in-time reading without a recorded output. Either way the operational point stands: a reader
reproducing these runs must leave room for their own interactive workload.

## 6. KV spills to system RAM at long context

```
strata serve: KV streaming: 90.84% of 357408 block reads hit VRAM, 131.8 MiB read from RAM
strata serve: KV streaming: 99.69% of 123350832 block reads hit VRAM, 1536.0 MiB read from RAM
strata serve: KV streaming: 99.50% of 158782212 block reads hit VRAM, 3168.7 MiB read from RAM
```

All three are published records from the 20:54:54 launch in
`results/strata/2026-11-02-config-sweep/`, each logged just after a request completes.

**These are session running totals, not per-request counters.** Within that launch the block-read count
increases monotonically line by line (4 536 → 357 408 → 2 156 700 → 3 703 380 → 123 350 832 → 129 161 568
→ 129 703 800 → 137 862 180 → 138 687 924 → 158 782 212), so the 99.50% / 3 168.7 MiB pair is the
session's accumulated state, not the cost of one request. Attributing it to "the 157 835-token request"
misreads the file: that request is followed by 90.84% of 357 408 reads with 131.8 MiB from RAM.

The per-request cost is the difference between consecutive lines:

| Request (prompt tokens, reused, generated) | Reads added | MiB from RAM added |
| --- | --- | --- |
| 53 warm-up | 4 536 | 0.7 |
| 157 835 cold, 43 generated | 352 872 | 131.1 |
| 12 733 cold, 329 generated | 1 799 292 | **−8.2** |
| 13 686 warm (13 061 reused), 225 generated | 1 546 680 | 19.4 |
| 16 668 warm (13 910 reused), 19 034 generated | 119 647 452 | 1 393.0 |
| 37 732 warm, 771 generated | 5 810 736 | 268.1 |
| 38 668 warm, 67 generated | 542 232 | 40.5 |
| 38 789 warm, 1 084 generated | 8 158 380 | 366.9 |
| 39 902 warm, 86 generated | 825 744 | 62.4 |
| 40 021 warm, 3 012 generated | 20 094 288 | 894.8 |

The negative delta is a real feature of the published data and is **not explained**: the MiB column does
not behave like a strict running total even though the read count does (**U**). Anyone reusing these
numbers must say which reading they use.

The headline point survives either reading: the hit **percentage** rises while the **absolute** spill rises
with it, so the percentage alone is a misleading number — 99.50% of 158.8 million accumulated block reads
is **3 168.7 MiB** (3.09 GiB) read from system RAM.

Long context is therefore not automatically a host-memory bottleneck on this configuration, but the
ratio and the absolute spill are both measured quantities that change with context length and
`--kv-resident`, and they must be reported alongside throughput rather than assumed.

## 7. Missing CPU and OS features that the engine reports

```
this CPU has no AVX-512: the expert kernels run on AVX-2 (multi-token for the i-quant gate/up rows)
expert arena: cudaHostRegister PORTABLE ok; MAP_HUGETLB unavailable (needed 20464 2 MiB pages,
  vm.nr_hugepages=0); transparent huge pages requested (MADV_HUGEPAGE)
```

52 of the 57 launches in the published census logged the AVX-512 line (the five that died on unknown
arguments never reached it) and 36 logged the huge-page fallback, with page requirements ranging from
20 464 to 24 010 2 MiB pages depending on how much the launch had already allocated. Both are environment
facts, not errors. They do explain performance differences against a machine that has AVX-512 or
preallocated huge pages, so they belong in any hardware report a contributor submits.

## 8. Vision-model accuracy warning

```
load_hparams: Qwen-VL models require at minimum 1024 image tokens to function correctly on grounding
tasks
load_hparams: if you encounter problems with accuracy, try adding --image-min-tokens 1024
```

Recorded for 40 of the 42 launches that ran with `--vision` (41 published lines in total; one line sits
before the first captured `engine started` record, and two vision launches — 2026-11-01 01:18:43 and
2026-11-02 14:49:02 — logged no such warning). The current configuration runs with vision off, so this
does not apply to the published throughput numbers — but a reader who enables vision and sees grounding
problems should look here first.

## 9. Launches rejected on argument names the engine no longer accepts

```
strata generate: unknown argument: --kv-streaming     (2026-11-02 11:13, 11:18, 11:21 local)
strata generate: unknown argument: --draft-vocab      (2026-11-02 11:33:48, 11:34:19 local)
```

In each case the engine printed its full usage text and exited without serving. **Where those two names
came from is not recorded**: the only published carriers of these flags are the five launches that died on
them, no launch that started successfully carried either flag (none of the 20 0.1.54-era launches did), and
neither name appears in the control-layer profiles inspected on 2026-11-03,
so their origin is **U** and cannot be attributed to 0.1.54. What *is* recorded is that 0.1.55 rejected
them. Practical consequence for anyone following this project's configuration notes: **argument names are
part of the engine version record, not part of a stable interface.** A launch script edited from memory or
from some engine's help output will fail in this way, and the failure is quiet unless the usage dump is
noticed.

This is also evidence about the quality of the historical data: five of the 24 sessions in the morning
window of 2026-11-02 never ran at all, which is part of why that day's records are a working history
rather than an experiment.

## 10. What is **not** in this file

No fix here is verified by a controlled experiment. Each entry pairs an observed log line with the
engine's own stated advice. Where this project has advice of its own, it is labelled as interpretation
in `docs/findings.md` and tagged **X**.
