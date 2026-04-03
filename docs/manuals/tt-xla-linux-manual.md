# TT-XLA Linux Installation and Usage Manual

**Tool:** TT-XLA (Tenstorrent XLA)  
**Version:** latest (as of 2026)  
**Audience:** Beginners in AI and Linux  
**Sources:** [GitHub tenstorrent/tt-xla](https://github.com/tenstorrent/tt-xla) · [Official Getting Started](https://raw.githubusercontent.com/tenstorrent/tt-xla/main/docs/src/getting_started.md) · [BOS Internal Tutorial](https://bos-semi.atlassian.net/wiki/spaces/AIMultimed/pages/337346574/TT-XLA+Installation)

---

## Table of Contents

1. [Overview and Key Concepts](#1-overview-and-key-concepts)
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

## 1. Overview and Key Concepts

### What is TT-XLA?

TT-XLA is a software tool that lets you run AI models (like image classifiers or language models)
on **Tenstorrent** AI accelerator cards. Instead of using a GPU, your AI computation runs on
Tenstorrent's custom chip, which is designed specifically for AI workloads.

### How Does It Work?

When you write an AI model in Python using PyTorch, TT-XLA automatically converts it into a
format the Tenstorrent chip can execute. You do not need to rewrite your model — just add one
line: `torch.compile(model, backend="tt")`.

**Step-by-step pipeline:**

```
Your PyTorch model (Python)
       ↓
FX tracing — PyTorch reads your model and builds a computation graph
       ↓
StableHLO — a standard AI compiler format
       ↓
TT-MLIR compiler — converts to Tenstorrent chip instructions
       ↓
Tenstorrent NPU (the AI accelerator card in your PC)
       ↓
Result tensor (numbers representing predictions)
```

### What Is ResNet50?

ResNet50 is a well-known image classification AI model. Given an image, it outputs probabilities
for 1000 different categories (e.g., "golden retriever: 87%", "car: 2%"). It is a popular
benchmark model and is available in the `torchvision` Python library with no manual download.

---

## 2. Prerequisites

### 2.1 Hardware

You **must** have a physical Tenstorrent PCIe card installed inside your computer.
TT-XLA cannot run AI models on CPU or without this card.

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

### 2.2 Operating System

| Requirement | Details |
|-------------|---------|
| OS | **Ubuntu 22.04 LTS** or **Ubuntu 24.04 LTS** (strongly recommended) |
| Kernel | ≥ 5.15 (check with `uname -r`) |
| Architecture | x86_64 (64-bit Intel or AMD processor) |

> **Linux beginner tip:** If you are not sure which Ubuntu version you have, run:
> ```bash
> lsb_release -a
> ```
> You will see output like `Ubuntu 22.04.3 LTS`.

### 2.3 Python

| Option | Python Version | Notes |
|--------|---------------|-------|
| Wheel install (recommended) | Python 3.11 or 3.12 | Works on Ubuntu 22.04+ |
| Build from source | Python 3.12 **required** | Only for advanced users |

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

This is the **fastest and simplest** way to get started. A **wheel** is a pre-compiled Python
package — no compiling needed on your side.

### 5.1 Create a Python Virtual Environment

```bash
# Create a virtual environment using Python 3.11
python3.11 -m venv ~/.tt-xla-venv
```

**What this does:** Creates a folder at `~/.tt-xla-venv` containing a private Python installation.

> If you have Python 3.12 instead of 3.11, use:
> ```bash
> python3.12 -m venv ~/.tt-xla-venv
> ```

Now **activate** the virtual environment (you must do this every time you open a new terminal):

```bash
source ~/.tt-xla-venv/bin/activate
```

**Expected output:** Your prompt will change to show the environment name:
```
(.tt-xla-venv) yourname@hostname:~$
```

The `(.tt-xla-venv)` prefix confirms the environment is active.

Upgrade the package management tools:

```bash
pip install --upgrade pip wheel setuptools
```

### 5.2 Install the TT-XLA PJRT Plugin Wheel

```bash
pip install pjrt-plugin-tt \
    --extra-index-url https://pypi.eng.aws.tenstorrent.com/
```

**What this does:** Downloads and installs the TT-XLA plugin from Tenstorrent's package server.
The `--extra-index-url` flag tells `pip` to also look at Tenstorrent's private index, since the
package is not on the main PyPI server.

**This single package installs everything needed:**
- `pjrt_plugin_tt.so` — compiled C++ plugin that bridges PyTorch to the card
- `jax_plugin_tt` — JAX backend wrapper
- `torch_plugin_tt` — PyTorch backend wrapper
- `tt-metal` — low-level Tenstorrent runtime kernels

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

**Why CPU wheel?** The Tenstorrent NPU is the compute target, not a GPU. Installing the CPU
version of PyTorch saves ~1 GB of unnecessary CUDA libraries.

**Expected output:**
```
Successfully installed torch-2.x.x torchvision-0.x.x
```

### 5.4 Verify the Installation

Run these two checks to confirm everything is working:

**Check 1 — JAX sees the TT device:**
```bash
python3 -c "import jax; print(jax.devices('tt'))"
```

**Expected output:**
```
[TTDevice(id=0, arch=Wormhole_b0)]
```

**Check 2 — PyTorch backend registered:**
```bash
python3 -c "import torch_plugin_tt; print('torch_plugin_tt loaded OK')"
```

**Expected output:**
```
torch_plugin_tt loaded OK
```

> If Check 1 shows an empty list `[]` or an error, see [Section 11 — Troubleshooting](#11-troubleshooting).

---

## 6. Software Installation — Option B: Docker

Use this option if you want a fully isolated environment or you do not want to modify your host
system. Docker packages everything (OS libraries, Python, TT-XLA) into a container.

### 6.1 Install Docker

```bash
# Update package lists
sudo apt-get update

# Install Docker prerequisites
sudo apt-get install -y ca-certificates curl gnupg

# Add Docker's official GPG key (verifies packages are from Docker, not impostors)
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor \
    -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add the Docker software repository to apt
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
    | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Allow your user to run Docker without sudo (requires logging out and back in)
sudo usermod -aG docker "$USER"
newgrp docker
```

### 6.2 Run TT-XLA Docker Container

```bash
docker run -it --rm \
    --device /dev/tenstorrent \
    -v /dev/hugepages-1G:/dev/hugepages-1G \
    ghcr.io/tenstorrent/tt-xla-slim:latest
```

**What each flag does:**
- `-it` — interactive terminal (you get a shell inside the container)
- `--rm` — automatically delete the container when you exit
- `--device /dev/tenstorrent` — gives the container access to the Tenstorrent hardware
- `-v /dev/hugepages-1G:/dev/hugepages-1G` — shares hugepages memory with the container
- `ghcr.io/tenstorrent/tt-xla-slim:latest` — the container image (downloaded automatically)

### 6.3 Inside the Container

```bash
# Install Python packages needed for the ResNet50 demo
pip install torch torchvision Pillow

# Verify the TT device is accessible
python3 -c "import jax; print(jax.devices('tt'))"
```

**Expected output:**
```
[TTDevice(id=0, arch=Wormhole_b0)]
```

---

## 7. Software Installation — Option C: Build from Source

> ⚠️ **Use this option only if you are developing or modifying TT-XLA itself.**  
> Building from source requires Ubuntu 24.04 and takes **30–90 minutes** depending on your
> system. Most users should use Option A (wheel install).

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
```

Set Clang 20 as the system default (required by the build system):

```bash
sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-20 100
sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-20 100
```

### 7.2 Build TT-MLIR Toolchain (Required Dependency)

```bash
# Clone the TT-MLIR repository
git clone https://github.com/tenstorrent/tt-mlir.git
cd tt-mlir

# Follow the official TT-MLIR build instructions:
# https://docs.tenstorrent.com/tt-mlir/getting-started.html#setting-up-the-environment-manually

# After building, set the toolchain directory (adjust path if different):
export TTMLIR_TOOLCHAIN_DIR=/opt/ttmlir-toolchain
cd ..
```

### 7.3 Clone and Build TT-XLA

```bash
# Clone the TT-XLA repository
git clone https://github.com/tenstorrent/tt-xla.git
cd tt-xla

# Download all required submodules (tt-metal, third-party libs, etc.)
# This can take several minutes and requires good internet speed
git submodule update --init --recursive

# Activate the bundled virtual environment
source venv/activate

# Configure the build (Ninja is a fast build system, faster than make)
cmake -G Ninja -B build

# Build everything (this step takes 30–90 minutes)
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

ResNet50 ("Residual Network, 50 layers") is a convolutional neural network (CNN) trained to
classify images into 1000 categories from the ImageNet dataset. It is widely used as a
benchmark because it is well understood and available without any manual data preparation.

**You do not need to:**
- Download model weights manually (they download automatically)
- Convert the model to ONNX or any other format
- Write any C++ or low-level code

### 8.2 How TT-XLA Compiles a PyTorch Model

When you call `torch.compile(model, backend="tt")`, TT-XLA automatically:

1. **Traces** your model — PyTorch records every math operation the model performs
2. **Decomposes** the operations into standard primitives
3. **Exports** the computation graph as StableHLO (a portable AI representation)
4. **Compiles** the StableHLO graph using TT-MLIR to a binary for the Tenstorrent chip
5. **Caches** the compiled binary so future runs start instantly

> ℹ️ **First-run latency:** Compilation happens on the first call to `compiled_model(input)`.
> For ResNet50, this takes **30–120 seconds**. After the first run, the binary is cached and
> subsequent runs are fast. **Do not interrupt the process** if it appears to hang — wait.

### 8.3 Make Sure the Virtual Environment Is Active

Before running any Python code, activate the virtual environment:

```bash
source ~/.tt-xla-venv/bin/activate
```

### 8.2 How TT-XLA Compiles a PyTorch Model

### 8.4 Create the ResNet50 Inference Script

Create a new file called `run_resnet50_tt.py` in your current directory.
You can use any text editor. For example, using `nano` (beginner-friendly):

```bash
nano run_resnet50_tt.py
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

# ── 1. Register the TT backend with torch.compile ─────────────────────────────
# This import is required. It registers the "tt" backend as a side-effect.
# Without it, torch.compile(backend="tt") would raise an error.
import torch_plugin_tt  # noqa: F401

print("[INFO] torch_plugin_tt backend registered.")

# ── 2. Load ResNet50 with pretrained ImageNet weights ─────────────────────────
# Weights download automatically the first time (~100 MB). Cached afterwards.
print("[INFO] Loading ResNet50 with IMAGENET1K_V1 pretrained weights...")
weights = models.ResNet50_Weights.IMAGENET1K_V1
model = models.resnet50(weights=weights)
model.eval()  # Set model to inference mode (disables dropout, etc.)
print("[OK]   ResNet50 loaded.")

# ── 3. Compile the model for the Tenstorrent device ───────────────────────────
print("[INFO] Compiling ResNet50 with torch.compile(backend='tt') ...")
print("       ⏳ First compilation takes 30–120 seconds. Please wait.")
compiled_model = torch.compile(model, backend="tt")
print("[OK]   Model compiled.")

# ── 4. Prepare an input image ─────────────────────────────────────────────────
sample_img_path = "/tmp/tt_xla_sample_dog.jpg"
sample_img_url = (
    "https://upload.wikimedia.org/wikipedia/commons/thumb/4/43/"
    "Cute_dog.jpg/320px-Cute_dog.jpg"
)
if not os.path.exists(sample_img_path):
    print(f"[INFO] Downloading sample image → {sample_img_path}")
    urllib.request.urlretrieve(sample_img_url, sample_img_path)
else:
    print(f"[INFO] Using cached sample image: {sample_img_path}")

# Standard ImageNet preprocessing:
# - Resize so the short side is 256 px
# - Crop the centre 224×224 region
# - Convert to a tensor with values in [0, 1]
# - Normalize using ImageNet channel mean and std
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
input_tensor = preprocess(img).unsqueeze(0)  # Add batch dimension → [1, 3, 224, 224]
print(f"[OK]   Input tensor shape: {input_tensor.shape}")

# ── 5. Run inference on the Tenstorrent card ──────────────────────────────────
print("[INFO] Running inference on Tenstorrent device...")
with torch.no_grad():  # Disable gradient tracking (not needed for inference)
    output = compiled_model(input_tensor)
print(f"[OK]   Output shape: {output.shape}")  # Expected: torch.Size([1, 1000])

# ── 6. Decode top-5 predictions ───────────────────────────────────────────────
probabilities = torch.nn.functional.softmax(output[0], dim=0)
top5_prob, top5_catid = torch.topk(probabilities, 5)

categories_path = "/tmp/imagenet_classes.txt"
categories_url = "https://raw.githubusercontent.com/pytorch/hub/master/imagenet_classes.txt"
if not os.path.exists(categories_path):
    urllib.request.urlretrieve(categories_url, categories_path)
with open(categories_path) as f:
    categories = [line.strip() for line in f.readlines()]

print("\n[RESULT] Top-5 ImageNet Predictions:")
for i in range(top5_prob.size(0)):
    label = categories[top5_catid[i]]
    prob  = top5_prob[i].item() * 100
    print(f"  {i+1}. {label:<40} {prob:.2f}%")
```

### 8.4 Run the Script

```bash
# Make sure your virtual environment is active
source ~/.tt-xla-venv/bin/activate

# Run the script
python run_resnet50_tt.py
```

---

## 9. Running Inference

### 9.1 Minimal Smoke Test (no image required)

```python
import torch
import torchvision.models as models
import torch_plugin_tt  # registers "tt" backend — required before torch.compile

model = models.resnet50(weights=None)  # No pretrained weights needed for shape test
model.eval()

compiled_model = torch.compile(model, backend="tt")

# Create a random input with the correct shape: batch=1, channels=3, height=224, width=224
dummy_input = torch.randn(1, 3, 224, 224)

with torch.no_grad():
    out = compiled_model(dummy_input)

print("Output shape:", out.shape)
# Expected: Output shape: torch.Size([1, 1000])
```

### 9.2 JAX Quick Test (alternative)

```python
import jax
import jax.numpy as jnp
import jax_plugin_tt  # registers the "tt" backend for JAX

# Print all TT devices visible to JAX
print("TT devices:", jax.devices("tt"))
# Expected: TT devices: [TTDevice(id=0, arch=Wormhole_b0)]

# JIT-compile a simple matrix multiplication to run on the TT card
@jax.jit
def matmul(a, b):
    return jnp.matmul(a, b)

a = jnp.ones((128, 128))
b = jnp.ones((128, 128))
result = matmul(a, b)
print("JAX matmul result shape:", result.shape)
# Expected: JAX matmul result shape: (128, 128)
```

---

## 10. Expected Outputs

### 10.1 Installation Verification

After completing Section 5 (wheel install), you should see:

```
# Wormhole cards (n150/n300):
[TTDevice(id=0, arch=Wormhole_b0)]

# BOS A0 — Blackhole cards (p100a/p150a/p150b):
[TTDevice(id=0, arch=blackhole)]
```

### 10.2 Full ResNet50 Demo Run

A complete successful run of `python run_resnet50_tt.py` looks like this:

```
[INFO] torch_plugin_tt backend registered.
[INFO] Loading ResNet50 with IMAGENET1K_V1 pretrained weights...
Downloading: "https://download.pytorch.org/models/resnet50-0676ba61.pth" to ...
100%|█████████████████████| 97.8M/97.8M [00:12<00:00, 8.31MB/s]
[OK]   ResNet50 loaded.
[INFO] Compiling ResNet50 with torch.compile(backend='tt') ...
       ⏳ First compilation takes 30–120 seconds. Please wait.
[TT-MLIR] Compiling graph ...
[TT-MLIR] Compilation complete (47.3s)
[OK]   Model compiled.
[INFO] Downloading sample image → /tmp/tt_xla_sample_dog.jpg
[OK]   Input tensor shape: torch.Size([1, 3, 224, 224])
[INFO] Running inference on Tenstorrent device...
[OK]   Output shape: torch.Size([1, 1000])

[RESULT] Top-5 ImageNet Predictions:
  1. golden retriever                          87.43%
  2. Labrador retriever                        6.21%
  3. kuvasz                                    1.58%
  4. Great Pyrenees                            0.94%
  5. clumber spaniel                           0.87%
```

> **Note:** The exact percentage values will vary depending on the image used.
> What matters is that `Output shape: torch.Size([1, 1000])` appears and predictions are printed.

### 10.3 Hardware Detection

```bash
$ lspci | grep -i tenstorrent
01:00.0 Processing accelerators: Tenstorrent Inc. Wormhole (rev 01)

$ ls /dev/tenstorrent/
0

$ grep HugePages_Total /proc/meminfo
HugePages_Total:       4
```

---

## 11. Troubleshooting

### Problem: `No TT devices found` or `jax.devices('tt')` returns `[]`

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

```bash
# 1. Is the kernel module loaded?
lsmod | grep tenstorrent
# Expected: tenstorrent  131072  0
# If nothing: the driver is not loaded

# 2. Do device files exist?
ls /dev/tenstorrent/
# Expected: 0
# If "No such file or directory": driver not installed

# 3. Is the card visible on the PCIe bus?
lspci | grep -i tenstorrent
# Expected: line starting with a bus address
```

**Fix:**
```bash
# Re-run the TT-Installer
curl -L https://installer.tenstorrent.com/tt-installer.sh -o /tmp/tt-installer.sh
chmod +x /tmp/tt-installer.sh
sudo /tmp/tt-installer.sh
sudo reboot
```

---

### Problem: `ImportError: No module named 'torch_plugin_tt'`

**Cause:** The `pjrt-plugin-tt` wheel is not installed, or the wrong virtual environment is active.

**Fix:**
```bash
# Step 1: Activate the correct virtual environment
source ~/.tt-xla-venv/bin/activate

# Step 2: Confirm the environment is active (prompt should show (.tt-xla-venv))
echo $VIRTUAL_ENV
# Expected: /home/yourname/.tt-xla-venv

# Step 3: Re-install pjrt-plugin-tt
pip install pjrt-plugin-tt --extra-index-url https://pypi.eng.aws.tenstorrent.com/
```

---

### Problem: `torch.compile` appears to hang for a very long time

**Cause:** This is **expected behaviour on the first run**. TT-XLA compiles the full model graph
to a Tenstorrent binary. For ResNet50, this takes 30–120 seconds.

**What to do:** Wait. Do not press Ctrl+C. The compilation is cached after the first run.

You can check if progress is happening by opening a second terminal and running:
```bash
# Check CPU usage — a high value means compilation is active
top -b -n 1 | head -20
```

---

### Problem: `fatal error: hugepages` / memory allocation failure

**Symptoms:**
```
[TT-Metal] Failed to allocate hugepages
```

**Fix:**
```bash
# Check current hugepages count
cat /proc/sys/vm/nr_hugepages

# Set to 4 (4 GB of hugepages)
sudo sysctl -w vm.nr_hugepages=4

# Verify
grep HugePages_Total /proc/meminfo
# Expected: HugePages_Total:       4

# Make permanent
echo 'vm.nr_hugepages=4' | sudo tee -a /etc/sysctl.conf
```

---

### Problem: `clang: error: unknown argument: '-march=...'` (build from source only)

**Cause:** An older version of Clang is being used instead of Clang 20.

**Fix:**
```bash
# Check current clang version
clang --version
# If it shows version < 20, install and set clang-20:

sudo apt-get install -y clang-20
sudo update-alternatives --install /usr/bin/clang clang /usr/bin/clang-20 100
sudo update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-20 100

# Verify
clang --version
# Expected: Ubuntu clang version 20.x.x
```

---

### Problem: Python version mismatch during source build

```bash
# Clear build artifacts and rebuild
rm -rf build/
cmake -G Ninja -B build
cmake --build build
```

---

### Problem: Docker — device not found inside container

```bash
# Verify the device exists on the host first
ls /dev/tenstorrent/
# Expected: 0

# Re-run the container with the correct flag
docker run -it --rm --device /dev/tenstorrent \
    -v /dev/hugepages-1G:/dev/hugepages-1G \
    ghcr.io/tenstorrent/tt-xla-slim:latest

# ⚠️ Do NOT use --device /dev/tenstorrent/0 (with device number)
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
