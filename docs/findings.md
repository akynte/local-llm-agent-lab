# Findings

Every number in this file is traceable to a dataset in `results/`, to a command recorded in
`docs/evidence-inventory.md`, or — where a fact could not be published — to an entry in
`docs/evidence-inventory.md` that names the private record and says so. Where a number is a derived
statistic rather than a recorded value, the derivation is shown.

Evidence tags (**V/H/A/I/X/P/U**) are defined in `docs/methodology.md` §1 and are attached to each
claim.

---

## 1. Strata on an 8 GB RTX 4060 Laptop: what a 256K context costs

**Class V/H.** Dataset: `results/strata/2026-11-02-config-sweep/` (engine 0.1.55, build
`99866a47a2b8+cuda13.0`, model `Qwen3.8-Flash-Next-GSQ-RCO-IQ3_XXS`, `--max-context 262144`,
`--kv q4_0`, `--kv-resident 20480`, `--prefill auto`). Eleven engine sessions, 30 request records.

The engine's own sizing decisions for each session, and the requests those sessions served:

| # | Session start (local, UTC+04) | `--vram-reserve-mib` | `--spec` | `--adapt-async` | `--pcie-frac` | `--mtp` | expert cache | prompt chunk | cold prompt (reused) | prefill tok/s | generated | decode tok/s |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 18:42:06 | 768 | 4 | default | default | off | 1107 slots / 1.82 GiB | 2048 | 16 992 (0) | 474.5 | 32 | 24.1 |
| 2 | 18:44:27 | 512 | 4 | default | default | off | 1257 slots / 2.07 GiB | 2816 | 16 994 (0) | **606.0** | 32 | 26.0 |
| 3 | 18:49:35 | 512 | 4 | 1 | default | off | 1257 / 2.07 GiB | 2816 | 16 993 (0) | 605.9 | 32 | 27.3 |
| 3 | 18:49:35 | " | " | " | " | off | " | " | 12 719 (0) | 533.7 | 5 843 | 28.1 |
| 4 | 18:57:26 | 512 | 4 | 0 | default | off | 1257 / 2.07 GiB | 2816 | 12 719 (0) | 529.9 | 5 773 | 26.5 |
| 5 | 19:04:16 | 512 | 4 | 1 | 0.20 | off | 1257 / 2.07 GiB | 2816 | 12 719 (0) | 531.9 | 12 250 | 28.2 |
| 6 | 19:13:24 | 512 | 6 | 1 | 0.20 | off | 1257 / 2.07 GiB | 2816 | 12 719 (0) | **537.5** | 8 562 | 28.5 |
| 7 | 19:20:29 | 512 | 6 | 1 | 0.20 | off | 1257 / 2.07 GiB | 2816 | 12 719 (0) | 537.4 | 7 631 | **29.2** |
| 8 | 20:03:24 | 768 | 6 | 1 | 0.20 | off | 1107 / 1.82 GiB | 2048 | *(warm-up only)* | — | — | — |
| 9 | 20:06:30 | 768 | 6 | 1 | 0.20 | off | 1107 / 1.82 GiB | 2048 | *(warm-up only)* | — | — | — |
| 10 | 20:31:11 | 768 | 6 | 1 | 0.20 | **`mtp/rt`** (draft layer 822 MiB) | **504 / 0.83 GiB** | **512** | 12 719 (0) | **245.8** | 10 951 | 26.0 |
| 11 | 20:54:54 | 512 | 6 | 1 | 0.20 | off | 1257 / 2.07 GiB | 2816 | 157 835 (0) | **594.2** | 43 | 28.4 |
| 11 | 20:54:54 | " | " | " | " | off | " | " | 12 733 (0) | 527.6 | 329 | 27.4 |

All sessions began with a 53-token warm-up request (60.8–65.0 tok/s prefill, 24.0–25.6 tok/s decode).
Warm-up requests are excluded from the throughput discussion: a 53-token prefill is dominated by
start-up cost and is not a throughput measurement.

### 1.1 The same cold prompt, five times, without MTP

