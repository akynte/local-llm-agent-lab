# Local LLM Agent Lab

Reproducible measurements of large-model inference and coding-agent work on consumer hardware — an 8 GB
laptop GPU, 64 GB of RAM, and the inference engine and coding agent that were actually running on it.

A research record rather than a benchmark leaderboard: raw sanitized records, provenance manifests, every
table re-derivable from published data by a command a reader can run, and an explicit label on every claim
for the kind of evidence behind it. Not a product, and not affiliated with, endorsed by, or sponsored by
the authors of any engine, model or agent discussed here.

---

## Verify this repository in one command

```sh
sh scripts/validate.sh
```

CPU-only. No engine, no model weights, no GPU, no private log, no network. It runs the extraction
regression tests, checks the structure and record counts of all three published datasets, checks each
manifest's declared sha256 and extraction window against the file beside it, **recomputes 34 published
figures straight from the published TSVs**, scans tracked text for personal paths and credential-shaped
strings, and confirms the three `extract.awk` programs fail loudly on a bad invocation. GitHub Actions runs
the same thing on every push (`.github/workflows/validate.yml`).

34 of 34 published figures currently reproduce from the committed data. That number is the point of this
repository: a reader should not have to trust a table.

---

## Status

| | |
| --- | --- |
| Phase 1 — evidence audit and repository foundation | written, through five correction rounds plus a 2026-11-05 audit pass |
| Phase 2 — benchmark harness, schemas, engine-internal artifact publication | **not started.** A narrow CPU-only validation tooling (`scripts/`, `tests/extract/`) was added on 2026-11-05; it is not the Phase 2 harness |
| Phase 3 — coding-agent evaluation with independent tests | not started |
| Phase 4 — engine comparison | **nothing here compares engines.** ExLlamaV3, llama.cpp, ik_llama.cpp and KTransformers have never been run |
| Datasets | three, all from one machine; two from a single day |
| First commit | `c3c51ce`, pushed to `main` on 2026-11-04 |

Owner decisions recorded 2026-11-04 and implemented: dual licensing (MIT for software, CC BY 4.0 for the
research record), the Go exercise kept **reference-only** (clean-room rebuild scheduled as Phase 3 work,
tasks T3.7/T3.8), and the private engine log archived off-repo from a snapshot whose identity and
verification result are recorded in [`docs/reproducibility.md`](docs/reproducibility.md) §6. That snapshot
was taken **mid-write** — the engine was live and the log grew by 1 760 bytes during the copy — so it is a
fixed copy of a live file, not a clean engine stop point.

---

## The problem this project addresses

Local inference numbers are usually published as single figures on ideal hardware. Coding agents are usually
evaluated by their own test suites. Neither is reproducible by someone with a laptop.

This project does the opposite: keep the records, publish enough of them that a reader can rebuild every
table, state what was **not** measured, and label every claim with the kind of evidence behind it.

The rules live in [`docs/methodology.md`](docs/methodology.md). Evidence classes: **V** verified by a command
whose output is captured, **I** independently re-run by this project, **A** as reported by an agent,
**H** from a private local record, **X** a hypothesis about causation, **U** unverified.

The rule that matters most: **an evaluated agent's own tests are not evidence about that agent's
correctness.** In this project's own case study, the category "claims supported by independently designed
correctness tests" is **empty** — see [`agents/pi/README.md`](agents/pi/README.md), "Who verified what".

---

## What has actually been tested

| Experiment | Status | Where |
| --- | --- | --- |
| Strata 0.1.55 evening sweep, IQ3_XXS, 262 144-token context advertised: 11 engine sessions, 30 requests | measured, published | `results/strata/2026-11-02-config-sweep/` |
| Same day 09:33–15:17: 24 engine sessions, 183 prompt records, 16 launches carrying `--mtp` | measured, published | `results/strata/2026-11-02-mtp-attempts/` |
| Launch census 2026-10-30 → 2026-11-02: 57 launches (20 on 0.1.54, 37 on 0.1.55) with argument vectors and start-up diagnostics | recorded, published | `results/strata/2026-10-30-11-02-engine-diagnostics/` |
| MTP speculative decoding on/off | requested by 25 of 57 launches, **confounded in both directions** | `docs/findings.md` §2 |
| Long-context probe, 157 835 prompt tokens | measured once, n = 1, fixture hash published | `docs/findings.md` §3 |
| Coding-agent exercise: Go token-bucket rate limiter | performed; mechanical claims re-run here; **no independent test suite exists** | `docs/evidence-inventory.md` §3 E4 |
| ExLlamaV3, llama.cpp, ik_llama.cpp, KTransformers | **not run** | `docs/research-roadmap.md` Q5 |
| Coding-agent defect repair against a pinned baseline with hidden tests | **not built** | Phase 3 |

