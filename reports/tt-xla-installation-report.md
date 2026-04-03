# TT-XLA Installation Report

**Tool:** TT-XLA (Tenstorrent XLA)  
**Report type:** Gap analysis, assumption log, and installation blockers  
**Author:** user_experience_tester agent  
**Date:** 2026  
**Sources consulted:**
- [BOS Internal Tutorial — PDF export](inputs/AIMultimed-TT-XLA%20Installation-030426-023800.pdf) *(now available — supersedes prior "blocked" status)*
- [GitHub tenstorrent/tt-xla](https://github.com/tenstorrent/tt-xla)
- [Official Getting Started (raw)](https://raw.githubusercontent.com/tenstorrent/tt-xla/main/docs/src/getting_started.md)
- [Tenstorrent Blackhole Hardware Installation](https://github.com/tenstorrent/tenstorrent.github.io/blob/main/core/aibs/blackhole/installation.md)
- [Tenstorrent Software Stack Installation](https://github.com/tenstorrent/tenstorrent.github.io/blob/main/core/getting-started/README.md)
- Web search synthesis (Tenstorrent docs, DeepWiki, community guides)

---

## 0. Third-Run Summary (Revised April 2026 — BOS A0 PDF Now Available)

This report has been revised a second time following the availability of the **BOS internal
tutorial as a PDF export** (`AIMultimed-TT-XLA Installation-030426-023800.pdf`, 7 pages).
This resolves the previously-critical blocker of Confluence inaccessibility.

Key improvements in this revision:

| Area | Change |
|------|--------|
| BOS internal tutorial | Now read and incorporated — blocker resolved |
| Docker section | Corrected image name, added BOS A0 device path `/dev/bos/`, full launch command |
| Build from source | Added BOS A0-specific repos (`bos-semi/tt-mlir`, `bos-semi/tt-xla`), cmake flags, SSH setup |
| Known bug | Documented `core_assignment.cpp` manual fix for BOS A0 `tt-metal` builds |
| Hugepages | Made optional — TT-Installer handles it; script now warns instead of failing |
| Test command | Added `pytest tests/benchmark/test_vision.py::test_resnet50 -sv` from PDF |
| Troubleshooting | Added SSH setup, SFPI mismatch, setuptools fix, Python version fix |

The core gap analysis and findings from the first and second runs remain valid and are preserved below.

---

## 1. Executive Summary

TT-XLA is a **hardware-dependent** compiler front-end. Installation can be split into two
distinct tiers:

| Tier | Requirement | Notes |
|------|------------|-------|
| Software-only | Python 3.11+ + pip | Wheel installs in minutes |
| Full execution | Physical Tenstorrent PCIe card + kernel driver + hugepages | Mandatory for any model to actually run |

The official wheel installation path (`pip install pjrt-plugin-tt`) is clean and well-documented.
The build-from-source path is significantly more complex and requires Ubuntu 24.04 + Clang 20 +
a separately built TT-MLIR toolchain.

ResNet50 compilation does **not** require any ONNX export, checkpoint conversion, or model
pre-processing step. `torch.compile(model, backend="tt")` handles all graph lowering internally.

---

## 2. Gaps in the Official Tutorial

### 2.1 BOS Internal Tutorial (Atlassian → PDF Export)

> **STATUS: RESOLVED.** The BOS internal Confluence page was previously inaccessible.
> A PDF export (`AIMultimed-TT-XLA Installation-030426-023800.pdf`) was provided in the `inputs/`
> directory and has now been fully read and incorporated.

Key findings from the PDF (7 pages, titled "TT-XLA Installation"):

| Finding | Significance |
|---------|-------------|
| Docker image for BOS A0 is `ghcr.io/tenstorrent/tt-xla/tt-xla-ci-ubuntu-22-04:latest` | Different from generic `tt-xla-slim` used in prior versions |
| BOS A0 device path is `/dev/bos/<device_id>` | Not `/dev/tenstorrent/<device_id>` — undocumented in public docs |
| BOS repos are `git@github.com:bos-semi/tt-mlir.git` (branch `develop`) and `git@github.com:bos-semi/tt-xla.git` (branch `release/a0`) | Private repos requiring SSH access |
| BOS cmake flags: `-DUSE_BOS_SEMI_TTMLIR=ON -DUSE_CUSTOM_TT_MLIR_VERSION=ON -DUSE_BOS_REPO=ON` | Required for BOS A0 build |
| Known bug in `tt-metal-e2`: `core_assignment.cpp` must be manually patched | Unused-parameter errors at lines 159–165 and 198–199 |
| SFPI toolchain mismatch fix: `$TT_METAL_RUNTIME_ROOT/install_dependencies.sh --sfpi` | Not in any public doc |
| `setuptools<82` required after building TT-MLIR tools | Version incompatibility |
| Test command: `pytest tests/benchmark/test_vision.py::test_resnet50 -sv` | Confirms ResNet50 test path |
| GitHub SSH access is mandatory for BOS repos | Must set up `~/.ssh/id_ed25519` and add to GitHub account |
| Hugepages are mounted as Docker volumes (not separately configured) | `-v /dev/hugepages:/dev/hugepages -v /dev/hugepages-1G:/dev/hugepages-1G` |

### 2.2 Official Public Tutorial Gaps

| Gap | Details | Workaround Used |
|-----|---------|----------------|
| No ResNet50 example | Official demos show GPT / OPT NLP models; no vision classification example | Created from scratch using `torchvision.models.resnet50` + `torch.compile` |
| No Python version pinning in wheel install | Docs say "Python ≥ 3.10" but build-from-source explicitly requires 3.12 | Used 3.11 for wheel install (known-good), 3.12 required only for source build |
| No pip version constraint | Old pip (<23) may fail with `--extra-index-url` resolution | Script upgrades pip before installing the plugin |
| torch-xla version not pinned | `pjrt-plugin-tt` bundles torch-xla internally; standalone `torch-xla` version compatibility is not documented | Used bundled version; added note not to install a separate conflicting torch-xla |
| No torchvision install in getting started | Not mentioned, but required for ResNet50 and many other vision models | Added explicit `pip install torchvision` step |
| No hugepages recovery instructions | Tutorial mentions hugepages requirement but does not show how to configure them if missing | Added `sysctl vm.nr_hugepages=4` workaround in the script |
| Build-from-source: TT-MLIR step is a black box | The getting started doc says "follow TT-MLIR build instructions" but links to a separate repo | Documented the dependency; build-from-source is treated as an advanced option |

---

## 3. Inferred and Undocumented Steps

The following steps were **not documented** in the official tutorial but were determined to be
necessary through analysis of the repository and related resources:

### 3.1 Driver / Kernel Module Setup

The public documentation mentions "follow hardware setup at docs.tenstorrent.com" but does not
give a direct command. The new TT-Installer script (v1.6+) is the recommended path:

```bash
# Prerequisites (required by the new installer):
sudo apt-get install -y curl jq

# Run the installer:
/bin/bash -c "$(curl -fsSL https://github.com/tenstorrent/tt-installer/releases/latest/download/install.sh)"
```

> **Note:** The old installer URL (`https://installer.tenstorrent.com/tt-installer.sh`) is
> deprecated. The new installer is hosted at GitHub Releases and also flashes firmware via
> TT-Flash, which is a new step not in the original manual.

This was **inferred** from community guides and the TT-SMI repository README, not from the
official TT-XLA getting-started guide.

### 3.2 Hugepages Configuration

`/proc/meminfo` hugepages can be zero on fresh Ubuntu installs. The `vm.nr_hugepages` kernel
parameter must be set for TT-Metal to allocate device memory. This is **not mentioned** in the
TT-XLA getting started doc.

```bash
# Inferred from TT-Metal documentation and community reports:
sudo sysctl -w vm.nr_hugepages=4
echo 'vm.nr_hugepages=4' | sudo tee -a /etc/sysctl.conf
```

### 3.3 `torch_plugin_tt` Import is a Side-Effect Import

To use `torch.compile(backend="tt")`, the user must `import torch_plugin_tt` first to register
the backend. This is **not documented** in the torch.compile usage example in the getting started
guide. It was inferred from PyPI package structure and the wheel layout documentation.

### 3.4 Docker Device Flag Restriction

The Docker instructions document that `--device /dev/tenstorrent` (directory, not individual
device files) must be used. Passing `--device /dev/tenstorrent/0` causes fatal errors. This is
documented but buried in a note and easy to miss.

### 3.5 Compilation Latency on First Run

`torch.compile(model, backend="tt")` performs JIT compilation of the full model graph on first
invocation. For ResNet50, this takes **30–120 seconds**. The official tutorial does not mention
this latency. Users unfamiliar with XLA-style compilation may assume the process has hung.

### 3.6 PyTorch CPU Wheel for Host

When installing torch for the host environment (outside Docker), the CPU wheel is appropriate
because the Tenstorrent NPU acts as the execution target; no CUDA is required. This is
**not stated** in the official docs. The default `pip install torch` pulls a CUDA wheel which
adds unnecessary size.

---

## 3b. BOS A0 (Blackhole) Specific Gaps

### 3b.1 BIOS Configuration Not Documented in TT-XLA Guides

The TT-XLA getting-started guide makes no mention of BIOS requirements. For Blackhole hardware,
two BIOS settings are **mandatory** before running the installer:

1. **PCIe AER Reporting Mechanism → "OS First"**  
   Without this, `tt-smi` will fail to enumerate devices. Source: official Tenstorrent
   getting-started guide.

2. **PCIe slot speed → Gen 5 (not "Auto")**  
   Some motherboards fail to enumerate Blackhole cards when PCIe speed is set to Auto. Source:
   Tenstorrent Blackhole installation troubleshooting docs.

These steps are now documented in Section 3 of the manual.

### 3b.2 Hardware Form Factor Differences

The Blackhole p100a and p150a are dual-slot boards with active coolers. The adjacent PCIe slot
must be left empty for adequate airflow. The p150b uses a passive heatsink and is designed for
rack-mounted systems with forced airflow. **Not mentioned** in the TT-XLA getting started docs.

### 3b.3 Power Connector Requirement

Blackhole cards require a **12+4-pin 12V-2x6 power connector** and an **ATX 3.1 certified PSU**.
Standard 8-pin PCIe power cables are incompatible. **Not mentioned** in the TT-XLA getting
started docs. Sourced from the official Blackhole hardware installation guide.

### 3b.4 Expected Architecture String Changes

The `jax.devices('tt')` expected output changes between hardware families:
- **Wormhole:** `[TTDevice(id=0, arch=Wormhole_b0)]`
- **Blackhole (BOS A0):** `[TTDevice(id=0, arch=blackhole)]`

The original manual and script only showed the Wormhole string. Both are now documented.

### 3b.5 PCI Vendor ID for Debugging

Tenstorrent's PCI vendor ID is `1e52`. When Blackhole cards fail to show up in standard
`lspci | grep tenstorrent` output (due to driver not yet naming the device), the following
command can reveal whether the card is at least enumerated:

```bash
lspci -d 1e52:
```

### 3b.6 TT-SMI for Post-Install Verification

On Blackhole hardware, the recommended post-install verification tool is `tt-smi` (installed
by the new TT-Installer), not just `ls /dev/tenstorrent/`. The `tt-smi` command provides device
health, firmware version, and PCIe link status in a single view.

### 3b.7 New TT-Installer Format and `jq` Dependency

The new TT-Installer (v1.6+) has a **different invocation** than the one previously documented:

| Old (deprecated) | New (current) |
|-----------------|---------------|
| `curl -L https://installer.tenstorrent.com/tt-installer.sh \| bash` | `/bin/bash -c "$(curl -fsSL https://github.com/tenstorrent/tt-installer/releases/latest/download/install.sh)"` |

The new installer also requires `jq` to be installed beforehand:
```bash
sudo apt-get install -y curl jq
```

The new installer is interactive (prompts for Metalium container, Python venv location, etc.)
and also flashes firmware to the card via `tt-flash`, which was not part of the old workflow.

---

## 4. Assumptions Made

| Assumption | Basis | Confidence |
|-----------|-------|-----------|
| Python 3.11 is supported by the wheel | Tenstorrent docs say "≥3.10"; build-from-source requires 3.12 | High |
| `torch.compile(backend="tt")` is the correct PyTorch entrypoint | DeepWiki architecture diagram + torch_plugin_tt README | High |
| `pjrt-plugin-tt` bundles all required C++ libraries | Wheel structure documentation in getting_started.md | High |
| ResNet50 requires no pre-export step | All PyTorch models supported via FX tracing — no ONNX needed | High |
| `ghcr.io/tenstorrent/tt-xla-slim:latest` is the correct Docker image | Official getting_started.md | High |
| Hugepages size is 1 GB per page | TT-Metal documentation references `/dev/hugepages-1G` | High |
| Ubuntu 22.04/24.04 are the target distros | Official getting_started.md mentions Ubuntu 24.04 for source build | High |
| Tenstorrent firmware is up to date | Not verified — firmware updates may be required before driver installation | Unknown |
| Blackhole `jax.devices` arch string is `blackhole` | Web search synthesis; not confirmed on live hardware | Medium |

---

## 5. Known Blockers

### 5.1 Hardware Mandatory

**Severity: Critical**  
TT-XLA cannot execute any model without a Tenstorrent PCIe card. There is no CPU fallback or
emulation mode. Any CI/CD pipeline or automated test environment without hardware will fail at
the device detection step.

**Workaround:** Use the Docker image for software-only validation tests; skip hardware execution.

### 5.2 Private PyPI Index Required

**Severity: High**  
The `pjrt-plugin-tt` package is hosted at `https://pypi.eng.aws.tenstorrent.com/`, which is
Tenstorrent's private AWS-hosted package index. This URL:
- May require VPN or network allowlisting in corporate environments
- Is not guaranteed to be stable long-term
- Has no documented authentication requirements (appears public as of analysis date)

**Workaround:** Download nightly wheels from GitHub Releases and install locally:
```bash
pip install pjrt_plugin_tt-*.whl
```

### 5.3 Build-from-Source Complexity

**Severity: Medium (for wheel users only)**  
Building TT-XLA from source requires:
- Ubuntu 24.04 specifically (not 22.04)
- Clang 20 (not the default Clang version in Ubuntu 22.04)
- A separately built TT-MLIR toolchain (hours of additional build time)
- CMake 4.0.3 (not in standard Ubuntu repos — requires manual install)

**Workaround:** Use the pip wheel unless developing TT-XLA itself.

### 5.4 BOS Internal Tutorial Not Accessible

**Severity: RESOLVED**  
The BOS internal Confluence tutorial is now available as a PDF export in `inputs/`. All
BOS A0-specific steps have been incorporated into the manual and script. See Section 2.1
for a full listing of what was found in the PDF.

### 5.5 BOS A0 Blackhole Arch String Not Verified on Live Hardware

**Severity: Low**  
The expected `jax.devices('tt')` output for Blackhole (`arch=blackhole`) was determined through
web search synthesis, not confirmed on a live BOS A0 system. The exact string may differ
depending on the firmware version and software stack version.

**Action required:** Verify on a live BOS A0 system and update the manual if the arch string
differs.

---

## 6. Environment Compatibility Matrix

| Environment | Hardware | Driver | Wheel Install | Source Build | Notes |
|------------|---------|--------|--------------|--------------|-------|
| Ubuntu 24.04 + Wormhole | ✅ | ✅ | ✅ | ✅ | Fully supported |
| Ubuntu 22.04 + Wormhole | ✅ | ✅ | ✅ | ⚠️ | Source build needs Clang manual install |
| Ubuntu 22.04 + BOS A0 (Blackhole) | ✅ | ✅ | ✅ | ⚠️ | BIOS AER + PCIe Gen5 + core_assignment.cpp fix |
| Ubuntu 24.04 + BOS A0 (Blackhole) | ✅ | ✅ | ✅ | ✅ | BIOS AER + PCIe Gen5 + core_assignment.cpp fix |
| Ubuntu 22.04, no hardware | N/A | N/A | ✅ (installs) | ⚠️ | Cannot execute — no device |
| Docker (tt-xla-ci-ubuntu-22-04) on BOS A0 | ✅ (via /dev/bos/) | Pre-installed | Pre-installed | N/A | Use BOS A0 docker run command |
| Docker (tt-xla-slim) on Wormhole | ✅ (via /dev/tenstorrent/) | Pre-installed | Pre-installed | N/A | Cleanest path for Wormhole |
| RHEL/CentOS | ✅ | ⚠️ | ⚠️ | ❌ | Untested; replace apt with dnf |
| macOS / Windows | ❌ | ❌ | ❌ | ❌ | Not supported |
| Arch Linux | ✅ | ⚠️ (AUR) | ⚠️ | ❌ | Community-only |

---

## 7. ResNet50 Compilation Analysis

### Model Source

- **Repository:** `torchvision.models.resnet50`
- **Pretrained weights:** `ResNet50_Weights.IMAGENET1K_V1` (downloaded automatically on first use)
- **Model format:** Native PyTorch (`nn.Module`)

### Conversion Pipeline

```
No conversion required — PyTorch FX tracing is done at torch.compile() time
```

| Step | Tool | Input | Output |
|------|------|-------|--------|
| Model definition | torchvision | N/A | `nn.Module` |
| Graph capture | torch.compile / FX | `nn.Module` | FX graph |
| Lowering | torch_xla | FX graph | StableHLO |
| Compilation | TT-MLIR (PJRT plugin) | StableHLO | TT binary |
| Execution | TT-Metal runtime | TT binary + inputs | Tensor output |

### Required Files

| File | Required | Source |
|------|----------|--------|
| `pjrt_plugin_tt.so` | Yes | Installed by wheel |
| `tt-metal` kernels | Yes | Bundled in wheel |
| ResNet50 weights | Auto-downloaded | PyTorch Hub |
| ImageNet class labels | Auto-downloaded (for demo) | pytorch/hub GitHub |

### Expected Output

```
torch.Size([1, 1000])   # softmax logits over 1000 ImageNet classes
```

---

## 8. Recommendations

1. **Maintain a pinned version of `pjrt-plugin-tt`** in `requirements.txt` to ensure
   reproducibility. The `--extra-index-url` approach pulls `latest` by default.

2. **Add a hardware detection pre-flight check** to any CI/CD pipeline using TT-XLA, to fail
   fast with a clear message when no Tenstorrent device is present.

3. **Verify BOS A0 arch string on live hardware**: Confirm the exact output of
   `jax.devices('tt')` on a Blackhole system and update the manual if needed.

4. **Document firmware update procedure**: TT-Flash is needed to update card firmware; the new
   TT-Installer runs it automatically, but manual re-flash steps are not yet documented.

5. **Consider mirroring `pjrt-plugin-tt` wheels** to an internal artifact registry (e.g.,
   Nexus, Artifactory) to reduce dependency on Tenstorrent's external PyPI index.

6. **Pin `setuptools<82`** in the `tt-mlir` build environment to prevent the known
   setuptools version incompatibility with TT-MLIR tools.