Six sessions ran the identical cold prompt of 12 719 tokens with 0 reused. Five had MTP off:

- prefill: 529.9, 531.9, 533.7, 537.4, 537.5 tok/s → mean 534.1, band 7.6 tok/s (1.4%)
- decode: 26.5, 28.1, 28.2, 28.5, 29.2 tok/s → mean 28.1, range 26.5–29.2

**V** for each number. **Those five runs are not one configuration.** Their engine argument vectors
differ:

| Launch | Vector (all at `--kv q4_0 --kv-resident 20480 --expert-cache auto --prefill auto --vram-reserve-mib 512`) | Cold 12.7K prefill |
| --- | --- | --- |
| 18:49:35 | `--spec 4 --adapt-async 1` | 533.7 |
| 18:57:26 | `--spec 4 --adapt-async 0` | 529.9 |
| 19:04:16 | `--spec 4 --adapt-async 1 --pcie-frac 0.20` | 531.9 |
| 19:13:24 | `--spec 6 --adapt-async 1 --pcie-frac 0.20` | 537.5 |
| 19:20:29 | `--spec 6 --adapt-async 1 --pcie-frac 0.20` | 537.4 |

Three launches share a byte-identical vector (19:13, 19:20 and 20:54:54). Only 19:13 and 19:20 ran the
same prompt, minutes apart, and they differ by 0.1 tok/s (0.02%). The third launch with that vector ran a
12 733-token prompt — 14 tokens longer — 1 h 41 min later at **527.6 tok/s**, 1.83% below the pair.

**Three** clean single-variable pairs exist in this family, all on the same 12 719-token cold prompt:

| Pair | Only difference | Cold prefill |
| --- | --- | --- |
| 18:49:35 → 18:57:26 | `--adapt-async` 1 → 0 | 533.7 → 529.9 (−0.71%) |
| 18:49:35 → 19:04:16 | `--pcie-frac` absent → 0.20 | 533.7 → 531.9 (−0.34%) |
| 19:04:16 → 19:13:24 | `--spec` 4 → 6 | 531.9 → 537.5 (+1.05%) |

Each was verified by diffing the two published argument vectors, whose token sets differ in that one value
alone. Each is still a single run per side.

There is one more structural fact worth recording, because it is the closest thing in this family to a
designed MTP A/B: 20:03:24 and 20:06:30 have the same argument vector as each other (same tokens, written
in a different order), and the MTP launch 20:31:11 differs from them by exactly one token,
`--mtp mtp/rt`. That is a same-vector, MTP-on-versus-off pair. It is unusable as a throughput comparison
because **both 20:03:24 and 20:06:30 ran only the 53-token warm-up** (63.2 and 64.1 tok/s prefill, 25.4 and
25.5 tok/s decode) against the MTP session's warm-up at 61.4 and 25.2 tok/s. On the warm-up alone the MTP
launch is 2.9–4.2% slower, which is within the noise band of a 53-token request and is reported as a
single observation, not as an MTP effect (**X**). What makes it worth publishing is that the pair exists and
that T2.7 can reuse it: the same-vector pair with a real prompt is the experiment this log never ran.

**V.** These are verbatim engine records. The prompt identity is inferred from the exact token-count
match, not from a published fixture (**U** for content identity).

Practical reading — the noise floor of this host, stated honestly:

| Comparison | Difference |
| --- | --- |
| identical vector, identical prompt, minutes apart (19:13 vs 19:20) | 0.02% |
| identical vector, prompt 14 tokens longer, 1 h 41 min apart (20:54) | 1.83% |
| `--adapt-async 1` vs `0`, one-variable difference (18:49 vs 18:57) | 0.7% |
| `--spec 4` vs `--spec 6`, one-variable difference (19:04 vs 19:13: 531.9 → 537.5) | 1.05% |
| descriptive band across the five runs and four vectors | 529.9–537.5 (1.4%) |

