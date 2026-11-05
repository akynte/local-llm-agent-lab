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

- the validation tooling in `scripts/validate.sh` and `scripts/validate.py` and the extraction programs in `results/strata/*/extract.awk`,
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

Run both forms of the publication-safety check described in `CONTRIBUTING.md`:

1. the four `git diff --cached` commands, which inspect what you are about to commit;
2. `sh scripts/validate.sh`, which scans **every tracked text file** for absolute personal paths,
   credential-shaped strings and this machine's hostname, and checks dataset structure and manifest
   consistency.

Neither is a guarantee. `docs/evidence-inventory.md` §6.1 lists seven things they cannot catch, including
a username appearing outside an absolute path, a home directory outside the roots the patterns cover, a
secret already committed before the check existed, and commit messages or author metadata. A claim that a
published file was scanned for a local username describes a manual action, not something any committed
program performs.
