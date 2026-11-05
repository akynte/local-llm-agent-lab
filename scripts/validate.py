#!/usr/bin/env python3
"""CPU-only validation for the published record of local-llm-agent-lab.

Everything here runs on the committed repository contents alone: no GPU, no model weights, no private
engine log and no network access. It answers three questions and no more:

  1. Are the published datasets structurally what their manifests and READMEs say they are?
  2. Do the numbers quoted in docs/ recompute from the published TSVs?
  3. Do the committed extraction programs behave as documented, on synthetic fixtures?

A fourth block reports the file-level licensing classification defined in LICENSE §"Scope of this file":
which tracked file is MIT, which is CC BY 4.0, whether the MIT-class files carry their SPDX notice, and
whether both standard license texts are intact.

It deliberately does NOT benchmark anything, does not run the engine, and does not evaluate a model.
Re-running the extraction against the private log is available only through --reextract, which reads a
path you pass it and is never part of CI.

Usage:
    python3 scripts/validate.py            # full validation, exit 0 or 1
    python3 scripts/validate.py --reextract <private-archive-dir>
    python3 scripts/validate.py --list     # list the checks without running the claim recomputation

Exit status: 0 all checks passed; 1 at least one failed; 2 usage error.
"""

# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2026 akynte (see the copyright line in LICENSE)

import argparse
import hashlib
import json
import os
import re
import shutil
import statistics
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESULTS = os.path.join(ROOT, "results", "strata")

DATASETS = {
    "diagnostics": "2026-10-30-11-02-engine-diagnostics",
    "evening": "2026-11-02-config-sweep",
    "morning": "2026-11-02-mtp-attempts",
}
WINDOW = {"diagnostics": (1, 13420), "evening": (12627, 13420), "morning": (9470, 12626)}
COUNTS = {"diagnostics": 1941, "evening": 134, "morning": 233}
HEADER = "kind\tlog_line\tengine_started_local\tpayload"
KINDS = {"engine_start", "event", "continuation"}

PAT = re.compile(
    r"prompt (\d+) tokens = (\d+) reused \+ (\d+) read in (\d+) ms \(([\d.]+) tok/s\),"
    r" (\d+) generated in (\d+) ms \(([\d.]+) tok/s\)"
)

fails = []
warns = []


def check(name, ok, detail=""):
    if ok:
        print(f"  ok   {name}" + (f" — {detail}" if detail else ""))
    else:
        print(f"  FAIL {name}" + (f" — {detail}" if detail else ""))
        fails.append(name)


def warn(name, detail):
    print(f"  warn {name} — {detail}")
    warns.append(name)


def read_tsv(path):
    with open(path, encoding="utf-8") as fh:
        header = fh.readline().rstrip("\n")
        rows = []
        for lineno, line in enumerate(fh, start=2):
            line = line.rstrip("\n")
            if not line:
                rows.append({"_lineno": lineno, "_fields": []})
                continue
            rows.append(dict(zip(header.split("\t"), line.split("\t"), strict=False)) | {"_lineno": lineno, "_raw": line})
    return header, rows


def request_records(rows):
    out = []
    for r in rows:
        m = PAT.search(r.get("payload", ""))
        if not m:
            continue
        out.append(
            dict(
                prompt=int(m[1]), reused=int(m[2]), generated=int(m[6]),
                prefill=float(m[5]), decode=float(m[8]),
                session=r.get("engine_started_local", ""), line=int(r["log_line"]),
            )
        )
    return out


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def band(values):
    return f"n={len(values)} min={min(values):.1f} max={max(values):.1f} mean={statistics.mean(values):.1f}"


# --------------------------------------------------------------------------- 1. layout
def check_layout():
    print("\n[1] dataset layout")
    for key, d in DATASETS.items():
        p = os.path.join(RESULTS, d)
        if not os.path.isdir(p):
            check(f"{key}: directory exists", False, p)
            continue
        names = sorted(os.listdir(p))
        allowed = re.compile(r"^(README\.md|manifest\.json|extract\.awk|.*\.tsv)$")
        extra = [n for n in names if not allowed.match(n)]
        check(f"{key}: only README/manifest/extract.awk/TSV present", not extra, f"stray: {extra}" if extra else "")
        for req in ("README.md", "manifest.json", "extract.awk", f"{'engine-diagnostics' if key == 'diagnostics' else 'engine-metrics'}.tsv"):
            check(f"{key}: {req} present", os.path.isfile(os.path.join(p, req)))