The 1.4% band quoted above **mixes `--spec 4` and `--spec 6` runs and four different argument vectors, so
it is not a measurement-noise figure.** The only same-vector, same-prompt repetition this dataset contains
is the 19:13 / 19:20 pair at 0.02%. Any claimed effect smaller than about 2% on this host needs repetitions
inside one identical argument vector before it means anything (**X** until measured).

### 1.2 Long prompt, cold

**V.** `prompt 157835 tokens = 0 reused + 157835 read in 265625 ms (594.2 tok/s), 43 generated in
1515 ms (28.4 tok/s)`. A 157 835-token cold prefill completed in 265.6 s at 594.2 tok/s in the same
configuration family as rows 6–7. Cold prefill throughput did not collapse between 13K and 158K
prompt tokens in this single observation. That is one data point per prompt size, not a scaling
curve (**X** for the scaling claim).

189 737 tokens is the longest **completed cold prefill** in the published datasets, measured once at
254.3 tok/s in a morning MTP session with a 512-token prompt chunk
(`results/strata/2026-11-02-mtp-attempts/`). It is not comparable to the 157 835-token figure above —
different KV quantization, different MTP state, different prompt chunk — but the contrast is itself
informative: 157 835 tokens at 594.2 tok/s with a 2816-token chunk against 189 737 tokens at 254.3 tok/s
with a 512-token chunk. Two data points, two configurations, no scaling curve (**X** for any causal
reading).

**Longer prompts do appear in the log, and they are not prefills.** The same morning dataset contains
requests of 190 804 and 208 846 prompt tokens recorded as `0 reused + 46 914 of 190 804 read` and
`0 reused + 68 605 of 208 846 read`: the engine read part of the prompt and the request did not complete.
Warm requests in the same session reach 197 272 prompt tokens. Any statement about "the longest prompt
the log contains" without saying *completed* and *cold* is wrong.

### 1.3 Warm requests are not prefill measurements

All eight warm-prompt records in the evening dataset come from **one launch** (20:54:54), where requests
reused prompt content. They show "prefill" rates of **39.6–555.7 tok/s**, and the spread is not noise — it
is how much of the prompt was fresh:

| Prompt tokens | Reused | Fresh read | Reported "prefill" |
| --- | --- | --- | --- |
| 13 686 | 13 061 (95.4%) | 625 | 255.7 tok/s |
| 16 668 | 13 910 (83.5%) | 2 758 | 555.7 tok/s |
| 37 732 | 35 701 (94.6%) | 2 031 | 428.7 tok/s |
| 38 789 | 38 734 (99.9%) | 55 | 68.7 tok/s |

Those figures are the cost of the small fresh remainder amortised over the whole prompt, which is why a
99.9%-reused request can report 68.7 tok/s while an 83.5%-reused one reports 555.7. They are **not**
comparable to cold prefill figures and are excluded from all throughput comparisons in this repository.

### 1.4 VRAM headroom changes the expert cache and the prefill chunk

Rows 1 vs 2 and rows 8–9 vs 6–7: raising `--vram-reserve-mib` from 512 to 768 lowered the resident
expert cache from 1257 to 1107 slots and the automatic prompt chunk from 2816 to 2048 tokens, and the
one 17K cold prefill that ran under the 768 setting measured 474.5 tok/s against 606.0 tok/s under
512. These **are** single-variable comparisons as far as the engine is concerned: 18:42:06 and 18:44:27
differ in no argument except the reserve value, and the 19:13:24 / 19:20:29 / 20:54:54 group differs from
20:03:24 / 20:06:30 in the reserve value alone. What is not held constant is **time and machine state**:
the pairs are 2 min 21 s apart (18:42:06 → 18:44:27) and 46–50 min apart (19:13:24 / 19:20:29 →
20:03:24 / 20:06:30), and no resource sampler was running. **V** for each logged
quantity; **X** for the causal chain and for treating a single run per side as a measurement.

