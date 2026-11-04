# Research roadmap

Status legend: **done** (evidence exists and is published) · **partial** (evidence exists but is
incomplete or uncontrolled) · **planned** (no evidence yet) · **open question** (a decision or unknown).

---

## The research questions

**Q1. What does a 256K-context MoE model actually cost on an 8 GB laptop GPU?**
Status: **partial.** The 2026-11-02 evening sweep records the engine's own VRAM partitioning for its
**no-MTP** launches (resident expert cache 1107–1257 slots, 1.82–2.07 GiB; automatic prompt chunk
2048–2816 tokens) and cold prefill at 474.5–606.0 tok/s. The same dataset also contains one MTP launch at
**504** slots, 0.83 GiB, a 512-token chunk and 245.8 tok/s, so quoting the 1107–1257 range as "the sweep's"
value silently excludes that launch. No peak RAM/VRAM sample exists and the configurations were not held
constant. Next: Phase 2 T2.4 and T2.6.

**Q2. How does throughput scale with prompt length on this host?**
Status: **partial, and the shape is not monotonic.** The published datasets contain completed
cold-prefill points at 1 222, 4 089, 4 093, 12 606, 12 716, 12 719, 12 733, 14 237, 16 382, 16 387,
16 390, 16 991, 16 992, 16 993, 16 994, 41 814, 48 333, 52 297, 89 744, 99 021, 157 835 and 189 737
prompt tokens — but across different engine configurations, so they form a scatter, not a curve. Five
further prefills **never completed** and are excluded from any throughput statement: 111 085 (15:06:31),
16 093 and 16 992 (both 15:17:33, the first cancelled after reading 1 280 of the 1 285 tokens it had not
reused, the second cancelled after reading 9 216 of 16 992 with nothing reused), 190 804 (10:00:17) and
208 846 (11:34:58) — all `0 generated`. Two of those five sit in the 16–17K-token class, so writing that
class as a range such as "16 991–16 994" would hide them: 16 992 appears **twice** in the published data,
as a cancelled record in the morning dataset at 15:17:33 and as a completed 474.5 tok/s cold prefill in the
evening dataset at 18:42:06, and those are different requests. Two facts stand out: cold prefill did **not**
collapse between 13K and 158K tokens in the evening family (534 → 594 tok/s), while the morning family's
completed cold prefills span **231.9–390.7 tok/s** across 1.2K–190K tokens (the largest **completed** morning
record is 189 737 tokens; the 190 804-token request in that family is one of the five that never completed).
That morning range is not one number and splits by session:

| Morning session | MTP layer | Completed cold prefill range |
| --- | --- | --- |
| 10:00:17 | loaded, 835 MiB | 360.2–390.7 tok/s (n=10) |
| 11:34:58 | loaded, 835 MiB | 231.9–279.6 tok/s (n=8) |
| 15:12:20 | **not** loaded | 250.8 tok/s (n=1, 12 716 tokens) |
| 15:17:33 | not loaded | 356.8–378.8 tok/s (n=3) |

So the family gap is size-dependent and configuration-dependent, not a single ratio. At the ~12.7K-token
class the evening family ran 529.9–537.5 tok/s against 250.8 in the 15:12:20 morning session and 356.8 in
the 15:17:33 one. At the ~16–17K-token class the evening family ran 474.5 (18:42:06), 605.9 (18:49:35) and
606.0 (18:44:27) against 376.9–390.7 in the morning family. At that size the evening family contains **one**
genuine single-variable `--vram-reserve-mib` comparison — 18:42:06 (768 MiB, 474.5 tok/s) against 18:44:27
(512 MiB, 606.0 tok/s), argument vectors differing in exactly one flag — while 18:49:35 (605.9 tok/s at
512 MiB) differs from 18:42:06 by **two** flags (reserve and `--adapt-async`), so it corroborates that pair
rather than belonging to it. Cross-family numbers are what T2.6 exists to replace, not evidence about any
one variable. Next: T2.6 with a fixed fixture ladder (e.g. 4K / 16K / 64K / 128K / 192K / 256K) and ≥3
repetitions each, inside one configuration family.

**Q3. What is the real cost of MTP speculative decoding on a VRAM-starved card?**
Status: **partial, confounded in both directions.** See `docs/findings.md` §2 and conflicts C4 and C12.
The evening data points one way (245.8 vs 529.9–537.5 tok/s on the same prompt); a near-matched pair in
the morning data points the other (388.7–390.7 with MTP vs 376.9–378.8 without). Acceptance counters now
exist for two MTP sessions (66.3% and 75.7%), which makes the interesting quantity — decode throughput
normalised by acceptance rate — computable once a no-MTP counterpart of comparable size exists in the
same configuration family. Next: a single-variable A/B with `--kv`, `--vision`, `--spec` and
`--vram-reserve-mib` all held fixed.