# --------------------------------------------------------------------------- 2. awk programs
def check_programs():
    print("\n[2] committed extraction programs")
    for key, d in DATASETS.items():
        prog = os.path.join(RESULTS, d, "extract.awk")
        # A parse error exits 2 in mawk/gawk; a validated missing-argument failure exits 64.
        r = subprocess.run(["awk", "-f", prog], stdin=subprocess.DEVNULL, capture_output=True, text=True)
        check(f"{key}: program parses and rejects a bad invocation", r.returncode == 64, f"exit {r.returncode}: {r.stderr.strip().splitlines()[:1]}")
        src = open(prog, encoding="utf-8").read()
        check(f"{key}: no absolute personal path written into the program", not re.search(r"/(home|Users)/[a-z0-9_.-]+/", src))
        check(f"{key}: sanitization is literal (index()), not gsub of a supplied value",
              "index(s, from)" in src and not re.search(r"gsub\(\s*(R|H)\b", src))
        check(f"{key}: refuses to publish an unsanitized path", "exit 66" in src)
        check(f"{key}: a zero-record window is an error", "exit 65" in src)


# --------------------------------------------------------------------------- 3. TSV structure
def check_tsv():
    print("\n[3] published TSV structure and counts")
    data = {}
    for key, d in DATASETS.items():
        tsv = os.path.join(RESULTS, d, "engine-diagnostics.tsv" if key == "diagnostics" else "engine-metrics.tsv")
        header, rows = read_tsv(tsv)
        data[key] = (header, rows)
        check(f"{key}: header is exactly the published four columns", header == HEADER, repr(header))
        check(f"{key}: {COUNTS[key]} data records", len(rows) == COUNTS[key], f"got {len(rows)}")
        bad_kind = [r["_lineno"] for r in rows if r.get("kind") not in KINDS]
        check(f"{key}: every kind is one of {sorted(KINDS)}", not bad_kind, f"lines {bad_kind[:5]}")
        nf = [r["_lineno"] for r in rows if len(r.get("_raw", "").split("\t")) != 4]
        check(f"{key}: every record has exactly four tab-separated fields", not nf, f"lines {nf[:5]}")
        lines = [r.get("log_line", "") for r in rows]
        numeric = all(re.fullmatch(r"\d+", l) for l in lines)
        check(f"{key}: log_line is a decimal integer in every record", numeric)
        if numeric:
            ints = [int(l) for l in lines]
            check(f"{key}: log_line strictly increasing", all(b > a for a, b in zip(ints, ints[1:])))
            lo, hi = WINDOW[key]
            check(f"{key}: every log_line lies inside the published window {lo}..{hi}", all(lo <= i <= hi for i in ints),
                  f"observed {min(ints)}..{max(ints)}")
        ts = [r.get("engine_started_local", "") for r in rows]
        bad_ts = [t for t in ts if t != "no-engine-start-seen" and not re.fullmatch(r"\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}", t)]
        check(f"{key}: engine_started_local is a local timestamp or the sentinel", not bad_ts, f"examples {sorted(set(bad_ts))[:3]}")
        payload = "\n".join(r.get("payload", "") for r in rows)
        check(f"{key}: no absolute personal path in the published payload",
              not re.search(r"/(home|Users|root|mnt|srv|export|run|var/home)/", payload),
              f"matches {sorted(set(re.findall(r'/(?:home|Users|root|mnt|srv|export|run)/[^\t ]{0,24}', payload)))[:3]}")
        check(f"{key}: no credential-shaped string",
              not re.search(r"(?i)(api[_-]?key|secret[_-]?key|access[_-]?token|refresh[_-]?token|password|passwd|BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-|eyJhbGciOi[A-Za-z0-9_.-]{20,})", payload))
    return data