The morning dataset contains a pair that breaks the simple monotonic reading: a session with **616**
expert slots and a **768**-token chunk measured 388.7–390.7 tok/s at ~16.4K prompt tokens, while a
session with **1039** slots and a **1536**-token chunk measured 376.9–378.8 tok/s at ~17.0K tokens.
More cache and a bigger chunk produced *lower* throughput there, so cache size is not the only variable
that governs prefill speed on this host (**V** for the numbers, **U** for the explanation).

The engine also logs its own headroom arithmetic and its own warnings, e.g.
`expert cache auto: 2.82 GiB free, 512 MiB reserved (+0 MiB for the draft head, +256 MiB for what is
allocated after the cache) -> 955 slots` followed by `expert cache 1257 slots`, and a warning that
only 508 MiB of VRAM was free at the start of a request, with the engine itself stating that at that
fullness the driver can page GPU memory to system RAM and "decode falls to a few tok/s". The
discrepancy between the auto estimate (955) and the final allocation (1257) is engine-internal
behaviour and is reported as observed, not explained (**U**).

---

## 2. MTP speculative decoding: recorded numbers, confounded comparison

**Class H** for the numbers, **X** for any causal statement.

Recorded in session 10 (`--mtp mtp/rt`, `--vram-reserve-mib 768`, `--spec 6`, `--pcie-frac 0.20`,
`--adapt-async 1`):

- draft layer loaded: 822 MiB of VRAM (experts 675, dense 111), files read in 0.36 s at 2158 MiB/s
- draft head over 106 299 tokens (178.4 MiB)
- resident expert cache: **1107 → 504 slots** (0.83 GiB). 1107 is what the three no-MTP launches at the
  same `--vram-reserve-mib 768` logged; 1257 belongs to the 512 MiB launches and is the wrong baseline
  for this comparison
- automatic prompt chunk: 2048 → **512 tokens** at the same 768 MiB reserve
- verify window grew from 6 to 8 tokens (`window up to 8 tokens, 82.5 MiB of device buffers`) — but the
  census shows this tracks `--spec`, not MTP: all 30 `--spec 4` launches that logged a window show 6 tokens
  and all six `--spec 6` launches show 8 tokens, including the no-MTP ones at 19:13, 19:20, 20:03, 20:06 and
  20:54

The draft-head line, the verify-window line and the `+186 MiB for the draft head` sizing line are
published in the **diagnostics** dataset, not in the sweep dataset: `engine-diagnostics.tsv` log lines
**13262**, **13261** and **13246**, all attributed to `2026-11-02 20:31:11`. The sweep dataset contains
the load line and the cache/chunk lines for that session and nothing about the draft head or the window.
- the 12 719-token cold prompt: **245.8 tok/s** prefill, 10 951 tokens generated at **26.0 tok/s**,
  drafts accepted 8 137 of 14 022 (58.0%)
- decode expert cache hit rate **31.9%** (1 923 239 hits / 6 031 942 lookups) against **54.1–57.7%** in
  the five no-MTP sessions that ran the identical 12 719-token prompt (57.7, 57.6, 55.7, 54.3, 54.1)

**"No MTP" does not mean "no drafting".** Every request record in both published datasets carries a
draft-acceptance counter, including the no-MTP evening sessions: 759/808, 864/1021, 2209/2581, 1657/2043,
1756/1972. **What is observable is the counter, not its source**: no published line names where the drafts
come from, and the engine's own help text (quoted in `engines/strata/configuration.md`, a private help dump,
not published) is the only pointer to prompt-suffix lookup. So the mechanism is **X**; what is **V** is that
drafts were proposed and accepted in sessions with no MTP draft layer. The evening comparison is therefore
*MTP draft layer present vs absent*, not *speculative decoding on vs off*, and no published dataset contains
a run with drafting disabled altogether.

### 2.1 The same day, earlier: 25 launches asked for MTP, and the outcomes were mixed

The evening session above was not the first MTP attempt on this machine. Two published datasets cover
the rest of the story: 24 further engine sessions on the same day
([`results/strata/2026-11-02-mtp-attempts/`](../results/strata/2026-11-02-mtp-attempts/)) and the
launch-level census of all 57 sessions
([`results/strata/2026-10-30-11-02-engine-diagnostics/`](../results/strata/2026-10-30-11-02-engine-diagnostics/)).

