# Security Policy

## Reporting a vulnerability

Open a **draft** security advisory at
`https://github.com/akynte/local-llm-agent-lab/security/advisories/new`, or email the repository
owner using the contact address listed on the repository's Security tab. Do not open a public
issue for a vulnerability.

We aim to acknowledge reports within seven days. This is a single-maintainer research project, so
fix timelines depend on the affected component.

## Scope

In scope:

- the benchmark and analysis tooling in `scripts/` (once it exists),
- the result schemas and their validation,
- documentation instructions that would cause a reader to leak credentials, expose a local inference
  endpoint, or run a destructive command.

Out of scope:

- the inference engines themselves (Strata, ExLlamaV3, llama.cpp, KTransformers) — report those to
  their own maintainers,
- the models and their quantizations,
- the coding agents evaluated by this project,
- denial-of-service attempts against someone else's machine.

## What this repository does not do

- It hosts no inference service and exposes no endpoint.
- It publishes no model weights. Model files are referenced by name, byte size and sha256 only.
- It publishes no raw engine logs and no agent conversation transcripts. The engine logs used for
  the published results interleave request metrics with private prompt and completion content, so
  only sanitized metric extracts are committed (see `results/README.md`).
- It never runs GPU benchmarks in continuous integration.

## Before you commit anything

Run the publication-safety scan described in `CONTRIBUTING.md`. It looks for absolute personal
paths, credentials, hostnames, and accidentally staged large or private files.