# --------------------------------------------------------------------------- 4. manifests
def check_manifests(data):
    print("\n[4] manifests agree with the published data")
    snaps = {}
    for key, d in DATASETS.items():
        path = os.path.join(RESULTS, d, "manifest.json")
        try:
            m = json.load(open(path, encoding="utf-8"))
        except Exception as exc:  # noqa: BLE001
            check(f"{key}: manifest.json parses", False, str(exc))
            continue
        check(f"{key}: manifest.json parses", True)
        tsv = os.path.join(RESULTS, d, "engine-diagnostics.tsv" if key == "diagnostics" else "engine-metrics.tsv")
        snap = m.get("archive_snapshot", {})
        re_v = snap.get("reverified_from_archive", {})
        check(f"{key}: manifest tsv_sha256 equals the published file",
              re_v.get("tsv_sha256") == sha256(tsv), f"manifest {str(re_v.get('tsv_sha256'))[:16]}… vs actual {sha256(tsv)[:16]}…")
        check(f"{key}: manifest rows_produced equals the record count",
              re_v.get("rows_produced") == len(data[key][1]), f"{re_v.get('rows_produced')} vs {len(data[key][1])}")
        check(f"{key}: manifest window equals the documented window",
              list(re_v.get("window_inclusive", [])) == list(WINDOW[key]), f"{re_v.get('window_inclusive')} vs {WINDOW[key]}")
        for f in ("dataset_id", "kind", "license", "schema_status", "captured_at_utc"):
            check(f"{key}: manifest has {f}", f in m)
        snaps[key] = (snap, re_v)
        if "model" not in m:
            check(f"{key}: manifest records a model block", False,
                  "CONTRIBUTING.md requires model name, quantization and file hashes in every manifest")
    shared = {"status", "snapshot_id_utc", "archived_log_sha256", "archived_log_lines", "archived_log_bytes", "snapshot_state", "engine_build_at_snapshot", "note"}
    vals = [{f: snaps[ds][0].get(f) for f in shared} for ds in snaps]
    check("archive_snapshot identity block is identical in all three manifests", len({json.dumps(v, sort_keys=True) for v in vals}) == 1)
    return snaps


