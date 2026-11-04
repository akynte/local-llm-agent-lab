# Local LLM Agent Lab

Reproducible measurements of large-model inference and coding-agent work on consumer hardware — an
8 GB laptop GPU, 64 GB of RAM, and the inference engine and coding agent that were actually running on
it.

This is a personal research record turned into an open project. It is not a benchmark leaderboard, it
is not a product, and it is not affiliated with, endorsed by, or sponsored by the authors of any engine,
model or agent discussed here.

**Status:** Phase 1 (evidence audit and repository foundation) is written, two independent reviewer passes
were run and their findings corrected into these files, and the mechanical validation is clean. The owner
decisions recorded on 2026-11-04 are implemented: dual licensing (MIT for code, CC BY 4.0 for the research
record), the Go exercise kept reference-only until Phase 4, and the private engine log archived off-repo by
the owner. A **local initial commit** exists; **nothing has been pushed**, and Phase 2 tooling has not
started. Three datasets exist, all from one machine; two of them come from a single day. **No engine
comparison exists** — ExLlamaV3, llama.cpp, ik_llama.cpp and KTransformers have not been run, and nothing in
this repository compares them.

---

## The problem this project addresses

Local inference numbers are usually published as single figures on ideal hardware, and coding agents
are usually evaluated by their own test suites. Neither is reproducible by someone with a laptop.

This project tries to do the opposite: keep the raw records, publish enough of them that a reader can
rebuild every table, state what was not measured, and label every claim with the kind of evidence
behind it.

The rules live in [`docs/methodology.md`](docs/methodology.md). The most important one: **an evaluated
agent's own tests are not evidence about that agent's correctness** until someone else runs them.

## What has actually been tested

| Experiment | Status | Where |
| --- | --- | --- |
| Strata 0.1.55, 256K context, IQ3_XXS, evening sweep: 11 engine sessions, 30 requests | measured, published | `results/strata/2026-11-02-config-sweep/` |
| Strata 0.1.55, same day 09:33–15:17: 24 engine sessions, 183 requests, 16 launches carrying `--mtp` | measured, published | `results/strata/2026-11-02-mtp-attempts/` |
| Engine launch census, 2026-10-30 → 2026-11-02: 57 launches (20 on 0.1.54, 37 on 0.1.55) with configurations and start-up diagnostics | recorded, published | `results/strata/2026-10-30-11-02-engine-diagnostics/` |
| MTP speculative decoding enabled/disabled | requested by 25 of 57 launches, **confounded in both directions** | `docs/findings.md` §2 |
| Long-context retrieval probe, 157 835 prompt tokens | measured once, fixture hash published | `docs/findings.md` §3 |
| Coding-agent exercise: Go token-bucket rate limiter | performed; mechanical claims independently re-verified | `docs/evidence-inventory.md` §3 E4 |
| ExLlamaV3, llama.cpp, ik_llama.cpp, KTransformers | **not run** | `docs/research-roadmap.md` Q5 |
| Coding-agent defect repair against a pinned baseline with hidden tests | **not built** | Phase 3 |

## Hardware (verified on the machine, not copied from a spec sheet)

Lenovo laptop (`82XV`), Ubuntu 26.04.1 LTS, kernel 7.0.0-38-generic, Intel Core i7-13620H (10 physical
cores / 16 logical, **no AVX-512**), 64 GB installed (61.3 GiB visible to the kernel), NVIDIA RTX 4060
Laptop GPU with 8188 MiB VRAM, driver 595.99.02 open kernel module, CUDA 13.2, PCIe Gen4 ×8 (the engine's
own probe reported 11.0–11.6 GB/s host→device across launches, 11.5 most often), Samsung 990 PRO 2 TB NVMe.

Full table with the commands that produced every value: [`docs/hardware.md`](docs/hardware.md). The
local hostname, the operating-system username, machine UUID and serial numbers are not published here.
The GitHub account name that owns this repository is public by nature of the repository existing.

## What has actually been measured

### Evening sweep — engine 0.1.55, model `Qwen3.8-Flash-Next-GSQ-RCO-IQ3_XXS`, context 262 144,
KV `q4_0`, no vision. The rows below are **cold** requests (0 prompt tokens reused); the same dataset also
contains 8 warm reused-prompt records, all in one launch, and those are excluded from every throughput
comparison here (see `docs/findings.md` §1.3):