**Across the whole 2026-10-30 → 2026-11-02 window (57 launches, 20 on 0.1.54 and 37 on 0.1.55):**

- **25 launches requested `--mtp`.** An outcome was logged for 19 of them:
  - **10 refusals** — `mtp: the 512 experts do not fit in VRAM`, reporting **246 MiB free** eight times
    and **247 MiB free** twice. Both variants are in the record; quoting only one misstates it.
  - **1 different failure mode**: `mtp: dense weights allocation failed (out of memory), requested
    110 MiB, CUDA0 free 57 MiB` (2026-11-02 11:29:40)
  - **8 successful draft loads** — 834, 834, 834, 835, 835, 835, 835 and 822 MiB. The first four belong
    to 0.1.54-era launches on 2026-10-30/31; the last four to 0.1.55 launches on 2026-11-02
    (10:00, 11:31, 11:34:58 at 835 MiB and 20:31 at 822 MiB).
  - **6 launches requested MTP with no logged MTP outcome.** Five of them never ran at all (below); one
    (11:00:09) started and logged no MTP line. Absence of a line is not proof the draft layer did not
    load.
- **Five launches failed before doing anything**: `unknown argument: --kv-streaming` (11:13, 11:18,
  11:21) and `unknown argument: --draft-vocab` (11:33:48, 11:34:19). 0.1.55 rejected both names. Where the
  names came from is **U**: the only published carriers of these flags are the five launches that died on
  them, no launch that started successfully carried either flag, and none of the 20 0.1.54-era launches
  did. Neither name appears in the control profiles inspected on 2026-11-03.

**In the morning window specifically (24 launches, 16 of them carrying `--mtp`):** six refusals (four
reporting 246 MiB free, two reporting 247), one dense-weights allocation failure, three successful loads
at 835 MiB — 616 expert slots and a 768-token chunk at 10:00, 588/768 at 11:31, 536/512 at 11:34:58.

The 11:34:58 session is the substantive one: **141 request records**, of which **140 completed** and one
(208 846 prompt tokens) is a partial prefill that generated nothing; draft acceptance **124 947 of
164 954 (75.7%)**; and 51 decode records of ≥1 000 generated tokens in the range **22.6–28.6 tok/s**.

The important part for the MTP question is a near-matched pair inside the morning window:

| Session | MTP | Expert cache | Prompt chunk | Cold prompt | Prefill tok/s |
| --- | --- | --- | --- | --- | --- |
| 10:00:17 | **on** | 616 slots | 768 | 16 387 ×3 | 388.7, 390.4, 390.7 |
| 15:12:20 | off | 952 slots | 1024 | 12 716 | 250.8 |
| 15:17:33 | off | 1039 slots | 1536 | 16 991, 16 993 | 376.9, 378.8 |

The 15:17:33 row lists only that session's **completed** cold prefills. The same session also produced two
cut-off records — 16 093 tokens (14 808 reused, cancelled part-way through the remaining 1 285) and 16 992
tokens (nothing reused, cancelled after reading 9 216) — and the 15:06:31 session produced an 111 085-token
cut-off. None of them is part of the pair, and 16 992 must not be read as a third data point: the same
number appears in the **evening** dataset as a completed 474.5 tok/s cold prefill at 18:42:06, which is a
different request in a different configuration family.

The 10:00:17 and 15:17:33 rows are the near-matched pair: same engine, same model, `--kv int8` in both,
`--spec 4` in both, prompt lengths within 3.7%. The MTP session was **faster**, not slower. It also had a
*smaller* expert cache and a *smaller* prompt chunk, so this pair is confounded too — but confounded in the
opposite direction from the evening pair, which is exactly why neither pair can be published as an MTP
result.

