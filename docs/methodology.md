# Methodology

This document is the rule set the rest of the repository follows. If a statement in this
repository does not satisfy it, that statement is a draft, not a result.

## 1. Evidence classes

Every technical claim in this project is tagged with one of these classes. The tag is mandatory and
appears next to the claim, not in a footnote.

| Tag | Meaning | Example in this repository |
| --- | --- | --- |
| **V** — verified locally | Reproduced on this machine by a command whose output is recorded, or extracted verbatim from a log that is still available | `go test -race -count=3` exit status; a prefill line quoted from the engine log |
| **H** — historical measurement | Measured on this machine at a recorded time, but the raw record is a log line that this project did not itself produce through a controlled run | the 2026-11-02 engine sessions |
| **A** — agent-reported | Produced by a coding agent that is itself under evaluation | the Go project's own `README.md` performance table |
| **I** — independently re-verified | An **A** claim that this project re-ran and confirmed (or refuted) with its own command | 100% statement coverage, 60 tests, 4 examples, 15 benchmarks |
| **T** — third-party | From another project or vendor, with the source named | upstream benchmark claims, when used |
| **X** — hypothesis | A proposed explanation not yet tested | "the MTP draft layer starves the resident expert cache, which collapses the prefill chunk" |
| **P** — planned | Work that has not been performed | ExLlamaV3 comparison |
| **U** — unknown | Evidence does not exist or was not retained | peak VRAM during the 2026-10-30 sessions |

**A** claims are never used as evidence for correctness. An evaluated agent's own tests are not an
independent check of that agent's work; they are a claim about its work until **I**.

## 2. Provenance record

Every measurement entry must carry, where available:

- date and time, with the time zone stated (this machine is UTC+04:00; published timestamps are
  converted to UTC with the local value also shown)
- hardware, OS, kernel, GPU driver, CUDA variant (see `docs/hardware.md`)
- model name, quantization, source repository, file names, byte sizes, sha256
- engine name, version, and build identifier
- the full configuration used, as the engine recorded it
- context size
- prompt or fixture description, prompt token count, and how many prompt tokens were cache-reused
- output token count
- prefill throughput and decode throughput, each with the elapsed time they were derived from
- peak RAM and peak VRAM, or an explicit statement that they were not captured
- the commands run and their exit status
- repetition count
- methodological limitations, written by the person who ran the experiment

Missing fields are written as `not captured`, never guessed.

### 2.1 Recorded tooling failures during extraction

Failures in the extraction tooling are recorded rather than hidden, because a reader reproducing this
work will meet the same walls. All of these happened during the 2026-11-02 → 2026-11-03 audit:

