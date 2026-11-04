# Evidence inventory

Phase 0 audit, performed 2026-11-03. Every item below was inspected on the local machine during the
audit; nothing in this file is inferred from the project brief alone. Evidence classes are defined in
`docs/methodology.md` (§1).

Audit commands used: read-only inspection of `~/.local/state/strata/`, `~/.local/share/strata/`,
`~/.pi/agent/`, `/tmp/pi-coding-benchmark`, `/tmp/pi-kv-test`, plus `lscpu`, `free`,
`/proc/meminfo`, `/proc/cpuinfo`, `lsblk`, `df`, `nvidia-smi`, `/sys/class/dmi/id/*`,
`/sys/bus/pci/devices/.../current_link_*`, `git log`, `sha256sum`, the Hugging Face model API, and
re-runs of the Go verification commands.

---

## 1. Repository state

| Item | Finding | Class |
| --- | --- | --- |
| Local directory `local-llm-agent-lab` | **empty and not a git repository** at audit start, despite the project brief describing an existing clone | V |
| GitHub repository `akynte/local-llm-agent-lab` | exists, public, default branch `main`, **zero commits**, size 0, created 2026-11-03T08:56:36Z, **no license**, no description, no topics, Pages disabled | V |
| Action taken | cloned the empty repository into the existing directory; `origin` points at the GitHub remote; no push performed | V |
| Existing content to preserve | none — there was no history, no files, no license to preserve | V |

Consequence: the architecture question is "what should this repository contain", not "how do we fit
into an existing layout". The licensing decision is open (see §6, gap G1).

## 2. Source evidence index