---

## Headline measurements

### Evening sweep — engine 0.1.55, model `Qwen3.8-Flash-Next-GSQ-RCO-IQ3_XXS`, context 262 144, KV `q4_0`, no vision

Every row below is a **cold** request (0 prompt tokens reused). The same dataset also holds 8 warm
reused-prompt records, all from one launch; they are published in full in `docs/findings.md` §1.3 and are
excluded from every throughput comparison here.

| Measurement | Value | Evidence |
| --- | --- | --- |
| Cold prefill, 12 719-token prompt, five runs, no MTP | 529.9–537.5 tok/s, mean 534.1, spread 7.6 tok/s (1.4%) — across **four different argument vectors**; only the `--spec 6` pair (537.4, 537.5) shares one vector **and** one prompt, agreeing to 0.02% | log records |
| Decode, the same five runs | 26.5–29.2 tok/s, mean 28.1 | log records |
| Highest cold prefill observed | 606.0 tok/s at 16 994 tokens | log record |
| Cold prefill at 157 835 tokens | 594.2 tok/s, 265.6 s | log record |
| Resident expert cache | 1257 slots / 2.07 GiB at `--vram-reserve-mib 512`; 1107 slots at 768 | engine's own sizing lines |
| Automatic prompt chunk | 2816 tokens at 1257 slots; 2048 at 1107; **512 at 504** | engine's own sizing lines |
| MTP draft layer, one session | loaded, 822 MiB VRAM; expert cache fell to 504 slots; the same cold prompt measured 245.8 tok/s | log records, **n = 1** |
| Long-context probe | 3 embedded keys out of 3 returned correctly at 157 835 tokens | fixture + output files, hashes published |

All of these are recomputed by `sh scripts/validate.sh` from the committed TSV.

### Same day, earlier — KV `int8` or `k8v4`, vision on in 20 of 24 sessions, `--spec 4` in all 24

| Measurement | Value | Evidence |
| --- | --- | --- |
| Launches carrying `--mtp` | 16. Logged outcomes: six refusals (246 MiB free ×4, 247 MiB ×2), one dense-weights allocation failure, three 835 MiB loads | log records |
| Launches that failed outright | five, on `unknown argument: --kv-streaming` and `--draft-vocab` | log records |
| Longest MTP session | 141 request records, 140 completed, 75.7% draft acceptance, decode 22.6–28.6 tok/s | log records |
| Cold prefill with MTP, 16 387 tokens ×3 | 388.7, 390.4, 390.7 tok/s | log records |
| Cold prefill without MTP, 16 991 / 16 993 tokens | 376.9 / 378.8 tok/s | log records |
| Longest **completed cold** prefill in the published data | 189 737 tokens at 254.3 tok/s, single run | log record |

**Read the qualifiers.** 262 144 is the context the engine *advertises*; the longest **completed cold**
prefill actually recorded is 189 737 tokens, and the longest prompt record of any kind in that dataset is
197 272 tokens — which reused 194 255 of them at 248.2 tok/s and is therefore not a prefill measurement at
all. The same window also contains 190 804- and 208 846-token requests that were cut off mid-prefill and
generated nothing; they are published for completeness and excluded from every throughput statement here.
Nothing in this repository describes behaviour at the 262 144-token limit.

**What these rows do not mean.** MTP is not proven slower: the evening pair points one way (245.8 against
529.9–537.5) and the morning pair points the other (388.7–390.7 against 376.9–378.8), and both are
confounded — the evening pair by `--vram-reserve-mib` (conflict C4), the morning pair by expert cache size,
prompt chunk, `--kv-resident` and vision state (C12). And one successful retrieval probe is not evidence of
long-context ability. Details in [`docs/findings.md`](docs/findings.md) §2 and §6.

