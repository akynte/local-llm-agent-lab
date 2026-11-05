# Hardware and host environment

All values below were read directly on the test machine on 2026-11-03 unless marked otherwise.
The verification commands are listed at the end so that a reader can confirm the same facts on
their own machine and record an equivalent table for their contribution.

Private identifiers are deliberately excluded: hostname, username, machine UUID, MAC address and
local IP addresses are not recorded anywhere in this repository.

## Host

| Item | Value | Evidence |
| --- | --- | --- |
| Operating system | Ubuntu 26.04.1 LTS (Resolute Raccoon) | `/etc/os-release` |
| Kernel | 7.0.0-38-generic, x86_64, SMP PREEMPT_DYNAMIC | `uname -a` |
| Machine | Lenovo laptop, sys_vendor `LENOVO`, product name `82XV`, chassis type 10 (laptop) | `/sys/class/dmi/id/{sys_vendor,product_name,chassis_type}` |
| Chassis claim | Lenovo LOQ 15IRH8 | owner-reported; `82XV` is the Lenovo machine type consistent with that model, but the marketing name itself was not verified by this project |
| Time zone | UTC+04:00 | `timedatectl` |
| Uptime at audit | up 3 days, 18 hours, 51 minutes (captured 2026-11-03T16:07:06Z; see §"Recorded outputs") | `uptime -p` |

Deliberately withheld: `product_uuid` (readable at `/sys/class/dmi/id/product_uuid`, unique per
machine), hostname, username, serial number, network identifiers.

## CPU

| Item | Value | Evidence |
| --- | --- | --- |
| Model | 13th Gen Intel Core i7-13620H | `lscpu` |
| Logical processors | 16 | `lscpu` |
| Physical cores per socket | 10 | `lscpu` |
| Threads per core | 2 | `lscpu` |
| NUMA nodes | 1 (CPUs 0-15) | `lscpu` |
| AVX-512 | **absent** — zero `avx512*` flags in `/proc/cpuinfo` | `/proc/cpuinfo`, independently corroborated by the engine's own startup line "this CPU has no AVX-512: the expert kernels run on AVX-2" |
| Relevant vector ISA | AVX2, AVX-VNNI, VAES (the flags `/proc/cpuinfo` reports; no `avx512*` flag is present) | `/proc/cpuinfo` flags. An earlier version of this row also asserted "bf16-adjacent paths as exposed by the kernel", which no captured command here supports; it was removed on 2026-11-05 (conflict C24) |

The engine assigns 9 worker threads, one per physical core but the host's, and pins the host
thread to logical CPU 0: 34 of the 57 logged launches carry
`CPU pool: 9 workers by default (10 physical cores, 16 logical processors; bounded by every physical
core but the host's)` and `9 pool workers on logical processors 2,4,6,8,10,12,13,14,15, the host thread
on 0`, published in `results/strata/2026-10-30-11-02-engine-diagnostics/`. Eight launches passed
`--pool-workers 6`; only two of those eight (11:31:51 and 11:34:58) reached the point of logging
`6 pool workers on logical processors 2,4,6,8,10,1` — **five** died on unknown arguments (11:13:40, 11:18:22,
11:21:07, 11:33:48, 11:34:19) and one (11:29:40)
logged no worker line. This is engine-version- and configuration-specific behaviour, not a hardware
property.

## Memory

| Item | Value | Evidence |
| --- | --- | --- |
| Installed (owner-reported) | 64 GB | owner-reported |
| Kernel-visible total | 64 247 028 kB ≈ 61.3 GiB | `/proc/meminfo` `MemTotal` |
| Swap | 31 GiB | `free` |
| Huge pages | `vm.nr_hugepages = 0`, Hugepagesize 2048 kB | `/proc/sys/vm/nr_hugepages`, `/proc/meminfo`; 36 launches additionally logged `MAP_HUGETLB unavailable (needed 20464–24010 2 MiB pages, vm.nr_hugepages=0)` and a transparent-huge-page fallback |
| `vm.swappiness` | 60 | `/proc/sys/vm/swappiness` |
| DIMM speed, ranks, channel count | **unknown** — `dmidecode` requires root and was not run | — |