| # | Artifact | Location (local) | Size / identity | Contains | Published? |
| --- | --- | --- | --- | --- | --- |
| S1 | Strata engine log, `iq3_xxs-256k` profile | `~/.local/state/strata/launch/iq3_xxs-256k.engine.log` | measured seven times during the audit: 15 426 lines / 1 948 084 bytes (sha256 `98ce435b…c765ae`), then 16 105 lines / 2 042 926 bytes, then 15 693 lines / 1 983 754 bytes, then 17 233 lines / 2 188 804 bytes, then 18 689 lines / 2 383 202 bytes, then 19 664 lines / 2 513 242 bytes (sha256 `034545f8…b08b`, 2026-11-03T20:29:42Z), then 20 648 lines / 2 644 061 bytes (sha256 `147bb441…`, 2026-11-04T00:48:21Z). The size did **not** change monotonically (see C11) | engine start lines with full arguments, engine-internal sizing decisions, per-request prefill/decode metric lines, **and private prompt/completion content interleaved** | **No.** Only selected metric lines are published, sanitized, from three line windows: 1–13420 (S15 diagnostics census), 9470–12626 and 12627–13420 (the two request datasets), each produced by a committed `extract.awk` |
| S2 | Strata server log, same profile | `~/.local/state/strata/runtime/launch-iq3_xxs-256k.server.log` | 77 593 lines | serving-layer records; no `prompt_per_second`-style JSON fields were found | No |
| S3 | Launch profile (control layer) | `~/.local/state/strata/launch/iq3_xxs-256k.json` | 1 762 bytes, modified 2026-11-02 20:54 | the exact engine argument list currently in force, plus `model_name`, port, host, `mtp: false` | Sanitized copy in `engines/strata/configuration.md` |
| S4 | Launch choices | `~/.local/state/strata/launch/iq3_xxs-256k.choices.json` | 550 bytes | `context 262144`, `kv q4_0`, `model IQ3_XXS`, `mtp off`, `vision off`, `parallel 1`, `tune skip`, port 8080, the `--set` values | Sanitized copy |
| S5 | Historical launch profiles | `iq3_xxs-256k.json.bak-imagefix-20261101-2015`, `strata-iq3_xxs.json.bak`, `.before-mtp`, `.pre-rollback.bak` in `~/.local/share/strata/install/` | 1 553–2 377 bytes each | the MTP-enabled and pre-rollback configurations, i.e. the change history | Sanitized summary only |
| S6 | Engine component records | `~/.local/share/strata/components/{engine,control}/…`, `~/.local/share/strata/tuning/recheck.json` | 0.1.54 and 0.1.55 engine directories; `active.json` version 0.1.55 | version, build id, manifest sha256, the recorded 0.1.54 → 0.1.55 engine change at 2026-10-31T21:13:54Z | Version and build ids published; binary paths not published |
| S7 | Model shards | `~/.local/share/strata/Strata-data/models/IQ3_XXS/` | 47 039 860 096 B + 28 800 138 432 B; `.done` markers hold sha256 | weights | **Never.** Name, size and sha256 only |
| S8 | MTP draft layer | `~/.local/share/strata/Strata-data/mtp/` | `mtp-q2_0.gguf` 889 017 216 B, `rt/` 823 MiB unpacked, manifest with per-tensor sha256 | draft-layer weights and manifest | Never committed; manifest facts referenced |
| S9 | Tuning attempt record | `~/.local/state/strata/launch/iq3_xxs-256k.tune.json` | 2 279 bytes | a **failed** automatic tuning run: `outcome base_failed`, `reason_code start_failed`, message stating the GPU could not be opened because it is in use by the loaded model | Sanitized finding, quoted in `engines/strata/troubleshooting.md` |
| S10 | Pi model/provider configuration | `~/.pi/agent/models.json`, `settings.json` | provider `strata`, base URL `http://127.0.0.1:8080/v1`, model id `qwen3.8-flash-next-iq3_xxs`, context window 262144, sampling params | the coding-agent evaluation target configuration | Sanitized copy (API key value not published) |
| S11 | Pi session transcript of the coding evaluation | `~/.pi/agent/sessions/--home-<user>--/2026-11-02T18-36-43-535Z_01a19d8c….jsonl` (session directory names encode the workspace path and therefore the local username; the username is not published here) | 2 265 602 bytes, 540 records: 1 session, 533 messages, 2 compactions, 2 custom messages, 1 model change, 1 thinking-level change; tool calls: bash 144, edit 67, read 24, write 20, todo 14, subagent 3; model `strata/qwen3.8-flash-next-iq3_xxs`; 2026-11-02T18:36:43Z → 2026-11-03T01:44:28Z | the full evaluation transcript | **No.** Only the metadata above is published |
| S12 | Short Pi sessions around the 2026-11-02 engine restarts | same session directory, **six** files: 14:51:37Z, 14:57:26Z, 15:04:28Z, 15:13:21Z, 15:20:32Z, 16:32:28Z | 6 records each (1 session, 1 model change, 1 thinking-level change, 3 messages), 69–89 KB each | sessions whose start times align with the engine restarts at 18:49, 18:57, 19:04, 19:13, 19:20 and 20:31 local. **They contain no tool-call records at all**, so the alignment is a timestamp coincidence, not evidence that these sessions drove the sweep | No |
| S13 | Go rate-limiter project | `/tmp/pi-coding-benchmark` | 13 `.go` files, 3 782 lines, 10 commits on `master`, no remote, **no LICENSE**, module `example.com/pibench/ratelimit`, `go 1.27.3`, clean working tree | implementation, tests, agent-authored README, `.pi/ledger/TASK.md` | **Not imported yet** (Phase 3 decision, see gap G2) |
| S14 | Long-context retrieval fixture | `/tmp/pi-kv-test/` | `prompt.txt` 721 821 B, 6 506 lines, ASCII, sha256 `ec0cb8cb…e491`; `expected.json` 63 B, sha256 `ed40c5a7…1a80`; `output.txt` 59 B, sha256 `0f0bf8f3…43cd` — hashes, byte counts, line count and the three key positions (653, 3 254, 5 855) re-verified by `sha256sum`/`grep -n` on 2026-11-03 | a synthetic 6 500-record document with three embedded keys, plus the expected and returned answers, which match all three keys | Fixture **not** published yet; hashes published (gap G3) |
| S15 | Published engine diagnostics census, derived from S1 lines 1–13420 | `results/strata/2026-10-30-11-02-engine-diagnostics/` | 1 941 records (1 942 TSV lines including the header): 57 `engine_start`, 1 776 `event`, 108 `continuation`; 308 718 bytes; zero personal absolute paths | every engine launch in the window with its full sanitized argument vector, plus the engine's start-up diagnostics: memory guard, PCIe probe, AVX-512 absence, huge-page fallback, expert-cache sizing, prompt-chunk choice, MTP load/refusal lines, unknown-argument rejections, vision warnings, verify-window sizes | **Yes.** This is the published backing for the engine-internal lines quoted elsewhere in this repository. The extraction program is committed beside it as `extract.awk` |
| S16 | Continuation session of the same audit, 2026-11-03 | `~/.pi/agent/sessions/--home-<user>-local-llm-agent-lab--/2026-11-03T09-00-50-278Z_01a1a0a3….jsonl` | counted 2026-11-03T16:54Z: 810 records, 3 075 849 bytes, 4 compactions; tool calls bash 251, edit 105, write 26, read 20, todo 10, subagent 2; **still growing while this audit runs** | the correction pass, the diagnostics census, the re-verifications of 2026-11-03 | **No.** Metadata only |