# --------------------------------------------------------------------------- 5. claim recomputation
def check_claims(data):
    print("\n[5] published numbers recomputed from the published TSVs")
    exp = []  # (label, expected, actual)

    def expect(label, want, got):
        exp.append((label, want, got))

    eh, ev_rows = data["evening"]
    mh, mo_rows = data["morning"]
    dh, dg_rows = data["diagnostics"]

    ev = request_records(ev_rows)
    mo = request_records(mo_rows)
    ev_start = [r for r in ev_rows if r.get("kind") == "engine_start"]
    mo_start = [r for r in mo_rows if r.get("kind") == "engine_start"]
    dg_start = [r for r in dg_rows if r.get("kind") == "engine_start"]

    mtp_sessions = {r["engine_started_local"] for r in ev_start if "--mtp" in r["payload"]}

    cold = [r["prefill"] for r in ev if r["reused"] == 0 and r["prompt"] >= 1000]
    dec_all = [r["decode"] for r in ev if r["generated"] >= 1000]
    dec_cold = [r["decode"] for r in ev if r["generated"] >= 1000 and r["reused"] == 0]
    warm = [r for r in ev if r["reused"] > 0]
    warmup = [r for r in ev if r["prompt"] == 53]
    nm = [r for r in ev if r["prompt"] == 12719 and r["reused"] == 0 and r["session"] not in mtp_sessions]
    nm_mtp = [r for r in ev if r["prompt"] == 12719 and r["reused"] == 0 and r["session"] in mtp_sessions]

    # docs/reproducibility.md §1 and docs/findings.md §1.1
    expect("config-sweep cold prefill (reused 0, prompt >= 1000)", "n=11 min=245.8 max=606.0 mean=520.4", band(cold))
    expect("config-sweep decode (generated >= 1000, mixed conditions)", "n=10 min=26.0 max=29.2 mean=27.5", band(dec_all))
    expect("config-sweep decode restricted to cold records", "n=6 min=26.0 max=29.2 mean=27.8", band(dec_cold))
    # docs/findings.md §1.1 five no-MTP runs of the identical 12 719-token prompt
    expect("no-MTP 12 719-token cold prefill band", "529.9-537.5", f"{min(r['prefill'] for r in nm):.1f}-{max(r['prefill'] for r in nm):.1f}")
    expect("no-MTP 12 719-token cold prefill mean", "534.1", f"{statistics.mean(r['prefill'] for r in nm):.1f}")
    expect("no-MTP 12 719-token prefill spread", "7.6 tok/s (1.4%)",
           f"{max(r['prefill'] for r in nm) - min(r['prefill'] for r in nm):.1f} tok/s ({100 * (max(r['prefill'] for r in nm) - min(r['prefill'] for r in nm)) / statistics.mean(r['prefill'] for r in nm):.1f}%)")
    expect("no-MTP 12 719-token decode mean", "28.1", f"{statistics.mean(r['decode'] for r in nm):.1f}")
    expect("no-MTP 12 719-token decode band", "26.5-29.2", f"{min(r['decode'] for r in nm):.1f}-{max(r['decode'] for r in nm):.1f}")
    expect("MTP 12 719-token cold record present", "1", str(len(nm_mtp)))
    # docs/findings.md §1.3 warm records
    expect("config-sweep warm record count", "8", str(len(warm)))
    expect("config-sweep warm records all come from one launch", "1", str(len({r['session'] for r in warm})))
    expect("config-sweep warm reported prefill band", "39.6-555.7",
           f"{min(r['prefill'] for r in warm):.1f}-{max(r['prefill'] for r in warm):.1f}")
    # docs/findings.md §1.2 warm-up probes
    expect("config-sweep 53-token warm-up count", "11", str(len(warmup)))
    expect("config-sweep warm-up prefill band", "60.8-65.0", f"{min(r['prefill'] for r in warmup):.1f}-{max(r['prefill'] for r in warmup):.1f}")
    expect("config-sweep warm-up decode band", "24.0-25.6", f"{min(r['decode'] for r in warmup):.1f}-{max(r['decode'] for r in warmup):.1f}")
    # docs/findings.md §1.4
    top = max((r for r in ev if r["reused"] == 0), key=lambda r: r["prompt"])
    expect("config-sweep longest cold prefill", "157835 tokens at 594.2 tok/s", f"{top['prompt']} tokens at {top['prefill']:.1f} tok/s")
    best = max((r for r in ev if r["reused"] == 0), key=lambda r: r["prefill"])
    expect("config-sweep highest cold prefill rate", "606.0 tok/s at 16 994 tokens", f"{best['prefill']:.1f} tok/s at {best['prompt']:,} tokens".replace(",", " "))
    # morning dataset
    mo_comp = [r for r in mo if r["generated"] > 0]
    mo_cancel = [r for r in mo_rows if r["payload"].startswith("prompt ") and "cancelled" in r["payload"]]
    expect("morning completed prompt records", "178", str(len(mo_comp)))
    expect("morning cancelled prompt records", "5", str(len(mo_cancel)))
    expect("morning engine sessions", "24", str(len(mo_start)))
    expect("morning launches carrying --mtp", "16", str(sum(1 for r in mo_start if "--mtp" in r["payload"])))
    expect("morning cold completed records (any length)", "42", str(sum(1 for r in mo_comp if r["reused"] == 0)))
    expect("morning cold completed records >= 1000 tokens", "22", str(sum(1 for r in mo_comp if r["reused"] == 0 and r["prompt"] >= 1000)))
    expect("morning warm completed records", "136", str(sum(1 for r in mo_comp if r["reused"] > 0)))
    expect("morning short warm-up records (< 1000 prompt tokens)", "20", str(sum(1 for r in mo if r["prompt"] < 1000)))
    expect("morning 53-token warm-up records", "8", str(sum(1 for r in mo if r["prompt"] == 53)))
    longest_cold = max(mo_comp, key=lambda r: r["prompt"] if r["reused"] == 0 else -1)
    expect("morning longest COMPLETED COLD prefill", "189737 tokens at 254.3 tok/s", f"{longest_cold['prompt']} tokens at {longest_cold['prefill']:.1f} tok/s")
    longest_any = max(mo_comp, key=lambda r: r["prompt"])
    print(f"  note longest completed prompt record of any kind in the morning dataset: "
          f"{longest_any['prompt']} tokens, {longest_any['reused']} reused, {longest_any['prefill']:.1f} tok/s "
          f"(warm — not a cold prefill, and not the figure quoted in docs/findings.md §1.4)")
    # diagnostics census
    expect("diagnostics record kinds", "engine_start 57 / event 1776 / continuation 108",
           f"engine_start {len(dg_start)} / event {sum(1 for r in dg_rows if r.get('kind') == 'event')} / continuation {sum(1 for r in dg_rows if r.get('kind') == 'continuation')}")
    ver = {}
    for r in dg_start:
        m = re.search(r"/(\d+\.\d+\.\d+)-linux", r["payload"])
        ver[m.group(1) if m else "unattributed"] = ver.get(m.group(1) if m else "unattributed", 0) + 1
    def census(d):
        return str(dict(sorted(d.items())))
    expect("diagnostics engine version census", "{'0.1.54': 20, '0.1.55': 37}", census(ver))
    expect("diagnostics launches with --vision", "42", str(sum(1 for r in dg_start if "--vision" in r["payload"])))
    expect("diagnostics launches with --mtp", "25", str(sum(1 for r in dg_start if "--mtp" in r["payload"])))
    quant = {}
    for r in dg_start:
        q = "IQ3_S" if "/IQ3_S/" in r["payload"] else ("IQ3_XXS" if "/IQ3_XXS/" in r["payload"] else "unattributed")
        quant[q] = quant.get(q, 0) + 1
    expect("diagnostics launches by quantization directory", "{'IQ3_S': 8, 'IQ3_XXS': 49}", census(quant))
    parity = {r["engine_started_local"] for r in dg_rows if "bench/results/2026-09-27-cache-parity" in r["payload"]}
    conts = sum(1 for r in dg_rows if r.get("kind") == "continuation")
    expect("diagnostics continuation lines = 3 per parity launch", f"{3 * len(parity)}", str(conts))
    expect("diagnostics unknown-argument lines", "5", str(sum(1 for r in dg_rows if r["payload"].startswith("unknown argument:"))))

    ok = 0
    for label, want, got in exp:
        if want == got:
            ok += 1
            print(f"  ok   {label}: {got}")
        else:
            print(f"  FAIL {label}: published says {want!r}, recomputed {got!r}")
            fails.append(label)
    print(f"  {ok}/{len(exp)} published figures reproduced from the published data")

    # The census spans two quantizations; the diagnostics manifest publishes no model block, so a reader
    # cannot see this from the manifest alone.
    if quant.get("IQ3_S"):
        warn("diagnostics census spans two quantizations",
             f"{census(quant)} — the launch census is not a census of one quantization; recorded in docs/evidence-inventory.md C14")


