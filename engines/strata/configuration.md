# Strata: configuration

## Two layers, and why the distinction matters

Strata is driven through two different argument layers, and conflating them is how configuration
records become wrong.

| Layer | What it holds | Where it lives |
| --- | --- | --- |
| Control layer | what the user asked for: family, model quantization, context label (`256k`), KV quant, MTP on/off, vision on/off, parallelism, port, tuning policy, and `--set` passthrough values | `launch/<profile>.choices.json`, `install/strata-<profile>.json` |
| Engine layer | the argument vector the engine process actually received | `launch/<profile>.json` → `args`, and the `engine started` line in the engine log |

`--tune skip` and `--restart` are control-layer instructions and never appear in the engine vector.
`--spec`, `--kv`, `--kv-resident`, `--vram-reserve-mib`, `--prefill`, `--adapt-async`, `--pcie-frac`,
`--mtp` and `--max-context` do appear in it. A configuration claim written from the control layer alone
is not a record of what the engine ran.

## The engine vector as recorded

Captured from the launch profile in force at audit (2026-11-02 20:54 local, still running at the time
of the Phase 0 audit), with install-root paths removed:

```
strata --serve
  --pack packs/iq3_xxs
  --native models/IQ3_XXS/Qwen3.8-Flash-Next-GSQ-RCO-IQ3_XXS-00001-of-00002.gguf
  --ple-gguf models/IQ3_XXS/Qwen3.8-Flash-Next-GSQ-RCO-IQ3_XXS-00002-of-00002.gguf
  --expert-profile expert-profile.bin
  --expert-cache auto
  --max-context 262144
  --kv q4_0
  --kv-resident 20480
  --vram-reserve-mib 512
  --prefill auto
  --adapt-async 1
  --pcie-frac 0.20
  --spec 6
```

The profile also records `model_name` `qwen3.8-flash-next-iq3_xxs`, host `127.0.0.1`, port 8080,
`mtp: false`, and a separate `args_written` list from an earlier generation of the profile — the
difference between `args` and `args_written` is how the record itself shows the configuration changed
over time.

Control-layer choices for the same profile: `family qwen`, `model IQ3_XXS`, `context 262144`, `kv q4_0`,
`mtp off`, `vision off`, `parallel 1`, `tune skip`, `port 8080`, `access local`, and the `--set` values
`kv-resident=20480`, `vram-reserve-mib=512`, `prefill=auto`, `adapt-async=1`, `pcie-frac=0.20`,
`spec=6`.

Two things the brief's historical command line contained that the engine vector does **not**:
`--tune skip` (control layer) and `--restart` (control layer). One thing earlier sessions had that the
current one does not: `--vision`. See conflict C3 in `docs/evidence-inventory.md`.

## Argument meanings, as the engine documents them

Quoted from the engine's own help output, which appears in the **private** engine log as the usage dump the
engine printed when it rejected the five unknown arguments on 2026-11-02. **These quotes are not in any
published dataset** (class **H**, provenance **S1** private log; gap **G12**): the diagnostics whitelist
deliberately selects engine decision lines, not usage text, so a reader cannot check these strings against
published data. They are the engine's words, not this project's paraphrase, and they are version-specific
(0.1.55). Publishing the usage dump as its own artifact is Phase 2 work.

