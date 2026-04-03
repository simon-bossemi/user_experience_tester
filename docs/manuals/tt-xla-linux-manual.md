# TT-XLA Linux Installation and Usage Manual

**Tool:** TT-XLA (Tenstorrent XLA)  
**Version:** latest (as of 2026)  
**Audience:** Beginners in AI and Linux  
**Sources:** [GitHub tenstorrent/tt-xla](https://github.com/tenstorrent/tt-xla) · [Official Getting Started](https://raw.githubusercontent.com/tenstorrent/tt-xla/main/docs/src/getting_started.md) · [BOS Internal Tutorial](https://bos-semi.atlassian.net/wiki/spaces/AIMultimed/pages/337346574/TT-XLA+Installation)

---

## Table of Contents

1. [Overview and Key Concepts](#1-overview-and-key-concepts)
2. [Prerequisites](#2-prerequisites)
3. [How to Open a Terminal](#3-how-to-open-a-terminal)
4. [Hardware Setup](#4-hardware-setup)
5. [Software Installation — Option A: Wheel (Recommended)](#5-software-installation--option-a-wheel-recommended)
6. [Software Installation — Option B: Docker](#6-software-installation--option-b-docker)
7. [Software Installation — Option C: Build from Source (Advanced)](#7-software-installation--option-c-build-from-source-advanced)
8. [ResNet50 PyTorch Model — Step-by-Step](#8-resnet50-pytorch-model--step-by-step)
9. [Running Inference](#9-running-inference)
10. [Expected Outputs](#10-expected-outputs)
11. [Troubleshooting](#11-troubleshooting)
12. [Replay Checklist](#12-replay-checklist)
13. [Glossary](#13-glossary)

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

| Requirement | Details |
|-------------|---------|
| Tenstorrent PCIe card | Wormhole (n150 or n300) or Grayskull |
| PCIe slot | Gen 3 x16 or better (the wide black slot on a desktop motherboard) |
| RAM | 32 GB system RAM recommended (minimum 16 GB) |
| Hugepages | 1 GB hugepages — configured automatically by the installer |
| Power supply | Ensure your PSU has enough wattage for the card (see card datasheet) |

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

> **Linux beginner tip:** Check your Python version with:
> ```bash
> python3 --version
> ```
> If you see `Python 3.11.x` or `Python 3.12.x`, you are ready.
> If the version is lower (e.g., 3.10 or 3.8), install Python 3.11 first:
> ```bash
> sudo apt-get update
> sudo apt-get install -y python3.11 python3.11-venv python3.11-dev
> ```

### 2.4 Internet Connection

Required to download the TT-XLA wheel, PyTorch, and ResNet50 pretrained weights.
All downloads are performed automatically by the commands in this manual.

### 2.5 Sudo (Administrator) Access

Installing the Tenstorrent kernel driver requires `sudo` access.
You will be prompted for your password where needed.

---

## 3. How to Open a Terminal

All commands in this manual are run in a **terminal** (also called a "shell" or "command line").

**On Ubuntu Desktop (GNOME):**
1. Press the **Super key** (Windows key on most keyboards) to open the Activities overview.
2. Type `terminal` and press **Enter**.
3. A black or dark window appears — this is your terminal.

**Keyboard shortcut:**
- Press `Ctrl + Alt + T` to open a terminal directly.

**If you are already connected via SSH to a remote machine:**
- You are already in a terminal. Proceed with the commands below.

> **What does a prompt look like?**
> After opening a terminal you will see something like:
> ```
> yourname@hostname:~$
> ```
> The `$` at the end means the terminal is ready for your input. Type commands after the `$`.

---

## 4. Hardware Setup

> **Note:** This entire section requires physical Tenstorrent hardware installed in your machine.
> If you are testing inside a Docker container that already has hardware access, skip to
> [Section 5](#5-software-installation--option-a-wheel-recommended).

### 4.1 Verify Hardware Detection

First, confirm your system can see the Tenstorrent card:

```bash
lspci | grep -i tenstorrent
```

**What this command does:** `lspci` lists all hardware devices connected via the PCIe bus.
We filter the output to show only Tenstorrent devices.

**Expected output:**
```
01:00.0 Processing accelerators: Tenstorrent Inc. Wormhole (rev 01)
```

> If you see no output at all, the card may not be seated correctly, or the machine needs a
> reboot after the card was installed. Try `sudo reboot` and then repeat this step.

### 4.2 Install the TT Kernel Module Driver

The Tenstorrent card needs a **kernel driver** — a piece of software that lets the operating
system communicate with the card. The official **TT-Installer** handles this automatically.

```bash
# Step 1: Download the installer script
curl -L https://installer.tenstorrent.com/tt-installer.sh -o /tmp/tt-installer.sh

# Step 2: Make it executable
chmod +x /tmp/tt-installer.sh

# Step 3: Run it with administrator privileges
sudo /tmp/tt-installer.sh
```

**What this installs:**
- `tt-kmd` — the kernel module (driver)
- `tt-smi` — the Tenstorrent System Management Interface (like `nvidia-smi` for NVIDIA GPUs)
- Hugepage configuration — special memory pages required by the card's runtime

> **Source:** https://docs.tenstorrent.com/getting-started/README.html#software-installation

**Expected output during installation:**
```
[TT-Installer] Detecting system...
[TT-Installer] Installing tt-kmd kernel module...
[TT-Installer] Configuring hugepages...
[TT-Installer] Installation complete.
```

### 4.3 Reboot the Machine

After the driver is installed, you **must reboot** for it to take effect:

```bash
sudo reboot
```

Your terminal will close. Wait for the machine to restart, then open a new terminal.

### 4.4 Verify Driver and Device Files

After rebooting, confirm the driver loaded and the device files exist:

```bash
# Check that the device directory exists
ls /dev/tenstorrent/
```

**Expected output:**
```
0
```
This means one Tenstorrent device is available. With multiple cards you would see `0  1  2  ...`.

```bash
# Check driver is loaded as a kernel module
lsmod | grep tenstorrent
```

**Expected output:**
```
tenstorrent           131072  0
```

### 4.5 Verify Hugepages

The TT-Metal runtime (used internally by TT-XLA) requires **1 GB hugepages** — large blocks of
memory that the card can access efficiently.

```bash
grep -i hugepage /proc/meminfo
```

**Expected output (at minimum):**
```
HugePages_Total:       4
HugePages_Free:        4
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:       1048576 kB
```

If `HugePages_Total` is 0, configure them manually:

```bash
# Set 4 hugepages (4 × 1 GB = 4 GB reserved)
sudo sysctl -w vm.nr_hugepages=4

# Make the setting permanent across reboots
echo 'vm.nr_hugepages=4' | sudo tee -a /etc/sysctl.conf
```

**Verify again:**
```bash
grep HugePages_Total /proc/meminfo
# Expected: HugePages_Total:       4
```

---

## 5. Software Installation — Option A: Wheel (Recommended)

This is the **fastest and simplest** way to get started. A **wheel** is a pre-compiled Python
package — no compiling needed on your side.

### 5.1 Create a Python Virtual Environment

A **virtual environment** is an isolated Python workspace. It keeps the TT-XLA dependencies
separate from other Python packages on your system, preventing conflicts.

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

**Expected output:**
```
Successfully installed pip-24.x wheel-0.x setuptools-xx.x
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

**Expected output (last few lines):**
```
Collecting pjrt-plugin-tt
  Downloading pjrt_plugin_tt-x.x.x-cp311-cp311-linux_x86_64.whl (...)
...
Successfully installed pjrt-plugin-tt-x.x.x tt-metal-x.x.x
```

> **Troubleshooting:** If pip cannot reach the URL, check your network connection. Corporate
> firewalls may block access to `pypi.eng.aws.tenstorrent.com`. If blocked, download the wheel
> directly from [GitHub Releases](https://github.com/tenstorrent/tt-xla/releases) and run:
> ```bash
> pip install pjrt_plugin_tt-*.whl
> ```

### 5.3 Install PyTorch and torchvision

```bash
# Install the CPU build of PyTorch (the TT card handles all compute — no GPU needed)
pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
```

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

> **What is Docker?** Docker is a tool that runs isolated "containers" — like a lightweight
> virtual machine — that contain all the software needed to run an application. You do not need
> to install Python or TT-XLA manually; it's all inside the container image.

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

**Verify Docker works:**
```bash
docker run hello-world
```

**Expected output:**
```
Hello from Docker!
This message shows that your installation appears to be working correctly.
```

### 6.2 Run the TT-XLA Container

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

> ⚠️ **Critical:** Always use `--device /dev/tenstorrent` (the full directory), **not**
> `--device /dev/tenstorrent/0`. Specifying a numbered device file causes fatal errors at runtime.

**Expected output on first run** (Docker downloads the image, which may take several minutes):
```
Unable to find image 'ghcr.io/tenstorrent/tt-xla-slim:latest' locally
latest: Pulling from tenstorrent/tt-xla-slim
...
root@container:/# 
```

The `root@container:/#` prompt means you are now inside the container.

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

## 7. Software Installation — Option C: Build from Source (Advanced)

> ⚠️ **Use this option only if you are developing or modifying TT-XLA itself.**  
> Building from source requires Ubuntu 24.04 and takes **30–90 minutes** depending on your
> system. Most users should use Option A (wheel install).

### 7.1 System Requirements for Source Build

- Ubuntu **24.04** LTS (not 22.04 — Clang 20 is required and not available in 22.04 by default)
- At least **50 GB of free disk space** (build artifacts are large)
- **8+ CPU cores** recommended for reasonable build times

### 7.2 Install System Dependencies

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

**Verify:**
```bash
clang --version
```

**Expected output:**
```
Ubuntu clang version 20.0.x
```

### 7.3 Build TT-MLIR Toolchain (Required Dependency)

TT-XLA depends on **TT-MLIR**, Tenstorrent's MLIR-based compiler. You must build it first.

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

### 7.4 Clone and Build TT-XLA

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

### 7.5 Verify Source Build

```bash
python3 -c "import jax; print(jax.devices('tt'))"
```

**Expected output:**
```
[TTDevice(id=0, arch=Wormhole_b0)]
```

### 7.6 (Optional) Package as a Wheel

```bash
cd python_package
python setup.py bdist_wheel
pip install dist/pjrt_plugin_tt*.whl
```

---

## 8. ResNet50 PyTorch Model — Step-by-Step

### 8.1 What Is ResNet50?

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

Your prompt should show `(.tt-xla-venv)` — if not, run the command above.

### 8.4 Create the ResNet50 Inference Script

Create a new file called `run_resnet50_tt.py` in your current directory.
You can use any text editor. For example, using `nano` (beginner-friendly):

```bash
nano run_resnet50_tt.py
```

Paste the following Python code, then press `Ctrl+X`, then `Y`, then `Enter` to save:

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

### 8.5 Run the Script

```bash
# Make sure your virtual environment is active
source ~/.tt-xla-venv/bin/activate

# Run the script
python run_resnet50_tt.py
```

---

## 9. Running Inference

### 9.1 Minimal Smoke Test (No Image Required)

This quick test checks whether the TT-XLA backend works end-to-end with a random input.
Copy this into a Python file or paste it into a Python REPL (`python3`):

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

**Expected output:**
```
Output shape: torch.Size([1, 1000])
```

### 9.2 JAX Quick Test

If you prefer to test using JAX (another AI framework):

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
$ python3 -c "import jax; print(jax.devices('tt'))"
[TTDevice(id=0, arch=Wormhole_b0)]

$ python3 -c "import torch_plugin_tt; print('torch_plugin_tt loaded OK')"
torch_plugin_tt loaded OK
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

**Symptoms:**
```python
>>> import jax; jax.devices('tt')
[]
# or
RuntimeError: No TT devices found
```

**Diagnosis steps:**

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

### Problem: pip cannot connect to `pypi.eng.aws.tenstorrent.com`

**Possible causes:**
- Corporate VPN or firewall blocking the URL
- Network instability

**Fix — download wheel from GitHub Releases instead:**
```bash
# Go to: https://github.com/tenstorrent/tt-xla/releases
# Download the .whl file for your Python version (cp311 = Python 3.11)
# Then install locally:
pip install pjrt_plugin_tt-x.x.x-cp311-cp311-linux_x86_64.whl
```

---

## 12. Replay Checklist

Use this checklist to verify a fresh installation from scratch. Tick each item before moving on.

### Hardware
- [ ] Tenstorrent PCIe card is physically installed in the PCIe x16 slot
- [ ] `lspci | grep -i tenstorrent` shows at least one device
- [ ] TT-Installer has been run: `sudo /tmp/tt-installer.sh`
- [ ] Machine has been rebooted after driver installation
- [ ] `ls /dev/tenstorrent/` shows at least one device file (e.g., `0`)
- [ ] `lsmod | grep tenstorrent` shows the kernel module is loaded
- [ ] `grep HugePages_Total /proc/meminfo` shows a value ≥ 1

### Software — Virtual Environment
- [ ] Python 3.11 or 3.12 is available: `python3.11 --version`
- [ ] Virtual environment created: `python3.11 -m venv ~/.tt-xla-venv`
- [ ] Virtual environment activated: `source ~/.tt-xla-venv/bin/activate`
- [ ] Prompt shows `(.tt-xla-venv)` prefix

### Software — Packages
- [ ] pip upgraded: `pip install --upgrade pip wheel setuptools`
- [ ] TT-XLA plugin installed: `pip install pjrt-plugin-tt --extra-index-url https://pypi.eng.aws.tenstorrent.com/`
- [ ] PyTorch installed: `pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu`

### Verification
- [ ] JAX device check passes: `python3 -c "import jax; print(jax.devices('tt'))"` → shows TTDevice
- [ ] torch_plugin_tt import succeeds: `python3 -c "import torch_plugin_tt; print('OK')"`

### ResNet50 Demo
- [ ] Script `run_resnet50_tt.py` created (copy from Section 8.4)
- [ ] Script runs without errors: `python run_resnet50_tt.py`
- [ ] Output shape is `torch.Size([1, 1000])`
- [ ] Top-5 predictions are printed with percentage values
- [ ] (Optional) JAX matmul test passes (Section 9.2)

---

## 13. Glossary

| Term | Meaning |
|------|---------|
| **NPU** | Neural Processing Unit — a chip designed specifically to accelerate AI/ML workloads |
| **PCIe** | Peripheral Component Interconnect Express — the interface connecting expansion cards (like GPUs, TPUs, NPUs) to the motherboard |
| **TT-XLA** | Tenstorrent XLA — the compiler front-end that converts PyTorch/JAX models to run on Tenstorrent hardware |
| **PJRT** | Portable JAX Runtime — a plugin interface that lets JAX (and PyTorch-XLA) use different hardware backends |
| **Wheel (.whl)** | A pre-compiled Python package format; faster to install than building from source |
| **Virtual environment (venv)** | An isolated Python workspace that keeps package dependencies separate per project |
| **FX tracing** | PyTorch's mechanism for recording model operations as a static computation graph |
| **StableHLO** | A portable AI compiler intermediate representation; common input format for hardware compilers |
| **TT-MLIR** | Tenstorrent's MLIR-based compiler that converts StableHLO to Tenstorrent chip instructions |
| **TT-Metal** | Tenstorrent's low-level runtime (like CUDA for NVIDIA GPUs) |
| **Hugepages** | Large (1 GB) memory pages reserved in the OS; required by TT-Metal for device memory management |
| **Kernel module (kmd)** | A driver that runs inside the Linux kernel to enable communication with hardware |
| **ResNet50** | A 50-layer residual convolutional neural network trained on ImageNet for image classification |
| **ImageNet** | A large dataset of ~1.2 million labelled images across 1000 categories, used to train and benchmark vision models |
| **`torch.compile`** | A PyTorch 2.0 API that JIT-compiles a model for a target backend (here: `"tt"` for Tenstorrent) |
| **Side-effect import** | An import statement whose purpose is to run setup code, not to use the module directly |
