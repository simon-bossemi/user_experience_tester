# TT-XLA Installation Manual

**Tool:** TT-XLA (Tenstorrent XLA)  
**Target hardware:** BOS A0 (Tenstorrent Blackhole: p100a / p150a / p150b)  
**Audience:** Beginners in AI and Linux

This file covers installation only:

- hardware and BIOS preparation
- driver and firmware setup
- Python wheel installation
- Docker installation path
- source-build installation path
- installation verification
- installation-related troubleshooting

For compilation artifacts, use `tt-xla-practical-example.md`.
For runtime execution, use `resnet50-run-example.md`.
For non-install troubleshooting, use `troubleshooting.md`.

---

## 1. Overview

TT-XLA lets you compile and run models from PyTorch or JAX on Tenstorrent hardware. On BOS A0,
the normal flow is:

1. Prepare the hardware and BIOS.
2. Install the Tenstorrent driver stack with TT-Installer.
3. Install the TT-XLA Python packages.
4. Verify that the card is visible to the runtime.

---

## 2. Prerequisites

### 2.1 Hardware

This guide targets BOS A0 systems with a Blackhole PCIe card.

| Requirement | Value |
|-------------|-------|
| Card | Blackhole p100a, p150a, or p150b |
| Slot | PCIe Gen 5.0 x16 |
| Power | 12+4-pin 12V-2x6 |
| PSU | ATX 3.1 certified |
| Device path | `/dev/bos/<device_id>` |
| RAM | 32 GB recommended |

### 2.2 Operating System

| Requirement | Value |
|-------------|-------|
| OS | Ubuntu 22.04 LTS or Ubuntu 24.04 LTS |
| Architecture | x86_64 |
| Kernel | 5.15 or newer recommended |

### 2.3 Required Base Tools

```bash
git --version
python3 --version
pip --version
lspci
curl
jq
```

### 2.4 Network Dependencies

These hosts should be reachable before you start:

| Host | Purpose |
|------|---------|
| `installer.tenstorrent.com` | TT-Installer |
| `pypi.eng.aws.tenstorrent.com` | `pjrt-plugin-tt` wheel |
| `download.pytorch.org` | PyTorch CPU wheels |
| `pypi.org` | pip, wheel, setuptools |
| `github.com` | TT-XLA / TT-MLIR source repositories |
| `ghcr.io` | Docker images |

Quick check:

```bash
curl -s -o /dev/null -w "%{http_code}" https://pypi.eng.aws.tenstorrent.com/
curl -s -o /dev/null -w "%{http_code}" https://download.pytorch.org/whl/cpu/
curl -s -o /dev/null -w "%{http_code}" https://pypi.org/simple/pip/
```

---

## 3. Hardware and BIOS Setup

### 3.1 Physical Installation

1. Power the host off completely.
2. Install the Blackhole card into a PCIe Gen 5.0 x16 slot.
3. Leave the adjacent slot empty for airflow on p100a and p150a systems.
4. Connect the 12+4-pin 12V-2x6 cable.
5. Boot the machine.

### 3.2 BIOS Configuration

Set these values before software installation:

1. Set PCIe AER reporting to `OS First`.
2. Force the target slot speed to `Gen 5.0` instead of `Auto`.

### 3.3 Verify PCIe Detection

```bash
lspci | grep -i tenstorrent
lspci -d 1e52:
lspci -nn | grep -E 'tenstorrent|16c3:abcd'
```

Expected result: at least one accelerator or BOS device entry is visible.

---

## 4. Driver and Firmware Installation

### 4.1 Install TT-Installer Prerequisites

```bash
sudo apt update
sudo apt install -y curl jq
```

### 4.2 Run TT-Installer

If you want to inspect the script first:

```bash
curl -fsSL https://github.com/tenstorrent/tt-installer/releases/latest/download/install.sh \
  -o /tmp/tt-installer.sh
less /tmp/tt-installer.sh
bash /tmp/tt-installer.sh
```

Direct execution:

```bash
/bin/bash -c "$(curl -fsSL https://github.com/tenstorrent/tt-installer/releases/latest/download/install.sh)"
```

Typical answers during the interactive flow:

- Continue: `Y`
- TT-Metalium container: `Y` if you need TT-NN tooling, otherwise `N`
- Model demos container: `N` unless you explicitly want it
- Python package location: press Enter for the default
- Reboot prompt: `Y`

### 4.3 Verify After Reboot

```bash
source ~/.tenstorrent-venv/bin/activate
tt-smi
ls /dev/bos/
grep HugePages_Total /proc/meminfo
```

Expected results:

- `tt-smi` shows at least one device
- `/dev/bos/` contains one or more device nodes
- `HugePages_Total` is greater than zero

---

## 5. Option A: Python Wheel Installation

This is the recommended path.

### 5.1 Create and Activate the Environment

```bash
python3.11 -m venv ~/.tt-xla-venv
source ~/.tt-xla-venv/bin/activate
pip install --upgrade pip wheel setuptools
```

If your host uses Python 3.12:

```bash
python3.12 -m venv ~/.tt-xla-venv
source ~/.tt-xla-venv/bin/activate
pip install --upgrade pip wheel setuptools
```

### 5.2 Install the TT-XLA Plugin

```bash
pip install pjrt-plugin-tt \
  --extra-index-url https://pypi.eng.aws.tenstorrent.com/
```

This installs:

- `torch_plugin_tt`
- `jax_plugin_tt`
- TT-XLA runtime pieces
- required low-level kernels