`MemTotal` is below 64 GiB because of kernel and firmware reservations; both numbers are reported
so that a reader comparing machines is not misled.

## GPU

| Item | Value | Evidence |
| --- | --- | --- |
| Model | NVIDIA GeForce RTX 4060 Laptop GPU | `nvidia-smi` |
| VRAM total | 8188 MiB | `nvidia-smi --query-gpu=memory.total` |
| Compute capability | 8.9 (Ada) | `nvidia-smi --query-gpu=compute_cap` |
| Driver | 595.99.02, NVIDIA UNIX **open** kernel module | `nvidia-smi`, `/proc/driver/nvidia/version` |
| CUDA reported by the driver banner | 13.2 | `nvidia-smi` banner |
| CUDA variant used by the engine build | cuda13 (`linux-x86_64-cuda-cuda13`) | engine component directory names and `recheck.json` |
| Max SM clock | 3105 MHz | `nvidia-smi --query-gpu=clocks.max.sm` |
| Max memory clock | 8001 MHz | `nvidia-smi --query-gpu=clocks.max.memory` |
| Power limit | not reported by the query on this laptop: `power.limit` returns `[N/A]`, and `power.draw.max` is not a valid field on this driver. Recorded instantaneous draw 53.22 W (2026-11-03, engine loaded, GPU at 100 %). An earlier draft of this file quoted "56 W with a 111 W cap" from a `nvidia-smi` table view whose output was never captured — that figure is **U** and is not used anywhere | `nvidia-smi --query-gpu=power.draw,power.limit --format=csv` |
| PCIe link in use | Gen4 (16.0 GT/s) × 8 lanes | `/sys/bus/pci/devices/0000:01:00.0/current_link_{speed,width}` — **the raw sysfs output of this reading is not captured in this repository**; the link width is corroborated only by the engine's own probe lines, which are published. Treat the Gen4 ×8 statement as reported-by-command but not evidenced by a captured output here |
| Host→device bandwidth measured by the engine | The engine probes the link only when `--pcie-frac` is absent: the **42** launches without that flag logged a probe (best-of-four value **11.0–11.6 GB/s**: 11.5 ×20, 11.4 ×14, 11.6 ×5, 11.0/11.1/11.2 ×1 each) and the **15** launches that set the flag logged no probe line; the two sets do not overlap (42 + 15 = 57) | `PCIe probe:` lines published in `results/strata/2026-10-30-11-02-engine-diagnostics/`; the engine turned the probe into `pcie_frac` 0.32 ×24, 0.31 ×17, 0.30 ×1 |
| ECC | not available on this GPU (`Volatile Uncorr. ECC: N/A`) | `nvidia-smi` |
| Graphics co-residency on the same device | **not established.** The captured `nvidia-smi` compute-apps query lists only the engine process, and the desktop session does not appear in it. An earlier draft claimed the desktop compositor "holds ~2 MiB on the same GPU"; that is **not** reproducible from the recorded command and is recorded as unverified (see §"Recorded outputs" and `docs/evidence-inventory.md` §5 item 1) | `nvidia-smi` process table — captured output shows one compute process only |

## Storage

| Item | Value | Evidence |
| --- | --- | --- |
| Primary NVMe | Samsung SSD 990 PRO 2 TB, non-rotational, 1.8 TiB, ext4, mounted at `/`, 398 GB used at audit | `lsblk`, `df -hT` |
| Secondary NVMe | Samsung SSD 980 PRO 1 TB, non-rotational, 931.5 GB | `lsblk` |
| Model weights location | primary NVMe (paths recorded only as sizes and hashes) | local inspection |

Model weights are ~75.8 GB across two shards. They are not committed to this repository and are
not required to reproduce the published analyses — only the extracted metric lines are needed.

## Toolchain present at audit

| Tool | Version |
| --- | --- |
| Go | 1.27.3 linux/amd64 |
| Python | 3.14.4 |
| matplotlib | 3.10.7 |
| jq | present |
| staticcheck | 2026.2.2 (0.8.2) |
| golangci-lint | 2.15.0 (built with go1.27.3) |
| govulncheck | installed (Go 1.27.3) |
| pynvml (Python NVML bindings) | **not installed** — GPU sampling is done through `nvidia-smi` queries instead |