The 15:12:20 row is the inconvenient third point, and it matters more than the pair does for interpreting
the evening number: a **no-MTP** morning session (`--kv int8 --kv-resident 32768 --vram-reserve-mib 768
--spec 4`, 952 slots, 1024-token chunk) ran the same prompt size class, 12 716 tokens, at **250.8 tok/s** —
within 2% of the evening MTP session's 245.8 tok/s on 12 719 tokens, and about half the evening no-MTP
sessions' 529.9–537.5. The morning/evening family difference is therefore roughly as large as the MTP
comparison inside either family, which is the clearest available demonstration that this data cannot
separate the MTP variable (**V** for the record, **X** for the interpretation).

### Why this is not a proven regression (and not a proven improvement either)

1. **Configuration families, not configurations.** The morning sessions used `int8` or `k8v4` KV with
   `--vision` enabled in 20 of 24 sessions and `--spec 4` in all 24. The evening sweep used `q4_0` and no
   vision; five of its eleven launches used `--spec 4` and six used `--spec 6`, so the two windows do
   overlap on `--spec 4` but not on KV quantization or vision state.
2. **n = 1** for the evening MTP condition, and the nearest no-MTP sessions used `--vram-reserve-mib 512`
   against the MTP session's 768.
3. **The near-matched morning pair points the other way** (389–391 with MTP against 377–379 without),
   while differing on expert cache size, prompt chunk, `--kv-resident` (20480 vs 8192),
   `--vram-reserve-mib` (unset vs 768), vision state and prompt-cache settings.
4. **The generations differ** — 10 951 tokens versus 5 773–12 250 in the evening runs — so decode rates
   are not same-length measurements, and acceptance rate is not normalised out. The morning session's
   75.7% acceptance over 141 requests is the only acceptance-rate sample large enough to be interesting,
   and it has no no-MTP counterpart of comparable size in the same configuration family.
5. **The mechanism is a hypothesis.** The logged chain (draft head consumes VRAM → fewer resident expert
   slots → smaller automatic prompt chunk → slower batched prefill) is plausible and every link is a
   logged fact, but the morning data shows a session with 616 slots and a 768-token chunk outperforming
   a session with 1039 slots and a 1536-token chunk, so cache size alone does not explain prefill speed
   on this host.

**What may be stated publicly:** MTP was requested by 25 of the 57 logged launches. Ten requests were
refused for lack of VRAM, one failed on a dense-weights allocation, and eight loaded a draft layer of
822–835 MiB. After a successful load the resident expert cache and the automatic chunk were — 0.1.54-era
launches (2026-10-30/31): **463, 463 and 553** slots with chunks **768, 768 and 256**; 0.1.55 launches
(2026-11-02): **616, 588, 536 and 504** slots with chunks **768, 768, 512 and 512**. "504–616 slots and
512–768 tokens" describes only the 0.1.55 subset. Note the asymmetry: four 0.1.54-era loads are published
(834, 834, 834, 835 MiB) but only **three** of them have a published expert-cache and chunk pair — the
launch at `2026-10-30 23:56:00` logged a draft load and no cache or chunk line inside the published window,
so its post-load sizing is **not captured**, not zero and not inferable from the other three. In the one long MTP session (140 completed requests) the
engine reported 75.7% draft acceptance and decode of 22.6–28.6 tok/s. In the evening session, the same
12 719-token cold prompt processed at 245.8 tok/s against 529.9–537.5 tok/s in five no-MTP sessions — whose
argument vectors differ from the MTP launch by **between two and five** flags (two for 19:13:24 and
19:20:29, three for 19:04:16, four for 18:49:35, five for 18:57:26; derivation published in
`docs/reproducibility.md` §1) — and in
the morning the same prompt size class measured 389–391 tok/s with MTP against 377–379 tok/s without it.
**What may not be stated:** any isolated effect of MTP on this host, in either direction.

Required follow-up (Phase 2 → 4): a single-variable A/B inside one configuration family, ≥3 repetitions
per condition, fixed published prompt fixtures, sampled VRAM, and decode throughput normalised by the
engine's own acceptance counters.

---

## 3. Long-context retrieval probe

**Class V** for the fixture and the answer check, **H** for the timings.