# --------------------------------------------------------------------------- 6. markdown links
def check_links():
    print("\n[6] internal links and cross-references resolve")
    md = []
    for base, _, files in os.walk(ROOT):
        if any(part in (".git", ".pi", "node_modules") for part in base.split(os.sep)):
            continue
        for f in files:
            if f.endswith(".md"):
                md.append(os.path.join(base, f))
    broken = []
    for path in md:
        text = open(path, encoding="utf-8").read()
        for m in re.finditer(r"\[([^\]]*)\]\(([^)]+)\)", text):
            target = m.group(2).split("#")[0].strip()
            if not target or target.startswith(("http://", "https://", "mailto:")):
                continue
            t = os.path.normpath(os.path.join(os.path.dirname(path), target))
            if not os.path.exists(t):
                broken.append(f"{os.path.relpath(path, ROOT)}: {m.group(2)}")
    check("every relative link target exists", not broken, "; ".join(broken[:6]))
    # Section cross-references of the form `docs/x.md §N` should exist in the target file.
    missing = []
    for path in md:
        text = open(path, encoding="utf-8").read()
        for m in re.finditer(r"`?(docs/[a-z-]+\.md|results/[A-Za-z0-9_./-]+)`?\s*§\s*([0-9]+(?:\.[0-9]+)*)", text):
            target = os.path.join(ROOT, m.group(1))
            if not os.path.isfile(target):
                continue
            if not re.search(rf"^#+\s*{re.escape(m.group(2))}(\.|\s|$)", open(target, encoding="utf-8").read(), re.M):
                missing.append(f"{os.path.relpath(path, ROOT)} -> {m.group(1)} §{m.group(2)}")
    if missing:
        warn("section cross-references not found by heading scan", "; ".join(sorted(set(missing))[:8]))