---

## The coding-agent case study, and its recursion

A Pi coding agent was pointed at a Go token-bucket rate-limiter exercise. The same local engine and the same
8 GB GPU served the agent **and** were the system under measurement. A captured `nvidia-smi` reading shows
the engine holding 7 485 MiB of 8 188 MiB at 100 % utilization while the audit was being served by it, so no
timing measurement taken in that session is a valid benchmark and the Go benchmark suite was deliberately not
re-run.

Claims are separated into four categories in [`agents/pi/README.md`](agents/pi/README.md):

1. **Reported by the evaluated agent** — six defects fixed, a RED→GREEN cycle, mutation-testing
   observations, all benchmark timings. Two of the agent's reported facts were shown to be **wrong**: a
   incorrect CPU core count (C6) and a headline `Allow` figure taken from the denied-path benchmark
   (C5).
2. **Rechecked by this project** — 60 tests / 4 examples / 15 benchmarks confirmed; `go test -race` clean at
   `-count=3`; `-shuffle=on` clean at `-count=5`; 100.0 % statement coverage; `gofmt`, `go vet`,
   `staticcheck`, `golangci-lint` clean. "Confirmed at reduced count" means exactly that.
3. **Supported by independently designed correctness tests** — **empty.** Every test in the exercise was
   written by the agent under evaluation. No claim in this case study may be read as evidence that the
   limiter is correct.
4. **Unverified or without artifacts** — `govulncheck`, all benchmark timings, the RED failures behind the
   six defects, mutation testing, the clock-ordering mechanism, the benchmark-metric fix, and the Go source
   itself, which is not published here.

---

## Hardware (verified on the machine, not copied from a spec sheet)

Lenovo laptop (`82XV`), Ubuntu 26.04.1 LTS, kernel 7.0.0-38-generic, Intel Core i7-13620H (10 physical
cores / 16 logical, **no AVX-512**), 64 GB installed (61.3 GiB visible to the kernel), NVIDIA RTX 4060
Laptop GPU with 8188 MiB VRAM, driver 595.99.02 open kernel module (banner reports CUDA 13.2; the engine
builds are labelled `cuda13`), PCIe Gen4 ×8 — the engine's own probe measured 11.0–11.6 GB/s host→device
across launches, 11.5 most often, and 15 of the 57 launches overrode the probed value: seven set
`--pcie-frac 0.20` and eight set 0.15.

Full table with the command behind every value: [`docs/hardware.md`](docs/hardware.md). Rows whose raw
output was not captured are marked as such there. The hostname, OS username, machine UUID and serial
numbers are not published here; the public GitHub account name is public by nature of the repository
existing.

---

## Where the raw data is

[`results/`](results/README.md). Each dataset is a directory holding a `manifest.json` (date, hardware,
driver, model files with sha256, engine build id, full configuration, extraction command, limitations), the
sanitized machine-readable TSV, and **the `extract.awk` program that produced it**, so the selection rule is
inspectable next to the data it selected.

| Dataset | Records | Window in the private log |
| --- | --- | --- |
| `2026-11-02-config-sweep` | 134 (11 engine starts, 123 events, 30 prompt records) | 12627–13420 |
| `2026-11-02-mtp-attempts` | 233 (24 engine starts, 209 events, 183 prompt records) | 9470–12626 |
| `2026-10-30-11-02-engine-diagnostics` | 1 941 (57 engine starts, 1 776 events, 108 continuation lines) | 1–13420 |

**The launch census spans two quantizations.** 49 of the 57 launches name `IQ3_XXS/…` and 8 name `IQ3_S/…`;
all 8 `IQ3_S` launches are 0.1.54-era, all carry `--vision` and none carries `--mtp`. Every whole-window
count in that dataset (57 launches, 42 with `--vision`, 25 requesting MTP, the version split) therefore is
not an `IQ3_XXS`-only count. The `IQ3_S` shards have no published size or hash anywhere in this repository
(gap G14).

Raw engine logs are **not** published: they interleave request metrics with prompt and completion content
from private agent sessions. Only whitelisted metric lines are extracted, install-root and home paths are
substituted, and a payload is the log line with those paths and the `strata generate:` / `strata serve:` /
`[strata] … engine started:` prefixes removed — no numeric value is ever edited. Model weights are never
committed; they are referenced by name, byte size and sha256, and the two published hashes equal the
upstream Hugging Face LFS oids for the 47 GB and 28.8 GB shards.