Fixture (`/tmp/pi-kv-test/`, hashes in `docs/evidence-inventory.md` §2): a 721 821-byte ASCII
document of 6 500 synthetic filler records ("backend worker completed a routine service health
check…") with three embedded keys:

| Key | Value | Line in fixture |
| --- | --- | --- |
| A | `0B0F720F84CF` | 653 |
| B | `D299897A7FC3` | 3254 |
| C | `1B04ADA9D003` | 5855 |

Returned output equals the expected JSON exactly, all three keys, no extra content. **Re-verified on
2026-11-03**: `sha256sum` of `prompt.txt` (721 821 B, 6 506 lines), `expected.json` (63 B) and `output.txt`
(59 B) matched the hashes published in `docs/evidence-inventory.md` §2, and the three keys sit at fixture
lines 653, 3 254 and 5 855. The fixture can therefore be re-used, but it still cannot be regenerated: no
generator exists (**G3**). The request is recorded in section 1.2: 157 835 prompt tokens, 0 reused, 594.2
tok/s, 43 generated tokens at 28.4 tok/s.

**Interpretation limits.** This is one request, one document type, three keys, one position sample,
one model quantization, one engine version, n = 1, with no repeated trials and no distractor variants.
It shows that a 157 835-token prompt was accepted and that three embedded values were returned
correctly in that request. It says nothing about long-context reasoning, about position sensitivity,
about failure rates, or about behaviour at the 262 144-token context limit. **X** for any broader
claim. The fixture has no published generator yet (gap G3), so the fixture itself is not yet
reproducible by a reader.

---

## 4. Coding-agent evaluation: Go token-bucket rate limiter

**Class A** for the agent's own report, **I** for what this project re-ran. Full detail in
`docs/evidence-inventory.md` §3 E4.

Independently confirmed on this machine (2026-11-03, Go 1.27.3, `GOMAXPROCS=4` because the machine
was under concurrent load):

| Check | Command | Result |
| --- | --- | --- |
| Formatting | `gofmt -l .` | no output, exit 0 |
| Vet | `go vet ./...` | clean, exit 0 |
| Build/tests | `go test -count=1 ./...` | ok, 1.836 s |
| Race detector | `go test -race -count=3 ./...` | ok, 9.224 s, no race reports |
| Shuffle | `go test -count=5 -shuffle=on ./...` | ok, 8.912 s |
| Coverage | `go test -cover` + `go tool cover -func` | **100.0%** statements |
| Static analysis | `staticcheck ./...` | 0 issues |
| Lint | `golangci-lint run ./...` | 0 issues |
| Inventory | `grep -hcE '^func Test' *_test.go \| paste -sd+ \| bc` (and the same for `^func Example` and `^func Benchmark`) | 60 tests, 4 examples, 15 benchmarks — re-run on 2026-11-03 with go1.27.3 |

Not re-run, therefore **A**: `govulncheck`, the benchmark timings, the mutation-testing evidence, the
original RED failures behind the six reported defects, and the clock-ordering proof. The benchmark
suite was deliberately not re-run because this audit session is itself served by the same GPU under
study (see `docs/evidence-inventory.md` §5.1); re-running it now would produce numbers that are
perturbed by the audit.

**Methodological warning that must stay in the record:** the 100% coverage figure is statement
coverage of the agent's own implementation measured by the agent's own tests. It is not evidence that
the implementation is correct, and it is not evidence that the agent is generally reliable. The task
was one exercise, in one language, in one problem domain, with the agent's own tests as the only
correctness oracle. Phase 3 exists precisely to replace that oracle.

Two concrete errors were found in the agent-authored record, which is the strongest available
argument for the rule above:

1. the README describes the CPU as "12 cores / 16 logical"; `lscpu` and the engine's own startup log
   both say 10 physical cores and 16 logical processors;
2. the README's headline "Allow ≈ 37 ns/op" is the *denied-path* benchmark (`BenchmarkAllowDenied`,
   37.98 ns/op), while the hot path in the same run was 58.58 ns/op; the README itself elsewhere
   states the 37–67 ns/op range.

