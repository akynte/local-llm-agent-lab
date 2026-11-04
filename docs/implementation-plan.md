# Implementation Plan

> **For agentic workers:** execute task-by-task. Steps use checkbox (`- [ ]`) syntax. Each task ends
> with an independently checkable deliverable. Do not start a phase whose predecessor has not been
> approved by the repository owner.

**Goal:** Build a public, reproducible research record of local LLM inference and coding-agent
evaluation on consumer hardware, with tooling that lets other people add their own measurements.

**Architecture:** Raw engine and harness output is extracted into sanitized, machine-readable datasets
under `results/`; a normalized record and its validator sit between extraction and any comparison;
comparison refuses mismatched conditions; all published tables and charts are generated from validated
data. Full rationale in `docs/architecture.md`.

**Tech stack:** Python 3.14 + shell for extraction/validation/rendering, `nvidia-smi` queries for
resource sampling, Go 1.27 for the coding-agent exercise (and for a validator CLI only if it earns
it), matplotlib for charts, pytest for tests. No database, no service, no GPU in CI.

**Spec:** the owner's project brief (sections 1–9 of the task statement) plus `docs/methodology.md`,
`docs/architecture.md` and `docs/evidence-inventory.md`.

## Global Constraints

- Evidence-first: no fabricated data, no invented logs, no placeholder files or empty directories.
- Never commit: model weights, raw engine logs, agent transcripts, personal absolute paths, hostnames,
  UUIDs, credentials, local virtual environments.
- Do not modify the existing Strata installation, Pi configuration, or the `/tmp/pi-coding-benchmark`
  project.
- Do not push to GitHub, create releases, or enable Pages without explicit owner approval.
- No GPU benchmark runs in CI. CI validation must run on a CPU-only runner.
- No new dependency without a recorded reason in the commit or pull request.
- No hardcoded personal filesystem paths in scripts or documentation.
- Planned work is described in `docs/research-roadmap.md`, never presented as a result.
- All repository text in clear technical English.

## Review Focus

The failure modes most likely to survive an unreviewed implementation:

1. **Incomparable rows compared anyway** — a warm request (95% prompt reused) averaged with a cold
   prefill. Expected behavior: the comparator refuses and names the differing fields.
2. **Silent unit confusion** — `ns/op` vs `ns/call`, `tok/s` from wall clock vs from engine-reported
   elapsed milliseconds, MiB vs MB. Expected: the validator rejects a record whose throughput does not
   reconcile with its token count and elapsed time.
3. **Private data leaking through an excerpt** — a metric line that happens to contain a path, a
   model path, or a fragment of prompt text. Expected: extraction selects only whitelisted line
   shapes, then a post-extraction scan fails the build on any personal path.
4. **Missing field treated as zero** — a record without `peak_vram_bytes` rendering as 0 or as
   "unknown" that a chart then plots. Expected: missing means absent, and any derived view that needs
   it says so explicitly.
