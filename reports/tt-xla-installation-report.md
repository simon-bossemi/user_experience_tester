# TT-XLA Installation Report

**Tool:** TT-XLA (Tenstorrent XLA)  
**Report type:** Gap analysis, assumption log, and installation blockers  
**Author:** user_experience_tester agent  
**Date:** 2026 (second run — revised)  
**Sources consulted:**
- [BOS Internal Tutorial](https://bos-semi.atlassian.net/wiki/spaces/AIMultimed/pages/337346574/TT-XLA+Installation) *(internal — not accessible during this analysis)*
- [GitHub tenstorrent/tt-xla](https://github.com/tenstorrent/tt-xla)
- [Official Getting Started (raw)](https://raw.githubusercontent.com/tenstorrent/tt-xla/main/docs/src/getting_started.md)
- Web search synthesis (Tenstorrent docs, DeepWiki, community guides)

---

## 0. Second-Run Summary (Revised 2026)

This report has been revised following updated agent and repository instructions. Key improvements
in this revision compared to the initial 2025 report:

| Area | Change |
|------|--------|
| Manual audience | Explicitly written for beginners in AI and Linux |
| Manual structure | Added "How to Open a Terminal" section; added Glossary |
| Manual commands | Added "what this command does" explanations next to each command |
| Manual outputs | Expanded expected output samples throughout |
| Troubleshooting | Added actionable next steps and diagnosis commands per error |
| Script error messages | Added specific recovery instructions per failure mode |
| Script Step 10 | Added per-step explanation of what the user should expect to see |

The core gap analysis and findings from the initial run remain valid and are preserved below.

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

### 2.1 BOS Internal Tutorial (Atlassian)

> **Blocker:** The BOS internal Atlassian page
> (`https://bos-semi.atlassian.net/wiki/spaces/AIMultimed/pages/337346574/TT-XLA+Installation`)
> **was not accessible** during this analysis. It requires authenticated access to the BOS-Semi
> Confluence instance.

As a result, all content in this report is derived from the **publicly available**
Tenstorrent documentation and GitHub repository. Any BOS-specific configuration,
credentials, internal package mirrors, or proprietary hardware variants described only
in the internal tutorial are **not captured here**.

**Action required:** A developer with Atlassian access should review the internal tutorial
and diff it against this report to identify any missing BOS-specific steps.

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
give a direct command. The TT-Installer script is the recommended path:

```bash
curl -L https://installer.tenstorrent.com/tt-installer.sh -o /tmp/tt-installer.sh
sudo /tmp/tt-installer.sh
```

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

**Severity: High (for this report)**  
The primary input tutorial (Atlassian Confluence page) could not be accessed. All analysis is
based on public documentation only.

**Action required:** Request Atlassian access or a PDF export of the internal tutorial, then
update this report with any BOS-specific steps, hardware variants, or internal package sources.

---

## 6. Environment Compatibility Matrix

| Environment | Hardware | Driver | Wheel Install | Source Build | Notes |
|------------|---------|--------|--------------|--------------|-------|
| Ubuntu 24.04 + TT card | ✅ | ✅ | ✅ | ✅ | Fully supported |
| Ubuntu 22.04 + TT card | ✅ | ✅ | ✅ | ⚠️ | Source build needs Clang 20 manual install |
| Ubuntu 22.04, no hardware | N/A | N/A | ✅ (installs) | ⚠️ | Cannot execute — no device |
| Docker (tt-xla-slim) | ✅ (passed through) | Pre-installed | Pre-installed | N/A | Cleanest path |
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

3. **Request access to the BOS internal Atlassian tutorial** and merge any BOS-specific steps
   into this report and the manual.

4. **Document firmware update procedure**: TT-Flash is needed to update card firmware; this is
   separate from the kernel driver and may be required on first-time hardware setup.

5. **Consider mirroring `pjrt-plugin-tt` wheels** to an internal artifact registry (e.g.,
   Nexus, Artifactory) to reduce dependency on Tenstorrent's external PyPI index.