# --------------------------------------------------------------------------- 7. publication safety
def check_publication_safety():
    print("\n[7] publication-safety scan of tracked files")
    tracked = subprocess.run(["git", "-c", "core.quotepath=false", "ls-files"], cwd=ROOT, capture_output=True, text=True).stdout.split("\n")
    tracked = [t for t in tracked if t]
    check("no model weights or raw logs are tracked",
          not [t for t in tracked if re.search(r"\.(gguf|safetensors|exl3|ggml|pack|log|jsonl|ndjson|tar|tar\.zst|zip)$", t)])
    host = subprocess.run(["hostname"], capture_output=True, text=True).stdout.strip()
    hits = []
    for t in tracked:
        p = os.path.join(ROOT, t)
        try:
            data = open(p, "rb").read()
        except OSError:
            continue
        if b"\0" in data:
            hits.append(f"{t}: binary")
            continue
        text = data.decode("utf-8", "replace")
        if re.search(r"/(home|Users|root)/[a-z0-9_.-]+/", text):
            hits.append(f"{t}: absolute personal path")
        if re.search(r"ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-|BEGIN [A-Z ]*PRIVATE KEY|eyJhbGciOi[A-Za-z0-9_.-]{20,}", text):
            hits.append(f"{t}: credential-shaped string")
        if host and len(host) > 2 and re.search(re.escape(host), text, re.I):
            hits.append(f"{t}: this machine's hostname")
    check("no personal path, credential or hostname in tracked text", not hits, "; ".join(hits[:6]))
    print("  note this scan covers tracked text only. It is not a guarantee: it cannot see untracked"
          " files, files added after it runs, a username that is not part of an absolute path, or a"
          " secret that was already published before this script existed.")


# --------------------------------------------------------------------------- 8. licensing
MIT_TEXT_MARKERS = [
    "Permission is hereby granted, free of charge, to any person obtaining a copy",
    "THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND",
]
MIT_EXTS = (".awk", ".py", ".sh", ".yml", ".yaml", ".go", ".json")
MIT_DIRS = ("scripts/", "tests/", "schemas/", ".github/")
# A *declaration* is a line that asserts the identifier, optionally behind that file format's comment
# marker. A sentence that merely quotes the identifier mid-line (which several CC BY documents here do,
# because they explain the policy) is not a declaration and must not be read as one.
SPDX_DECL_RE = r"(?m)^[ \t]*(<!--|#|//)?[ \t]*SPDX-License-Identifier:[ \t]*([^ \t,\r\n]+)"
COPYRIGHT_DECL_RE = r"(?m)^[ \t]*(<!--|#|//)?[ \t]*SPDX-FileCopyrightText:"


def declarations(text):
    return [m.group(2) for m in re.finditer(SPDX_DECL_RE, text)]


