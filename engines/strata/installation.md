# Strata: installation notes

**Honesty note first.** This project did not install Strata and did not re-run its installer. What is
documented here is (a) the install layout observed on the owner's machine during the Phase 0 audit and
(b) the verification steps a reader can run to confirm their own install matches the environment the
published results were produced in. Any step this project did not perform is labelled as such.

Strata is a third-party inference engine. This repository is not affiliated with, endorsed by, or
sponsored by its authors.

## What a working install looked like at audit

Observed layout (paths shortened to relative form; the install root is the reader's own):

```
<install root>/
  components/
    engine/0.1.54-linux-x86_64-cuda-cuda13/
    engine/0.1.55-linux-x86_64-cuda-cuda13/
    control/0.1.55/            active.json -> {"version":"0.1.55","folder":"0.1.55","sha256":"50783d2f…"}
    control/0.1.55/data/expert-profile.bin
    control/0.1.55/data/quant_quality/v1/
  install/
    run-iq3_xxs.sh             launch helper
    strata-iq3_xxs.json        launch profile, with .bak / .before-mtp / .pre-rollback.bak history
    third_party/llama.cpp/     engine dependency, present as a component
  Strata-data/
    packs/iq3_xxs/             derived pack: dense.bin 1 538 035 200 B, index.txt, tokenizer/
    packs/iq3_s/               a second quantization pack, present but not measured
    models/IQ3_XXS/            the two GGUF shards
    models/IQ3_S/
    models/mmproj-Qwen3.8-Flash-Next-BF16.gguf     vision projector
    mtp/                       draft layer: mtp-q2_0.gguf 889 017 216 B, rt/, manifest with per-tensor sha256
  terminal/0.1.54/data/expert-profile.bin
```

State directory (kept entirely out of the repository):

```
~/.local/state/strata/
  launch/     per-profile engine log, launch json, choices json, tune result
  runtime/    sockets, ready record, server log
  procs/      per-process records
  tuning/     recheck record
```

## Environment the published results were produced in

| Item | Value |
| --- | --- |
| Engine | 0.1.55, build `99866a47a2b8+cuda13.0`, platform `linux-x86_64`, variant `cuda13` |
| Previous engine in the same log | 0.1.54, build `8c1aea4bca1b+cuda13.0` |
| Backend | CUDA; driver 595.99.02 (open kernel module), CUDA 13.2 reported by `nvidia-smi` |
| GPU | RTX 4060 Laptop, 8188 MiB, compute capability 8.9 |
| CPU | i7-13620H, 10 physical cores / 16 logical, **no AVX-512** |
| OS | Ubuntu 26.04.1 LTS, kernel 7.0.0-38-generic |
| Model | Qwen3.8-Flash-Next-GSQ-RCO-IQ3_XXS, two shards, 47 039 860 096 B + 28 800 138 432 B |
| Model source | `ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF` on Hugging Face |
| Derived pack tool | `tools/iq_pack.py`, schema 1 |

Results produced on 0.1.54 are **not** comparable to results produced on 0.1.55; the engine changed at
2026-10-31T21:13:54Z and the change is recorded locally with build ids and manifest hashes.

## Verifying your own environment matches

```sh
# engine identity (read the component records rather than guessing from a CLI version string)
cat <install root>/components/control/active.json
ls <install root>/components/engine/

# driver and device
nvidia-smi --query-gpu=name,driver_version,memory.total,compute_cap --format=csv

# model integrity: list the upstream LFS oids for the shards you downloaded
curl -s "https://huggingface.co/api/models/ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF/tree/main/IQ3_XXS?recursive=true" \
  | jq -r '.[] | select(.path|endswith(".gguf")) | "\(.path)  \(.size)  \(.lfs.oid)"'

# then compare with the marker the engine wrote next to your local shard file
cat <install root>/Strata-data/models/IQ3_XXS/*.done
```

Output of the upstream query, captured on 2026-11-03 and recorded in
`results/strata/2026-11-02-config-sweep/manifest.json`:

```
IQ3_XXS/...-00001-of-00002.gguf  47039860096  219ea929900dfa9ef091f3aa473fdba6874b65fcb36526d7d851ac9e95856d15
IQ3_XXS/...-00002-of-00002.gguf  28800138432  316b46f3a2dbd68c900f43136ab9449f9dcc3725dfd8c794847c204bc161e113
```

The local `.done` markers on the owner's machine contain exactly these two hashes. Note what that
proves and what it does not: it proves the engine's downloader recorded those hashes and that they
match upstream. It is not a full-file hash computed independently by this project, which would require
reading 75.8 GB.

## Steps this project did **not** perform

- It did not install Strata, download the model, or run the pack conversion.
- It did not verify the installer's behaviour on a fresh machine.
- It did not test whether 0.1.55 is currently the latest release, or whether this configuration works on
  other GPUs.

Do not follow this file as an installation guide. Follow the engine's own documentation for
installation; use this file to check that your environment is comparable to the one the published
measurements came from.

## Model files are never committed

Model weights are ~75.8 GB for this model alone. They are referenced by name, byte size and sha256
everywhere in this repository, and are matched by `.gitignore` rules so that they cannot be committed
by accident.
