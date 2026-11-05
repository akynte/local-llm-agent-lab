# results/

Machine-readable experimental data. Every directory here corresponds to one experiment or one
sweep and contains:

- `manifest.json` — provenance: date, hardware, engine version and build, model files with
  integrity hashes, the exact configuration, the extraction command, and the limitations of that
  dataset.
- one or more `.tsv` files — sanitized raw records extracted from engine or tool output.
- `README.md` — a short human-readable description of what the dataset is and what it is not.
- `extract.awk` — the program that produced the TSV. All three current datasets carry one, so the
  selection rule is inspectable next to the data it selected, and re-running it is a diff rather than an
  act of trust.

Rules that apply to everything in this directory:

1. **No fabricated data.** Every number traces back to a log line, a command exit, or a test run.
2. **No private data.** Raw engine logs are not published because they interleave request metrics
   with prompt and completion content from private agent sessions. Only metric lines are extracted,
   with local filesystem paths replaced by placeholders.
3. **No model weights.** Model files are referenced by name, byte size and sha256, never committed.
4. **Derived numbers are not stored here.** Tables, charts and averages belong in `docs/findings.md`
   or in generated output; this directory holds what was actually measured.
5. **Licensed for reuse, with attribution.** The datasets and manifests in this directory are CC BY 4.0
   (`LICENSE.docs`); the `extract.awk` programs beside them are MIT (`LICENSE`). Each manifest carries a
   `license` field. `LICENSE.docs` states the required credit form and the two limits that matter most for
   measurement data: these are sanitized extracts rather than raw logs, and reusing a single-run observation
   does not make it a verified result.

## Current datasets

| Directory | Engine | What it contains |
| --- | --- | --- |
| `strata/2026-11-02-config-sweep/` | Strata 0.1.55 | 11 engine sessions, 30 prompt records (11 warm-ups, 11 cold, 8 warm), expert-cache and prompt-chunk sizing, one MTP-enabled session |
| `strata/2026-11-02-mtp-attempts/` | Strata 0.1.55 | 24 engine sessions from the same day 09:33–15:17, 183 prompt records (20 short warm-ups under 1 000 tokens, 8 of them literally 53 tokens; 178 completed, 5 cut-off), 16 launches carrying `--mtp`, six MTP refusals, one dense-weights allocation failure, three 835 MiB draft loads |
| `strata/2026-10-30-11-02-engine-diagnostics/` | Strata 0.1.54 **and** 0.1.55 | launch census: 57 engine launches with full sanitized argument vectors, plus engine start-up diagnostics (memory guard, PCIe probe, AVX-512 absence, huge-page fallback, expert-cache sizing, prompt-chunk choice, MTP load/refusal lines, unknown-argument rejections, vision warnings). No throughput records. **The census spans two quantizations**: 49 launches name `IQ3_XXS/…` and 8 name `IQ3_S/…`, so every whole-window figure in it (57 launches, 42 with `--vision`, 25 requesting MTP, 20 / 37 by engine version) is not an `IQ3_XXS`-only count — see conflict C14 |

## Checking this directory without a GPU

```sh
sh scripts/validate.sh
```

Checks the structure of all three TSVs, the record counts, the windows, each manifest's declared sha256,
recomputes the published figures from these files, scans tracked text for personal paths and
credential-shaped strings, and runs the three `extract.awk` programs against synthetic fixtures. No engine,
no weights, no private log, no network.

All three datasets come from the same private log. The line windows they were extracted from
(`12627–13420`, `9470–12626` and `1–13420`) were re-verified against the log by running the committed
`extract.awk` programs and diffing the output against the committed TSVs:

| Dataset | Re-derivations that were actually performed and recorded in its manifest | Live-log sizes |
| --- | --- | --- |
| `2026-11-02-config-sweep` | five | 15 693 · 17 233 · 18 689 · 19 664 · 20 648 |
| `2026-11-02-mtp-attempts` | five | 15 693 · 17 233 · 18 689 · 19 664 · 20 648 |
| `2026-10-30-11-02-engine-diagnostics` | **four** — 15 693 is **not** recorded for this dataset | 17 233 · 18 689 · 19 664 · 20 648 (last on 2026-11-04T00:48:21Z, sha256 `147bb441…`) |

An earlier version of this page claimed all five sizes for all three datasets; the diagnostics manifest
never recorded the 15 693-line run. Corrected 2026-11-05 (conflict C13). All three were re-derived again
on 2026-11-05 from the **archived copy** (`2026-11-04T10:29:44Z`, 22 132 lines, sha256 `c102ade0…a68b9`)
with the corrected extraction programs, and all three diffs were empty. Where the log's size did not change
monotonically between checks, see conflict C11 in `docs/evidence-inventory.md`.

A payload column is the log line with the install-root paths removed **and** with the line prefixes
(`[strata] … engine started: `, `strata generate: `, `strata serve: `) stripped. Numeric values are never
edited. The two request manifests now state the prefix stripping explicitly; an earlier version described
the payloads as verbatim apart from path substitution, which they are not (conflict C15).

Datasets for ExLlamaV3 and llama.cpp do not exist yet. They will be added only after those
experiments have actually been run.