| Measurement | Value | Evidence |
| --- | --- | --- |
| Cold prefill, 12 719-token prompt, five runs, no MTP | 529.9–537.5 tok/s across **four different argument vectors**; only the `--spec 6` pair (537.4, 537.5) is a true repetition, agreeing to 0.02% | log records |
| Decode, same five runs | 26.5–29.2 tok/s | log records |
| Highest cold prefill observed | 606.0 tok/s at 16 994 tokens | log record |
| Cold prefill at 157 835 tokens | 594.2 tok/s, 265.6 s | log record |
| Resident expert cache | 1257 slots / 2.07 GiB at `--vram-reserve-mib 512`; 1107 slots at 768 | engine's own sizing lines |
| Automatic prompt chunk | 2816 tokens at 1257 slots; 2048 at 1107; **512 at 504** | engine's own sizing lines |
| MTP draft layer | loaded successfully, 822 MiB VRAM; expert cache fell to 504 slots; same cold prompt measured 245.8 tok/s | log records, **n=1** |
| Long-context probe | 3 embedded keys out of 3 returned correctly at 157 835 tokens | fixture + output files, hashes published |
| Go exercise | 60 tests, 4 examples, 15 benchmarks, 100.0% statement coverage, race detector clean, vet/staticcheck/golangci-lint clean | **independently re-run here** |

### Same day, earlier — `int8` or `k8v4` KV, vision on in 20 of 24 sessions, `--spec 4` in all 24:

| Measurement | Value | Evidence |
| --- | --- | --- |
| Launches carrying `--mtp` in this window | 16; logged outcomes: six refusals (246 MiB free ×4, 247 MiB ×2), one dense-weights allocation failure, three 835 MiB loads | log records |
| Launches that failed outright | five, on `unknown argument: --kv-streaming` and `--draft-vocab` | log records |
| Longest MTP session | 141 request records, 140 completed, 75.7% draft acceptance, decode 22.6–28.6 tok/s | log records |
| Cold prefill with MTP, 16 387 tokens ×3 | 388.7, 390.4, 390.7 tok/s | log records |
| Cold prefill without MTP, 16 991 / 16 993 tokens | 376.9 / 378.8 tok/s | log records |
| Longest **completed cold** prefill in the published datasets | 189 737 tokens, 254.3 tok/s, single run | log record |

The last row needs its qualifier: the same dataset also contains requests of 190 804 and 208 846 prompt
tokens that were **partial prefills** (`0 reused + 46 914 of 190 804 read`), and warm requests up to
197 272 tokens. "Longest prompt in the log" without saying *completed* and *cold* is false.

Two things those rows do **not** mean: MTP is not proven slower (the evening pair points one way and the
morning pair points the other, and both are confounded), and a single successful retrieval probe is not
evidence of long-context ability. Details in [`docs/findings.md`](docs/findings.md) §2 and §6.

## Reproducing an experiment

- **Rebuild a published table from published data** — a command in
  [`docs/reproducibility.md`](docs/reproducibility.md) §1 parses the committed TSV and prints the real
  output it produced during the audit. No weights, no GPU, no engine needed.
- **Re-verify the coding exercise** — §2 of the same file. Needs Go 1.27+ only.
- **Re-measure on your own hardware** — §3 and §4 give the manifest skeleton and the clean-run
  procedure, including the rule that nothing else may use the GPU during a timing run.

## Where the raw data is

[`results/`](results/README.md). Each dataset is a directory with a `manifest.json` (date, hardware,
driver, model files with sha256, engine build id, full configuration, limitations) and sanitized
machine-readable records.

Raw engine logs are **not** published: they interleave request metrics with prompt and completion
content from private agent sessions. Only whitelisted metric lines are extracted, paths are sanitized,
and the extraction program is published so the selection is auditable rather than asserted. Model
weights are never committed — they are referenced by name, byte size and sha256, and the two published
hashes match the upstream Hugging Face LFS oids for the 47 GB and 28.8 GB shards.

## Known limitations (read these before citing anything)

1. **Single machine.** One 8 GB laptop GPU, one CPU without AVX-512, one engine version. Nothing here
   is claimed to generalise.
2. **No peak RAM or VRAM samples exist** for any historical run. Only engine self-reported allocations.
3. **The published sweep was not a controlled experiment.** It came from interactive agent sessions and
   several arguments changed together.
