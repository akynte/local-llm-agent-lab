# Repository architecture

## Design intent

The repository has one hard structural requirement: **a published result must be reconstructible from
data that is itself published.** Everything else follows from that.

That requirement produces three separations.

1. **Raw record vs. derived view.** `results/` holds what was measured. `docs/findings.md` holds
   interpretation. Nothing is hand-typed from one into the other; derived views come from generated
   output.
2. **Private vs. publishable.** Engine logs are the primary raw source and they are not publishable,
   because they interleave metrics with prompt and completion content. The repository therefore needs
   an explicit extraction step with a published selection rule, rather than a copy-paste step.
3. **Engine-specific vs. engine-neutral.** Log parsing is engine-specific. The normalized record,
   the validator, the comparison and the rendering must not be. Today only Strata parsing exists, so
   the engine-neutral half is a design, not a module; building it in the wrong order (a Strata-shaped
   "neutral" layer) is the main architectural risk of Phase 2.

## Layout

```
README.md                  first-contact entry point: what was tested, on what, with what results
CONTRIBUTING.md            how to add an experiment, claim discipline, publication-safety scan
SECURITY.md                reporting path, scope, what the repository never publishes
.gitignore                 weights, raw logs, agent state, build scratch

docs/
  hardware.md              verified host/device facts, with the commands that produced them
  methodology.md           evidence classes, provenance fields, measurement rules, claim rules
  reproducibility.md       how to re-derive, re-verify, or re-measure; what is not reproducible
  findings.md              interpretation of published datasets, each claim evidence-tagged
  evidence-inventory.md    what evidence exists, what is missing, what conflicts with what
  architecture.md          this file
  implementation-plan.md   phased tasks, each independently checkable
  research-roadmap.md      research questions, status of each, decision points

engines/
  strata/                  installation, configuration, tuning, troubleshooting
  exllamav3/               (created when an experiment exists)
  llama-cpp/               (created when an experiment exists)

agents/
  pi/                      how the evaluated agent was configured and what was actually run

results/
  README.md                dataset rules
  strata/2026-11-02-config-sweep/     manifest.json + engine-metrics.tsv + extract.awk + dataset README
  strata/2026-11-02-mtp-attempts/     manifest.json + engine-metrics.tsv + extract.awk + dataset README
  strata/2026-10-30-11-02-engine-diagnostics/  manifest.json + engine-diagnostics.tsv + extract.awk + dataset README
                             (the third is a launch census and engine start-up diagnostics with no
                              throughput records; in all three the extraction program is committed next
                              to the data it produced)

scripts/                   (Phase 2) extraction, parsing, validation, comparison, rendering
schemas/                   (Phase 2) the normalized result record and its validator
benchmarks/                (Phase 2/3) fixtures, task definitions, harness inputs
case-studies/              (Phase 3) the Go rate-limiter study, once licensable
site/                      (Phase 5) generated pages that read results/ only
.github/                   (Phase 5) issue templates, GPU-free validation workflow
```

Directories are created when their first real file exists. An empty directory is a claim about future
work placed in the wrong place; future work belongs in `docs/research-roadmap.md`.

## The data flow (target state, Phase 2)

```
engine output            harness output
     |                        |
     v                        v
 [engine adapters]     [run capture]        RAM/VRAM sampler, exit status, config recorder
     |                        |
     +-----------+------------+
                 v
      [normalized record set]      engine-neutral, one row per request
                 v
      [schema validator]           refuses incomplete or inconsistent records
                 v
      [comparator]                 only compares records whose conditions match
                 v
      [renderer]                   Markdown tables and charts, generated, never hand-edited
```

Each box is a module with one job and one seam. The seams are the normalized record and the schema,
which is why `schemas/` exists before `site/`: without a validated record there is nothing safe to
render, and a dashboard built directly on engine log parsing is a dashboard that silently compares
incomparable things.

## Normalized record (direction, not a frozen schema)

One row per request, at minimum:

`run_id`, `engine`, `engine_version`, `engine_build`, `model_id`, `quantization`, `context_tokens`,
`kv_quant`, `config_hash`, `fixture_id`, `prompt_tokens`, `reused_tokens`, `output_tokens`,
`prefill_ms`, `prefill_tokens_per_s`, `decode_ms`, `decode_tokens_per_s`, `ttft_ms`,
`peak_ram_bytes`, `peak_vram_bytes`, `captured_at_utc`, `source_excerpt`, `notes`.

`config_hash` is what makes comparison honest: two rows may be compared only if their `config_hash`
matches, or if a human has written down which fields differ. The comparator's default answer to a
mismatch is refusal, not a warning.

## Tooling choices

- **Python 3.14 + shell** for extraction, validation and rendering. Already present on this machine
  (Python 3.14.4, matplotlib 3.10.7, jq). No new dependency is added without a recorded reason.
- **Go** is welcome for a reusable CLI if it earns it — specifically if contributors need a
  single-binary validator. It is not used for orchestration, because shell and Python already do
  that job here with no build step.
- **GPU sampling through `nvidia-smi --query-gpu` in a loop**, not through `pynvml`, because
  `pynvml` is not installed and adding a dependency to sample a counter is not a reason to add a
  dependency.
- **No database.** JSON and TSV in `results/` are the storage. A repository whose benchmark data is
  greppable is more useful to contributors than one whose data needs a service.
- **CI without a GPU**: schema validation, parser unit tests, link checks, and a check that every
  dataset directory has a manifest. GPU benchmarks are never run in CI.

## Testing seams

Things that must have tests, because they are where silent errors happen:

1. log line → normalized record (per engine adapter), including malformed and partial lines
2. normalized record → validation error, for missing and inconsistent fields
3. comparison eligibility (the "may these two rows be compared" decision)
4. arithmetic (throughput from token counts and elapsed milliseconds, and the `ns/op ÷ calls/op`
   reconciliation pattern that the Go exercise already demonstrated as a real failure mode)
5. rendering (a table generated from a fixture dataset must match a golden file)

## What this architecture deliberately refuses

- No engine-specific code in the comparison or rendering layers.
- No hand-maintained performance table.
- No dashboard that contains a number not read from `results/`.
- No placeholder directory or documentation written to make the tree look complete.
- No automated GPU benchmarking in CI.
- No model weights, raw logs or agent transcripts anywhere in git.