Counted 2026-11-03T16:54Z, the two session directories that cover 2026-11-01 → 2026-11-03 hold **14
session files, 1 901 records, 8 332 860 bytes**. Tool calls across them: bash 598, edit 187, write 50,
read 49, todo 30, subagent 5, web_fetch 7, ask_user_question 6, web_search 3, tool_search 3, plus two
one-off MCP listing calls. Session directory names encode the workspace path and therefore the local
username; they appear here as `--home-<user>--`.

## 3. Experiments and claims

### E1 — Strata configuration sweep, 2026-11-02 (11 engine sessions)

- **Class:** H (captured from log S1), with the published extract being a verbatim selection.
- **Evidence available:** 11 `engine started` lines with complete argument lists; per-session expert
  cache slot counts and prompt chunk sizes; 30 request records; published as
  `results/strata/2026-11-02-config-sweep/engine-metrics.tsv` with `manifest.json`.
- **Reproducibility:** the extraction is reproducible from the private log by the published awk
  program; re-running the *measurements* requires the same GPU, model and engine and is a Phase 2
  controlled re-run, not a re-extraction.
- **Publication safety:** metric lines contain no prompt or completion text; the published TSV was
  re-checked and contains zero occurrences of a personal absolute path.
- **Confidence:** high that the numbers are what the engine reported for those sessions; **low**
  that they isolate any single cause (see §4 conflicts C4 and C12).
- **Related dataset:** `results/strata/2026-11-02-mtp-attempts/` covers 09:33–15:17 local on the same
  day, 24 further sessions and 183 request records, in a **different configuration family**
  (`int8`/`k8v4` KV, `--vision` on in 20 of 24 sessions, `--spec 4`).
- **Follow-up:** controlled re-run with 3+ repetitions per configuration and sampled VRAM/RAM.

### E2 — MTP speculative decoding attempts, 2026-11-02

- **Class:** H for the recorded numbers; **X** for any causal explanation, in either direction.
- **Evidence available.** The published census (S15) shows **25 of 57 launches requested `--mtp`**, and
  an outcome was logged for 19 of them:
  - **10 refusals** — `mtp: the 512 experts do not fit in VRAM`, reporting **246 MiB free eight times**
    (2026-10-30 19:22, 19:28, 23:48, 23:49 on 0.1.54; 2026-11-02 09:33, 09:38, 09:40, 09:48 on 0.1.55)
    and **247 MiB free twice** (2026-11-02 14:41, 14:42). Both variants are in the record.
  - **1 dense-weights allocation failure** — `mtp: dense weights allocation failed (out of memory),
    requested 110 MiB, CUDA0 free 57 MiB` (2026-11-02 11:29:40). A second failure mode, invisible if only
    the refusal line is counted.
  - **8 successful draft loads**: 834, 834, 834 MiB and 835 MiB on 0.1.54-era launches (2026-10-30/31),
    after which the resident expert cache and automatic chunk were 463/768, 463/768 and 553/256;
    835 MiB at 10:00:17, 11:31:51 and 11:34:58 (cache 616/768, 588/768, 536/512) and 822 MiB at 20:31:11
    (cache 504/512) on 0.1.55.
  - **6 launches requested MTP with no logged MTP outcome.** Five never ran (unknown arguments); one
    (11:00:09) started and logged no MTP line. Absence of a line is not proof the draft layer was absent.
  - The evening 20:31:11 load is the one inside the published sweep: expert cache 504 slots (against
    **1107** in the three no-MTP launches at the same 768 MiB reserve), prompt chunk 512 tokens (against
    2048), one 12 719-token cold prefill at 245.8 tok/s, 10 951 tokens generated at 26.0 tok/s, against
    five no-MTP sessions with the same cold prompt at 529.9–537.5 tok/s and decode 26.5–29.2 tok/s.
