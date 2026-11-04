# Pi: how the evaluated coding agent was configured

Pi is a third-party coding agent. This repository is not affiliated with, endorsed by, or sponsored by
its authors, and this project does not claim Pi is good or bad at software engineering. It records what
was run and what was verified.

## Configuration used for the evaluation

Sanitized from the local Pi configuration; secret values are not published and none were found in the
profile fields inspected.

| Item | Value |
| --- | --- |
| Provider | `strata` (local), base URL `http://127.0.0.1:8080/v1`, OpenAI-compatible completions API |
| Model served to the agent | `qwen3.8-flash-next-iq3_xxs` — the same engine, model and GPU that this project benchmarks |
| Context window advertised | 262 144 tokens |
| Sampling parameters | temperature 0.6, top_p 0.95, top_k 20, min_p 0.05 |
| Compatibility flags | no developer role, no reasoning-effort parameter, Qwen chat template for thinking |
| Reasoning level used | medium |
| Cache warming | off |
| Compaction | enabled, with model-specific token reserves |
| Extra packages | a subagent/todo/question tool package and a superpowers skill collection |

**The recursion problem, stated plainly.** The agent under evaluation and the inference system under
measurement were the same process chain. A recorded `nvidia-smi` reading from 2026-11-03T16:07:06Z shows
the engine holding **7 485 MiB of the 8 188 MiB** device at **100 %** utilization while the audit itself was
being served by it (full output in `docs/hardware.md`, "Recorded outputs"). Any timing taken in that state
is invalid, which is why the Go benchmark suite was not re-run — see
`docs/evidence-inventory.md` §5.1. A coding-agent evaluation that also *is* the inference load cannot
measure that inference load.

## Session record (metadata only)

| Field | Value |
| --- | --- |
| Session window | 2026-11-02T18:36:43Z → 2026-11-03T01:44:28Z |
| Records | 540 (533 messages, 2 custom messages, 1 session start, 2 compactions, 1 model change, 1 thinking-level change) |
| Tool calls | bash 144, edit 67, read 24, write 20, todo 14, subagent 3 |
| Model | `strata/qwen3.8-flash-next-iq3_xxs` |
| Transcript | private; not published, not quoted |

Message and tool counts describe effort spent. They are not a quality measure and are not used as one
anywhere in this repository.

Six shorter Pi sessions (14:51:37Z, 14:57:26Z, 15:04:28Z, 15:13:21Z, 15:20:32Z and 16:32:28Z) begin within
a minute or two of six engine restarts at 18:49, 18:57, 19:04, 19:13, 19:20 and 20:31 local time. Those six
files contain **no tool calls at all** (source **S12** in `docs/evidence-inventory.md`), so the alignment is
a timestamp coincidence and is **not** evidence that these sessions drove the sweep. What the sweep is
described as — *agent-session-driven* — rests on a different and weaker observation: the requests in it came
from interactive work, which is exactly why their prompt content is private and why they were not a controlled
benchmark.

## What the Go exercise asked for

Recorded in the working ledger the agent itself maintained inside the project (an **A** artifact,
quoted because it is the task record, not because it is verified):

1. create a Go token-bucket rate limiter (standard library only) with `Allow`, `Wait`, `WaitN`,
   `Reserve`/`Cancel`, a pluggable clock, context cancellation and deterministic tests;
2. audit it, with every finding first demonstrated by a failing test;
3. an adversarial second pass on two specific targets: whether reading the clock outside the mutex can
   produce incorrect replenishment, time regression or over-permission, and whether
   `BenchmarkAllow1000Callers` reported a correct per-call cost.

The second pass **rejected** the clock-ordering defect hypothesis after writing six forced-inversion
tests that all passed against the unmodified code, and **confirmed** the benchmark reporting defect.
Those are the agent's own claims (**A**); the tests exist in `clockorder_test.go` and the suite passes
(**I** that the suite passes), but the reasoning was not independently reproduced by this project.

## What this evaluation does not establish

- It is one task, in one language, in one domain, with the evaluated agent's own tests as the only
  correctness oracle.
- Two factual errors were found in the agent's own report (conflicts C5 and C6 in
  `docs/evidence-inventory.md`): a wrong CPU core count, and a headline benchmark figure taken from the
  denied-path benchmark rather than the hot path. They are recorded because they are the clearest
  available demonstration of why agent-reported numbers need independent re-measurement.
- 100% statement coverage of the agent's own code, measured by the agent's own tests, is not evidence
  of correctness.
- No hidden test, no externally authored fixture, and no independent oracle existed for this run.
  Phase 3 exists to add them.

## What Phase 3 will change

- Tasks with pinned baseline revisions, including seeded-defect repair tasks.
- An independent test suite written by this project, not derived from the evaluated agent's output.
- Hidden fixtures withheld from the task statement.
- Recorded exit codes, wall time, and the engine/model configuration that served the agent, as part of
  the dataset manifest.
- Explicit outcome classification: complete / incomplete / wrong-but-passing / correct-but-overfit /
  blocked / failed.