---

## 5. Operational findings about this host and engine

**Class V**, all captured during the audit or from the engine's own records.

1. **The engine's automatic tuner cannot run while the model is loaded.** The recorded attempt returned
   `outcome: base_failed`, `reason_code: start_failed`, with the message that the graphics card could not
   be opened by the measuring engine because it is in use by the loaded model. The working configuration's
   `tune skip` is the consequence of that failure, not a tuning choice. **This one is quoted from a
   private local record, not from a published dataset**; the record and the command that reads it are
   inventory entry **E8** (source **S9**) in `docs/evidence-inventory.md`.
2. **No AVX-512.** The CPU has no AVX-512 (`/proc/cpuinfo`), and 52 of the 57 logged launches carry the
   engine's own line that expert kernels run on AVX-2 with multi-token handling for the i-quant gate/up
   rows ([diagnostics dataset](../results/strata/2026-10-30-11-02-engine-diagnostics/)).
3. **No preallocated huge pages.** `vm.nr_hugepages = 0`; 36 launches logged `MAP_HUGETLB unavailable`
   (needing 20 464–24 010 2 MiB pages) and a fallback to transparent huge pages.
4. **PCIe Gen4 ×8 in use.** 42 of the 57 launches logged the engine's own probe, and those 42 are exactly
   the launches that did **not** pass `--pcie-frac`: the 15 launches that set the flag logged no probe line,
   and no launch appears in both sets (42 + 15 = 57), so the engine probes the link only when the flag is
   absent. Its best-of-four value
   ranges **11.0–11.6 GB/s** host→device across launches (11.4 ×14, 11.5 ×20, 11.6 ×5, 11.0/11.1/11.2 ×1
   each), so 11.5 is the modal reading and not a property of the machine. The engine turned the probe into
   `pcie_frac` 0.32 in 24 launches, 0.31 in 17 and 0.30 in 1; the working configuration sets 0.20 instead
   of the probed value. That override has one published single-variable observation — 18:49:35 (no
   `--pcie-frac`) against 19:04:16 (`--pcie-frac 0.20`), same 12 719-token cold prompt, 533.7 → 531.9 tok/s
   (−0.34%) — which is a single run per side and does not establish the override's effect (**X**, and the
   general effect remains **U**).
5. **The GPU is shared with the desktop.** The census shows the engine reserving no value at all in 37 of
   57 launches, and 512 ×8, 768 ×7, 600 ×3 or 1024 ×2 MiB of the 8 188 MiB in the other 20. Thirteen
   request-start warnings name the free VRAM as 259, 341, 396, 438, 467, 496 or 508 MiB — five of them at
   508 MiB — each warning that at that fullness the driver can page GPU memory to system RAM. Those same
   warnings advise a reserve of 576 MiB eight times, 704 twice, 832 twice and 960 once; the advice is
   computed per launch, so differing advice is not a contradiction.
6. **Model download integrity** is verifiable: local sha256 markers equal the upstream Hugging Face
   LFS oids for both 47 GB and 28.8 GB shards.

---

## 6. What this repository explicitly does **not** conclude

- No engine ranking exists. No ExLlamaV3 or llama.cpp measurement has been taken (**P**).
- No claim that MTP is slower, faster or unsuitable. §2 contains a confounded evening observation that
  points one way and a near-matched morning pair that points the other.
- No claim that the model is good at long context. One retrieval probe succeeded at 157 835 tokens.
- No claim that Pi is a reliable coding agent. One exercise produced a Go package that passes a
  large self-authored suite; independent verification of that suite's claims is partial.
- No claim that 100% coverage means defect-free.
- No claim that the 606 tok/s figure generalises: it is one configuration on one 8 GB laptop GPU at
  one engine version, measured by an engine that also served the interactive workload being measured.
- No published per-request resource sampling. CPU load, GPU utilization and VRAM occupancy were never
  recorded alongside a request (**G11**), so no throughput figure here can be attributed to a resource
  state.