- **The counter-example.** In the morning family, an MTP session (616 expert slots, 768-token chunk,
  `int8` KV, `--spec 4`) measured **388.7–390.7 tok/s** on a 16 387-token cold prompt repeated three
  times, while a no-MTP session (1039 slots, 1536-token chunk, `int8` KV, `--spec 4`) measured
  **376.9–378.8 tok/s** at 16 991 / 16 993 tokens. The **direction** of the difference is the reverse of
  the evening pair's: there, the MTP run was slower; here the MTP run was faster.
- **Acceptance data that exists:** the 11:34:58 MTP session has 141 request records, **140 of which
  completed** (the 141st, at 208 846 prompt tokens, is a partial prefill that generated nothing), with
  **124 947 of 164 954 drafts accepted (75.7%)** and 51 decode records of ≥1 000 generated tokens at
  22.6–28.6 tok/s; the 10:00:17 session reported 2 948 of 4 448 (66.3%). No no-MTP session of comparable
  size exists in the same configuration family. **Note:** draft counters also appear in no-MTP sessions
  (759/808, 864/1021, 2209/2581, 1657/2043, 1756/1972 in the evening sweep), because the engine drafts
  from prompt-suffix lookup when the MTP draft layer is absent. "No MTP" is not "no drafting".
- **Missing:** repetitions of the MTP condition inside one configuration family; peak VRAM; a
  same-session A/B; fixed prompt fixtures; acceptance-rate-normalised decode throughput.
- **Confidence:** the recorded numbers are reliable; **no isolated MTP effect can be stated in either
  direction.** See conflicts C4 and C12.
- **Follow-up:** Phase 2 harness, then a single-variable MTP A/B inside one configuration family with
  ≥3 repetitions per condition.

### E3 — Long-context retrieval probe (157 835 prompt tokens)

- **Class:** V for the fixture and the answer comparison; H for the throughput numbers.
- **Evidence available:** engine record `prompt 157835 tokens = 0 reused + 157835 read in 265625 ms
  (594.2 tok/s), 43 generated in 1515 ms (28.4 tok/s)`; fixture, expected and returned JSON all
  present on disk with hashes; the three expected values equal the three returned values exactly;
  the keys sit at lines 653, 3254 and 5855 of a 6 506-line document.
- **Reproducibility:** the fixture exists, so the probe can be re-run; the fixture generator was not
  found, so the fixture cannot currently be regenerated deterministically.
- **Publication safety:** the fixture is synthetic filler text and is safe to publish once a
  generator is written, but publishing it without a generator leaves a 722 KB blob with no provenance.
- **Confidence:** high that one retrieval request succeeded at 157 835 tokens; **no basis** for any
  wider long-context claim. n = 1, three keys, one document type, one position distribution.
- **Follow-up:** publish a generator, then a proper multi-probe suite with varied key positions and
  distractor types (Phase 3).

### E4 — Pi coding-agent evaluation, Go token-bucket rate limiter

- **Class:** A for everything the agent itself reported; **I** for the items this project re-ran.

| Agent claim (A) | Re-run by this project | Result |
| --- | --- | --- |
| 60 tests, 4 examples, 15 benchmarks | `grep -hcE '^func Test' *_test.go \| paste -sd+ \| bc`, repeated for `^func Example` and `^func Benchmark` | 60 / 4 / 15 — **confirmed (I)**, re-run 2026-11-03 with go1.27.3 on module `example.com/pibench/ratelimit`. An earlier version of this row printed the command as `grep -h '^func Test/Example/Benchmark'`, which is not a working pattern; the counts were produced by three separate greps |
| `go test -race -count=10` clean | `go test -race -count=3` (fewer repetitions, `GOMAXPROCS=4`) | ok, 9.2 s — **confirmed at reduced count (I)** |
| `go test -count=20 -shuffle=on` clean | `go test -count=5 -shuffle=on` | ok, 8.9 s — **confirmed at reduced count (I)** |
| 100.0% statement coverage of `ratelimit.go` | `go test -cover -coverprofile=/tmp/cover-verify.out` + `go tool cover -func` | 100.0% total, per-function 100.0% on the sampled tail — **confirmed (I)** |
| `gofmt -l` clean, `go vet` clean | both run | no output, exit 0 — **confirmed (I)** |
| `staticcheck` 0 issues, `golangci-lint` 0 issues | both run | 0 / 0 issues — **confirmed (I)** |
| `govulncheck` no vulnerabilities | **not re-run** (network vulnerability database fetch) | **unverified (A)** |
| Six production defects found and fixed | commit `5c78431` body lists six defect fixes; `audit_test.go` contains the seven corresponding tests | corroborated as a record (**I** that the record exists), **not** re-verified as a RED→GREEN cycle (A) |
| Clock-ordering hypothesis rejected after six forced-inversion tests | **not re-run**; tests exist in `clockorder_test.go` and the suite passes | record corroborated, mechanism **unverified (A)** |
| Benchmark metric fix (`ns/call` was inflated by `b.N`) | **not re-run** | **unverified (A)** |
| Mutation-testing evidence (M-A, M-B, M-C) | **not re-run** — mutation was performed by the agent, not recorded as an artifact | **unverified (A)** |
| Benchmark timings (37–67 ns/op Allow, 44.81 ns/op Wait, 94.30 ns/op ReserveCancel, 168.6–184.0 ns/call 1000-caller) | **deliberately not re-run in Phase 0** — see §5, self-perturbation | **unverified (A)** |