4. **MTP comparisons are confounded in both directions** — the evening pair by `--vram-reserve-mib`
   (conflict C4), the morning pair by expert cache size, prompt chunk, `--kv-resident` and vision state
   (conflict C12). See [`docs/evidence-inventory.md`](docs/evidence-inventory.md).
5. **Prompt identity across sessions is inferred** from exact token-count matches, not from published
   fixture hashes. Publishing fixtures is Phase 2/3 work.
6. **The coding-agent evaluation had no independent oracle.** The agent wrote the tests that judged its
   own work; two factual errors were found in its report.
7. **Some claims remain unverified** — `govulncheck`, the Go benchmark timings, the mutation-testing
   evidence, and the original failing tests behind the six reported defects.
8. **Engine 0.1.54 covers the launches from 2026-10-30 19:22 to 2026-11-01 01:03 local time** (20 of the
   57 launches in the published census); engine 0.1.55 covers the launches **from 2026-11-01 01:18 local**
   onward (37). Both generations ran on 2026-11-01, so a date alone does not identify a generation. Those
   0.1.54-era sessions are not comparable to the 0.1.55 numbers. Their launches and configurations are now
   published in the diagnostics census; their 678 request records are a **private-log count** and are not
   extracted (gap G7).
9. **No throughput number here has a paired resource sample.** No CPU load, GPU utilization, VRAM
   occupancy or temperature was ever captured alongside a request (gap G11).
10. **The engine log is not provably append-only.** Its size went 15 426 → 16 105 → 15 693 → 17 233 →
    18 689 → 19 664 → 20 648 lines across seven measurements for reasons this project does not understand
    (conflict C11), and its first lines belong to a launch whose start record is no longer in the file.
    Line windows were re-verified by re-extraction and diff at five of those sizes, all identical, but the
    log needs archiving before further analysis (gap G10).
11. **The Go rate-limiter exercise is described here but not published here**, so its mechanical claims
    cannot be re-run from this repository. See the License section and `docs/findings.md` §4.

## Contributing

Read [`CONTRIBUTING.md`](CONTRIBUTING.md). The short version: add a dataset directory with a manifest,
state which evidence class each number belongs to, run the publication-safety scan before committing,
and do not compare numbers whose conditions do not match. Hardware reports and result submissions from
other machines are the point of this project — they are how a single-laptop record becomes useful.

Issue templates and CI validation are Phase 5 work and do not exist yet.

## License

This repository is **dual-licensed**, decided by the owner on 2026-11-04 (gap G1 in
`docs/evidence-inventory.md`, which previously recorded "no license chosen" as an open decision).

- **Software** — scripts, the `extract.awk` extractors committed beside every dataset, parsers, validators,
schemas, CI workflow definitions, and any program code added by later phases: **MIT**, in `LICENSE`.
- **Research record** — `docs/`, `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, the engine and agent
write-ups, and the datasets under `results/` (`.tsv` extracts, `manifest.json` metadata and the derived
tables and analyses): **CC BY 4.0**, in `LICENSE.docs`, whose legal text is incorporated by reference at
<https://creativecommons.org/licenses/by/4.0/legalcode>.

The split exists because the measurement records are meant to be reused **with attribution to this project**
while the tooling is meant to be reused freely. `LICENSE.docs` states the required credit form and the two
reuse limits that matter most here: the published extracts are sanitized metric records, not raw logs, and
a single-run observation does not become a verified result because someone reused it.

The Go rate-limiter exercise discussed in `docs/findings.md` §4 is **not** published here. It has no license,
no remote, and lives outside this repository. The owner decision (gap G2) is **reference-only until Phase 4**,
where the exercise is to be rebuilt clean-room from the published task specification under this repository's
licenses. Nothing from that directory has been imported.

## Repository map

```
docs/            hardware, methodology, reproducibility, findings, evidence inventory,
                 architecture, implementation plan, research roadmap
engines/strata/  installation notes, configuration record, tuning notes, troubleshooting
agents/pi/       how the evaluated agent was configured and what the evaluation did and did not show
results/         machine-readable datasets with provenance manifests
```

Start with [`docs/evidence-inventory.md`](docs/evidence-inventory.md) if you want to know exactly what
evidence exists, what is missing, and where the records disagree with each other.