def classify(path):
    """File-level license class per LICENSE §"Scope of this file": MIT, CC-BY, NEUTRAL, or None."""
    ext = os.path.splitext(path)[1]
    if path in ("LICENSE", "LICENSE.docs"):
        return "NEUTRAL"
    if path == ".gitignore":
        return "MIT"
    if path.endswith("extract.awk"):
        return "MIT"
    if ext in MIT_EXTS and path.startswith(MIT_DIRS):
        return "MIT"
    if ext in (".md", ".tsv"):
        return "CC-BY"
    if ext == ".json" and path.startswith("results/"):
        return "CC-BY"
    return None


def check_licensing():
    print("\n[8] file-level licensing policy (LICENSE §\"Scope of this file\")")
    tracked = subprocess.run(["git", "-c", "core.quotepath=false", "ls-files"], cwd=ROOT,
                             capture_output=True, text=True).stdout.split("\n")
    tracked = [t for t in tracked if t]
    cls = {t: classify(t) for t in tracked}
    counts = {}
    for t, c in cls.items():
        counts[c or "UNCLASSIFIED"] = counts.get(c or "UNCLASSIFIED", 0) + 1
    check("every tracked file falls into exactly one license class", not [t for t, c in cls.items() if c is None],
          "unclassified: " + ", ".join(t for t, c in cls.items() if c is None))
    print("       " + "  ".join(f"{k}={v}" for k, v in sorted(counts.items())))

    mit_files = sorted(t for t, c in cls.items() if c == "MIT")
    missing = [t for t in mit_files if "MIT" not in declarations(open(os.path.join(ROOT, t), encoding="utf-8").read())]
    check("every MIT-class file declares SPDX-License-Identifier: MIT on its own line", not missing, ", ".join(missing))
    nomark = [t for t in mit_files if not re.search(COPYRIGHT_DECL_RE, open(os.path.join(ROOT, t), encoding="utf-8").read())]
    check("every MIT-class file declares an SPDX copyright line", not nomark, ", ".join(nomark))

    cc = sorted(t for t, c in cls.items() if c == "CC-BY")
    clash = [t for t in cc if "MIT" in declarations(open(os.path.join(ROOT, t), encoding="utf-8", errors="replace").read())]
    check("no CC BY-class file declares an MIT license", not clash, ", ".join(clash))

    lic = open(os.path.join(ROOT, "LICENSE"), encoding="utf-8").read()
    docs = open(os.path.join(ROOT, "LICENSE.docs"), encoding="utf-8").read()
    check("the MIT permission notice in LICENSE is the standard text, unamended",
          all(m in lic for m in MIT_TEXT_MARKERS),
          "missing: " + ", ".join(m[:40] for m in MIT_TEXT_MARKERS if m not in lic))
    check("LICENSE states a file-level scope section naming both classes",
          "Scope of this file" in lic and "CC BY 4.0" in lic and "SPDX-License-Identifier: MIT" in lic)
    check("LICENSE.docs incorporates the CC BY 4.0 legal text by reference",
          "Creative Commons Attribution 4.0" in docs and "creativecommons.org/licenses/by/4.0/legalcode" in docs)
    check("the two license files are the only scope-neutral files",
          sorted(t for t, c in cls.items() if c == "NEUTRAL") == ["LICENSE", "LICENSE.docs"])

    bad = []
    for d in sorted({os.path.dirname(t) for t in tracked if t.startswith("results/strata/") and t.endswith("manifest.json")}):
        m = json.load(open(os.path.join(ROOT, d, "manifest.json"), encoding="utf-8"))
        s = m.get("license", "")
        if "CC BY 4.0" not in s or "MIT" not in s or "extract.awk" not in s:
            bad.append(d)
    check("every dataset manifest names the license of both its record and its extractor", not bad, ", ".join(bad))
    print("       note .tsv and manifest.json carry no inline notice because neither format has a comment")
    print("       syntax; their coverage is the rule above plus the manifest license field, and check [4]")
    print("       pins each published TSV to the sha256 its manifest already published.")