## Verification commands

```sh
# host
lsb_release -a; cat /etc/os-release; uname -a; timedatectl; uptime
cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name /sys/class/dmi/id/chassis_type

# cpu and memory
lscpu; grep -o 'avx512[a-z0-9]*' /proc/cpuinfo | sort -u; grep -E 'MemTotal|Hugepagesize' /proc/meminfo
cat /proc/sys/vm/nr_hugepages /proc/sys/vm/swappiness; free -h

# gpu
nvidia-smi
nvidia-smi --query-gpu=name,driver_version,memory.total,compute_cap,clocks.max.sm,clocks.max.memory,power.limit,pcie.link.gen.current,pcie.link.width.current --format=csv
cat /proc/driver/nvidia/version
cat /sys/bus/pci/devices/0000:01:00.0/current_link_speed /sys/bus/pci/devices/0000:01:00.0/current_link_width

# storage
lsblk -d -o NAME,SIZE,MODEL,ROTA,TYPE; df -hT /
```

## Known gaps in the hardware record

- RAM speed, DIMM configuration and channel count are unverified (root-only `dmidecode`).
- Laptop power profile and battery/AC state during historical runs were not recorded. GPU draw and
  clock behaviour differ between profiles, so prefill and decode numbers from different power
  states are not directly comparable.
- Thermal state and clock throttling were not sampled during the historical runs.
- The 512 MiB and 768 MiB values seen in engine configurations are the engine's VRAM headroom
  reservation, not a driver setting.

## Recorded outputs (2026-11-03T16:07:06Z)

These are the captured outputs behind the point-in-time claims in this repository. Quoted as returned,
except that process paths are reduced and no username appears.

```sh
$ nvidia-smi --query-gpu=name,driver_version,compute_cap,memory.total,memory.used,utilization.gpu,temperature.gpu,clocks.sm,clocks.max.sm --format=csv
NVIDIA GeForce RTX 4060 Laptop GPU, 595.99.02, 8.9, 8188 MiB, 7485 MiB, 100 %, 58, 2550 MHz, 3105 MHz

$ nvidia-smi --query-compute-apps=pid,used_gpu_memory --format=csv
1291633, 7316 MiB        # /proc/1291633/comm is "strata-host"

$ uptime -p
up 3 days, 18 hours, 51 minutes

$ cat /proc/loadavg
9.90 9.92 9.87 1/1254 1609733

$ awk '/MemTotal|MemAvailable/{print $1, $2/1048576" GiB"}' /proc/meminfo
MemTotal: 61.2707 GiB
MemAvailable: 7.73158 GiB

$ nvidia-smi --query-gpu=power.draw,power.limit --format=csv
53.22 W, [N/A]
```

What this establishes, and what it does not:

- The engine held **7 485 MiB of 8 188 MiB at 100 % utilization** at 58 °C, SM clock 2550 of 3105 MHz,
  while it was serving this audit. That is the recorded basis for refusing to take timing measurements
  during the audit.
- The compute-apps query lists **only** the engine process (7 316 MiB of it). The desktop session does not
  appear in that query, so the earlier statement that the desktop compositor "holds ~2 MiB on the same
  GPU" is **not reproducible from this command** and is recorded as **U**, not as a measurement.
- `MemAvailable` was **7.73 GiB**. An earlier draft of `engines/strata/troubleshooting.md` quoted 8.3 GiB;
  both are point-in-time readings of a moving quantity, and the one with recorded output is this one.
- Load average 9.90 / 9.92 / 9.87 on a 16-logical-processor host, i.e. the machine was saturated by the
  inference workload at that moment.
- The power query returned **53.22 W** of instantaneous draw and **`[N/A]`** for the limit. This is the
  captured output behind the power row in §GPU: no power ceiling is published because this driver does not
  report one, and `--query-gpu=power.draw.max` is rejected by it as an invalid field. A later query at
  2026-11-04T00:48Z, with the engine loaded again, returned **61.78 W** with the same `[N/A]` limit — draw
  is a moving quantity, so both readings are point-in-time and neither is a machine constant.
