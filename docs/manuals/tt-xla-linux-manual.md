# TT-XLA Linux Installation and Usage Manual

**Tool:** TT-XLA (Tenstorrent XLA)  
**Version:** latest (as of 2025)  
**Sources:** [GitHub tenstorrent/tt-xla](https://github.com/tenstorrent/tt-xla) · [Official Getting Started](https://raw.githubusercontent.com/tenstorrent/tt-xla/main/docs/src/getting_started.md) · [BOS Internal Tutorial](https://bos-semi.atlassian.net/wiki/spaces/AIMultimed/pages/337346574/TT-XLA+Installation)

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Hardware Setup](#3-hardware-setup)
4. [Software Installation — Option A: Wheel (Recommended)](#4-software-installation--option-a-wheel-recommended)
5. [Software Installation — Option B: Docker](#5-software-installation--option-b-docker)
6. [Software Installation — Option C: Build from Source](#6-software-installation--option-c-build-from-source)
7. [ResNet50 PyTorch Model — Discovery and Compilation](#7-resnet50-pytorch-model--discovery-and-compilation)
8. [Running Inference](#8-running-inference)
9. [Expected Outputs](#9-expected-outputs)
10. [Troubleshooting](#10-troubleshooting)
11. [Replay Checklist](#11-replay-checklist)

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

| Requirement | Details |
|-------------|---------|
| Tenstorrent PCIe card | Wormhole (e.g. n150, n300) or Grayskull |
| PCIe slot | Gen 3 x16 or better |
| RAM | ≥ 32 GB system RAM recommended |
| Hugepages | 1 GB hugepages required by TT-Metal runtime |

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
```

---

## 3. Hardware Setup

> **Note:** This step requires physical Tenstorrent hardware installed in your machine.
> Skip if testing in a containerised environment that already has hardware access configured.

### 3.1 Verify Hardware Detection

```bash
lspci | grep -i tenstorrent
# Expected output example:
# 01:00.0 Processing accelerators: Tenstorrent Inc. Wormhole (rev 01)
```

### 3.2 Install TT Kernel Module Driver

The recommended way is via the **TT-Installer** script, which installs the kernel module (tt-kmd),
configures hugepages, and sets up the TT-SMI management utility.

```bash
# Download the official installer
curl -L https://installer.tenstorrent.com/tt-installer.sh -o /tmp/tt-installer.sh
chmod +x /tmp/tt-installer.sh

# Run the installer (requires sudo)
sudo /tmp/tt-installer.sh
```

> **Source:** https://docs.tenstorrent.com/getting-started/README.html#software-installation

### 3.3 Reboot and Verify

```bash
sudo reboot
# After reboot:
ls /dev/tenstorrent/
# Expected: /dev/tenstorrent/0  (or multiple entries for multi-card setups)
```

### 3.4 Verify Hugepages

```bash
grep -i hugepage /proc/meminfo
# Expected: HugePages_Total should be >= 1 and HugePages_Free >= 1
# If zero, the installer may need to be re-run or hugepages configured manually:
sudo systemctl status tt-smi   # check TT service status
```

---

## 4. Software Installation — Option A: Wheel (Recommended)

This is the fastest way to get started running models on Tenstorrent hardware.

### 4.1 Create a Python Virtual Environment

```bash
# Use Python 3.11 or 3.12
python3.11 -m venv ~/.tt-xla-venv
# Or with Python 3.12:
# python3.12 -m venv ~/.tt-xla-venv

source ~/.tt-xla-venv/bin/activate
pip install --upgrade pip wheel setuptools
```

### 4.2 Install the TT-XLA PJRT Plugin Wheel

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

### 4.3 Install PyTorch and torchvision (for ResNet50)

```bash
# Install PyTorch (CPU build sufficient for tracing; TT device handles compute)
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu

# Install torch-xla (Tenstorrent's fork is bundled inside pjrt-plugin-tt,
# but if a standalone torch-xla is needed):
pip install torch-xla
```

### 4.4 Verify Installation

```bash
python3 -c "import jax; print(jax.devices('tt'))"
# Expected: [TTDevice(id=0, arch=Wormhole_b0)]

python3 -c "import torch_plugin_tt; print('torch_plugin_tt loaded OK')"
```

---

## 5. Software Installation — Option B: Docker

Use this option to keep your environment isolated or if you do not want to modify the host system.

### 5.1 Install Docker

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

### 5.2 Run TT-XLA Docker Container

```bash
docker run -it --rm \
    --device /dev/tenstorrent \
    -v /dev/hugepages-1G:/dev/hugepages-1G \
    ghcr.io/tenstorrent/tt-xla-slim:latest
```

> **Important:** Pass `--device /dev/tenstorrent` (the directory), not individual numbered devices
> like `/dev/tenstorrent/0`. Using specific device numbers causes fatal errors at runtime.

### 5.3 Inside the Container

```bash
# The PJRT plugin is pre-installed inside the image.
# Install demo dependencies:
pip install flax transformers torch torchvision

# Verify:
python3 -c "import jax; print(jax.devices('tt'))"
```

---

## 6. Software Installation — Option C: Build from Source

> **Use this option only if you are developing TT-XLA itself.**
> It requires Ubuntu 24.04 and takes 30–60+ minutes to build.

### 6.1 System Dependencies

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

### 6.2 Build TT-MLIR Toolchain (Required Dependency)

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

### 6.3 Clone and Build TT-XLA

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

### 6.4 Verify Source Build

```bash
python3 -c "import jax; print(jax.devices('tt'))"
# Expected: [TTDevice(id=0, arch=Wormhole_b0)]
```

### 6.5 (Optional) Build the Wheel

```bash
cd python_package
python setup.py bdist_wheel
pip install dist/pjrt_plugin_tt*.whl
```

---

## 7. ResNet50 PyTorch Model — Discovery and Compilation

### 7.1 Model Source

ResNet50 is available directly from `torchvision.models` — no download or export is required
before passing it to TT-XLA.

```bash
pip install torchvision
```

### 7.2 How TT-XLA Compiles a PyTorch Model

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

### 7.3 Create the ResNet50 Inference Script

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

### 7.4 Run the Script

```bash
# Ensure the venv with pjrt-plugin-tt is active
source ~/.tt-xla-venv/bin/activate

python run_resnet50_tt.py
```

---

## 8. Running Inference

### 8.1 Minimal Smoke Test (no image required)

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

### 8.2 JAX Quick Test (alternative)

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

## 9. Expected Outputs

### Device Detection

```
[TTDevice(id=0, arch=Wormhole_b0)]
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

## 10. Troubleshooting

### `No TT devices found` / `jax.devices('tt')` returns empty

1. Verify the kernel module is loaded:
   ```bash
   lsmod | grep tt
   ls /dev/tenstorrent/
   ```
2. Re-run the TT-Installer:
   ```bash
   sudo /tmp/tt-installer.sh
   sudo reboot
   ```
3. Check hugepages:
   ```bash
   grep HugePages /proc/meminfo
   ```

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

## 11. Replay Checklist

Use this checklist to verify a fresh install from scratch:

- [ ] Tenstorrent PCIe card is physically installed and detected by `lspci`
- [ ] `ls /dev/tenstorrent/` shows at least one device file
- [ ] Hugepages are configured (`grep HugePages_Total /proc/meminfo` > 0)
- [ ] Python 3.11 or 3.12 virtual environment created and activated
- [ ] `pip install pjrt-plugin-tt --extra-index-url https://pypi.eng.aws.tenstorrent.com/` succeeds
- [ ] `python3 -c "import jax; print(jax.devices('tt'))"` shows TT devices
- [ ] `pip install torch torchvision` succeeds
- [ ] `python3 -c "import torch_plugin_tt; print('OK')"` succeeds
- [ ] ResNet50 smoke test runs without errors: `python run_resnet50_tt.py`
- [ ] Output shape is `torch.Size([1, 1000])`
- [ ] (Optional) JAX matmul test passes