# --------------------------------------------------------------------------- 9. extract regression tests
def check_extract_tests():
    print("\n[9] extraction regression tests (synthetic fixtures only)")
    script = os.path.join(ROOT, "tests", "extract", "run_tests.sh")
    if not os.path.isfile(script):
        check("tests/extract/run_tests.sh exists", False)
        return
    r = subprocess.run(["sh", script], cwd=ROOT, capture_output=True, text=True)
    for line in r.stdout.splitlines():
        if line.startswith(("==", "  ok", "  FAIL", "passed=")):
            print(f"       {line}")
    if r.stderr.strip():
        print(f"       stderr: {r.stderr.strip()[:200]}")
    tail = [l for l in r.stdout.splitlines() if l.startswith("passed=")]
    check("synthetic extraction tests pass", r.returncode == 0, tail[-1] if tail else "no summary line produced")


# --------------------------------------------------------------------------- 10. optional private re-extraction
def do_reextract(archive_dir):
    print(f"\n[10] re-extraction against the private archive at {archive_dir}")
    log = None
    for base, _, files in os.walk(archive_dir):
        for f in files:
            if f.endswith(".engine.log"):
                log = os.path.join(base, f)
                break
        if log:
            break
    if not log:
        check("private engine log found", False, "no *.engine.log under the archive directory")
        return
    print(f"  log: {log} ({os.path.getsize(log)} bytes, {sum(1 for _ in open(log, 'rb'))} lines)")
    r_home = os.environ.get("HOME_DIR") or subprocess.run(["sh", "-c", "printf %s \"$HOME\""], capture_output=True, text=True).stdout.strip()
    r_root = os.environ.get("INSTALL_ROOT") or f"{r_home}/.local/share/strata"
    print(f"  sanitization roots: INSTALL_ROOT={r_root} HOME_DIR={r_home} (override with $INSTALL_ROOT / $HOME_DIR)")
    tmp = os.path.join(ROOT, ".tmp", "reextract")
    os.makedirs(tmp, exist_ok=True)
    for key, d in DATASETS.items():
        lo, hi = WINDOW[key]
        out = os.path.join(tmp, os.path.basename(d) + ".tsv")
        with open(out, "w", encoding="utf-8") as fh:
            fh.write(HEADER + "\n")
            fh.flush()  # the awk child writes to this same descriptor; an unflushed header would land after its output
            cmd = ["awk", "-v", f"lo={lo}", "-v", f"hi={hi}", "-v", f"R={r_root}",
                   "-v", f"H={r_home}", "-v", f"expect={COUNTS[key]}",
                   "-f", os.path.join(RESULTS, d, "extract.awk"), log]
            r = subprocess.run(cmd, stdout=fh, stderr=subprocess.PIPE, text=True)
        published = os.path.join(RESULTS, d, "engine-diagnostics.tsv" if key == "diagnostics" else "engine-metrics.tsv")
        same = sha256(out) == sha256(published)
        got = sum(1 for _ in open(out, encoding="utf-8")) - 1
        check(f"{key}: re-extraction is byte-for-byte identical to the published file", same,
              f"exit {r.returncode}, {got} records produced, sha256 {'matches' if same else 'differs'}"
              + (f", stderr: {r.stderr.strip()[:120]}" if r.stderr.strip() else ""))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--reextract", metavar="ARCHIVE_DIR", help="also re-run the extraction against a private log directory (never part of CI)")
    ap.add_argument("--skip-claims", action="store_true", help="skip the claim recomputation")
    args = ap.parse_args()
    if args.reextract and not os.path.isdir(args.reextract):
        print("usage error: --reextract needs an existing directory", file=sys.stderr)
        return 2

    print(f"validating {ROOT}")
    if not shutil.which("awk"):
        print("awk not found on PATH", file=sys.stderr)
        return 1
    check_layout()
    check_programs()
    data = check_tsv()
    check_manifests(data)
    if not args.skip_claims:
        check_claims(data)
    check_links()
    check_publication_safety()
    check_licensing()
    check_extract_tests()
    if args.reextract:
        do_reextract(args.reextract)

    print(f"\nsummary: {len(fails)} failed, {len(warns)} warnings")
    for f in fails:
        print(f"  failed: {f}")
    return 1 if fails else 0


if __name__ == "__main__":
    sys.exit(main())
