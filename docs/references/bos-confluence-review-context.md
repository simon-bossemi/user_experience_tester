# BOS Confluence Review Context — TT-XLA Installation

**Source:** BOS Semi Atlassian Confluence, Space: AIMultimed  
**Page ID:** 337346574  
**Page title:** TT-XLA Installation  
**Page URL:** https://bos-semi.atlassian.net/wiki/spaces/AIMultimed/pages/337346574/TT-XLA+Installation  
**Access requirement:** Authenticated BOS Semi Confluence account  
**Status of this file:** Derived from the PDF export `inputs/AIMultimed-TT-XLA Installation-030426-023800.pdf` (full page export, 2026-04-03)

---

## Purpose

This file captures the key BOS-specific facts extracted from the internal Confluence page and
serves as the reference context for the user-experience tester agent (`user_experience_tester`).
It exists so that:

1. The tester agent can reference a local file instead of requiring live Confluence access.
2. Reviewers can inspect the source context without needing a Confluence account.
3. Any delta between this snapshot and the live Confluence page can be tracked explicitly.

---

## Hardware Target

| Field | Value |
|-------|-------|
| Card | BOS A0 (Tenstorrent Blackhole) — p100a, p150a, p150b |
| PCIe | Gen 5.0 x16 (no bifurcation) |
| Power | 12+4-pin 12V-2x6, ATX 3.1 PSU required |
| Device path | `/dev/bos/<id>` (managed by the `bos` kernel driver) |
| Sysfs class | `/sys/class/bos/bos!<id>` |

---

## Docker Image

| Field | Value |
|-------|-------|
| Image | `ghcr.io/tenstorrent/tt-xla/tt-xla-ci-ubuntu-22-04:latest` |
| Run flags | `--cap-add ALL --ipc=host --device /dev/bos/<id>` |
| Hugepage mounts | `-v /dev/hugepages:/dev/hugepages -v /dev/hugepages-1G:/dev/hugepages-1G` |

---

## Private Source Repositories

| Repository | Branch | Access |
|-----------|--------|--------|
| `git@github.com:bos-semi/tt-mlir.git` | `develop` | SSH, bos-semi org member required |
| `git@github.com:bos-semi/tt-xla.git` | `release/a0` | SSH, bos-semi org member required |

---

## BOS-Specific CMake Build Flags

```cmake
-DUSE_BOS_SEMI_TTMLIR=ON
-DUSE_CUSTOM_TT_MLIR_VERSION=ON
-DUSE_BOS_REPO=ON
```

---

## Known Build Issue — `core_assignment.cpp`

File: `tt-metal-e2/src/core_assignment.cpp`  
Fix: Add `[[maybe_unused]]` attribute to suppress the unused-variable compiler error.

```cpp
// Before:
auto unused_var = some_function();

// After:
[[maybe_unused]] auto unused_var = some_function();
```

---

## `setuptools` Pin

After building TT-MLIR tools, pin `setuptools` to avoid packaging errors:

```bash
pip install "setuptools<82"
```

---

## Test Command

```bash
pytest tests/benchmark/test_vision.py::test_resnet50 -sv
```

---

## BOS Eagle PCIe Enumeration

On BOS Eagle systems, the PCIe co-processor may enumerate under a different PCI ID and driver
than the Tenstorrent-branded hardware:

| Field | Value |
|-------|-------|
| PCI ID | `16c3:abcd` |
| Kernel driver | `bos` |
| Sysfs class | `/sys/class/bos` |
| Device path | `/dev/bos/` |

Detection command:

```bash
lspci -nn | grep -E 'tenstorrent|16c3:abcd'
```

---

## Network Dependencies

All of the following hosts must be reachable for a full install:

| Host | Purpose |
|------|---------|
| `installer.tenstorrent.com` | TT-Installer script |
| `pypi.eng.aws.tenstorrent.com` | `pjrt-plugin-tt` wheel |
| `download.pytorch.org` | PyTorch CPU wheels |
| `pypi.org` | pip, wheel, setuptools |
| `github.com` | Source repositories (HTTPS + SSH) |
| `ghcr.io` | Docker CI image |

---

## Access Status (as of 2026-04-03)

| Resource | Status | Notes |
|---------|--------|-------|
| Confluence page | ❌ Inaccessible | Requires BOS Semi Confluence login |
| `bos-semi/tt-mlir` | ❌ Private | SSH key registered to bos-semi org member required |
| `bos-semi/tt-xla` | ❌ Private | SSH key registered to bos-semi org member required |
| `pypi.eng.aws.tenstorrent.com` | ⚠️ External | May be firewalled in corporate environments |
| PDF export (local) | ✅ Available | `inputs/AIMultimed-TT-XLA Installation-030426-023800.pdf` |

For full access blocker details, see `reports/credential_or_access_issues.md`.