**Q4. Which quantization gives the best quality-per-GB on this hardware?**
Status: **planned.** IQ3_XXS and IQ3_S packs both exist locally, and 8 of the 20 0.1.54-era launches
served the IQ3_S pack, but only IQ3_XXS appears in the published throughput datasets (gap G7). No quality
measurement has been made at all, so a quantization comparison today would be a throughput comparison
with the quality axis missing.

**Q5. How do inference engines compare on the same hardware and the same fixtures?**
Status: **planned.** No ExLlamaV3, llama.cpp, ik_llama.cpp or KTransformers measurement exists. Phase 4.
Prerequisite: published shared fixtures with hashes, and an engine adapter per engine that produces the
same normalized record.

**Q6. How reliable are local coding agents on real software tasks?**
Status: **partial.** One exercise (Go token-bucket rate limiter) with the agent's own tests as the only
correctness oracle. Independent re-verification covered the mechanical claims (test counts, coverage,
race detector, vet, lint) and found two factual errors in the agent's own report. Next: Phase 3,
whose central requirement is an oracle the evaluated agent did not write.

**Q7. Can a coding agent fix a defect it did not write, in a codebase it did not choose?**
Status: **planned.** This is the evaluation Q6 actually needs. The rate-limiter exercise measured
greenfield construction plus self-audit, which is a weaker test than defect repair. Next: a task whose
baseline is a pinned revision containing a seeded defect, with hidden tests.

**Q8. Does KV reuse change what a coding agent can practically do?**
Status: **open question, and arguably the most important one in this project.** The logs show reuse
rates above 99% for some requests and 0% for cold requests, and the engine maintains a parked-conversation
cache sized from free RAM. Interactive agent workloads are dominated by warm turns, yet the throughput
numbers this project has published are cold-prefill numbers by construction; the warm figures in
`docs/findings.md` §1.3 (39.6–555.7 tok/s) are amortised rates over mostly-reused prompts, not designed
warm-turn measurements. Next: measure warm-turn cost separately and report it as its own metric rather
than folding it into "prefill speed".

**Q9. Can other people reproduce these results on their own hardware?**
Status: **planned.** The contribution path exists in `CONTRIBUTING.md` and the manifest format exists
in `docs/reproducibility.md`, but no external contributor dataset exists yet, and the validator that
would catch an incomplete submission is Phase 2 work.

---

## Experimental timeline (as recorded, not as reconstructed)

| Date | What happened | Evidence class |
| --- | --- | --- |
| 2026-10-30 19:22 → 2026-11-01 01:03 local | Strata sessions on engine 0.1.54 (20 launches): 12 served the IQ3_XXS pack and **8 served the IQ3_S pack**, vision enabled in all 20 | H; launches published in the diagnostics census. The figure of 678 request records is a **private-log count**, not reconstructible from any published dataset (gap G7) |
| 2026-10-31T21:13:54Z (= 2026-11-01 01:13 local) | Engine changed 0.1.54 → 0.1.55 (`recheck.json`); the first 0.1.55 launch in the published census is 2026-11-01 01:18:43 local | V |
| 2026-11-01 | Vision/image configuration adjustments recorded as backup profiles in the install directory | H |
| 2026-11-02 09:33–14:49 | **Twenty** sessions with `--vision` on and `int8`/`k8v4` KV: six MTP refusals, one dense-weights allocation failure, three draft loads at 835 MiB, five launches that died on `unknown argument` | H, published |
| 2026-11-02 10:00, 11:31, 11:34:58 | MTP draft layer loaded at 835 MiB; expert cache 616 / 588 / 536 slots; prompt chunk 768 / 768 / 512 tokens | H, published |
| 2026-11-02 11:34:58 → 14:xx | The longest-running MTP session: 141 prompt records (140 completed, 1 cut-off), 75.7% draft acceptance, completed cold prefills from 1 222 to 189 737 tokens | H, published |
| 2026-11-02 15:01–15:17 | Four sessions with vision off and `int8` KV, no MTP; 16 991 / 16 993-token cold prefills at 376.9 / 378.8 tok/s, plus three cut-off prefills that generated nothing (111 085 tokens at 15:06:31, and 16 093 and 16 992 tokens at 15:17:33) | H, published |
| 2026-11-02 18:42 → 19:20 | Seven engine sessions, `--vram-reserve-mib` and `--spec` varied, five runs of the same 12 719-token cold prompt across four different argument vectors | H, published |
| 2026-11-02 20:03, 20:06 | Two sessions at `--vram-reserve-mib 768`, warm-up only | H, published |
| 2026-11-02 20:31 | The MTP session: draft 822 MiB, cache 504 slots, chunk 512, cold prefill 245.8 tok/s | H, published |
| 2026-11-02 20:54 | Rollback to 512 MiB reserve and no MTP; the 157 835-token retrieval probe | H + V, published |
| 2026-11-02T18:36:43Z → 2026-11-03T01:44:28Z | Pi coding-agent evaluation session (533 messages, 144 bash calls, 3 subagent dispatches) | V (metadata) |
| 2026-11-02T23:02:41+04 → 2026-11-03T05:42:08+04 | Ten commits in the Go rate-limiter project | V (git history) |
| 2026-11-03 | Phase 1 audit (called "Phase 0" in some earlier documents; see the naming note in `docs/implementation-plan.md`); independent re-verification of the Go exercise; reviewer audit of this documentation and the corrections it forced; three datasets extracted; repository prepared but not committed | V |

