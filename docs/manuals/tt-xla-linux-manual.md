# TT-XLA Linux Installation and Usage Manual

**Tool:** TT-XLA (Tenstorrent XLA)  
**Version:** latest (as of 2026)  
**Audience:** Beginners in AI and Linux  
**Sources:** [GitHub tenstorrent/tt-xla](https://github.com/tenstorrent/tt-xla) · [Official Getting Started](https://raw.githubusercontent.com/tenstorrent/tt-xla/main/docs/src/getting_started.md) · [BOS Internal Tutorial](https://bos-semi.atlassian.net/wiki/spaces/AIMultimed/pages/337346574/TT-XLA+Installation)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [For BOS A0 (Blackhole) — Hardware and BIOS Setup](#3-for-bos-a0-blackhole--hardware-and-bios-setup)
4. [Software Installation — Driver and Kernel Module](#4-software-installation--driver-and-kernel-module)
5. [Software Installation — Option A: Wheel (Recommended)](#5-software-installation--option-a-wheel-recommended)
6. [Software Installation — Option B: Docker](#6-software-installation--option-b-docker)
7. [Software Installation — Option C: Build from Source](#7-software-installation--option-c-build-from-source)
8. [ResNet50 PyTorch Model — Discovery and Compilation](#8-resnet50-pytorch-model--discovery-and-compilation)
9. [Running Inference](#9-running-inference)
10. [Expected Outputs](#10-expected-outputs)
11. [Troubleshooting](#11-troubleshooting)
12. [Replay Checklist](#12-replay-checklist)

---

## 1. Overview

TT-XLA is an AI compiler front-end for Tenstorrent hardware. It bridges PyTorch and JAX to
Tenstorrent's ML accelerators via the **PJRT** (Portable JAX Runtime) interface.

**Pipeline:**
```
PyTorch model
    → torch_xla (FX trace + decomposition)
    → StableHLO graph
    → TT-MLIR compiler
    → Tenstorrent hardware (NPU)
```

TT-XLA currently supports:
- **PyTorch** — via `torch.compile(model, backend="tt")` (uses torch-xla under the hood)
- **JAX** — via `jax.jit(fn)` with the `jax_plugin_tt` backend

---

## 2. Prerequisites

### Hardware

| Requirement | Wormhole (n150/n300) | BOS A0 — Blackhole (p100a/p150a/p150b) |
|-------------|---------------------|----------------------------------------|
| PCIe card | Wormhole n150 or n300 | Blackhole p100a, p150a, or p150b |
| PCIe slot | Gen 3 x16 or better | **Gen 5.0 x16** (required; no bifurcation) |
| Power connector | Standard 8-pin or 6+2 PCIe | **12+4-pin 12V-2x6** (ATX 3.1 certified PSU required) |
| Adjacent slot | Not required | Leave empty for airflow (p100a/p150a are dual-slot) |
| RAM | ≥ 32 GB recommended | ≥ 32 GB recommended |
| Hugepages | Configured by installer | Configured by installer |

> **BOS A0 note:** The Blackhole family (p100a, p150a, p150b) uses PCIe Gen 5.0 and a 12+4-pin
> power connector. An ATX 3.1 certified power supply is required. Using an older PSU may cause
> system instability. The p150b uses a passive heatsink and is designed for rack-mounted systems.

### Operating System

| Requirement | Details |
|-------------|---------|
| OS | Ubuntu 22.04 LTS or Ubuntu 24.04 LTS (strongly recommended) |
| Kernel | ≥ 5.15 |
| Architecture | x86_64 |

### Python

| Option | Python Version |
|--------|---------------|
| Wheel install | Python 3.11 or 3.12 |
| Build from source | Python 3.12 (required by build system) |

### Software Tools Required

```bash
# Minimum required tools (check with which/--version):
git --version          # >= 2.30
python3 --version      # >= 3.11
pip --version          # >= 23
lspci                  # to verify hardware detection
curl                   # to download the TT-Installer
jq                     # required by TT-Installer (see Section 4)
```

---

## 3. For BOS A0 (Blackhole) — Hardware and BIOS Setup

> **Note:** This section is specific to **BOS A0** systems using Tenstorrent Blackhole cards
> (p100a, p150a, p150b). If you are using a Wormhole card (n150, n300), skip to [Section 4](#4-software-installation--driver-and-kernel-module).

### 3.1 Physical Installation

Before powering on, complete the following steps:

1. **Disconnect power** from the host computer.
2. Verify the motherboard has a **PCIe Gen 5.0 x16 slot** (no bifurcation).
3. Insert the Blackhole add-in board into the PCIe x16 slot and secure it with the retaining screw.
4. Leave the **adjacent PCIe slot empty** (p100a and p150a are dual-slot boards with active
   coolers; airflow through the adjacent gap is required).
5. Connect a **12+4-pin 12V-2x6 power cable** to the connector on the back of the card.
   Ensure the cable is fully and securely seated.
6. Connect power and power on the system.

> ⚠️ An **ATX 3.1 certified power supply** is required. Older PSUs with standard 8-pin PCIe
> connectors are not compatible with the 12V-2x6 connector.

### 3.2 BIOS Configuration (Required for BOS A0)

Two BIOS settings must be configured before running TT-SMI or the TT-Installer.

#### 3.2.1 Set PCIe AER Reporting Mechanism to "OS First"

Tenstorrent's `tt-smi` management tool requires the PCIe AER (Advanced Error Reporting) mechanism
to be handled by the OS, not the firmware.

1. Enter the BIOS/UEFI setup (usually `Del`, `F2`, or `F12` at boot).
2. Navigate to the PCIe or chipset settings. The exact menu path varies by motherboard vendor;
   look for a setting called **"PCIe AER Reporting Mechanism"**, **"PCIe Error Reporting"**,
   or similar under **Motherboard Information** or **Advanced > PCIe Subsystem**.
3. Set the value to **"OS First"** (or **"OS Native"** on some platforms).
4. Save and exit.

> **Note:** If you update or reset your BIOS, you must reconfigure this setting.
> If you are using a TT-QuietBox appliance, this setting is already correct and can be skipped.

#### 3.2.2 Force PCIe Speed to Gen 5 (Do Not Use "Auto")

Some motherboards fail to enumerate Blackhole cards when PCIe speed is set to "Auto".

1. In BIOS, find the PCIe speed setting for the target slot (e.g. **"PCIe Link Speed"** or
   **"PCIE x16 Speed"**).
2. Set it explicitly to **Gen 5.0** (or Gen 4.0 if Gen 5.0 causes issues).
3. Save and exit.

### 3.3 Verify Hardware Detection

After completing BIOS setup, boot into Linux and confirm the card is enumerated:

```bash
lspci | grep -i tenstorrent
# Expected output for Blackhole:
# 01:00.0 Processing accelerators: Tenstorrent Inc. Blackhole (rev 01)

# Alternative using Tenstorrent's PCI vendor ID:
lspci -d 1e52:
```

If no output appears, the card was not detected — recheck power connection, PCIe slot, and BIOS
speed settings.

### 3.4 Check Firmware LED

After power-on, verify:
- The **fan spins** (for p100a/p150a).
- The **green power LED** on the card illuminates.

If neither is observed, the power cable may not be properly connected.

---

## 4. Software Installation — Driver and Kernel Module

> **Note:** This step applies to all Tenstorrent hardware (Wormhole and Blackhole/BOS A0).

The recommended installation path is the **TT-Installer** script, which automatically installs:
- `tt-kmd` — the kernel module (driver)
- `tt-flash` — firmware update utility
- system firmware (flashed to the card)
- hugepage configuration
- `tt-smi` — the Tenstorrent System Management Interface

### 4.1 Install Prerequisites

```bash
sudo apt update && sudo apt install -y curl jq
```

### 4.2 Run the TT-Installer

```bash
/bin/bash -c "$(curl -fsSL https://github.com/tenstorrent/tt-installer/releases/latest/download/install.sh)"
```

During the installation you will be prompted interactively:
- **"OK to continue?"** — answer `Y`
- **sudo password** — enter your user password
- **Install TT-Metalium container?** — answer `Y` if you need TT-NN; answer `N` for TT-XLA only
- **Install Model Demos container?** — answer `N` unless you need pre-built model demos (large, ~10 GB)
- **Python package location** — press Enter to accept the default (new venv at `~/.tenstorrent-venv`)
- **"Would you like to reboot now?"** — answer `Y` (required on first install)

> **Source:** https://docs.tenstorrent.com/getting-started/README.html

### 4.3 Verify After Reboot

After rebooting, activate the environment and run `tt-smi`:

```bash
source ~/.tenstorrent-venv/bin/activate
tt-smi
```

**Expected output:** The `tt-smi` interface shows one or more Tenstorrent devices under the
"Device Information" pane. For a single Blackhole p150a, you will see one device entry.

Alternatively, check device files directly:

```bash
ls /dev/tenstorrent/
# Expected: 0  (or 0 1 2 ... for multi-card setups)
```

### 4.4 Verify Hugepages

```bash
grep -i hugepage /proc/meminfo
# Expected: HugePages_Total should be >= 1
```

If `HugePages_Total` is 0, configure manually:

```bash
sudo sysctl -w vm.nr_hugepages=4
echo 'vm.nr_hugepages=4' | sudo tee -a /etc/sysctl.conf
```

---

## 5. Software Installation — Option A: Wheel (Recommended)

This is the fastest way to get started running models on Tenstorrent hardware.

### 5.1 Create a Python Virtual Environment

```bash
# Use Python 3.11 or 3.12
python3.11 -m venv ~/.tt-xla-venv
# Or with Python 3.12:
# python3.12 -m venv ~/.tt-xla-venv

source ~/.tt-xla-venv/bin/activate
pip install --upgrade pip wheel setuptools
```

### 5.2 Install the TT-XLA PJRT Plugin Wheel

```bash
# Install from Tenstorrent's private PyPI index
pip install pjrt-plugin-tt \
    --extra-index-url https://pypi.eng.aws.tenstorrent.com/
```

> **Source:** https://github.com/tenstorrent/tt-xla — Getting Started docs

This installs:
- `pjrt_plugin_tt.so` — the compiled PJRT C++ plugin
- `jax_plugin_tt` — thin JAX wrapper
- `torch_plugin_tt` — thin PyTorch/XLA wrapper
- `tt-metal` — runtime kernels and dependencies

### 5.3 Install PyTorch and torchvision (for ResNet50)

```bash
# Install PyTorch (CPU build sufficient for tracing; TT device handles compute)
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Install torch-xla (Tenstorrent's fork is bundled inside pjrt-plugin-tt,
# but if a standalone torch-xla is needed):
pip install torch-xla
```

### 5.4 Verify Installation

```bash
python3 -c "import jax; print(jax.devices('tt'))"
# Expected for Wormhole:  [TTDevice(id=0, arch=Wormhole_b0)]
# Expected for BOS A0:    [TTDevice(id=0, arch=blackhole)]

python3 -c "import torch_plugin_tt; print('torch_plugin_tt loaded OK')"
```

---

## 6. Software Installation — Option B: Docker

Use this option to keep your environment isolated or if you do not want to modify the host system.

### 6.1 Install Docker

```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor \
    -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo usermod -aG docker "$USER" && newgrp docker
```

### 6.2 Run TT-XLA Docker Container

```bash
docker run -it --rm \
    --device /dev/tenstorrent \
    -v /dev/hugepages-1G:/dev/hugepages-1G \
    ghcr.io/tenstorrent/tt-xla-slim:latest
```

> **Important:** Pass `--device /dev/tenstorrent` (the directory), not individual numbered devices
> like `/dev/tenstorrent/0`. Using specific device numbers causes fatal errors at runtime.

### 6.3 Inside the Container

```bash
# The PJRT plugin is pre-installed inside the image.
# Install demo dependencies:
pip install flax transformers torch torchvision

# Verify:
python3 -c "import jax; print(jax.devices('tt'))"
```

---

## 7. Software Installation — Option C: Build from Source

> **Use this option only if you are developing TT-XLA itself.**
> It requires Ubuntu 24.04 and takes 30–60+ minutes to build.

### 7.1 System Dependencies

```bash
sudo apt-get update
sudo apt-get install -y \
    git cmake ninja-build \
    clang-20 gcc-13 g++-13 \
    python3.12 python3.12-venv python3.12-dev \
    protobuf-compiler libprotobuf-dev \
    ccache \
    libnuma-dev \
    libhwloc-dev \
    libboost-all-dev \
    libnsl-dev

# Ensure clang-20 is the default:
sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-20 100
sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-20 100
```

### 7.2 Build TT-MLIR Toolchain (Required Dependency)

```bash
# Clone tt-mlir
git clone https://github.com/tenstorrent/tt-mlir.git
cd tt-mlir

# Follow tt-mlir build instructions:
# https://docs.tenstorrent.com/tt-mlir/getting-started.html#setting-up-the-environment-manually

# After building, set the required environment variable:
export TTMLIR_TOOLCHAIN_DIR=/opt/ttmlir-toolchain  # Adjust path as needed
cd ..
```

### 7.3 Clone and Build TT-XLA

```bash
git clone https://github.com/tenstorrent/tt-xla.git
cd tt-xla

# Pull all submodules (this includes tt-metal, third-party libs, etc.)
git submodule update --init --recursive

# Activate the bundled virtual environment
source venv/activate

# Configure and build with Ninja
cmake -G Ninja -B build
# For debug build add: -DCMAKE_BUILD_TYPE=Debug
cmake --build build
```

### 7.4 Verify Source Build

```bash
python3 -c "import jax; print(jax.devices('tt'))"
# Expected for Wormhole:  [TTDevice(id=0, arch=Wormhole_b0)]
# Expected for BOS A0:    [TTDevice(id=0, arch=blackhole)]
```

### 7.5 (Optional) Build the Wheel

```bash
cd python_package
python setup.py bdist_wheel
pip install dist/pjrt_plugin_tt*.whl
```

---

## 8. ResNet50 PyTorch Model — Discovery and Compilation

### 8.1 Model Source

ResNet50 is available directly from `torchvision.models` — no download or export is required
before passing it to TT-XLA.

```bash
pip install torchvision
```

### 8.2 How TT-XLA Compiles a PyTorch Model

TT-XLA uses `torch.compile(model, backend="tt")` which triggers the following pipeline:

```
torch.compile(model, backend="tt")
    ↓
FX tracing (PyTorch → computation graph)
    ↓
Custom decompositions & optimizations
    ↓
torch_xla StableHLO export
    ↓
TT-MLIR compiler (PJRT plugin)
    ↓
Binary for Tenstorrent NPU
```

> **No ONNX export, no separate conversion step is needed** for PyTorch models.
> `torch.compile` handles all graph lowering internally.

### 8.3 Create the ResNet50 Inference Script

Create the file `run_resnet50_tt.py`:

```python
#!/usr/bin/env python3
"""
ResNet50 inference on Tenstorrent hardware via TT-XLA.

Sources:
  - https://github.com/tenstorrent/tt-xla
  - https://docs.tenstorrent.com/tt-xla/
  - torchvision.models.resnet50
"""

import torch
import torchvision.models as models
import torchvision.transforms as transforms
from PIL import Image
import urllib.request
import os

# ── 1. Load TT-XLA backend ────────────────────────────────────────────────────
# Importing torch_plugin_tt registers the "tt" backend with torch.compile
import torch_plugin_tt  # noqa: F401  (side-effect import)

# ── 2. Load ResNet50 pretrained weights ───────────────────────────────────────
print("[INFO] Loading ResNet50 pretrained weights...")
weights = models.ResNet50_Weights.IMAGENET1K_V1
model = models.resnet50(weights=weights)
model.eval()

# ── 3. Compile model for Tenstorrent hardware ─────────────────────────────────
print("[INFO] Compiling ResNet50 with TT-XLA backend...")
compiled_model = torch.compile(model, backend="tt")

# ── 4. Prepare a sample input image ──────────────────────────────────────────
# Download a sample image if not already present
sample_img_url = (
    "https://upload.wikimedia.org/wikipedia/commons/thumb/4/43/"
    "Cute_dog.jpg/320px-Cute_dog.jpg"
)
sample_img_path = "/tmp/sample_dog.jpg"
if not os.path.exists(sample_img_path):
    print(f"[INFO] Downloading sample image to {sample_img_path} ...")
    urllib.request.urlretrieve(sample_img_url, sample_img_path)

# ImageNet preprocessing pipeline
preprocess = transforms.Compose([
    transforms.Resize(256),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize(
        mean=[0.485, 0.456, 0.406],
        std=[0.229, 0.224, 0.225],
    ),
])

img = Image.open(sample_img_path).convert("RGB")
input_tensor = preprocess(img).unsqueeze(0)  # shape: [1, 3, 224, 224]

# ── 5. Run inference ──────────────────────────────────────────────────────────
print("[INFO] Running inference on Tenstorrent device...")
with torch.no_grad():
    output = compiled_model(input_tensor)

# ── 6. Decode and print top-5 predictions ────────────────────────────────────
probabilities = torch.nn.functional.softmax(output[0], dim=0)
top5_prob, top5_catid = torch.topk(probabilities, 5)

# Load ImageNet class labels
categories_url = (
    "https://raw.githubusercontent.com/pytorch/hub/master/imagenet_classes.txt"
)
categories_path = "/tmp/imagenet_classes.txt"
if not os.path.exists(categories_path):
    urllib.request.urlretrieve(categories_url, categories_path)
with open(categories_path) as f:
    categories = [line.strip() for line in f.readlines()]

print("\n[RESULT] Top-5 Predictions:")
for i in range(top5_prob.size(0)):
    print(f"  {categories[top5_catid[i]]}: {top5_prob[i].item() * 100:.2f}%")
```

### 8.4 Run the Script

```bash
# Ensure the venv with pjrt-plugin-tt is active
source ~/.tt-xla-venv/bin/activate

python run_resnet50_tt.py
```

---

## 9. Running Inference

### 9.1 Minimal Smoke Test (no image required)

```python
import torch
import torchvision.models as models
import torch_plugin_tt  # registers "tt" backend

model = models.resnet50(weights=None)
model.eval()

compiled_model = torch.compile(model, backend="tt")

dummy_input = torch.randn(1, 3, 224, 224)
with torch.no_grad():
    out = compiled_model(dummy_input)

print("Output shape:", out.shape)  # Expected: torch.Size([1, 1000])
```

### 9.2 JAX Quick Test (alternative)

```python
import jax
import jax.numpy as jnp
import jax_plugin_tt  # registers "tt" backend for JAX

print("TT devices:", jax.devices("tt"))

@jax.jit
def matmul(a, b):
    return jnp.matmul(a, b)

a = jnp.ones((128, 128))
b = jnp.ones((128, 128))
result = matmul(a, b)
print("JAX matmul result shape:", result.shape)
```

---

## 10. Expected Outputs

### Device Detection

```
# Wormhole cards (n150/n300):
[TTDevice(id=0, arch=Wormhole_b0)]

# BOS A0 — Blackhole cards (p100a/p150a/p150b):
[TTDevice(id=0, arch=blackhole)]
```

### ResNet50 Compilation Log (first run)

```
[INFO] Loading ResNet50 pretrained weights...
[INFO] Compiling ResNet50 with TT-XLA backend...
# Compilation may take 30–120 seconds on first run (graph is cached afterwards)
[INFO] Running inference on Tenstorrent device...

[RESULT] Top-5 Predictions:
  golden retriever: 87.43%
  Labrador retriever: 6.21%
  ...
```

### Inference Output Tensor Shape

```
Output shape: torch.Size([1, 1000])
```

---

## 11. Troubleshooting

### `No TT devices found` / `jax.devices('tt')` returns empty

1. Verify the kernel module is loaded:
   ```bash
   lsmod | grep tt
   ls /dev/tenstorrent/
   ```
2. Re-run the TT-Installer:
   ```bash
   /bin/bash -c "$(curl -fsSL https://github.com/tenstorrent/tt-installer/releases/latest/download/install.sh)"
   sudo reboot
   ```
3. Check hugepages:
   ```bash
   grep HugePages /proc/meminfo
   ```

### BOS A0 (Blackhole) card not detected by `lspci`

1. Verify the power LED is lit and the fan is spinning (p100a/p150a only).
2. Check the 12+4-pin 12V-2x6 power cable is fully inserted.
3. In BIOS, confirm the PCIe slot speed is forced to Gen 5 (not "Auto").
4. Reseat the card and retry.
5. Use the Tenstorrent PCI vendor ID to check:
   ```bash
   lspci -d 1e52:
   ```
   If this returns nothing, the card failed to enumerate — check power and BIOS settings.

### `tt-smi` shows no devices or crashes

On Blackhole hardware, `tt-smi` requires the PCIe AER reporting mode to be set to "OS First" in
BIOS. Without this, `tt-smi` may show no devices or exit unexpectedly. See [Section 3.2.1](#321-set-pcie-aer-reporting-mechanism-to-os-first).

### `ImportError: cannot import name 'torch_plugin_tt'`

The `pjrt-plugin-tt` wheel was not installed or the wrong venv is active:
```bash
source ~/.tt-xla-venv/bin/activate
pip install pjrt-plugin-tt --extra-index-url https://pypi.eng.aws.tenstorrent.com/
```

### `clang: error: unknown argument: '-march=...'` (build from source)

Ensure `clang-20` is installed and is the default clang:
```bash
clang --version  # must say 20.x
sudo apt-get install -y clang-20
sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-20 100
```

### Python version mismatch during build

Clear the Bazel/CMake cache and rebuild:
```bash
rm -rf build/
cmake -G Ninja -B build
cmake --build build
```

### `torch.compile` hangs or takes very long (first run)

On first invocation, the model graph is compiled to a TT binary. This is expected and can take
1–3 minutes for ResNet50. Subsequent runs use the cached compilation result.

### `fatal error: hugepages` / memory allocation failures

```bash
# Check and configure hugepages manually:
cat /proc/sys/vm/nr_hugepages
sudo sysctl -w vm.nr_hugepages=4
echo 'vm.nr_hugepages=4' | sudo tee -a /etc/sysctl.conf
```

### Docker: device not found inside container

```bash
# Verify the device exists on the host first:
ls /dev/tenstorrent/
# Then re-run with the correct device flag:
docker run -it --rm --device /dev/tenstorrent ...
# Do NOT use --device /dev/tenstorrent/0 (specific number)
```

---

## 12. Replay Checklist

Use this checklist to verify a fresh install from scratch.

### For all hardware (Wormhole and BOS A0 / Blackhole)

- [ ] Tenstorrent PCIe card is physically installed and detected (`lspci | grep -i tenstorrent`)
- [ ] `ls /dev/tenstorrent/` shows at least one device file
- [ ] Hugepages are configured (`grep HugePages_Total /proc/meminfo` ≥ 1)
- [ ] Python 3.11 or 3.12 virtual environment created and activated
- [ ] `pip install pjrt-plugin-tt --extra-index-url https://pypi.eng.aws.tenstorrent.com/` succeeds
- [ ] `python3 -c "import jax; print(jax.devices('tt'))"` shows a TT device
- [ ] `pip install torch torchvision` succeeds
- [ ] `python3 -c "import torch_plugin_tt; print('OK')"` succeeds
- [ ] ResNet50 smoke test runs without errors: `python run_resnet50_tt.py`
- [ ] Output shape is `torch.Size([1, 1000])`
- [ ] (Optional) JAX matmul test passes

### Additional checks for BOS A0 (Blackhole only)

- [ ] ATX 3.1 certified PSU connected with 12+4-pin 12V-2x6 cable
- [ ] Adjacent PCIe slot is empty (for airflow)
- [ ] BIOS: PCIe AER Reporting Mechanism set to "OS First"
- [ ] BIOS: PCIe slot speed forced to Gen 5 (not "Auto")
- [ ] Card power LED is lit and fan spins (p100a/p150a)
- [ ] `lspci -d 1e52:` shows a Tenstorrent device entry
- [ ] `tt-smi` shows the Blackhole device in the Device Information pane
- [ ] `jax.devices('tt')` returns `arch=blackhole`