- **Missing:** a pinned baseline revision for the "before the fix" state (the pre-fix code is only
  reachable through git history, and the RED runs were not retained as artifacts); an independent
  test suite written by this project; hidden tests; a task rubric.
- **Publication safety:** the Go project has **no license** and no upstream remote; importing it
  requires a licensing decision (gap G2). It contains no unrelated proprietary content, no
  credentials and no personal paths. Its `.pi/ledger/TASK.md` and `.serena/` are tool state.
- **Follow-up:** Phase 3. Re-run the benchmarks on a quiet machine, write an independent test suite,
  and treat the agent's suite as an artifact rather than as proof.

### E5 — Coding-agent session provenance

- **Class:** V (metadata read from S11).
- **Evidence available:** session window 2026-11-02T18:36:43Z → 2026-11-03T01:44:28Z, 533 messages,
  144 bash / 67 edit / 24 read / 20 write / 14 todo / 3 subagent tool calls, 2 compactions, model
  `strata/qwen3.8-flash-next-iq3_xxs`. The Go project's 10 commits are dated 2026-11-02T23:02:41+04
  → 2026-11-03T05:42:08+04, i.e. 19:02:41Z → 01:42:08Z, inside that window.
- **Interpretation limit:** message and tool-call counts describe effort spent; they are not a
  quality measure and must not be presented as one.
- **Publication safety:** transcript content is private; only counts, times and model identity are
  published.

### E6 — Model integrity and provenance

- **Class:** V.
- **Evidence:** local download markers record sha256 `219ea929…56d15` and `316b46f3…1e113` for the
  two shards; the Hugging Face LFS oids for
  `ISTA-DASLab/Qwen3.8-Flash-Next-GSQ-RCO-GGUF` at the same two paths are identical; sizes match
  byte for byte. Upstream base model recorded by the engine's own quantization-quality data as
  `Qwen/Qwen3.8-Flash-Next`.
- **Limit:** the `.done` marker is written by the engine's downloader. It proves the engine recorded
  that hash; it is not an independent full-file hash computed by this project (computing it would
  require reading 75.8 GB).
- **Publication safety:** safe — hashes and names only.

### E7 — Host and device facts

- **Class:** V, recorded in `docs/hardware.md`, with the memory topology and power-state facts marked
  **U**.

### E8 — Engine self-tuning failure