5. **Agent-authored claim promoted to fact** — a number copied from an evaluated agent's own report
   into a findings table without an **A**/**I** tag. Expected: the evidence tag is mandatory and
   `docs/findings.md` cannot contain an untagged number.

---

## Phase 1 — Repository foundation

**Status: implemented, independently reviewed once, corrections applied, awaiting owner review.**
Evidence for each completed task is in `docs/evidence-inventory.md`.

**Naming note.** Some earlier documents in this repository call the audit work "Phase 0". That is
T1.1–T1.6 of this phase. "Phase 0", "the Phase 1 audit" and "the audit" refer to the same work; no
separate Phase 0 exists in this plan.

- [x] **T1.1 Evidence audit.** Files: `docs/evidence-inventory.md`. Deliverable: an inventory of every
  available source, its publication status, and the conflicts between records. Verified: 16 artifacts
  indexed (S1–S16); conflicts and gaps recorded in §4 and §6 of that file.
- [x] **T1.2a Correction pass.** Extracting the second window contradicted the first draft of the MTP
  finding. Deliverable: `docs/findings.md` §2 rewritten, `docs/evidence-inventory.md` E2 rewritten and
  conflicts C11/C12 added, `engines/strata/troubleshooting.md` §2 corrected and §9 added,
  `docs/research-roadmap.md` Q2/Q3 updated. Recorded deliberately: a plan that lists only the work that
  went smoothly is not a plan.
- [x] **T1.2 Sanitized raw datasets.** Files: `results/strata/2026-11-02-config-sweep/`,
  `results/strata/2026-11-02-mtp-attempts/` and `results/strata/2026-10-30-11-02-engine-diagnostics/`,
  each with `manifest.json`, a TSV, a dataset README and the `extract.awk` that produced it.
  Deliverable: 134, 233 and 1 941 records. Verified: a scan for
  absolute personal paths returned zero matches in all three TSV files; 11 + 24 + 57 engine launches and
  30 + 183 prompt records (11 + 20 of them short warm-ups under 1 000 prompt tokens — all eleven evening
  ones and eight morning ones are literally `prompt 53 tokens` — and 5 cut-off prefills); manifests carry
  model hashes that match the upstream LFS oids; all three windows re-extracted byte-for-byte identically
  on 2026-11-03 and 2026-11-04 with the committed programs, at log sizes of 15 693, 17 233, 18 689,
  19 664 and 20 648 lines.
- [x] **T1.2b Reviewer audit and correction pass.** A reviewer subagent audited the documentation against
  the published data before owner review. It found, and this plan's owner-facing text now reflects, the
  following defects in the first draft: a warm-reuse prefill band quoted as 39–116 tok/s when the published
  records span 39.6–555.7; a no-MTP decode hit-rate comparator of 39–46% when the identical-prompt
  comparator sessions logged 54.1–57.7%; "189 737 is the longest prompt in the log" when the same dataset
  contains 190 804- and 208 846-token cut-off prefills and 197 272-token warm requests; "ten MTP attempts"
  when 16 launches in that window (25 across the census) carried `--mtp` and only 10 outcomes were logged;
  a missing second MTP failure mode (`dense weights allocation failed`); a 246-vs-247 MiB refusal-message
  variant that was quoted as only 247; a 1257→504 slot comparison that mixed two different VRAM reserves;
  a 1.4% "run-to-run spread" that mixed four different argument vectors; and a claim that the 99.77% KV
  streaming figure belonged to the published 157 835-token request when the published figure for that
  request is 90.84% with 131.8 MiB from RAM. Deliverable: a third published dataset
  (`2026-10-30-11-02-engine-diagnostics/`) created so that quoted engine-internal lines are traceable
  rather than private, and corrections across `docs/findings.md`, `docs/evidence-inventory.md`,
  `docs/hardware.md`, `docs/reproducibility.md`, `docs/research-roadmap.md`, `README.md`,
  `engines/strata/{tuning,troubleshooting}.md`, `CONTRIBUTING.md` and both request manifests.
- [x] **T1.2c Second reviewer audit and correction pass (2026-11-03).** Two reviewer subagents audited
  the corrected documentation against the published data. Findings, each verified against the TSVs before
  being acted on:
  - the KV-streaming lines in the evening dataset are **session running totals**, not per-request
    counters; the published block-read sequence increases monotonically while the MiB column does not
    (one −8.2 MiB step), so the per-request spill is a difference between consecutive lines and the
    reading must be stated. Corrected in `engines/strata/troubleshooting.md` §6 with the difference table.
  - the 11:34:58 session was counted as "142 prompt records (141 completed)" in `docs/research-roadmap.md`
    while the dataset manifest and README use 141 records / 140 completed. Unified to the dataset
    convention.
  - `--spec 4` vs `--spec 6` was quoted only as a group band; a **single-variable** pair exists
    (19:04:16 vs 19:13:24, argument vectors differing in exactly one token: 531.9 → 537.5 tok/s, +1.05%)
    and is now used, with the group band labelled descriptive. Same fix in `docs/methodology.md`, whose
    "1–2% run-to-run spread" example had mixed four argument vectors: the only same-vector, same-prompt
    repetition in the published data agrees to 0.02%.
  - three launches (19:13, 19:20, 20:54) share a byte-identical argument vector, not two.
  - the 15:12:20 no-MTP morning session (12 716 tokens, 250.8 tok/s) was missing from the MTP discussion;
    it lands within 2% of the evening MTP number and is now part of the confounding argument.
  - MTP post-load cache/chunk ranges were quoted as 504–616 slots and 512–768 tokens, which describes
    only the 0.1.55 subset; the 0.1.54-era loads left 463, 463 and 553 slots with 768, 768 and 256 token
    chunks. Split by era in `docs/findings.md` and `docs/evidence-inventory.md`.
  - the mechanism behind drafting without an MTP layer is an **inference**, not a published fact; retagged
    **X**.
  - the PCIe probe value 11.5 GB/s was presented as a machine constant; the published distribution is
    11.0–11.6 GB/s over 42 launches. Corrected in `docs/findings.md`, `docs/hardware.md`, `README.md`,
    `engines/strata/tuning.md`.
  - engine help-text quotes live only in the private log; retagged and recorded as gap **G12**.
  - the tuner verdict needed a named inventory entry (**E8** / **S9**) with the read command; added.
  - the Go inventory row published a command that does not work (`grep -h '^func Test/Example/Benchmark'`);
    replaced with the three greps actually used, re-run on 2026-11-03 (60 / 4 / 15).
  - point-in-time host claims (7 485 MiB at 95 %, load 9.2, `MemAvailable` 8.3 GiB, "GNOME shell holds
    ~2 MiB") had no recorded output. A real `nvidia-smi` / `loadavg` / `meminfo` capture is now published
    in `docs/hardware.md` "Recorded outputs" (7 485 MiB at **100 %**, load **9.90/9.92/9.87**,
    `MemAvailable` **7.73 GiB**), and the unreproducible GPU-share claim is retagged **U**.
  - the extraction program published on the reproducibility page failed under **mawk**, this host's
    default awk. All three extraction programs are now committed next to their data, written with
    one-line conditions, and verified to reproduce all three TSVs byte for byte. Tool failures are
    recorded in `docs/methodology.md` §2.1.
  Deliverable: corrections across `docs/{findings,evidence-inventory,methodology,reproducibility,
  research-roadmap,implementation-plan,hardware}.md`, `README.md`, `agents/pi/README.md`,
  `engines/strata/{tuning,troubleshooting,configuration}.md`, all three manifests, two new
  `extract.awk` programs, and gap G12.
- [x] **T1.3 Core documentation.** Files: `docs/{hardware,methodology,reproducibility,findings}.md`.
  Deliverable: verified host facts, the evidence-class system, the reproduction procedure, and
  interpretation of the published dataset. Verified: `docs/reproducibility.md` §1 contains a command
  whose real output is quoted.
- [x] **T1.4 Architecture and roadmap.** Files: `docs/{architecture,implementation-plan,research-roadmap}.md`.
- [x] **T1.5 Engine and agent notes.** Files: `engines/strata/{installation,configuration,tuning,troubleshooting}.md`,
  `agents/pi/README.md`.
- [x] **T1.6 Repository hygiene.** Files: `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `.gitignore`.
- [ ] **T1.7 License decision.** Owner decision, not an agent decision. See gap G1. Until it is made,
  no `LICENSE` file exists and `README.md` says so explicitly.
- [ ] **T1.8 Independent review of Phase 1.** Deliverable: reviewer confirms that no claim in the
  repository outruns its evidence tag. **Partly done:** one reviewer pass was run and its findings were
  corrected (T1.2b); a second pass over the corrected text, and the owner's own sign-off, are still
  outstanding.
- [x] **T1.9 First commit.** Owner-approved on 2026-11-04. The publication-safety scan in
  `CONTRIBUTING.md` was run against the staged diff before the commit, and the license files (T1.7) were
  in the staged set. The commit is **local only**; nothing has been pushed, and pushing remains a separate
  owner approval.

---

## Phase 2 — Benchmark infrastructure

**Depends on:** Phase 1 approval. **Delivers:** extraction, normalization, validation, comparison,
rendering, and a resource sampler — all testable without a GPU.

**File structure**

```
schemas/result.schema.json          normalized record + dataset manifest rules
scripts/strata_extract.py           engine log -> sanitized TSV
scripts/normalize.py                sanitized TSV -> normalized records
scripts/validate_results.py         dataset directory -> validation errors
scripts/compare.py                  validated datasets -> comparison eligibility + tables
scripts/render.py                   validated datasets -> Markdown tables and charts
scripts/capture_resources.sh        interval sampler for GPU and RAM counters -> CSV
scripts/run_strata_session.sh       start a documented configuration, capture, stop
tests/test_strata_extract.py        parsing, malformed lines, sanitization
tests/test_normalize.py             record construction, missing fields
tests/test_validate.py              schema acceptance and rejection cases
tests/test_compare.py               eligibility decisions and arithmetic reconciliation
tests/test_render.py                golden-file table generation
conftest.py                         fixture datasets under tests/fixtures/
```

### Task 2.0 — Archive the private log before analysing it further (prerequisite for 2.1 and 2.7)

**Why:** the engine log's size moved 15 426 → 16 105 → 15 693 → 17 233 → 18 689 → 19 664 → 20 648 lines
across seven observations during the audit (conflict C11). The 0.1.54-era records exist only inside that
file.

- [ ] Step 1: copy the log to a private archive location outside the engine's state directory, record its
  sha256 / line count / byte count in a private note, and confirm the copy is not in any path a future
  `git add -A` could reach.
- [ ] Step 2: re-run both published extractions against the archived copy and diff against the committed
  TSV files; expect byte-for-byte identity.
- [ ] Step 3: record the archive's identity in `docs/evidence-inventory.md` S1 without publishing the
  archive itself.

### Task 2.1 — Log extraction

**Files:** Create `scripts/strata_extract.py`, `tests/test_strata_extract.py`

**Interfaces:**
- Consumes: a Strata engine log path.
- Produces:
  - `sanitize_paths(text: str, install_root: str) -> str`
  - `iter_sessions(lines: Iterable[str]) -> Iterator[tuple[int, str, list[str]]]` — `(line_no, timestamp, payload_lines)`
  - `extract(log_path: Path, from_line: int, to_line: int, install_root: str) -> list[Row]`
  - CLI `strata_extract.py --log PATH --from-line N --to-line M --install-root PATH --out FILE`

- [ ] Step 1: write failing tests for a request line, an `engine started` line, a sizing line, a line
  that must **not** be selected (prompt text, tool output), and a malformed request line.
- [ ] Step 2: run them; expect `ModuleNotFoundError` / missing-function failures.
- [ ] Step 3: implement the whitelist selection and `sanitize_paths`; the whitelist is the same line
  shapes documented in `docs/reproducibility.md` §1.
- [ ] Step 4: re-run; expect pass.
- [ ] Step 5: run it against the owner's archived log for lines 12627–13420 and 9470–12626 and diff
  against the two committed `engine-metrics.tsv` files; expect no difference apart from the header.
- [ ] Step 6: commit `feat: strata log extraction with published selection rule`.

### Task 2.2 — Normalized record and schema

**Files:** Create `schemas/result.schema.json`, `scripts/normalize.py`, `tests/test_normalize.py`,
`tests/test_validate.py`, `scripts/validate_results.py`

**Interfaces:**
- Produces: `Record` (dataclass, fields exactly as listed in `docs/architecture.md`),
  `to_records(tsv_path: Path, manifest: dict) -> list[Record]`,
  `validate_dataset(dir: Path) -> list[str]`, `validate_record(r: Record) -> list[str]`.
- Consumes: TSV rows from 2.1, a dataset `manifest.json`.

- [ ] Step 1: write failing tests — a complete record validates; a record missing `reused_tokens`
  fails; a record whose `prefill_tokens_per_s` disagrees with `prompt_tokens - reused_tokens` over
  `prefill_ms` by more than 2% fails; a record with `peak_vram_bytes: 0` fails the same way as a
  missing one; a manifest without `limitations` fails.
- [ ] Step 2: run; expect failures.
- [ ] Step 3: implement the schema and validators. The reconciliation rule is
  `abs(reported - computed)/computed <= 0.02` where `computed = (prompt_tokens - reused_tokens) / (prefill_ms / 1000)`.
- [ ] Step 4: run; expect pass.
- [ ] Step 5: validate the committed 2026-11-02 dataset; expect a reported list of *known* validation
  gaps (peak RAM/VRAM absent), recorded in the dataset README rather than hidden.
- [ ] Step 6: commit `feat: normalized result record, schema and validators`.

### Task 2.3 — Comparison eligibility

**Files:** Create `scripts/compare.py`, `tests/test_compare.py`

**Interfaces:**
- Produces: `config_hash(manifest: dict) -> str`, `eligibility(a: Record, b: Record) -> tuple[bool, list[str]]`,
  `compare(datasets: list[Path], metric: str) -> ComparisonResult`.

- [ ] Step 1: failing tests — same `config_hash` and same fixture: eligible; cold vs warm:
  ineligible with `reused_tokens` named; different engine version: ineligible; different quantization:
  ineligible; missing fixture id: ineligible.
- [ ] Step 2: run; expect failures.
- [ ] Step 3: implement eligibility as a refusal-first rule with an explicit reason list.
- [ ] Step 4: run; expect pass.
- [ ] Step 5: run against the 2026-11-02 dataset asking for the MTP comparison; expect it to **refuse**
  and name `mtp` and `vram_reserve_mib` as differing fields — this is the C4 conflict expressed in code.
- [ ] Step 6: commit `feat: comparison eligibility refuses mismatched measurement conditions`.

### Task 2.4 — Resource sampling

**Files:** Create `scripts/capture_resources.sh`, `scripts/normalize.py` extension for CSV input,
`tests/test_normalize.py` additions

- [ ] Step 1: failing test that a CSV of `nvidia-smi --query-gpu` samples normalizes to peak VRAM with
  the sampling interval preserved, and that an empty sample file yields "not captured" rather than 0.
- [ ] Step 2: implement the sampler: `--every-seconds N --out FILE --until PID-exits`, using only
  `nvidia-smi --query-gpu=...` and `/proc/self` style reads; no new dependency.
- [ ] Step 3: run it for 10 seconds against the currently running engine (read-only sampling is
  permitted; it does not perturb throughput measurements) and confirm the CSV.
- [ ] Step 4: commit `feat: interval resource sampling for RAM and VRAM peaks`.

### Task 2.5 — Rendering

**Files:** Create `scripts/render.py`, `tests/test_render.py`, `tests/fixtures/mini-dataset/`

- [ ] Step 1: failing test — rendering the fixture dataset produces a Markdown table identical to a
  golden file, and a chart is written to a generated directory only.
- [ ] Step 2: implement `render_markdown(datasets) -> str` and `render_charts(datasets, out_dir)`.
- [ ] Step 3: run; expect pass.
- [ ] Step 4: commit `feat: generated result tables and charts`.

### Task 2.6 — Controlled re-measurement (owner-supervised, GPU required)

**Depends on:** 2.1–2.5 complete and the machine quiet. **This is the first task that produces new
performance numbers.**

- [ ] Step 1: define the fixture set and publish fixtures with sha256 under `benchmarks/inference/`.
- [ ] Step 2: define the condition matrix, one variable per row, ≥3 repetitions per condition.
- [ ] Step 3: run with `scripts/run_strata_session.sh` plus the resource sampler, no other workload.
- [ ] Step 4: extract, normalize, validate; confirm the validator's known-gap list is empty.
- [ ] Step 5: render tables; write a new dataset directory with its manifest and limitations.
- [ ] Step 6: update `docs/findings.md` §1–2 and `docs/evidence-inventory.md` E1/E2.

### Task 2.7 — Extract the 2026-10-30 → 2026-11-01 sessions (gap G7)

**Depends on:** Task 2.0. Without an archived snapshot this data may no longer be reachable.

- [ ] Step 1: extract the 0.1.54-era window (20 engine sessions; **678 request records counted in the
  private log, a figure no published dataset can reproduce until it is extracted**) as its own dataset
  with its own manifest and engine build id.
- [ ] Step 2: validate; expect and record the same class of known gaps.
- [ ] Step 3: commit `data: 0.1.54-era strata sessions (engine 0.1.54, not comparable to 0.1.55)`.

---

## Phase 3 — Coding-agent evaluation framework

**Depends on:** Phase 2 validators (so that run records are machine-checked) and the license decision
for gap G2.

**File structure**

```
benchmarks/coding/tasks/<task-id>/   task.md, acceptance.md, baseline revision, fixtures
benchmarks/coding/hidden/            externally prepared tests, never visible to the agent
benchmarks/coding/harness/           workspace setup, execution log capture, classification
case-studies/go-rate-limiter/        the 2026-11-02 exercise, documented as a case study
```

- **T3.1** Workspace isolation: a task directory, a pinned baseline revision, a recorded start state.
- **T3.2** Execution capture: every command, exit status, wall time, and the model/engine that served
  the agent, recorded as a dataset manifest.
- **T3.3** Independent oracle: tests written by this project, not derived from the evaluated agent's
  suite, run against the agent's output.
- **T3.4** Hidden fixtures: tests withheld from the task statement, to detect overfitting to visible
  tests.
- **T3.5** Classification: complete / incomplete / wrong-but-passing / correct-but-overfit / blocked
  / failed, with the decision recorded per task.
- **T3.6** Go benchmark re-measurement on a quiet machine, replacing the **A** timings in E4 with **V**.
- **T3.7** Case study write-up of the rate-limiter exercise, including the two agent-authored errors
  found (C5, C6) as evidence for why the independent oracle is needed. Per the owner decision recorded on
  2026-11-04, the case study publishes the **task specification, the methodology and the evidence classes**,
  not the original source.
- **T3.8** Clean-room reimplementation of the rate-limiter exercise under this repository's licenses, with
  independent tests (T3.6/G6) and retained run artifacts. The original Go source stays **reference-only**
  and is not imported: it has no license, no remote, and lives in a temporary directory (gap G2, closed as
  a decision on 2026-11-04).

---

## Phase 4 — Engine comparison

**Depends on:** Phase 2 harness, and owner approval to download weights and install engines. Nothing
in this phase may produce a comparison table before the runs exist.

- **T4.1** ExLlamaV3 installation and verification on this host (owner-approved downloads; EXL3
  2.05 bpw and 3.05 bpw).
- **T4.2** ExLlamaV3 adapter for the extraction/normalization layer, producing the same normalized
  record.
- **T4.3** llama.cpp adapter (CPU/GPU offload configurations), same record shape.
- **T4.4** Common fixture set shared across engines, published with hashes.
- **T4.5** Comparison run matrix: prefill, decode, time-to-first-token, peak RAM, peak VRAM, achievable
  context, tool-calling behaviour, coding-task success, install complexity, stability.
- **T4.6** `docs/findings.md` engine-comparison section, generated, with every limitation stated.

---

## Phase 5 — Publication and community

- **T5.1** Issue templates (`bug report`, `result submission`, `hardware report`, `task proposal`).
- **T5.2** CI: schema validation, unit tests, link check, manifest-presence check. CPU-only.
- **T5.3** Result submission template and reviewer checklist.
- **T5.4** GitHub Pages site generated from `results/` only, with the generator checked so that no
  number exists in the site source.
- **T5.5** Versioned reports: tagged snapshots of `docs/findings.md` plus the dataset hashes it used.

---

## Self-review of this plan

1. **Spec coverage.** Repository architecture → T1.4/T2 layout. Evidence rules → global constraints,
   T2.2, T2.3. Benchmark infrastructure → Phase 2. Coding-agent framework → Phase 3. Engine
   comparison → Phase 4. Publication → Phase 5. Security and privacy → global constraints,
   `SECURITY.md`, `CONTRIBUTING.md`, T2.1 sanitization, and the Review Focus item 3. Licensing →
   **decided for this repository on 2026-11-04** (MIT for software in `LICENSE`, CC BY 4.0 for the research
   record in `LICENSE.docs`); the Go exercise is reference-only until T3.8 rebuilds it clean-room.
2. **Step scan.** Each step states one action. Phase 1 tasks are recorded as complete with the
   evidence that proves them rather than with steps to redo.
3. **Type consistency.** `Record`, `to_records`, `validate_dataset`, `config_hash`, `eligibility` and
   `compare` are used with the same names and shapes in 2.1–2.5; the normalized field list is defined
   once, in `docs/architecture.md`.
4. **Review focus coverage.** Item 1 → T2.3 step 1; item 2 → T2.2 step 1 (reconciliation test);
   item 3 → T2.1 step 1 (must-not-select test) and step 5 (diff against the committed file);
   item 4 → T2.2 step 1 (zero-vs-missing) and T2.4 step 1; item 5 → enforced by the evidence-tag rule
   in `docs/methodology.md` and by T1.8 review rather than by a code test.
5. **Proportion.** Phase 2 is the only phase written to step granularity, because it is the next
   executable work and its interfaces are the ones a fresh implementer cannot infer. Phases 3–5 are
   right-sized as task-level deliverables and will be expanded into steps only after Phase 2 is
   approved, so that this document stays a plan rather than a transcript.
