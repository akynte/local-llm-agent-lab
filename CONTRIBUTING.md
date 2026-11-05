# Contributing

Thanks for interest in this project. It is a research record, so the bar for a contribution is
"this is reproducible and it is honest" rather than "this is impressive".

## What this project is for

Documenting reproducible local inference and coding-agent evaluation on consumer hardware, and
building the tooling that lets other people add their own measurements. See `docs/architecture.md`
and `docs/research-roadmap.md`.

## Before you start

1. Read `docs/methodology.md`. It defines the evidence classes used everywhere in this repository.
2. Read `docs/reproducibility.md` for the environment you are expected to record.
3. If you are contributing measurements, read `results/README.md` first.

## Adding an experiment

1. Create `results/<engine>/<YYYY-MM-DD>-<short-slug>/`.
2. Add a `manifest.json` describing the run: date and time, hardware, OS, GPU driver and CUDA
   version, model name and quantization, model source and file hashes, engine and engine build
   version, the full configuration, prompt/fixture description, prompt tokens and cache reuse,
   output tokens, repetitions, exit status, and the limitations of the run.
3. Add sanitized raw records as `.tsv`. Keep the raw log out of the repository.
4. Add derived tables or charts only as generated output, never as the only evidence.
5. Reference the dataset from `docs/findings.md` and `docs/evidence-inventory.md`.

A contribution that reports a number without a manifest is treated as an anecdote and will be
labelled as such.

## Claim discipline

- State which evidence class a result belongs to: independently re-run here, captured from a log,
  reported by an evaluated agent, third-party, hypothesis, or planned.
- Do not compare two numbers as if they were measured under identical conditions unless the
  manifests show they were.
- Do not use "significant", "proves" or "robust" for single-run observations.
- Do not describe a model as production-ready on the basis of a limited test.
- Planned work belongs in `docs/research-roadmap.md`, never in the results tables.

## Publication-safety scan (run before every commit)

```sh
# 1. Absolute personal paths and credential-shaped strings.
#    The bracketed first characters ([h], [U], [w], …) are deliberate: they keep this
#    pattern from matching its own text when CONTRIBUTING.md is itself staged.
git diff --cached | grep -nE '/[h]ome/[a-z0-9_.-]+|/[U]sers/|/[r]oot/\.|[A-Za-z0-9_.-]*[a]pi[_-]?key[[:space:]"]*[:=]|(access|refresh|api|se[c]ret)[_-]?(token|key)[[:space:]"]*[:=]|pass[w]ord[[:space:]"]*[:=]|gh[p]_[A-Za-z0-9]{20,}|github_[p]at_[A-Za-z0-9_]{20,}|xox[baprs]-[A-Za-z0-9-]+|AK[I]A[0-9A-Z]{16}|BEGIN [A-Z ]*PR[I]VATE KEY|eyJ[h]bGciOi[A-Za-z0-9_.-]{20,}'

# 2. This machine's hostname, resolved at run time instead of written into the file
git diff --cached | grep -ni -- "$(printf '%s' "$(hostname)" | tr -c '[:alnum:]' '-')" && echo "REJECT: hostname in the staged diff"

# 3. Anything unexpectedly large or binary
git diff --cached --name-only | xargs -r -I{} sh -c 'test -f "{}" && printf "%8d  %s\n" "$(wc -c <"{}")" "{}"' | sort -rn | head -20

# 4. Model weights or raw logs must never appear
git diff --cached --name-only | grep -nE '\.(gguf|safetensors|exl3|ggml|pack|log|jsonl|ndjson|tar|tar\.zst|zip)$' && echo "REJECT: model or raw-log artifact staged"

# 5. The repository-wide check (scans every tracked text file, not just the staged diff)
sh scripts/validate.sh
```

What the commands produce, stated precisely:

