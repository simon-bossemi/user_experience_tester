# bos-sdk_user_experience_tester

User-experience testing for the BOS A0 (Tenstorrent Blackhole) TT-XLA development environment.
This repository documents the full installation workflow from hardware setup through running a
ResNet50 inference on a BOS A0 card.

---

## Target hardware

**BOS A0 — Tenstorrent Blackhole** (p100a / p150a / p150b)

The primary source for this workflow is the BOS internal tutorial
(`AIMultimed-TT-XLA Installation-030426-023800.pdf`) provided in `inputs/`, combined with the
public Tenstorrent getting-started documentation.

---

## Generated artifacts

| Artifact | Location | Description |
|----------|----------|-------------|
| **Manual** | [`docs/manuals/tt-xla-linux-manual.md`](docs/manuals/tt-xla-linux-manual.md) | Step-by-step guide for beginners: hardware setup, driver install, wheel install, Docker, build-from-source, ResNet50 demo |
| **Bootstrap script** | [`scripts/tt-xla-bootstrap.sh`](scripts/tt-xla-bootstrap.sh) | One-command automated install + ResNet50 demo on BOS A0; idempotent (safe to re-run) |
| **Installation report** | [`reports/tt-xla-installation-report.md`](reports/tt-xla-installation-report.md) | Gap analysis, PDF findings, assumptions, blockers, environment matrix |
| **Access issues** | [`reports/credential_or_access_issues.md`](reports/credential_or_access_issues.md) | Documents credentials/access that blocked the agent and their resolutions |
| **Input PDF** | [`inputs/AIMultimed-TT-XLA Installation-030426-023800.pdf`](inputs/AIMultimed-TT-XLA%20Installation-030426-023800.pdf) | BOS internal TT-XLA installation guide (source document) |

---

## Supported workflows

### Option A — Wheel install (fastest, recommended)

```bash
# 1. Complete BOS A0 hardware + BIOS setup (Section 3 of the manual)
# 2. Run TT-Installer to set up driver and hugepages (Section 4)
# 3. Run the bootstrap script:
chmod +x scripts/tt-xla-bootstrap.sh
./scripts/tt-xla-bootstrap.sh
```

The script is **idempotent**: re-running it skips steps that are already complete.

### Option B — Docker (BOS A0)

See `docs/manuals/tt-xla-linux-manual.md` Section 6 for the full `docker run` command
using `ghcr.io/tenstorrent/tt-xla/tt-xla-ci-ubuntu-22-04:latest` and the BOS A0 device
path `/dev/bos/<id>`.

### Option C — Build from source (BOS A0)

See `docs/manuals/tt-xla-linux-manual.md` Section 7 for:
- GitHub SSH setup for the `bos-semi` private repositories
- TT-MLIR toolchain build (`cmake env/build`)
- TT-XLA BOS A0 cmake flags (`-DUSE_BOS_SEMI_TTMLIR=ON`, `-DUSE_BOS_REPO=ON`, etc.)
- Known `core_assignment.cpp` build workaround

---

## Quick reference

```bash
# Verify BOS A0 hardware is present:
lspci -d 1e52:
ls /dev/bos/

# Check hugepages (set by TT-Installer):
grep HugePages_Total /proc/meminfo

# Run ResNet50 on BOS A0 (after wheel install):
source ~/.tt-xla-venv/bin/activate
python run_resnet50_tt.py
```