### 5.3 Install a Compatible PyTorch Pair

```bash
pip install --force-reinstall \
  torch==2.9.0+cpu \
  torchvision==0.24.0+cpu \
  --index-url https://download.pytorch.org/whl/cpu
```

Do not install standalone `torch-xla` on top of this. The TT-XLA wheel already bundles the
matching integration pieces.

### 5.4 Verify the Wheel Install

```bash
python3 -c "import jax; print(jax.devices('tt'))"
python3 -c "import torch_plugin_tt; print('torch_plugin_tt loaded OK')"
```

Expected result:

```text
[TTDevice(id=0, arch=blackhole)]
torch_plugin_tt loaded OK
```

---

## 6. Option B: Docker Installation

Use Docker if you want an isolated environment or already have the runtime on the host.

### 6.1 Install Docker

```bash
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
newgrp docker
```

### 6.2 Pull the TT-XLA Image

```bash
docker pull ghcr.io/tenstorrent/tt-xla/tt-xla-ci-ubuntu-22-04:latest
```

### 6.3 Run the Container on BOS A0

```bash
docker run -it --rm \
  --cap-add ALL \
  --ipc=host \
  --device /dev/bos/0:/dev/bos/0 \
  -v /dev/hugepages:/dev/hugepages \
  -v /dev/hugepages-1G:/dev/hugepages-1G \
  ghcr.io/tenstorrent/tt-xla/tt-xla-ci-ubuntu-22-04:latest bash
```

---

## 7. Option C: Build from Source

Use this path only if you need TT-MLIR tools or BOS-specific source changes.

### 7.1 Source-Build Requirements

- GitHub access to the BOS repositories
- Python 3.12
- Clang 20
- CMake and Ninja

Install the base packages:

```bash
sudo apt update
sudo apt install -y \
  git git-lfs openssh-client \
  python3.12 python3.12-venv python3-pip \
  clang-20 lld-20 cmake ninja-build pkg-config
```

### 7.2 Clone the BOS Repositories

```bash
mkdir -p /workspace/xla-dev
cd /workspace/xla-dev

git clone --branch develop git@github.com:bos-semi/tt-mlir.git
git clone --branch release/a0 git@github.com:bos-semi/tt-xla.git
```

### 7.3 Build TT-MLIR

```bash
cd /workspace/xla-dev/tt-mlir
python3.12 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip wheel setuptools
pip install "setuptools<82"
pip install cmake ninja

cmake -G Ninja -B build -DTTMLIR_ENABLE_BINDINGS_PYTHON=ON
cmake --build build
```

### 7.4 Build TT-XLA

```bash
cd /workspace/xla-dev/tt-xla
python3.12 -m venv venv
source venv/bin/activate
pip install --upgrade pip wheel setuptools

cmake -G Ninja -B build \
  -DUSE_BOS_SEMI_TTMLIR=ON \
  -DUSE_CUSTOM_TT_MLIR_VERSION=ON \
  -DUSE_BOS_REPO=ON

cmake --build build
```

If you hit the known `core_assignment.cpp` unused-variable build issue, apply the
`[[maybe_unused]]` fix described in the BOS review context.

---

## 8. Installation Verification Checklist

### Hardware and Driver

- [ ] Card appears in `lspci`
- [ ] `/dev/bos/` exists
- [ ] `tt-smi` shows the device
- [ ] hugepages are configured

### Wheel Installation

- [ ] `pjrt-plugin-tt` installs successfully
- [ ] PyTorch and torchvision install successfully
- [ ] `torch_plugin_tt` imports successfully
- [ ] `jax.devices('tt')` returns at least one TT device

### Source Build

- [ ] `ttmlir-opt` exists under `tt-mlir/build/bin/`
- [ ] `ttmlir-translate` exists under `tt-mlir/build/bin/`
- [ ] `cmake --build build` succeeds for TT-XLA

---

## 9. Installation Troubleshooting

### Card not detected by `lspci`

1. Re-check the power cable.
2. Re-check the slot seating.
3. Force PCIe speed to Gen 5 in BIOS.
4. Re-check AER mode is `OS First`.

### `tt-smi` shows no devices

Re-run TT-Installer, reboot, then verify:

```bash
ls /dev/bos/
grep HugePages_Total /proc/meminfo
tt-smi
```

### `ImportError: No module named 'torch_plugin_tt'`

Activate the correct environment and reinstall:

```bash
source ~/.tt-xla-venv/bin/activate
pip install --force-reinstall \
  pjrt-plugin-tt==0.9.0 \
  --extra-index-url https://pypi.eng.aws.tenstorrent.com/
```

### `torch_xla` or `torch_plugin_tt` fails with undefined symbols

Reinstall the pinned wheel set:

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

### Hugepages are not configured

```bash
grep HugePages_Total /proc/meminfo
sudo sysctl -w vm.nr_hugepages=4
echo 'vm.nr_hugepages=4' | sudo tee -a /etc/sysctl.conf
```

### Docker cannot see the BOS device

```bash
ls /dev/bos/
docker run -it --rm --device /dev/bos/0:/dev/bos/0 \
  -v /dev/hugepages:/dev/hugepages \
  -v /dev/hugepages-1G:/dev/hugepages-1G \
  ghcr.io/tenstorrent/tt-xla/tt-xla-ci-ubuntu-22-04:latest bash
```

### Source build fails with old Clang

```bash
clang --version
sudo apt install -y clang-20
```

### Source build fails because Python is not 3.12

```bash
python --version
sudo apt install -y python3.12 python3.12-venv
```