---

## Known limitations (read these before citing anything)

1. **Single machine.** One 8 GB laptop GPU, one CPU without AVX-512, one engine generation pair. Nothing
   here is claimed to generalise.
2. **No peak RAM or VRAM samples exist** for any historical run. Only engine self-reported allocations.
3. **The published sweep was not a controlled experiment.** It came from interactive agent sessions and
   several arguments changed together.
4. **MTP comparisons are confounded in both directions** (C4, C12). No isolated MTP effect is established
   in either direction.
5. **Prompt identity across sessions is inferred** from exact token-count matches, not from published
   fixture hashes. Publishing fixtures is Phase 2/3 work.
6. **The coding-agent evaluation had no independent oracle.** The agent wrote the tests that judged its own
   work, and two factual errors were found in its report.
7. **Some claims remain unverified** — `govulncheck`, the Go benchmark timings, the mutation-testing
   evidence, and the original failing tests behind the six reported defects.
8. **Engine 0.1.54 covers 2026-10-30 19:22 → 2026-11-01 01:03 local** (20 of the 57 census launches);
   0.1.55 covers **from 2026-11-01 01:18 local** (37). Both generations ran on 2026-11-01, so a date alone
   does not identify a generation; the argument vector's engine path does. The 0.1.54-era launches and
   configurations are published; their **request records** are not (gap G7), and the 678-record count behind
   that gap is a private-log count that no published dataset can reconstruct.
9. **No throughput number here has a paired resource sample** — no CPU load, GPU utilization, VRAM
   occupancy or temperature was captured alongside any request (gap G11).
10. **The engine log is not provably append-only.** Its size went 15 426 → 16 105 → 15 693 → 17 233 →
    18 689 → 19 664 → 20 648 lines across seven measurements for reasons this project does not understand
    (C11), and its first lines belong to a launch whose start record is no longer in the file. It was
    archived off-repo on 2026-11-04 (`2026-11-04T10:29:44Z`, 22 132 lines, 2 839 708 bytes, sha256
    `c102ade0…a68b9`, taken **mid-write**) and the archive is now the anchor of record; line numbers remain
    re-verifiable pointers, never identifiers.
11. **The Go rate-limiter exercise is described here but not published here**, so its mechanical claims
    cannot be re-run from this repository. See the License section and `docs/findings.md` §4.
12. **Engine argument meanings quoted in `engines/strata/configuration.md` come from the engine's own help
    text as it appeared in the private log.** No published dataset contains those strings, so a reader
    cannot check them (gap G12).

---

## What was found wrong, and what happened to it

This section exists because it is the most transferable output of the project.

Phase 1 went through five correction rounds, the last two driven by independent reviewer agents. A further
audit pass on **2026-11-05** found **fourteen** more discrepancies, recorded as conflicts **C13–C26** in
[`docs/evidence-inventory.md`](docs/evidence-inventory.md). Thirteen were corrected in that pass; one — the
tension between the MIT grant text and its own scope note over documentation — was **left open for an owner
decision** rather than resolved unilaterally. They include:

- a `results/README.md` claim that all three datasets had been re-derived at five log sizes, where the
  diagnostics manifest recorded four (C13);
- the launch census silently spanning a second quantization while its manifest published no model block at
  all (C14);
- two manifests describing their payloads as verbatim apart from path substitution while their own program
  also strips line prefixes (C15);
- a program comment that contradicted the program beside it and its own output (C16);
- documentation that misdescribed how the sanitiser worked, and a sanitiser that passed caller-supplied
  paths through the **regular-expression** engine — so a root containing `.` over-matched a different
  directory, a root containing `+` or `(` silently did nothing and left a personal path in the output, an
  empty value corrupted every payload, and a trailing slash leaked a full personal path into a re-extracted
  record (C17);
- a zero-row extraction that exited **0**, which had already produced a false "DIFFERS" alarm during the
  audit (C17, C18);
- a warm-request table that published four of eight records while quoting a band only all eight produce
  (C22);