| Failure | Message as it appeared | What it taught |
| --- | --- | --- |
| Python regex group reference | `IndexError: no such group` | a group index used after a pattern was edited; patterns are now re-checked against sample lines before counting |
| Python `Counter` misuse | `TypeError: object is not iterable` | counting was done on a generator expression instead of an iterable |
| Multi-line awk condition | `awk: line 2: syntax error at or near ,` and later `awk: …: line 3: missing ) near end of line` | **the default `awk` on this host is mawk**, which rejects an `if` / `else if` condition continued across lines. All three committed `extract.awk` programs keep every condition on one line; an earlier published version of the extraction program failed here and was replaced |
| grep pattern starting with `->` | `grep: invalid option -- '>'` | patterns that begin with a dash are passed after `--` or rewritten |
| JSON manifest edit | `Expecting ',' delimiter: line 80 column 5 (char 4450)` and later `Illegal trailing comma before end of object: line 68 column 543` | every manifest edit is followed by a `json.load` validation pass. The second message came from a note rewritten during the 2026-11-04 correction pass, where the sentence it replaced had ended with a comma that the new text no longer justified; the validator is what caught it |
| Shell quoting of a scan pattern | `/bin/bash: -c: line 1: syntax error near unexpected token '[_-]?'` | publication-safety patterns live in a file, not in a shell one-liner. Until 2026-11-05 that file did not exist and the sentence described an intention; the patterns are now in `scripts/validate.py` check [7], and the `CONTRIBUTING.md` one-liners remain as the staged-diff form |
| `wc` on an empty argument | `wc: invalid zero-length file name` and the follow-on `FileNotFoundError: [Errno 2] No such file or directory: ''` | a pipeline built filenames from a variable that was empty. `scripts/validate.py` builds no shell pipeline and resolves each dataset path before hashing it |
| Edit-tool mismatches | `Could not find edits[0] … must match exactly including all whitespace and newlines` | documentation edits are re-read from the file before being retried, never guessed at |
| Re-extraction run **without the window variables** | three empty TSVs, reported as "config-sweep DIFFERS / mtp-attempts DIFFERS / diagnostics DIFFERS" | `extract.awk` needs `-v lo=… -v hi=…`; run without them the old programs selected nothing and exited cleanly. The false alarm was caught by checking the output line count (0) before believing the diff. Since 2026-11-05 all three programs reject a missing `lo`/`hi` with status 64 and report a zero-record window with status 65, so this failure mode cannot recur silently. The lesson about checking the line count before believing a diff still stands |
| Re-extraction run with a **wrong `-v R=` install root** (2026-11-04) | all three datasets reported "DIFFERS" while their record counts matched exactly (134 / 233 / 1941), and the payload diff consisted only of placeholder form | The old sanitiser substituted the install root with `gsub(R …)`, treating a caller-supplied path as a **regular expression**. A wrong root therefore produced placeholder-shaped payloads instead of failing. (The explanation first recorded here — that the programs "fall back to the home-directory substitution" — was itself wrong: the two request programs never read `-v H=` at all. Corrected 2026-11-05, conflict C17.) A diff that changes only placeholders is a tooling fault, not evidence that the log changed. `scripts/validate.py` now compares record counts, the manifest-declared sha256 and the window before any statement about the log is made |
| Sanitiser treating a supplied path as a **regular expression** (found 2026-11-05) | synthetic reproduction: a root containing `.` over-matched a different directory; a root containing `+` or `(` produced **no** substitution at all and left the personal path in the payload; an empty `-v R=` inserted `<STRATA_INSTALL_ROOT>` between every character of every payload; a trailing slash on `-v R=` left a full personal path in a re-extracted evening `engine_start` record | The three programs now substitute with `index()` and only at a path boundary, reject an empty or relative `R`/`H`, normalise a trailing slash, and exit 66 if any absolute personal path survives sanitization. `tests/extract/run_tests.sh` holds the synthetic cases. No published record changed: the corrected programs reproduce all three committed TSVs byte for byte |
| awk census command written as `print …, NR > 0` | a 29-byte file named `0` appeared inside `results/strata/2026-10-30-11-02-engine-diagnostics/` during a 2026-11-04 review pass | mawk parses `print … > expr` as a **redirect to a file named by that expression**, not as a comparison, so a guard written after `print` silently creates a file in the current directory. Every census command published here avoids `>` inside a `print`, and `scripts/validate.py` check [1] now fails a run if a dataset directory contains anything other than `README.md`, `manifest.json`, `extract.awk` and `.tsv` files |

None of these changed a published number. Several changed a published **program**, and the corrected
program is the one committed next to the data.

The 2026-11-05 pass added three failure modes to this table that had **not** been observed as incidents —
they were found by reading the programs and then reproducing each one on synthetic fixtures. They are
listed here rather than in a changelog because the point of this section is that a tool which fails quietly
is a defect you will eventually believe.

## 3. Measurement rules

1. **Cold versus warm.** A request with 0 reused prompt tokens is a cold prefill. A request with
   95% of its prompt reused is not a prefill measurement at all. The two are never averaged
   together, and the reused-token count is always published with the throughput.
2. **One variable at a time.** A configuration change is only interpretable when the other
   arguments are identical. If more than one argument changed, the result is labelled *confounded*.
3. **Repetition.** Single-run numbers are reported as single-run numbers. Where a claim is meant to
   support a comparison, the minimum is three repetitions per condition, with the spread published.
   The published data contains **five repetition groups**, and they are not one kind of control: four
   are same-session, same-argument-vector, same-prompt repeats inside a single morning launch, and one
   is a same-argument-vector pair produced by **two separate** evening launches. Their spreads are not
   one number:

   | Dataset | Session | Prompt tokens | Runs | Rates (tok/s) | Spread | Control kind |
   | --- | --- | --- | --- | --- | --- | --- |
   | evening sweep | 19:13:24 / 19:20:29 | 12 719 | 2 | 537.5, 537.4 | **0.02%** | two launches, byte-identical argument vector |
   | morning dataset | 10:00:17 | 16 387 | 3 | 388.7, 390.4, 390.7 | **0.51%** | three requests in one launch |
   | morning dataset | 10:00:17 | 4 093 | 3 | 360.2, 375.1, 377.3 | **4.75%** | three requests in one launch |
   | morning dataset | 10:00:17 | 4 089 | 2 | 362.4, 382.5 | **5.55%** | two requests in one launch |
   | morning dataset | 10:00:17 | 77 | 3 | 52.2, 54.0, 87.2 | **67.05%** | three requests in one launch |

   The pattern is consistent and uncomfortable: repetition is tight at long prompts and loose at short
   ones, so a 5% difference measured on a ~4K-token prompt is inside this host's own noise, while a 1%
   difference at ~13–16K tokens is measurable but needs a third run. Requests under 1 000 prompt tokens are
   not usable as noise evidence at all — the 77-token triple above varies by more than half, because a
   request that short is dominated by start-up and scheduling rather than by prefill throughput. The wider
   529.9–537.5 band sometimes quoted as "run-to-run spread" spans **four different argument vectors** and
   is not a noise figure — see `docs/findings.md` §1.1.
