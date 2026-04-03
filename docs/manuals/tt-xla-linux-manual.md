# TT-XLA Linux Installation and Usage Manual

**Tool:** TT-XLA (Tenstorrent XLA)  
**Target hardware:** BOS A0 (Tenstorrent Blackhole — p100a / p150a / p150b)  
**Audience:** Beginners in AI and Linux  
**Sources:** [GitHub bos-semi/tt-xla](https://github.com/bos-semi/tt-xla) · [BOS Internal Tutorial (PDF)](../inputs/AIMultimed-TT-XLA%20Installation-030426-023800.pdf) · [Tenstorrent Getting Started](https://raw.githubusercontent.com/tenstorrent/tt-xla/main/docs/src/getting_started.md)

---

## Table of Contents

1. [Overview and Key Concepts](#1-overview-and-key-concepts)
2. [Prerequisites](#2-prerequisites)
3. [BOS A0 (Blackhole) — Hardware and BIOS Setup](#3-bos-a0-blackhole--hardware-and-bios-setup)
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
TT-MLIR compiler — converts to BOS A0 chip instructions
       ↓
BOS A0 NPU (the Blackhole AI accelerator card in your workstation)
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

This manual targets **BOS A0** systems — workstations or servers equipped with a Tenstorrent
**Blackhole** PCIe add-in card (p100a, p150a, or p150b).

| Requirement | BOS A0 — Blackhole (p100a / p150a / p150b) |
|-------------|---------------------------------------------|
| PCIe card | Blackhole p100a, p150a, or p150b |
| PCIe slot | **Gen 5.0 x16** (no bifurcation; lane-sharing disabled) |
| Power connector | **12+4-pin 12V-2x6** (ATX 3.1 certified PSU required) |
| Adjacent PCIe slot | Leave empty — p100a/p150a are dual-slot with active coolers |
| RAM | ≥ 32 GB recommended |
| Device path | `/dev/bos/<device_id>` |

> ⚠️ An **ATX 3.1 certified power supply** is required. Standard 8-pin PCIe power cables are
> physically incompatible with the 12V-2x6 connector. The p150b uses a passive heatsink and is
> designed for rack-mounted systems with forced airflow.

> **Wormhole users (n150/n300):** The core Python workflow in Sections 5–9 also works on Wormhole
> hardware with device path `/dev/tenstorrent/<id>` and PCIe Gen 3. Sections 3 and parts of 6–7
> that are BOS A0-specific are labelled accordingly.

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

### 2.4 Network Requirements

> ⚠️ **Internet connectivity is required** for the standard wheel install (Option A) and Docker
> (Option B) paths. Build from source (Option C) requires network access only during the initial
> clone and dependency download.

The following external hosts must be reachable from your system:

| Host | Purpose | Used by |
|------|---------|---------|
| `installer.tenstorrent.com` | TT-Installer script download | Section 4 |
| `pypi.eng.aws.tenstorrent.com` | Tenstorrent's private PyPI (pjrt-plugin-tt) | Section 5.2 |
| `download.pytorch.org` | PyTorch CPU wheels | Section 5.3 |
| `pypi.org` | pip, wheel, setuptools upgrades | Sections 5–7 |
| `github.com` (HTTPS + SSH) | TT-XLA / TT-MLIR source clones (Option C) | Section 7 |
| `ghcr.io` | Docker CI image (Option B) | Section 6 |

**Check reachability before starting:**

```bash
# Quick connectivity check — all should return HTTP 200 or a redirect:
curl -s -o /dev/null -w "%{http_code}" https://pypi.eng.aws.tenstorrent.com/  # expect 200 or 301
curl -s -o /dev/null -w "%{http_code}" https://download.pytorch.org/whl/cpu/  # expect 200
curl -s -o /dev/null -w "%{http_code}" https://pypi.org/simple/pip/            # expect 200
```

**Offline / air-gapped alternatives:**

If your host cannot reach the required URLs (e.g., corporate firewall, lab environment), you
can pre-download the wheels on a connected machine and transfer them:

```bash
# On a connected machine — download all required wheels:
pip download pjrt-plugin-tt \
    --extra-index-url https://pypi.eng.aws.tenstorrent.com/ \
    -d /tmp/tt-xla-wheels/

pip download torch==2.9.0+cpu torchvision==0.24.0+cpu Pillow \
    --index-url https://download.pytorch.org/whl/cpu \
    -d /tmp/tt-xla-wheels/

# Transfer the /tmp/tt-xla-wheels/ directory to the air-gapped host, then install:
pip install --no-index --find-links /path/to/tt-xla-wheels/ pjrt-plugin-tt
pip install --no-index --find-links /path/to/tt-xla-wheels/ torch torchvision Pillow
```

The `pjrt-plugin-tt` wheel can also be downloaded directly from:
`https://github.com/bos-semi/tt-xla/releases` (requires GitHub access).

> **Corporate proxy:** If your environment requires an HTTP proxy, set it before running any
> `pip install` or `curl` command:
> ```bash
> export https_proxy=http://proxy.example.com:8080
> export http_proxy=http://proxy.example.com:8080
> ```

---

## 3. BOS A0 (Blackhole) — Hardware and BIOS Setup

Complete all steps in this section before installing any software.

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
# Option 1 — check by product name (Tenstorrent systems):
lspci | grep -i tenstorrent
# Expected output for BOS A0 (Blackhole):
# 01:00.0 Processing accelerators: Tenstorrent Inc. Blackhole (rev 01)

# Option 2 — check by PCI vendor ID (more reliable if driver not yet installed):
lspci -d 1e52:
# Expected: at least one line beginning with a bus address

# BOS Eagle systems may enumerate under the BOS driver instead:
lspci -nn | grep -E 'tenstorrent|16c3:abcd'
# Expected examples:
# 01:00.0 Co-processor [0b40]: Synopsys, Inc. DWC_usb3 / PCIe bridge [16c3:abcd]
#   Kernel driver in use: bos
```

Also confirm the BOS device directory is present after driver install (see Section 4):

```bash
ls /dev/bos/
# Expected: 0   (or 0 1 2 … for multi-device setups)
```

If no output appears from `lspci`, the card was not detected — recheck power connection, PCIe
slot, and BIOS speed settings.

### 3.4 Check Firmware LED

After power-on, verify:
- The **fan spins** (for p100a/p150a).
- The **green power LED** on the card illuminates.

If neither is observed, the power cable may not be properly connected.

---

## 4. Software Installation — Driver and Kernel Module

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

> **Security note:** The one-liner below downloads and immediately executes an installation
> script. If you prefer to inspect it first, run:
> ```bash
> curl -fsSL https://github.com/tenstorrent/tt-installer/releases/latest/download/install.sh \
>     -o /tmp/tt-installer.sh
> less /tmp/tt-installer.sh          # review the script
> bash /tmp/tt-installer.sh          # then execute it
> ```

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

**Expected output:** The `tt-smi` interface shows one or more devices under the "Device
Information" pane. For a single BOS A0 Blackhole p150a, you will see one device entry.

Check that the BOS A0 device directory was created:

```bash
ls /dev/bos/
# Expected: 0  (or 0 1 2 ... for multi-card setups)
```

### 4.4 Verify Hugepages

> **Note:** Hugepage configuration is handled automatically by the TT-Installer (see Section 4.2).
> If you have already run the installer and rebooted, you can skip straight to the verification
> command below.

```bash
# Verify hugepages are configured (the TT-Installer should have done this already):
grep HugePages_Total /proc/meminfo
# Expected: HugePages_Total:       4   (or any value ≥ 1)
```

If — and only if — `HugePages_Total` is 0 and you did **not** use the TT-Installer, configure
hugepages manually:

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

### 5.3 Install a TT-XLA-Compatible PyTorch Pair (for ResNet50)

Do **not** run an unpinned `pip install torch torchvision` after installing `pjrt-plugin-tt`.
That can upgrade `torch` beyond the `torch-xla` ABI expected by the TT-XLA wheel.

**Why CPU wheel?** The Tenstorrent NPU is the compute target, not a GPU. Installing the CPU
version of PyTorch saves ~1 GB of unnecessary CUDA libraries.

For `pjrt-plugin-tt==0.9.0`, the working pair observed in Linux validation was:

```bash
pip install --force-reinstall \
    torch==2.9.0+cpu \
    torchvision==0.24.0+cpu \
    --index-url https://download.pytorch.org/whl/cpu
```


> ⚠️ **Do NOT install `torch-xla` separately.** Tenstorrent's fork of `torch-xla` is already
> bundled inside the `pjrt-plugin-tt` wheel. Installing a standalone `torch-xla` on top will
> create a version conflict and break the plugin. See the gap analysis in
> `reports/tt-xla-installation-report.md` (Section 2.2) for details.

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

**Expected output (BOS A0 / Blackhole):**
```
[TTDevice(id=0, arch=blackhole)]
```

**Expected output (Wormhole n150/n300):**
```
# BOS A0 (Blackhole) — primary target:
[TTDevice(id=0, arch=blackhole)]

# Wormhole (if applicable):
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

If `jax.devices('tt')` fails with `No chips detected in the cluster`, the Python installation is
present but the runtime still cannot see a usable device. On BOS Eagle systems, check `/sys/class/bos`
and `/dev/bos/` before troubleshooting the Python packages further.

---

## 6. Software Installation — Option B: Docker

Use this option if you want a fully isolated environment or you do not want to modify your host
system. Docker packages everything (OS libraries, Python, TT-XLA) into a container.

> **BOS A0 note:** The BOS internal tutorial prescribes a specific Docker workflow using
> `ghcr.io/tenstorrent/tt-xla/tt-xla-ci-ubuntu-22-04:latest` and the BOS A0 device path
> `/dev/bos/<device_id>`. Follow **Section 6.3** for BOS A0 systems. Sections 6.1–6.2 cover the
> generic Tenstorrent (Wormhole) path.

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

### 6.2 Run TT-XLA Docker Container (Wormhole / Generic Tenstorrent)

```bash
docker run -it --rm \
    --device /dev/tenstorrent \
    -v /dev/hugepages:/dev/hugepages \
    -v /dev/hugepages-1G:/dev/hugepages-1G \
    ghcr.io/tenstorrent/tt-xla-slim:latest
```

**What each flag does:**
- `-it` — interactive terminal (you get a shell inside the container)
- `--rm` — automatically delete the container when you exit
- `--device /dev/tenstorrent` — gives the container access to the Tenstorrent hardware
- `-v /dev/hugepages:/dev/hugepages` and `-v /dev/hugepages-1G:/dev/hugepages-1G` — share hugepages memory with the container
- `ghcr.io/tenstorrent/tt-xla-slim:latest` — the container image (downloaded automatically)

On BOS Eagle systems, adapt the device path to `/dev/bos` once the BOS device nodes exist.

### 6.3 Run TT-XLA Docker Container (BOS A0 / Blackhole)

The BOS A0 system exposes the device at `/dev/bos/<device_id>` instead of `/dev/tenstorrent/<device_id>`.
It also uses a dedicated CI image and a long-running named container.

#### Step 1 — Pull the Docker image

```bash
docker pull ghcr.io/tenstorrent/tt-xla/tt-xla-ci-ubuntu-22-04:latest
```

**Expected output:**  Ends with `Status: Downloaded newer image for ghcr.io/...`

#### Step 2 — Define environment variables on the host

Replace the placeholder values with your own choices:

```bash
DOCKER_NAME="tt-xla-bos"          # name for the container (any word you like)
PORT_NUMBER=8080                   # port to forward into the container
HOME_WORKDIR="/home/$USER/xla-dev" # where your source code lives on the host
DATA_DIR="/home/$USER/data"        # where your datasets live on the host
CONTAINER_WORKDIR="/workspace"     # path inside the container

IMAGE_NAME="ghcr.io/tenstorrent/tt-xla/tt-xla-ci-ubuntu-22-04:latest"
SHM_SIZE="128g"                    # shared memory size

# BOS A0 device path (replace 0 with your device ID if different):
DEVICE_PATH="/dev/bos/0"

# Create the workspace directory if it does not yet exist:
mkdir -p "$HOME_WORKDIR" "$DATA_DIR"
```

> **How to find your BOS device ID:**
> ```bash
> ls /dev/bos/
> # Expected: 0  (or 0 1 2 … for multi-device setups)
> ```

#### Step 3 — Launch the Docker container

```bash
docker run -itd \
    --name $DOCKER_NAME \
    -p $PORT_NUMBER:$PORT_NUMBER \
    -v $HOME_WORKDIR:$CONTAINER_WORKDIR \
    -v $DATA_DIR:/data \
    -v /dev/hugepages:/dev/hugepages \
    -v /dev/hugepages-1G:/dev/hugepages-1G \
    --device $DEVICE_PATH:$DEVICE_PATH \
    --shm-size $SHM_SIZE \
    --cap-add ALL \
    --ipc=host \
    --restart unless-stopped \
    $IMAGE_NAME bash
```

**What the key flags do:**
- `-itd` — interactive + detached (runs in background; you attach later)
- `--name $DOCKER_NAME` — assigns a memorable name for `docker exec`
- `-v $HOME_WORKDIR:$CONTAINER_WORKDIR` — mounts your workspace into the container
- `--device $DEVICE_PATH:$DEVICE_PATH` — passes the BOS A0 device into the container
- `--shm-size 128g` — large shared memory needed by TT-Metal kernels
- `--cap-add ALL` — required for low-level device access
- `--ipc=host` — shares host IPC namespace (needed for inter-process communication)
- `--restart unless-stopped` — auto-restarts the container after reboots

**Expected output:** A 64-character container ID (hash), e.g.:
```
7f3a2b1c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a
```

#### Step 4 — Connect to the running container

```bash
docker exec -it $DOCKER_NAME bash
```

You will get a shell prompt inside the container.

#### Step 5 — Set environment variables inside the container

Add these lines to `~/.bashrc` inside the container so they persist across sessions:

```bash
cat >> ~/.bashrc << 'EOF'
export TT_XLA_RUNTIME_ROOT=/workspace/xla-dev/tt-xla
export PROJECT_SOURCE_DIR=/workspace/xla-dev/tt-xla
export TT_MLIR_RUNTIME_ROOT=$TT_XLA_RUNTIME_ROOT/third_party/ttmlir/src/tt-mlir
export TT_METAL_RUNTIME_ROOT=$TT_MLIR_RUNTIME_ROOT/third_party/ttmetal/src/tt-metal
export TTMLIR_TOOLCHAIN_DIR=/opt/ttmlir-toolchain
EOF

# Apply immediately:
source ~/.bashrc
```

**What each variable does:**
| Variable | Purpose |
|----------|---------|
| `TT_XLA_RUNTIME_ROOT` | Root of the cloned `tt-xla` repository |
| `PROJECT_SOURCE_DIR` | Same as above (some scripts use this alias) |
| `TT_MLIR_RUNTIME_ROOT` | Root of the `tt-mlir` submodule inside tt-xla |
| `TT_METAL_RUNTIME_ROOT` | Root of the `tt-metal` submodule inside tt-mlir |
| `TTMLIR_TOOLCHAIN_DIR` | Where the pre-built LLVM toolchain lives |

### 6.4 Inside the Container — Verification

```bash
# Verify the BOS device is accessible inside the container
ls /dev/bos/
# Expected: 0

# Verify hugepages are available:
grep HugePages_Total /proc/meminfo
# Expected: HugePages_Total:   4   (or any value ≥ 1)
```

---

## 7. Software Installation — Option C: Build from Source

> ⚠️ **Use this option only if you are developing or modifying TT-XLA itself.**  
> Building from source requires Ubuntu 22.04 or 24.04 and takes **30–90 minutes** depending on
> your system. Most users should use Option A (wheel install).

There are two build paths depending on your hardware:

| Path | Hardware | Repository |
|------|----------|-----------|
| **BOS A0** | Blackhole (p100a/p150a/p150b) | Private BOS repos — SSH access required |
| **Tenstorrent** | Wormhole (n150/n300) | Public Tenstorrent GitHub repos |

### 7.0 Prerequisites for BOS A0 — GitHub SSH Access

The BOS A0 build requires accessing private repositories on GitHub (`bos-semi` org). SSH
authentication is required.

```bash
# Check if you already have SSH access:
ssh -T git@github.com
# If configured correctly, you will see:
# Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.
```

If the check fails, create and register an SSH key:

```bash
# Generate a new SSH key (press Enter to accept the default file path):
ssh-keygen -t ed25519 -C "your_email@example.com"

# Display your public key:
cat ~/.ssh/id_ed25519.pub
# Copy the output

# Start the SSH agent and add your key:
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Then add the key to your GitHub account:
# GitHub → Settings → SSH and GPG keys → New SSH key → paste the output

# Verify the connection:
ssh -T git@github.com
```

### 7.1 System Dependencies

```bash
sudo apt-get update
sudo apt-get install -y \
    git cmake ninja-build \
    clang gcc g++ \
    python3.12 python3.12-venv python3.12-dev \
    protobuf-compiler libprotobuf-dev \
    ccache \
    libnuma-dev \
    libhwloc-dev \
    libboost-all-dev \
    libnsl-dev
```

> **Python 3.12 note:** The TT-MLIR toolchain requires Python 3.12. If `python3.12` is not
> available in your environment, install it directly:
> ```bash
> sudo apt-get install -y python3.12 python3.12-venv
> ```
> The symlink workaround `ln -s /usr/bin/python3.12 /usr/bin/python3.11` shown in some guides
> is **not recommended** — it will break any script or tool that genuinely requires Python 3.11.
> Install 3.12 natively and reference it explicitly (`python3.12 ...`).

### 7.2 Clone Required Repositories

Create a workspace and clone the repositories. Use the **BOS A0** path for Blackhole systems.

#### For BOS A0 (Blackhole)

```bash
# Create workspace directory
mkdir -p /workspace/xla-dev && cd /workspace/xla-dev

# Clone the BOS-forked TT-MLIR (toolchain — develop branch):
git clone --branch develop git@github.com:bos-semi/tt-mlir.git

# Clone the BOS-forked TT-XLA (A0 release branch):
git clone --branch release/a0 git@github.com:bos-semi/tt-xla.git
```

#### For Tenstorrent (Wormhole / public upstream)

> ⚠️ **This is the most complex step.** TT-MLIR is a separate project with its own build
> process. Expect this step to take **1–3 hours** on a modern workstation.

```bash
mkdir -p /workspace/xla-dev && cd /workspace/xla-dev

git clone https://github.com/tenstorrent/tt-mlir.git
cd tt-mlir

# Create and activate a Python 3.12 environment for the TT-MLIR build
python3.12 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip cmake ninja

# Configure the TT-MLIR build
# Downloads LLVM and other dependencies (~2–5 GB on first run)
cmake -G Ninja -B build \
    -DCMAKE_BUILD_TYPE=Release \
    -DTTMLIR_ENABLE_BINDINGS_PYTHON=ON

# Build TT-MLIR (takes 1–3 hours depending on hardware)
cmake --build build

# Install to the system toolchain directory
sudo cmake --install build --prefix /opt/ttmlir-toolchain

# Deactivate the TT-MLIR build environment and return to the parent directory
deactivate
cd ..

# Set the toolchain directory (required by the TT-XLA build — keep this in your shell)
export TTMLIR_TOOLCHAIN_DIR=/opt/ttmlir-toolchain
```

> **Note:** The cmake flags above follow the TT-MLIR main-branch build process. If any step
> fails, consult the up-to-date instructions at:
> https://docs.tenstorrent.com/tt-mlir/getting-started.html#setting-up-the-environment-manually

### 7.3 Clone and Build TT-XLA

```bash
cd /workspace/xla-dev/tt-mlir

export TTMLIR_TOOLCHAIN_DIR=/opt/ttmlir-toolchain
mkdir -p $TTMLIR_TOOLCHAIN_DIR

# Configure the toolchain build:
cmake -B env/build env \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++

# Build (takes 20–40 minutes):
cmake --build env/build
```

**Expected output:** Ends with `[100%] Built target ...` — no errors.

If you see build failures, see [Section 11 — Troubleshooting](#11-troubleshooting) (Build Tools
TT-MLIR and SFPI Toolchain sections).

Activate the toolchain environment (required before building TT-XLA):

```bash
source env/activate
```

> **What `source env/activate` does:** The `cmake --build env/build` step above generates an
> `env/activate` shell script inside the `tt-mlir` directory. Running `source env/activate` sets
> up the LLVM/MLIR environment variables (compilers, linkers, library paths) needed to compile
> TT-XLA. You must run this in every new shell session before running any `cmake` or `ninja`
> commands in the TT-XLA build.

```bash
# Confirm Python 3.12 is active:
python --version
# Expected: Python 3.12.x
```

### 7.4 Build TT-XLA

#### For BOS A0 (Blackhole)

Set environment variables first (if not already in `~/.bashrc`):

```bash
export TT_XLA_RUNTIME_ROOT=/workspace/xla-dev/tt-xla
export PROJECT_SOURCE_DIR=/workspace/xla-dev/tt-xla
export TT_MLIR_RUNTIME_ROOT=$TT_XLA_RUNTIME_ROOT/third_party/ttmlir/src/tt-mlir
export TT_METAL_RUNTIME_ROOT=$TT_MLIR_RUNTIME_ROOT/third_party/ttmetal/src/tt-metal
export TTMLIR_TOOLCHAIN_DIR=/opt/ttmlir-toolchain
```

```bash
cd $TT_XLA_RUNTIME_ROOT

# Fetch all submodules (tt-metal, third-party libs, etc. — may take several minutes):
git submodule update --init --recursive

# Create and activate a Python 3.12 virtual environment for the TT-XLA build
python3.12 -m venv venv
source venv/bin/activate
pip install --upgrade pip

> **What `source venv/activate` does:** The `tt-xla` repository ships a `venv/activate`
> shell script (not a standard Python venv activation). Running it:
> 1. Creates a Python 3.12 virtual environment at `$TT_XLA_RUNTIME_ROOT/venv/` if it does not
>    exist yet (requires `python3.12` to be installed — see Section 7.1).
> 2. Activates that virtual environment for the current shell session.
> 3. Sets `PYTHONPATH` and other variables needed by TT-XLA's test runner and build system.
>
> You must run `source venv/activate` **after** each `source env/activate` from the TT-MLIR
> toolchain step, and in every new shell session before running `pytest` or Python tools.

# Configure the BOS A0 build:
cmake -G Ninja -B build \
    -DTT_MLIR_VERSION=develop \
    -DUSE_BOS_SEMI_TTMLIR=ON \
    -DUSE_CUSTOM_TT_MLIR_VERSION=ON \
    -DUSE_BOS_REPO=ON

# Build:
cmake --build build
```

> **Optional extra build flags for BOS A0:**
> ```bash
> cmake -G Ninja -B build \
>     -DTT_MLIR_VERSION=develop \
>     -DUSE_BOS_SEMI_TTMLIR=ON \
>     -DUSE_CUSTOM_TT_MLIR_VERSION=ON \
>     -DUSE_BOS_REPO=ON \
>     -DTTMLIR_ENABLE_BINDINGS_PYTHON=ON \
>     -DTTMLIR_ENABLE_PERF_TRACE=ON \
>     -DTTXLA_ENABLE_TOOLS=ON
> ```
>
> **Convenient aliases for TT-MLIR tools:**
> ```bash
> alias ttmlir-opt='$TT_MLIR_RUNTIME_ROOT/build/bin/ttmlir-opt'
> alias ttmlir-translate='$TT_MLIR_RUNTIME_ROOT/build/bin/ttmlir-translate'
> ```

> ⚠️ **Known BOS A0 build issue in `core_assignment.cpp`:** When using `tt-metal-e2`, the build
> may fail with unused-parameter errors. Apply the following fix manually:
>
> ```bash
> # Open the file in a text editor:
> nano $TT_METAL_RUNTIME_ROOT/tt_metal/common/core_assignment.cpp
> ```
>
> Inside the function `get_optimal_dram_to_physical_worker_assignment(...)`, at lines 159–165,
> add `[[maybe_unused]]` before each parameter declaration:
>
> ```cpp
> [[maybe_unused]] const std::vector<CoreCoord>& dram_phy_coords,
> [[maybe_unused]] uint32_t full_grid_size_x,
> [[maybe_unused]] uint32_t full_grid_size_y,
> [[maybe_unused]] std::vector<uint32_t> worker_phy_x,
> [[maybe_unused]] std::vector<uint32_t> worker_phy_y
> ```
>
> Also comment out the two debug log lines at lines 198–199:
> ```cpp
> // log_info(tt::LogMetal, "Dram Interface Workers: {}", full_grid_size_x);
> // log_info(tt::LogMetal, "Dram Interface Workers: {}", worker_phy_x);
> ```
>
> Then commit the fix and rebuild:
> ```bash
> cd $TT_METAL_RUNTIME_ROOT
> git add tt_metal/common/core_assignment.cpp
> git commit -m "resolve"
> cd $TT_XLA_RUNTIME_ROOT
> cmake --build build
> ```

#### For Tenstorrent (Wormhole / public upstream)

```bash
cd /workspace/xla-dev/tt-xla
git submodule update --init --recursive
source venv/activate

cmake -G Ninja -B build
cmake --build build
```

#### Activate the build on every new session

Add these lines to `~/.bashrc` so the build is usable in new terminal sessions:

```bash
echo 'source $TT_XLA_RUNTIME_ROOT/venv/activate' >> ~/.bashrc
```

#### (Optional) Debug build

```bash
cmake -G Ninja -B build -DCMAKE_BUILD_TYPE=Debug
cmake --build build
```

### 7.5 Run Tests

After a successful build, validate TT-XLA with the ResNet50 benchmark test:

```bash
pytest $TT_XLA_RUNTIME_ROOT/tests/benchmark/test_vision.py::test_resnet50 -sv
```

**Expected output:** Ends with `PASSED` and displays inference results.

### 7.6 Verify Source Build

```bash
python3 -c "import jax; print(jax.devices('tt'))"
# Expected for BOS A0:     [TTDevice(id=0, arch=blackhole)]
# Expected for Wormhole:   [TTDevice(id=0, arch=Wormhole_b0)]
```

### 7.7 (Optional) Build the Wheel

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

### 8.4 Create the ResNet50 Inference Script

Create a new file called `run_resnet50_tt.py` in your current directory.
You can use any text editor. For example, using `nano` (beginner-friendly):

```bash
nano run_resnet50_tt.py
```

> **No ONNX export, no separate conversion step is needed** for PyTorch models.
> `torch.compile` handles all graph lowering internally.

### 8.5 ResNet50 Inference Script

Copy and paste the following code into the file:

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

### 8.6 Run the Script

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
# Expected (BOS A0 / Blackhole): TT devices: [TTDevice(id=0, arch=blackhole)]
# Expected (Wormhole n150/n300): TT devices: [TTDevice(id=0, arch=Wormhole_b0)]

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
# BOS A0 — Blackhole cards (p100a/p150a/p150b):
[TTDevice(id=0, arch=blackhole)]

# Wormhole cards (n150/n300):
[TTDevice(id=0, arch=Wormhole_b0)]
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

For **BOS A0 (Blackhole)** — the primary target:

```bash
$ lspci | grep -i tenstorrent
# BOS A0 (Blackhole):
01:00.0 Processing accelerators: Tenstorrent Inc. Blackhole (rev 01)
# Wormhole:
01:00.0 Processing accelerators: Tenstorrent Inc. Wormhole (rev 01)

$ ls /dev/bos/
0

$ grep HugePages_Total /proc/meminfo
HugePages_Total:       4
```

---

## 11. Troubleshooting

### Problem: `No TT devices found` or `jax.devices('tt')` returns `[]`

1. Verify the kernel module is loaded and BOS device directory exists:
   ```bash
   lsmod | grep tt
   ls /dev/bos/
   ```
2. Re-run the TT-Installer:
   ```bash
   curl -fsSL https://github.com/tenstorrent/tt-installer/releases/latest/download/install.sh \
       -o /tmp/tt-installer.sh
   bash /tmp/tt-installer.sh
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

# 2. Do BOS device files exist?
ls /dev/bos/
# Expected: 0
# If "No such file or directory": driver not installed

# 3. Is the card visible on the PCIe bus?
lspci -d 1e52:
# Expected: line starting with a bus address
```

**Fix:**
```bash
# Re-run the TT-Installer (inspect first, then execute):
sudo apt-get install -y curl jq
curl -fsSL https://github.com/tenstorrent/tt-installer/releases/latest/download/install.sh \
    -o /tmp/tt-installer.sh
bash /tmp/tt-installer.sh
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

### `torch_xla` / `torch_plugin_tt` import fails with undefined symbols

This usually means `torch` was upgraded beyond the version expected by the installed TT-XLA wheel.

```bash
source ~/.tt-xla-venv/bin/activate
pip install --force-reinstall \
    torch==2.9.0+cpu \
    torchvision==0.24.0+cpu \
    --index-url https://download.pytorch.org/whl/cpu
pip install --force-reinstall --no-deps \
    pjrt-plugin-tt==0.9.0 \
    --extra-index-url https://pypi.eng.aws.tenstorrent.com/
```

### `No chips detected in the cluster`

The TT-XLA Python packages are installed, but runtime device discovery still failed.

```bash
# Tenstorrent path:
ls /dev/tenstorrent/

# BOS Eagle path:
ls /sys/class/bos
ls /dev/bos/
```

If `/sys/class/bos` exists but `/dev/bos/` is missing, fix the BOS driver/device-node setup before
retrying `jax.devices('tt')`.


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

> **Note:** If you ran the TT-Installer (Section 4.2) and rebooted, hugepages should already be
> configured. Run the verification command first before making any changes:

```bash
# Quick check (should show ≥ 1):
grep HugePages_Total /proc/meminfo
```

If the value is 0, configure hugepages:

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
# For Wormhole: verify the device exists on the host first
ls /dev/tenstorrent/
# Expected: 0

# Re-run the container with the correct flag
docker run -it --rm --device /dev/tenstorrent \
    -v /dev/hugepages:/dev/hugepages \
    -v /dev/hugepages-1G:/dev/hugepages-1G \
    ghcr.io/tenstorrent/tt-xla-slim:latest

# ⚠️ Do NOT use --device /dev/tenstorrent/0 (with device number) — use the directory
```

For **BOS A0**, the device path is `/dev/bos/<device_id>`:

```bash
ls /dev/bos/
# Expected: 0

# Use /dev/bos/0 explicitly in the docker run command:
docker run -it --rm --device /dev/bos/0:/dev/bos/0 \
    -v /dev/hugepages:/dev/hugepages \
    -v /dev/hugepages-1G:/dev/hugepages-1G \
    ghcr.io/tenstorrent/tt-xla/tt-xla-ci-ubuntu-22-04:latest bash
```

On BOS Eagle systems, use `/dev/bos` instead once the BOS device nodes exist.

---

### Problem (BOS A0 build): GitHub SSH authentication fails

```bash
ssh -T git@github.com
# Permission denied (publickey).
```

**Fix:** Generate and register an SSH key — see [Section 7.0](#70-prerequisites-for-bos-a0--github-ssh-access).

---

### Problem (BOS A0 build): SFPI toolchain mismatch

**Symptoms:** Build fails with SFPI-related errors.

**Fix:**
```bash
$TT_METAL_RUNTIME_ROOT/install_dependencies.sh --sfpi
```

Then re-run the build:
```bash
cd $TT_XLA_RUNTIME_ROOT
cmake --build build
```

---

### Problem (BOS A0 build): `setuptools` version too high when building TT-MLIR tools

**Symptoms:** Error referencing `setuptools` version incompatibility after building TT-MLIR tools.

**Fix:**
```bash
python -m pip install --force-reinstall "setuptools<82"
```

Then rebuild the affected tools.

---

### Problem (BOS A0 build): Python version mismatch during source build

The TT-MLIR toolchain requires Python 3.12. If the environment activates a different version:

```bash
# Check which Python is active:
python --version

# If not 3.12, install it directly:
sudo apt-get install -y python3.12 python3.12-venv

# Re-activate the toolchain environment specifying 3.12:
python3.12 -m venv /opt/ttmlir-toolchain/venv

# Then rebuild:
cmake --build env/build
```

> **Note:** Do not create a symlink from `python3.11` to `python3.12`. This will break any
> tool or script that genuinely requires Python 3.11. Install 3.12 natively instead.

---

### Problem (BOS A0 build): `core_assignment.cpp` unused-parameter compile error

See [Section 7.4 — Known BOS A0 build issue](#74-build-tt-xla) for the full fix with the
`[[maybe_unused]]` annotations and debug log comments.

---

## 12. Replay Checklist

Use this checklist to verify a fresh BOS A0 install from scratch.

### Hardware and driver (BOS A0)

- [ ] ATX 3.1 certified PSU connected with 12+4-pin 12V-2x6 cable
- [ ] Adjacent PCIe slot is empty (for airflow — p100a/p150a)
- [ ] BIOS: PCIe AER Reporting Mechanism set to "OS First"
- [ ] BIOS: PCIe slot speed forced to Gen 5 (not "Auto")
- [ ] Card power LED is lit and fan spins (p100a/p150a)
- [ ] `lspci -d 1e52:` shows a Tenstorrent/Blackhole device entry
- [ ] TT-Installer completed successfully and system rebooted
- [ ] `ls /dev/bos/` shows at least one device file
- [ ] `tt-smi` shows the Blackhole device in the Device Information pane
- [ ] `grep HugePages_Total /proc/meminfo` shows ≥ 1

### Python wheel install (Option A)

- [ ] Python 3.11 or 3.12 virtual environment created and activated
- [ ] `pip install pjrt-plugin-tt --extra-index-url https://pypi.eng.aws.tenstorrent.com/` succeeds
- [ ] `python3 -c "import jax; print(jax.devices('tt'))"` returns `arch=blackhole` (BOS A0) or shows TT devices
- [ ] A TT-XLA-compatible `torch`/`torchvision` pair is installed (e.g. `torch==2.9.0+cpu`)
- [ ] **No** standalone `torch-xla` installed (bundled in `pjrt-plugin-tt`)
- [ ] `python3 -c "import torch_plugin_tt; print('OK')"` succeeds
- [ ] ResNet50 smoke test runs without errors: `python run_resnet50_tt.py`
- [ ] Output shape is `torch.Size([1, 1000])`
- [ ] (Optional) JAX matmul test passes

### Build-from-source (Option C — BOS A0)

- [ ] GitHub SSH access confirmed (`ssh -T git@github.com` shows your username)
- [ ] Both `bos-semi/tt-mlir` (branch `develop`) and `bos-semi/tt-xla` (branch `release/a0`) cloned
- [ ] TT-MLIR toolchain built and activated (`source env/activate; python --version` shows 3.12)
- [ ] `cmake -G Ninja -B build -DUSE_BOS_SEMI_TTMLIR=ON -DUSE_BOS_REPO=ON ...` completes without errors
- [ ] `cmake --build build` succeeds (apply `core_assignment.cpp` fix if needed)
- [ ] `pytest tests/benchmark/test_vision.py::test_resnet50 -sv` passes