| Argument | Engine's own description (abridged where the help wraps across lines) |
| --- | --- |
| `--max-context N` | "KV/state capacity (default 4096)" |
| `--kv q4_0` | "4-bit K/V after a Hadamard rotation (PR #21): half of int8's memory" |
| `--kv fp16\|int8` | "int8 codes + fp16 scale per 64 values, half the [memory]" |
| `--kv k8v4` | "hybrid: INT8 K (exact attention scores) + rotated Q4_0 V, 816 B/cell" |
| `--kv-resident N` | "KV streaming: keep N cells of each QSA layer in VRAM (min 20480) and the [rest elsewhere]" — **note the contradiction with published data**: one 0.1.55 launch (15:17:33) ran `--kv-resident 8192`, below the stated minimum, and served requests |
| `--expert-cache N` | "R4: keep N expert blobs resident in VRAM and compute their rows on the [GPU]" |
| `--prefill CHUNK` | "batched prompt processing in chunks of CHUNK tokens (needs --native); auto = [engine chooses]" |
| `--spec N` | "the MTP drafter's verify window: how many tokens it proposes per check (setup writes 4; --suffix-draft lets it grow by 2, up to 8, where a repeat is likely)" |
| `--spec-min-p P` | "how sure the draft layer must be to extend a verify window by another guess (setup writes 0.5; --calibrate measures it on this PC)" |
| `--mtp PATH` | draft-layer path; `--mtp-max-t M` caps its windows, `--mtp-q4 all\|proj\|head` opts into 4-bit copies of the draft projections |
| `--adapt-async 0\|1` | "--serve with the resident RAM mode or the arena (one GPU): the adaptive [tier]" |
| `--conversation-cache-mib N` | "--serve: RAM budget for parked conversations (default: sized from the free RAM, up to 8192; 0 = off)" |
| `--suffix-draft N` | "prompt lookup: draft from an earlier repeat of the last N+ tokens of context when it pays (default 3; 0 = MTP only)" |

Two engine-internal behaviours worth knowing, both observed in the log rather than documented:

- The prompt path **borrows** resident-expert cache slots: `the prompt path borrows 1107 CUDA0 cache
  slots (1.82 GiB)` in one session, `358 … (0.59 GiB)` in the MTP session. Prefill and expert residency
  compete for the same VRAM.
- The automatic prompt chunk is chosen from the cache size, so anything that shrinks the cache shrinks
  the chunk: `prompt chunk auto: 2816 tokens, a 227-slot ring` with 1257 slots, `512 tokens, a 8-slot
  ring` with 504 slots.

## Configuration history recorded locally

Two profile families exist, and they are not the same profile. The `install/strata-iq3_xxs.*` files are
an older profile whose engine vector carries `--spec 4` and no `--adapt-async`, `--pcie-frac`,
`--kv-resident` or `--vram-reserve-mib`. The `launch/iq3_xxs-256k.*` profile is the one the measured
sessions used. Quoting the wrong family is how a configuration record becomes wrong.

`install/strata-iq3_xxs.json` family (control-layer profile, engine args identical in all four files
except where noted):

| File (relative) | Modified | `mtp` flag | `user_args` |
| --- | --- | --- | --- |
| `strata-iq3_xxs.json.bak` | 2026-11-02 18:42 | `false` | — |
| `strata-iq3_xxs.json.before-mtp` | 2026-11-02 20:06 | **`true`** | — |
| `strata-iq3_xxs.json.pre-rollback.bak` | 2026-11-02 20:30 | `true` | `--mtp <data root>/mtp/rt` |
| `strata-iq3_xxs.json` | 2026-11-02 20:54 | `false` | `[]` |

The instructive part: at 20:06 the profile already had `mtp: true` while the engine vector had no
`--mtp`, and the engine sessions at 20:03 and 20:06 logged no draft-layer load. A control-layer intent
flag is not evidence that the engine did the thing. The engine vector in the `engine started` log line
is the only authoritative record.

`launch/iq3_xxs-256k.json` family: the current profile has `mtp: false` and the engine vector listed
above. The 2026-11-01 backup profile carried `--vision`, `--spec-min-p`, `--prompt-cache-every` and
`--prompt-cache-tail`, none of which are in the current one — a real configuration change over time,
recorded because the engine keeps backups.

These profile files are private (they contain absolute paths). No secret material was found in the
profiles inspected: `choices.json` carries a `key` field whose value is the hash of an empty input
(`e3b0c44298fc1c14`) together with `no_key: false`, i.e. no API key. Only argument differences are
published here. The authoritative published record is
`results/strata/2026-11-02-config-sweep/engine-metrics.tsv`.

## What this configuration is not

It is not a tuned configuration. The engine's automatic tuner failed on this machine (see
`tuning.md`), and `tune skip` is the consequence. It is one person's working setup on one 8 GB laptop
GPU, recorded so that measurements made with it can be attributed to it.