---

## Roadmap by phase

### Completed

- Evidence audit of the repository and host (`docs/evidence-inventory.md`)
- Sanitized publication of the 2026-11-02 Strata sweep
- Methodology, reproducibility procedure, hardware record
- Independent re-verification of the mechanical claims of the Go exercise
- Repository foundation documents

### Decisions recorded by the owner (2026-11-04)

- **License for this repository** (T1.7): MIT for software in `LICENSE`, CC BY 4.0 for the research record in
  `LICENSE.docs`. Previously "not assumed by this project"; now chosen, with the reason for the split stated
  in `README.md`.
- **The Go exercise is reference-only** (T3.8): it has no license, no remote, and lives in a temporary
  directory, so nothing is imported. T3.8 rebuilds it clean-room from the published task specification under
  this repository's licenses, with independent tests and retained artifacts.
- **The private engine log is archived**, privately and off-repo, from a frozen snapshot (gap G10, closed
  2026-11-04). The snapshot is `2026-11-04T10:29:44Z`: engine log 22 132 lines / 2 839 708 bytes, sha256
  `c102ade0…a68b9`, taken mid-write. All three published datasets were re-derived from it byte for byte. The
  procedure, the commands and the verification result are published in `docs/reproducibility.md` §6; the copy
  itself is private and its contents never enter this repository.

### Still awaiting an environment, not a decision

- **Re-running the Go benchmarks** (T3.6): requires a machine that is not currently serving this project's
  own agent session.

### Next (Phase 2)

1. **Work from the archive, not the live log** (gap G10, decided 2026-11-04): the engine log's size did not
   change monotonically during the audit (conflict C11), and the 0.1.54-era records are reachable only
   through it. The owner's private snapshot is the anchor; gap G7 work proceeds from that snapshot.
2. Extraction and normalization tooling with tests.
3. Schema and validator, including the throughput-reconciliation rule.
4. Comparison eligibility that refuses to compare cold and warm, or MTP and non-MTP, or `int8` and
   `q4_0`, configurations.
5. Resource sampling, so that the next measurement carries peak RAM and VRAM.
6. A controlled re-measurement of the sweep, and extraction of the 0.1.54-era sessions.

### Later (Phases 3–5)

- Independent coding-agent oracle and hidden tests; defect-repair tasks with pinned baselines.
- ExLlamaV3 and llama.cpp adapters and a shared published fixture set.
- Long-context evaluation with a published generator and multiple probe types.
- Contributor result submission path and a generated site that reads only from `results/`.

---

## Open questions this project should answer before it builds more tooling

1. **What is the fixture?** Every comparison needs a published prompt fixture with a hash. Nothing in
   the published results has one yet.
2. **What is being measured: engine speed or agent workload cost?** They differ. An agent workload is
   mostly warm turns; an engine benchmark is mostly cold prefill. Decide which one the headline metric
   reports, and report the other separately.
3. **What counts as a coding-agent success?** Test pass rates are the easy metric and the weak one.
   Defect repair against a pinned baseline with hidden tests is the hard metric.
4. **How much of this is about this specific laptop?** A single 8 GB card, one CPU without AVX-512, one
   engine version. Generality claims must wait for either more hardware or external contributions.

## Non-goals

- No leaderboard. Rankings without controlled conditions are marketing.
- No automated GPU benchmarking in CI.
- No claim of engine, model or agent superiority before the measurements exist.
- No reproduction of vendor benchmarks; third-party numbers are labelled **T** and never mixed with
  local measurements.