- **Command 1 prints candidate matches for a human to read; it is not a pass/fail gate.** Documentation that
  *names* a home-directory root (`/home/…`, `/Users/…`, `/root/.…`) matches it, as does a synthetic test
  fixture such as `/home/example`. What must not appear in the output is a path containing a real username.
  Every match in a commit here has been read for that reason, and the bracketed first characters in the
  pattern keep it from matching its own text and nothing else.
- **Commands 2 and 4 print nothing** unless they match, in which case they print `REJECT`.
- **Command 3 is informational:** check that nothing listed is a weight, a log or an unexplained large file.
- **Command 5 (`scripts/validate.py` check [7]) is the gate**: its path pattern requires a trailing `/`, so it
  matches a real path rather than prose that names a root, and it scans every tracked text file.

`sh scripts/validate.sh` is the check that also catches a personal path committed **earlier**, because it
scans every tracked text file rather than the staged diff. It additionally checks dataset structure,
manifest consistency and the published figures. Run it before every commit and expect the extraction
regression tests to pass.

What these checks do **not** do — read `docs/evidence-inventory.md` §6.1 before describing any of them as a
guarantee:

- commands 1–4 see only the staged diff; a path already in an earlier commit is invisible to them;
- the path patterns cover `/home/…`, `/Users/…` and `/root/.…`. A home directory elsewhere
  (`/export/home/…`, `/var/home/…`) is not matched by them, and neither form checks for a local username
  that appears outside an absolute path;
- the hostname check resolves `hostname` at run time, so it only catches this machine's name, and matches
  nothing if `hostname` returns empty;
- nothing inspects commit messages, author metadata, or Git history;
- `.gitignore` prevents weight and raw-log extensions from being added by accident. It is not a scan.

What is allowed and what is not:

- **Not allowed:** an absolute path that begins under a user's home directory (any path whose first
  component is a home-directory root), a hostname, a machine UUID or serial, a credential, a raw log, a
  transcript, model weights.
- **Allowed:** tilde-relative paths that describe where a tool keeps its state, e.g.
  `~/.local/share/strata/…` and `~/.local/state/strata/…`. They locate the software for a reader
  without naming a user.
- **Allowed:** the public GitHub account name that owns this repository. It is public by nature of the
  repository existing. It is not the local username and must not be used as one.

## Licensing

This repository is dual-licensed, and the split is deliberate:

- **Software** — scripts, the `extract.awk` extractors committed beside the datasets, parsers, validators,
  schemas, CI definitions, and any program code added by later phases — **MIT**, in `LICENSE`.
- **Research record** — documentation, `manifest.json` metadata, `.tsv` datasets, and the tables and analyses
  built from them — **CC BY 4.0**, in `LICENSE.docs`, whose legal text is incorporated by reference.

When you contribute:

1. Contribute only material you have the right to contribute under these terms. If a measurement came from
   someone else's machine, you are licensing your own record of it, not their data.
2. Code you contribute is offered under the MIT terms; documentation and measurements under CC BY 4.0.
3. Never contribute raw engine logs, agent transcripts, model weights, or code you did not write or are not
   licensed to share. `SECURITY.md` and `results/README.md` explain what is excluded and why.
4. Do not relicense existing files and do not add a third license file. If a future component genuinely needs
   different terms, open an issue before writing it.
5. Keep the evidence-class label (`docs/methodology.md` §1) attached to any number you reuse. Stripping the
   label is the most common way this data gets misused.

## Pull requests

- One experiment or one tool change per pull request.
- Show the commands you ran and their output.
- State what you could not verify.
- Do not reformat unrelated files.

## Tooling standards

- Python 3.14 and shell for orchestration; Go is welcome for a reusable CLI when it earns its keep.
- No dependency is added without a reason recorded in the pull request.
- Parsers, validators and calculations are tested. Tests run without a GPU.
- Scripts must be safe to re-run and must not write outside the paths they are given.
- No hardcoded personal filesystem paths.