- five internal cross-references pointing at section numbers that do not exist (C23);
- a hardware row asserting GPU co-residency that its own captured command contradicts (C24).

**No published record, number or measurement window was changed by any of this.** The corrected extraction
programs reproduce all three committed TSVs byte for byte: 134 / 233 / 1 941 records, sha256
`95e46eb1…4bff6`, `e1e91051…8f1d`, `8bc104e1…d1af` — equal to the `tsv_sha256` each manifest already
published — re-derived from the archived copy on 2026-11-04 and again on 2026-11-05.

---

## Reproducing an experiment

- **Rebuild a published table from published data** — [`docs/reproducibility.md`](docs/reproducibility.md)
  §1 gives commands that parse the committed TSVs and prints the real output they produced, including two
  traps in the obvious filter. §1 also documents the CPU-only validator.
- **Re-verify the coding exercise** — §2. Needs Go 1.27+ **and the exercise's source, which is not published
  in this repository**.
- **Re-measure on your own hardware** — §3 and §4 give the manifest skeleton and the clean-run procedure,
  including the rule that nothing else may use the GPU during a timing run. §5 lists what is not reproducible
  today and why. §6 is the owner procedure for archiving a private log.
- **Re-extract from the private log** (owner only) — `sh scripts/validate.sh --reextract <archive-dir>`.
  Never part of CI, and never run against anything but a private copy.

---

## Contributing

Read [`CONTRIBUTING.md`](CONTRIBUTING.md). The short version: add a dataset directory with a manifest, state
which evidence class each number belongs to, run both forms of the publication-safety check before
committing, and do not compare numbers whose conditions do not match. Hardware reports and result
submissions from other machines are the point of this project — that is how a single-laptop record becomes
useful.

CI runs `sh scripts/validate.sh` on every push and pull request. Issue templates are Phase 5 work and do
not exist yet.

## License

This repository is **dual-licensed**, decided by the owner on 2026-11-04 (gap G1).

- **Software** — scripts, the `extract.awk` extractors committed beside every dataset, parsers, validators,
  schemas, CI workflow definitions and any program code added by later phases: **MIT**, in `LICENSE`.
- **Research record** — `docs/`, `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, the engine and agent
  write-ups, and the datasets under `results/` (`.tsv` extracts, `manifest.json` metadata and the derived
  tables and analyses): **CC BY 4.0**, in `LICENSE.docs`, whose legal text is incorporated by reference at
  <https://creativecommons.org/licenses/by/4.0/legalcode>.

The split exists because the measurement records are meant to be reused **with attribution to this project**
while the tooling is meant to be reused freely. `LICENSE.docs` states the required credit form and the two
reuse limits that matter most here: the published extracts are sanitized metric records, not raw logs, and a
single-run observation does not become a verified result because someone reused it.

One known rough edge is recorded rather than papered over: the MIT grant text licenses "this software and
associated documentation files" while `LICENSE`'s own scope note assigns documentation prose to CC BY 4.0, and
the `extract.awk` files contain research prose in their comments. `LICENSE`'s mixed-file rule is the reading
this repository applies day to day (conflict C25, gap G15), and an owner decision is outstanding.

The Go rate-limiter exercise discussed in `docs/findings.md` §4 is **not** published here. It has no license,
no remote, and lives outside this repository. The owner decision (gap G2) is **reference-only**, and the
exercise is to be rebuilt clean-room from the published task specification under this repository's licenses
(Phase 3, tasks T3.7/T3.8). Nothing from that directory has been imported.

## Repository map

```
docs/            hardware, methodology, reproducibility, findings, evidence inventory,
                 architecture, implementation plan, research roadmap
engines/strata/  installation notes, configuration record, tuning notes, troubleshooting
agents/pi/       how the evaluated agent was configured, and who verified what
results/         machine-readable datasets, provenance manifests, and the programs that produced them
scripts/         CPU-only validation (structure, manifests, claim recomputation, publication safety)
tests/extract/   synthetic regression tests for the extraction programs
.github/         one CPU-only validation workflow
```

Start with [`docs/evidence-inventory.md`](docs/evidence-inventory.md) if you want to know exactly what
evidence exists, what is missing, and where the records disagree with each other — including the fourteen
disagreements found after the first audit was declared clean.