- **Class:** V (S9). The engine's automatic tuner returned `outcome base_failed`, `code failed`,
  `reason_code start_failed`, with the message that the graphics card could not be opened by the measuring
  engine because it was in use by the loaded model. This explains why the working configuration carries
  `tune skip`: tuning was skipped after it failed, not chosen as an optimization. Recorded in
  `engines/strata/troubleshooting.md` §4 ("The automatic tuner cannot get a CUDA context while the model is
  loaded") and `engines/strata/tuning.md` §1.
- **Read command used** (private file, output not published): `jq '.result | {outcome, code, reason_code,
  gain_decode_pct, mode, seconds, runs, message}' ~/.local/state/strata/launch/iq3_xxs-256k.tune.json`,
  re-run on 2026-11-03 against the 2 279-byte record; it returned `base_failed`, `failed`, `start_failed`,
  `0.0`, `quick`, `8.6`, `1` and the in-use message above. The "6 runs / ~15 minutes" plan quoted in
  `engines/strata/tuning.md` §1 comes from the **top level** of the same record
  (`jq '{runs_planned, eta_s, minutes_left, runs_done}'` → `6`, `900`, `15`, `0`), i.e. the plan was
  published while the run produced no measured pairs. The record is **not** published; only this sanitized
  verdict is.

### E9 — ExLlamaV3, llama.cpp, ik_llama.cpp, KTransformers

- **Class:** P. No measurement, no install verification, no data. `llama.cpp` exists on disk as a
  third-party component directory of the Strata install; that is an engine dependency, not evidence
  of a llama.cpp experiment. **No comparison may be reported for these engines.**

## 4. Conflicts and discrepancies found during the audit

Evidence-class tags are given per entry in §3 rather than repeated in this table: a conflict row describes
what disagrees, not a new measurement, so its class is the class of the sources it names. Where a conflict
row asserts a number, that number is re-derived from the published datasets on 2026-11-03 and is **V**
(derived from committed TSVs) unless the row says otherwise.

These are the places where the project brief, the agent-authored records and the local evidence do
not agree. They are resolved here rather than smoothed over.

| ID | Discrepancy | Resolution |
| --- | --- | --- |
| C1 | The brief describes an existing local clone with history. The directory was empty and not a git repository; the GitHub repository exists with zero commits. | The repository was created but never pushed to or cloned. Nothing existed to preserve. Resolved by cloning the empty repository. |
| C2 | The brief gives engine version 0.1.55 as *the* engine version. | The log contains two engine generations. In the published census the 0.1.54 launches run from **2026-10-30 19:22:03 to 2026-11-01 01:03:16** local (20 launches) and the 0.1.55 launches run **from 2026-11-01 01:18:43** local (37). Both generations therefore ran on 2026-11-01, so a date alone does not identify a generation; the argument vector's engine path does. `recheck.json` records the engine change 0.1.54 → 0.1.55 at 2026-10-31T21:13:54Z (= 2026-11-01 01:13 local) with build ids `8c1aea4bca1b+cuda13.0` → `99866a47a2b8+cuda13.0`, which is consistent with the first 0.1.55 launch logged 5 min 19 s later. Results from the two generations are not comparable. |
| C3 | The brief's historical launch command is not what the engine actually received. | The brief's `--set …` and `--tune skip` / `--restart` belong to the control layer; the engine argument list recorded in S3 is the authoritative record. `--tune` never reaches the engine, and `--vision` is absent from the current session although earlier sessions ran with `--vision`. |
| C4 | "MTP made things slower" is presented as a measured regression. | The MTP session (20:31, `--vram-reserve-mib 768`) is not adjacent to a no-MTP session with the same reserve. **Five** no-MTP sessions ran the same 12 719-token cold prompt and all five used `--vram-reserve-mib 512`. **Three** no-MTP launches did use 768: 20:03:24 and 20:06:30 recorded only a 53-token warm-up (63.2 and 64.1 tok/s prefill, 25.4 and 25.5 tok/s decode), and 18:42:06 recorded a 16 992-token cold prefill at 474.5 tok/s — the only same-reserve no-MTP cold prefill in the published data, at a different prompt size. The 20:03:24 / 20:06:30 vectors differ from the MTP launch's by exactly one token, `--mtp mtp/rt`, so a same-vector MTP A/B exists in this log and yields no comparable throughput record. So `--mtp` and `--vram-reserve-mib` changed together for every comparable prompt, and the comparison is **confounded**. Within the 768 MiB reserve the cache went **1107 → 504 slots** and the chunk **2048 → 512 tokens**; 1257 slots and a 2816-token chunk belong to the 512 MiB launches and are the wrong baseline for this comparison. The logged mechanism (draft head consuming VRAM → smaller cache → smaller prompt chunk) is a hypothesis about causation (**X**), even though each individual logged quantity is fact. |
| C5 | The brief reports "Allow(): approximately 37 ns/op, zero allocations". | In the published benchmark table, `BenchmarkAllow` is 58.58 ns/op and `BenchmarkAllowDenied` is 37.98 ns/op. 37 ns/op is the denied-path figure, and the agent's own README says Allow ranged 37–67 ns/op across runs. Quoting 37 ns/op as "Allow" understates the hot-path cost. |
| C6 | The agent-authored Go README describes the CPU as "12 cores / 16 logical". | `lscpu` reports 10 physical cores and 16 logical processors, and the engine independently logged "10 physical cores, 16 logical processors". The README's hardware line is **wrong** and is a concrete example of why **A** claims need re-verification. |
| C7 | Commit `5c78431` is titled "close five audit-found defects" but its message body lists six defect fixes, and the README's audit table lists six. | The defect count of six is corroborated by the commit body and the audit table; the subject line is inaccurate. Reported as six with this note. |
| C8 | "MTP draft layer consumed approximately 822 MiB". | Four values are logged across the published census: **834 MiB ×3** and **835 MiB ×1** on 0.1.54-era launches (2026-10-30/31), **835 MiB ×3** on 2026-11-02 morning launches, and **822 MiB ×1** for the 20:31:11 evening session analysed in the sweep dataset. All are recorded; 822 MiB belongs to the evening session only. |
| C9 | "Best observed prompt processing approximately 606 tok/s". | Two lines reach that figure: **606.0 tok/s** for a 16 994-token prompt with 0 reused (a cold prefill, published in the sweep dataset) and **606.6 tok/s** for a 64 563-token prompt with 11 509 reused tokens (a warm request at private log line 14283, **outside every published window**). Only the first is a cold prefill and only the first is published; the claim is retained with that distinction because the two are not the same measurement. Note a coincidence worth flagging: the published morning dataset contains a **different** record with the same reused-token count — `2026-11-02 15:17:33`, prompt 12 603 = 11 509 reused + 1 094 read at 247.0 tok/s. The private 64 563-token line and that published 12 603-token line are different requests that happen to share a reused-token figure; a reader must not merge them. |
| C10 | The brief's Go figures "1,000-caller benchmark ≈ 184 ns per Allow()" and the README table's 168.6 ns/call. | Both appear in the agent's README: 168.6 ns/call for the run whose table is published, 184.0 ns/call for a different run. The README itself states the range 168–184. Reported as a range, not a single number. |
| C11 | The engine log's size did not change monotonically during the audit: 15 426 → 16 105 → 15 693 → 17 233 → 18 689 → 19 664 → 20 648 lines, with byte counts 1 948 084 → 2 042 926 → 1 983 754 → 2 188 804 → 2 383 202 → 2 513 242 → 2 644 061. | Unexplained. The log cannot be assumed append-only, so line numbers are treated as anchors that must be re-verified rather than as stable identifiers. Every published window was re-verified on 2026-11-03 by running the committed `extract.awk` programs and diffing against the committed TSVs: all three reproduced byte for byte at 15 693, at 17 233, at 18 689, at 19 664 and again at 20 648 lines (2026-11-04T00:48:21Z), and lines 9470, 12626, 12627 and 13420 still held the same records. The 2026-11-04 run initially reported a false *DIFFERS* for all three datasets because the `-v R=` install-root value had been derived from the log line instead of supplied correctly; the record counts matched exactly, which is what identified it as a tooling fault rather than log drift (see `docs/methodology.md` §2.1). A second symptom was found the same day: the log **begins** with `ggml_cuda_init:` and `load_hparams:` lines that precede any `engine started` record, i.e. the head of the file belongs to a launch whose start line is no longer in the file. The cause of the shrinkage between 07:25 and 10:22, and of the truncated head, is **U**. |
| C12 | The evening sweep suggests MTP roughly halves cold prefill (245.8 vs 529.9–537.5 tok/s); the morning data suggests MTP is slightly **faster** at a comparable prompt size (388.7–390.7 vs 376.9–378.8 tok/s). | Both observations are confounded, and they belong to different configuration families (`q4_0`/no-vision, `--spec 4` in five evening launches and `--spec 6` in six, `int8`/vision-on/`--spec 4` in all 24 morning launches). Neither is an MTP result. The repository states that no isolated MTP effect is established in either direction. |

## 5. Evidence that does not exist

Recorded explicitly so that no reader mistakes absence for a result.

1. **Self-perturbation problem in Phase 0.** The audit was performed by a Pi session whose provider is
   the same local Strata engine and the same GPU under study (`PI_PROVIDER=strata`,
   `PI_MODEL=qwen3.8-flash-next-iq3_xxs`). A recorded reading at 2026-11-03T16:07:06Z shows the engine
   holding **7 485 MiB of the 8 188 MiB** device at **100 %** utilization, with load average
   **9.90 / 9.92 / 9.87** and `MemAvailable` 7.73 GiB (full outputs in `docs/hardware.md`, "Recorded
   outputs"). **Therefore no timing measurement taken in this session is a valid benchmark**, and the Go
   benchmark suite was deliberately not re-run. Correctness checks (which do not depend on timing
   precision) were run; performance numbers were not.
2. **No peak RAM or peak VRAM samples exist** for any historical run. Only engine self-reported
   allocations (expert cache GiB, MTP draft layer MiB, VRAM-free-at-start warnings) are available.
3. **No controlled benchmark harness exists yet.** Historical numbers came from interactive agent
   sessions, not from a benchmark tool.
4. **The long-context fixture generator does not exist.** Only the produced 722 KB prompt file exists.
5. **No ExLlamaV3 or llama.cpp data of any kind.** No EXL3 quantization was found on disk.
6. **The 2026-10-30 to 2026-11-01 sessions (engine 0.1.54) have not been extracted or analysed.**
   Counted on 2026-11-03 from the private log: 20 of the 57 engine sessions in S1 are 0.1.54-era and they
   account for 678 request records; the 0.1.55-era sessions account for 1 238 request records at the time
   of writing, and that number is still growing. **These two counts are private-log-derived and are not
   reconstructible from any published dataset** (**H** for the count method, **U** for the exact future
   value); they are recorded here as the size of the gap, not as a publishable measurement. The 0.1.54-era
   records are not comparable to the published 0.1.55 numbers, and because of C11 they may not remain
   retrievable from the same log file indefinitely.
7. **No hidden or externally authored test set** exists for coding-agent evaluation.
8. **Licenses now exist for this repository** (`LICENSE`, MIT, for software; `LICENSE.docs`, CC BY 4.0, for
   the research record), decided by the owner on 2026-11-04. **No license exists for the Go project in S13**,
   and it is not published here, so its code remains outside the repository's licensing entirely.
9. **No retained artifacts for the mutation-testing and RED-test claims** in E4. The claims are
   recorded in the agent's README and in commit messages; the runs themselves were not captured.

## 6. Gaps and required follow-up

| ID | Gap | Phase | Action |
| --- | --- | --- | --- |
| G1 | This repository has no license | 1 (decision) | **Closed 2026-11-04.** Owner decision: MIT for software (`LICENSE`) and CC BY 4.0 for the research record (`LICENSE.docs`, legal text incorporated by reference). The reason for the split is recorded in `README.md` and in both license files |
| G2 | The Go rate-limiter project has no license, no remote, and lives in `/tmp` | 3 | **Decided 2026-11-04: reference-only.** Nothing is imported. The exercise stays class-**A** evidence here, and T3.7/T3.8 rebuild it clean-room from the published task specification under this repository's licenses, with independent tests (G6) and retained run artifacts |
| G3 | Long-context fixture has no generator | 3 | Write a deterministic generator, publish its hash, re-verify the published fixture reproduces `prompt.txt` byte for byte |
| G4 | No benchmark harness | 2 | Build the harness, then re-measure the sweep with repetitions and memory sampling |
| G5 | MTP comparison confounded, in both directions (C4, C12) | 2/4 | Single-variable A/B inside one configuration family with ≥3 repetitions |
| G6 | No independent test suite for the coding task | 3 | Write tests that do not derive from the evaluated agent's own suite |
| G7 | 0.1.54-era sessions unanalysed at request level (20 launches, 678 request records) | 2 | Those 20 launches are now published at launch and configuration level in S15, including four MTP refusals and four draft loads. Their **request records** are still unpublished; extract them as a separate dataset with its own manifest. **Time-sensitive**, because the log's head content is not guaranteed to persist (C11) |
| G8 | RAM topology, power profile and thermal state unrecorded | 2 | Add to the run-capture procedure |
| G9 | `govulncheck` claim unverified | 1 | Re-run when a network fetch is acceptable |
| G10 | The engine log's growth is not monotonic and its retention behaviour is unknown | 2 | **Owner action started 2026-11-04:** the owner archives the private log off-repo, privately, from a frozen snapshot; the procedure and the hash list are published in `docs/reproducibility.md` §6 and contain no personal absolute paths. Line numbers remain anchors, never identifiers, and must be re-verified against the archive rather than the live file |
| G11 | No per-request resource sampling exists for any published record | 2 | Every throughput number in this repository was captured without a simultaneous CPU-load, GPU-utilization, VRAM-occupancy or temperature sample. The Phase 2 harness must record them; until then no throughput figure can be attributed to a resource state |
| G12 | Engine argument documentation is private | 2 | `engines/strata/configuration.md` quotes the engine's own help text, which lives only in the private log as the usage dump printed by the five unknown-argument rejections. No published dataset contains those strings, so a reader cannot check them. Publish the usage dump as a sanitized artifact (or drop the quotes) in Phase 2 |
