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
`docs/evidence-inventory.md` §5 item 1. A coding-agent evaluation that also *is* the inference load cannot
measure that inference load.

## Who verified what

Every claim in this case study belongs to exactly one of four categories, and the categories are not
interchangeable evidence. The full claim-by-claim table with the commands actually run is
`docs/evidence-inventory.md` §3 E4; this is the classification.

### 1. Claims reported by the evaluated agent

The agent's own README and commit messages. Recorded as class **A** — evidence that the agent said it — and
nothing more:

- six production defects found and fixed in the rate limiter, and the RED→GREEN cycle that allegedly
  demonstrated each one first;
- the clock-ordering hypothesis (reading the clock outside the mutex causing incorrect replenishment, time
  regression or over-permission) rejected after six forced-inversion tests, and the benchmark-reporting
  hypothesis confirmed;
- the benchmark metric correction (`ns/call` had been inflated by `b.N`);
- mutation-testing observations M-A, M-B and M-C;
- all benchmark timings (37–67 ns/op `Allow`, 44.81 ns/op `Wait`, 94.30 ns/op `ReserveCancel`,
  168.6–184.0 ns/call for the 1 000-caller benchmark).

Two of these were shown to be **wrong as reported**: the CPU core count (C6) and the headline `Allow`
figure, which was the denied-path number (C5). That is the strongest available evidence in this case study
about how agent-reported numbers must be treated.

### 2. Mechanical properties rechecked by this project

Reproduced on this machine on 2026-11-03 with go1.27.3 at deliberately lower repetition counts than the
agent used, all class **I**:

| Rechecked | Result here | Agent's own figure |
| --- | --- | --- |
| `func Test` / `func Example` / `func Benchmark` counts | 60 / 4 / 15 | 60 / 4 / 15 |
| `go test -race` | clean at `-count=3`, `GOMAXPROCS=4`, 9.2 s | clean at `-count=10` |
| `go test -shuffle=on` | clean at `-count=5`, 8.9 s | clean at `-count=20` |
| Statement coverage of `ratelimit.go` | 100.0 % | 100.0 % |
| `gofmt -l`, `go vet` | no output, exit 0 | clean |
| `staticcheck`, `golangci-lint` | 0 / 0 issues | 0 / 0 issues |
| Existence of the six-defect record and the seven corresponding tests in `audit_test.go` | present | six defects |

"Confirmed at reduced count" means exactly that: the same command family ran clean here with fewer
repetitions, on a machine that was concurrently serving inference. It does not extend to anything that
depends on timing.

### 3. Claims supported by independently designed correctness tests

**None.** This is the category with nothing in it, and it is the reason gap G6 is open.

Every test in the Go project was written by the agent under evaluation. No test written by this project,
no hidden fixture, no externally prepared input and no seeded-defect repair task exists for this exercise.
The clock-ordering tests in `clockorder_test.go` were written by the same agent whose reasoning was being
audited, so a passing run of them corroborates that the tests pass — it does not corroborate the
conclusion the agent drew from them. The only independent findings this project produced in the exercise
are the two reporting errors in category 1 (C5, C6), and those are errors in the agent's *report*, not
verdicts on the limiter's behaviour.

Until category 3 has content in it, no statement in this case study may be read as evidence that the rate
limiter is correct.

### 4. Claims that remain unverified, or whose artifacts are unavailable

- `govulncheck` — not re-run (needs a network fetch); gap G9.
- All benchmark timings — deliberately not re-run, because this audit session is itself the inference load
  on the device under study.
- The RED failures behind each of the six defects — the runs were not retained; there is no pinned
  baseline revision of the pre-fix code.
- Mutation testing M-A / M-B / M-C — performed by the agent, no artifact retained.
- The clock-ordering mechanism — the tests exist and pass; the reasoning was not independently reproduced.
- The benchmark-metric fix itself — not re-run.
- The Go source as a whole — not published here at all (gap G2, reference-only), so a reader cannot check
  any of the above from this repository.

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
  Phase 3 exists to add them. The "who verified what" section above states plainly that the
  independently-tested category is currently empty.

## What Phase 3 will change

- Tasks with pinned baseline revisions, including seeded-defect repair tasks.
- An independent test suite written by this project, not derived from the evaluated agent's output.
- Hidden fixtures withheld from the task statement.
- Recorded exit codes, wall time, and the engine/model configuration that served the agent, as part of
  the dataset manifest.
- Explicit outcome classification: complete / incomplete / wrong-but-passing / correct-but-overfit /
  blocked / failed.