4. **Quiet machine.** Timing runs are performed with no other inference workload on the machine and
   with the load average recorded before and after the run. Note the recursion problem: this
   project's own agent session can be the inference workload. When that is true, the run is not a
   timing run and is labelled accordingly.
5. **No throughput from wall-clock alone.** Engine-reported token counts and elapsed milliseconds
   are used, because they are what the engine measured. If a wrapper measures wall-clock instead,
   the wrapper and its overhead are named.
6. **Peak memory.** Sampled at an interval, not read once at the end, and reported with the sampling
   interval. When only the engine's self-reported allocations exist, that is stated.
7. **No statistical language without a design.** "Significant", "proves", "robust" and "reliable"
   require repetitions and a stated design. Otherwise the wording is "in this run" or "in the
   recorded sessions".
8. **Failure is a result.** Crashes, refusals, OOM, degraded decode and non-determinism are recorded
   as findings, not discarded.

## 4. Naming and layout conventions

- Dataset directory: `results/<engine>/<YYYY-MM-DD>-<slug>/`
- Run identifier inside a manifest: `<engine>-<YYYYMMDD>-<HHMMSS>-<variant>`, e.g.
  `strata-20261102-203111-mtp-rt`
- Engine slug: `strata`, `exllamav3`, `llama-cpp`, `ik-llama-cpp`, `ktransformers`
- Model slug: `<family>-<name>-<quant>`, e.g. `qwen3.8-flash-next-iq3_xxs`
- Raw records: `engine-metrics.tsv`; provenance: `manifest.json`
- Derived output (tables, charts) is generated from `results/` and written to a generated directory,
  never hand-maintained

## 5. Coding-agent evaluation rules

1. The evaluated agent's own tests are not the correctness oracle. Correctness is judged by tests
   this project writes and runs independently, and by the task's stated acceptance conditions.
2. Baseline revisions are pinned by commit hash.
3. Workspaces are isolated per task, and the task's starting state is reproducible.
4. Every command the agent ran, and every command the evaluation ran, is retained with exit status.
5. Task outcomes are classified: complete, incomplete, wrong-but-passing, correct-but-overfit,
   blocked, failed. A passing test suite authored by the agent does not by itself mean complete.
6. Coverage is reported as what it is: statement coverage of the agent's own implementation, which
   is not evidence of absence of defects.
7. Hidden tests and externally prepared fixtures are planned (Phase 3) precisely because
   agent-authored tests are weak evidence.

## 6. Publication safety

Before any commit, run the scan in `CONTRIBUTING.md` (the staged-diff form) and `sh scripts/validate.sh`
(which scans every tracked text file). Never publish: model weights, raw engine or agent logs, conversation
transcripts, session metadata that identifies a person, absolute personal paths, hostnames, UUIDs,
credentials, or local virtual environments.

Engine logs are the most dangerous artifact in this project: they interleave request metrics with prompt
and completion content. The published extracts are produced by a selection that only matches metric lines,
then re-checked for personal paths. The extraction program is published so that the selection is auditable
rather than asserted. Since 2026-11-05 the extraction programs also refuse to publish: a payload in which
an absolute personal path survived sanitization makes `extract.awk` exit 66 rather than emit it.

Neither mechanism is a guarantee. `docs/evidence-inventory.md` §6.1 lists seven things they do not catch,
including a username that appears outside an absolute path, a home directory outside the listed roots, a
secret already committed before the check existed, and commit messages or author metadata. A publication
claim in a manifest ("the published TSV was re-checked … for the local username") describes an action the
owner performed by hand; no committed program performs a username check.

## 7. What this methodology explicitly does not claim

- It does not claim that a model is safe, aligned, or production-ready.
- It does not claim that a coding agent is generally reliable on the basis of one Go exercise.
- It does not claim that a long-context retrieval probe measures long-context reasoning.
- It does not claim engine rankings. Engine comparison is Phase 4 and no comparison result exists
  yet.
