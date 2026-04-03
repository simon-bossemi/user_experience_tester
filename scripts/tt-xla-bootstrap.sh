#!/usr/bin/env bash
# =============================================================================
# tt-xla-bootstrap.sh — One-command TT-XLA installation and ResNet50 demo
#
# Target hardware: BOS A0 (Tenstorrent Blackhole — p100a / p150a / p150b)
# Audience:        Linux beginners and first-time TT-XLA users
#
# Sources:
#   - inputs/AIMultimed-TT-XLA Installation-030426-023800.pdf  (BOS internal guide)
#   - https://github.com/bos-semi/tt-xla  (branch release/a0)
#   - https://docs.tenstorrent.com/getting-started/README.html
#
# Usage:
#   chmod +x tt-xla-bootstrap.sh
#   ./tt-xla-bootstrap.sh
#
# The script is idempotent — re-running it skips steps that are already complete:
#   - Step 4: uses the first available device directory (/dev/bos or /dev/tenstorrent)
#   - Step 6: reuses the virtual environment if it already exists
#   - Step 7: skips pip install if pjrt-plugin-tt is already importable
#   - Step 8: skips pip install if torch is already importable
#   - Step 9: skips writing the demo script if it already exists
#   - Step 10: skips the demo run if it previously passed (marker file present)
#
# Prerequisites (checked automatically by this script):
#   - Ubuntu 22.04 or 24.04 LTS (other distros may work with warnings)
#   - BOS A0 hardware installed and TT driver/firmware set up via the TT-Installer
#     (see docs/manuals/tt-xla-linux-manual.md Section 4 — run installer first)
#   - Python 3.11 or 3.12
#   - Internet connection (to download wheels and pretrained model weights)
#
# What this script does (in order):
#   1. Detect the Linux distribution and validate Ubuntu/Debian support
#   2. Check required system tools are present
#   3. Verify BOS A0 hardware is detected on the PCIe bus
#   4. Check kernel module and BOS device files are present
#   5. Validate hugepages configuration (set by TT-Installer — verify only)
#   6. Create a Python virtual environment
#   7. Install the TT-XLA PJRT plugin wheel from Tenstorrent's PyPI index
#   8. Install PyTorch, torchvision, and demo dependencies
#   9. Write a ResNet50 demo script to the working directory
#  10. Run the ResNet50 demo on BOS A0 hardware
# =============================================================================

set -euo pipefail

# ── Color helpers ─────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[0;36m'
NC='\033[0m'  # No color

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()     { error "$*"; exit 1; }
step()    { echo -e "\n${CYAN}════════════════════════════════════════${NC}"; \
            echo -e "${CYAN}  $*${NC}"; \
            echo -e "${CYAN}════════════════════════════════════════${NC}"; }

# ── Configuration ──────────────────────────────────────────────────────────────
VENV_DIR="${HOME}/.tt-xla-venv"
TT_PYPI_URL="https://pypi.eng.aws.tenstorrent.com/"
DEMO_SCRIPT="run_resnet50_tt.py"
DEMO_PASSED_MARKER="${HOME}/.tt-xla-demo-passed"
PYTHON_MIN_MINOR=11       # Minimum Python 3.x version
HUGEPAGES_MIN=1           # Minimum number of 1 GB hugepages

# ── Step 1: Detect Linux distribution ─────────────────────────────────────────
step "Step 1/10 — Detecting Linux distribution"

if [[ ! -f /etc/os-release ]]; then
    die "/etc/os-release not found. This script requires a Linux OS."
fi

source /etc/os-release
OS_NAME="${ID:-unknown}"
OS_VERSION="${VERSION_ID:-unknown}"
info "Detected OS: ${PRETTY_NAME:-${OS_NAME} ${OS_VERSION}}"

case "${OS_NAME}" in
    ubuntu|debian|linuxmint|pop)
        success "Ubuntu/Debian-based distro — full support."
        PKG_MGR="apt-get"
        ;;
    rhel|centos|fedora|rocky|almalinux)
        warn "RHEL-based distro detected. Most commands should work but are untested."
        warn "You may need to replace apt-get commands with dnf/yum equivalents."
        PKG_MGR="dnf"
        ;;
    arch|manjaro)
        warn "Arch-based distro detected. The script will attempt to continue."
        warn "Replace apt-get commands with pacman equivalents as needed."
        PKG_MGR="pacman"
        ;;
    *)
        warn "Unknown distro '${OS_NAME}'. Proceeding with best-effort; some steps may fail."
        PKG_MGR="unknown"
        ;;
esac

# ── Step 2: Check required tools ──────────────────────────────────────────────
step "Step 2/10 — Checking required tools"

MISSING_TOOLS=()

check_tool() {
    local tool="$1"
    local install_hint="${2:-}"
    if ! command -v "${tool}" &>/dev/null; then
        MISSING_TOOLS+=("${tool}")
        warn "Missing: ${tool}${install_hint:+ (install hint: ${install_hint})}"
    else
        success "Found: ${tool} ($(${tool} --version 2>&1 | head -1))"
    fi
}

check_tool git    "sudo apt-get install -y git"
check_tool curl   "sudo apt-get install -y curl"
check_tool jq     "sudo apt-get install -y jq"
check_tool lspci  "sudo apt-get install -y pciutils"
check_tool python3 "sudo apt-get install -y python3"
check_tool pip3   "sudo apt-get install -y python3-pip"

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
    error "The following required tools are missing: ${MISSING_TOOLS[*]}"
    if [[ "${PKG_MGR}" == "apt-get" ]]; then
        info "Attempting to install missing tools via apt-get..."
        sudo apt-get update -qq
        sudo apt-get install -y git curl jq pciutils python3 python3-pip python3-venv
        success "Missing tools installed."
    else
        die "Please install the missing tools manually and re-run this script."
    fi
fi

# ── Check Python version ───────────────────────────────────────────────────────
PYTHON_BIN=$(command -v python3.12 || command -v python3.11 || command -v python3 || true)
if [[ -z "${PYTHON_BIN}" ]]; then
    die "No suitable Python 3 interpreter found. Install Python 3.11 or 3.12."
fi

PY_VERSION=$("${PYTHON_BIN}" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
PY_MINOR=$("${PYTHON_BIN}" -c "import sys; print(sys.version_info.minor)")

if [[ "${PY_MINOR}" -lt "${PYTHON_MIN_MINOR}" ]]; then
    die "Python ${PY_VERSION} is too old. TT-XLA requires Python 3.${PYTHON_MIN_MINOR}+."
fi
success "Python ${PY_VERSION} found at ${PYTHON_BIN}"

# ── Step 3: Verify Tenstorrent hardware ───────────────────────────────────────
step "Step 3/10 — Verifying BOS A0 hardware presence"

DEVICE_KIND=""
DEVICE_PATH=""

if lspci | grep -qi tenstorrent; then
    DEVICE_KIND="tenstorrent"
    DEVICE_PATH="/dev/tenstorrent"
elif lspci -d 1e52: | grep -q .; then
    DEVICE_KIND="tenstorrent"
    DEVICE_PATH="/dev/tenstorrent"
elif lspci -nn | grep -qi '16c3:abcd'; then
    DEVICE_KIND="bos"
    DEVICE_PATH="/dev/bos"
fi

if [[ -z "${DEVICE_KIND}" ]]; then
    error "No supported TT-XLA PCIe device found by lspci."
    error "Possible causes:"
    error "  - The Blackhole card is not physically installed"
    error "  - The PCIe slot/card has a power issue"
    error "  - The machine has not been rebooted after card installation"
    error ""
    error "BOS A0 (Blackhole) BIOS requirements:"
    error "  - 12+4-pin 12V-2x6 power cable must be fully connected"
    error "  - BIOS PCIe slot speed must be forced to Gen 5 (not 'Auto')"
    error "  - Adjacent PCIe slot must be empty (airflow for p100a/p150a)"
    error "  - The device is present but not enumerating with a supported driver"
    die "Cannot continue without accelerator hardware. Exiting."
fi

if [[ "${DEVICE_KIND}" == "tenstorrent" ]]; then
    DEVICE_COUNT=$(lspci | grep -ic tenstorrent || true)
    success "Found ${DEVICE_COUNT} Tenstorrent device(s) on PCIe bus:"
    lspci | grep -i tenstorrent | while read -r line; do info "  ${line}"; done
else
    DEVICE_COUNT=$(lspci -nn | grep -ic '16c3:abcd' || true)
    success "Found ${DEVICE_COUNT} BOS Eagle device(s) on PCIe bus:"
    lspci -nn | grep -i '16c3:abcd' | while read -r line; do info "  ${line}"; done
fi

# ── Step 4: Check kernel module and device files ───────────────────────────────
step "Step 4/10 — Checking kernel driver and device files"

if [[ ! -d "${DEVICE_PATH}" ]]; then
    error "${DEVICE_PATH} not found."
    if [[ "${DEVICE_KIND}" == "tenstorrent" ]]; then
        error "The tt-kmd kernel module is not loaded."
    else
        error "The BOS PCIe device is present, but the BOS device nodes are missing."
        error "Check that the BOS driver/udev setup has created /dev/bos/*."
        if [[ -d /sys/class/bos ]]; then
            error "/sys/class/bos exists, so PCIe enumeration succeeded but device-node creation is incomplete."
        fi
    fi
    error ""
    if [[ "${DEVICE_KIND}" == "tenstorrent" ]]; then
        error "Run the TT-Installer to set up the driver and device files:"
        error "  curl -L https://installer.tenstorrent.com/tt-installer.sh -o /tmp/tt-installer.sh"
        error "  chmod +x /tmp/tt-installer.sh"
        error "  sudo /tmp/tt-installer.sh"
        error "  sudo reboot"
    fi
    die "Driver setup required. Exiting."
fi

DEV_FILES=$(ls "${DEVICE_PATH}"/ 2>/dev/null | wc -l)
if [[ "${DEV_FILES}" -eq 0 ]]; then
    die "${DEVICE_PATH}/ directory exists but contains no device files. Complete the driver setup and retry."
fi
success "Device files found under ${DEVICE_PATH}: $(ls "${DEVICE_PATH}"/ | tr '
' ' ')"

# ── Step 5: Validate hugepages ─────────────────────────────────────────────────
step "Step 5/10 — Validating hugepages configuration"

# Hugepages are configured automatically by the TT-Installer (Section 4 of the manual).
# If the TT-Installer was run before this script, hugepages should already be set.
# This step only verifies the current state and warns — it does NOT fail the script.

HP_TOTAL=$(grep -i 'HugePages_Total' /proc/meminfo | awk '{print $2}')
HP_FREE=$(grep -i 'HugePages_Free' /proc/meminfo | awk '{print $2}')

info "HugePages_Total: ${HP_TOTAL}"
info "HugePages_Free:  ${HP_FREE}"

if [[ "${HP_TOTAL}" -lt "${HUGEPAGES_MIN}" ]]; then
    warn "HugePages_Total is ${HP_TOTAL} — at least ${HUGEPAGES_MIN} x 1 GB hugepage is recommended."
    warn "The TT-Installer should have configured hugepages. If it was not run, configure manually:"
    warn "  sudo sysctl -w vm.nr_hugepages=4"
    warn "  echo 'vm.nr_hugepages=4' | sudo tee -a /etc/sysctl.conf"
    warn "Continuing — TT-Metal will report an error at runtime if hugepages are missing."
else
    success "Hugepages OK: ${HP_TOTAL} total, ${HP_FREE} free."
fi

# ── Step 6: Create Python virtual environment ─────────────────────────────────
step "Step 6/10 — Setting up Python virtual environment"

if [[ -d "${VENV_DIR}" ]]; then
    info "Virtual environment already exists at ${VENV_DIR} — reusing."
else
    info "Creating virtual environment at ${VENV_DIR} with ${PYTHON_BIN}..."
    "${PYTHON_BIN}" -m venv "${VENV_DIR}"
    success "Virtual environment created."
fi

# Activate the venv for all subsequent pip/python commands in this script
# shellcheck disable=SC1090
source "${VENV_DIR}/bin/activate"

info "Upgrading pip, wheel, setuptools..."
pip install --quiet --upgrade pip wheel setuptools
success "pip $(pip --version | awk '{print $2}') ready."

# ── Step 7: Install TT-XLA PJRT plugin ────────────────────────────────────────
step "Step 7/10 — Installing TT-XLA PJRT plugin (pjrt-plugin-tt)"

if "${VENV_DIR}/bin/python3" -c "import pjrt_plugin_tt" 2>/dev/null; then
    success "pjrt-plugin-tt is already installed — skipping."
else
    info "Installing pjrt-plugin-tt from Tenstorrent's PyPI index..."
    info "  This downloads the compiled TT-XLA plugin (~300 MB)."
    info "  Source: pip install pjrt-plugin-tt --extra-index-url ${TT_PYPI_URL}"

    pip install pjrt-plugin-tt \
        --extra-index-url "${TT_PYPI_URL}" \
        || {
            error "Failed to install pjrt-plugin-tt."
            error ""
            error "Possible causes:"
            error "  1. No internet connection or firewall blocking ${TT_PYPI_URL}"
            error "  2. The Tenstorrent PyPI index is temporarily unavailable"
            error ""
            error "Alternative: download the wheel from GitHub Releases:"
            error "  https://github.com/bos-semi/tt-xla/releases"
            error "  Then install with: pip install pjrt_plugin_tt-*.whl"
            die "Installation failed. See above for options."
        }
    success "pjrt-plugin-tt installed."
fi

# ── Step 8: Install PyTorch, torchvision, and demo dependencies ────────────────
step "Step 8/10 — Installing PyTorch, torchvision, and Pillow"

info "Installing a TT-XLA-compatible torch/torchvision pair (CPU wheel — TT device handles compute)..."
info "Note: Do NOT install torch-xla separately; it is bundled inside pjrt-plugin-tt."
pip install --quiet     "torch==2.9.0+cpu"     "torchvision==0.24.0+cpu"     "Pillow"     --index-url https://download.pytorch.org/whl/cpu     || die "Failed to install PyTorch/torchvision."
success "PyTorch $(python3 -c 'import torch; print(torch.__version__)') installed."


# ── Step 9: Write the ResNet50 demo script ────────────────────────────────────
step "Step 9/10 — Writing ResNet50 TT-XLA demo script"

if [[ -f "${DEMO_SCRIPT}" ]]; then
    info "Demo script already exists at $(pwd)/${DEMO_SCRIPT} — reusing."
else

cat > "${DEMO_SCRIPT}" << 'PYEOF'
#!/usr/bin/env python3
"""
ResNet50 inference on Tenstorrent hardware via TT-XLA.

Sources:
  - https://github.com/tenstorrent/tt-xla (Getting Started)
  - torchvision.models.resnet50
"""

import torch
import torchvision.models as models
import torchvision.transforms as transforms
from PIL import Image
import urllib.request
import os

# ── 1. Register TT backend ────────────────────────────────────────────────────
# Importing torch_plugin_tt registers the "tt" backend with torch.compile
import torch_plugin_tt  # noqa: F401  (side-effect import)

print("[INFO] torch_plugin_tt backend registered.")

# ── 2. Load ResNet50 pretrained weights ───────────────────────────────────────
print("[INFO] Loading ResNet50 with IMAGENET1K_V1 pretrained weights...")
weights = models.ResNet50_Weights.IMAGENET1K_V1
model = models.resnet50(weights=weights)
model.eval()
print("[OK]   ResNet50 loaded.")

# ── 3. Compile with TT-XLA backend ───────────────────────────────────────────
print("[INFO] Compiling ResNet50 with torch.compile(backend='tt') ...")
print("       First compilation may take 30–120 seconds — please wait.")
compiled_model = torch.compile(model, backend="tt")
print("[OK]   Compilation complete.")

# ── 4. Prepare input image ────────────────────────────────────────────────────
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
input_tensor = preprocess(img).unsqueeze(0)  # [1, 3, 224, 224]
print(f"[OK]   Input tensor shape: {input_tensor.shape}")

# ── 5. Run inference ──────────────────────────────────────────────────────────
print("[INFO] Running inference on Tenstorrent device...")
with torch.no_grad():
    output = compiled_model(input_tensor)
print(f"[OK]   Output shape: {output.shape}")

# ── 6. Decode top-5 predictions ───────────────────────────────────────────────
probabilities = torch.nn.functional.softmax(output[0], dim=0)
top5_prob, top5_catid = torch.topk(probabilities, 5)

categories_path = "/tmp/imagenet_classes.txt"
categories_url = (
    "https://raw.githubusercontent.com/pytorch/hub/master/imagenet_classes.txt"
)
if not os.path.exists(categories_path):
    urllib.request.urlretrieve(categories_url, categories_path)
with open(categories_path) as f:
    categories = [line.strip() for line in f.readlines()]

print("\n[RESULT] Top-5 ImageNet Predictions:")
for i in range(top5_prob.size(0)):
    label = categories[top5_catid[i]]
    prob  = top5_prob[i].item() * 100
    print(f"  {i+1}. {label:<40} {prob:.2f}%")
PYEOF

chmod +x "${DEMO_SCRIPT}"
success "Demo script written to $(pwd)/${DEMO_SCRIPT}"

fi  # end: if demo script not already present

# ── Step 10: Run the ResNet50 demo ────────────────────────────────────────────
step "Step 10/10 — Running ResNet50 on BOS A0 hardware"

if [[ -f "${DEMO_PASSED_MARKER}" ]]; then
    success "Demo previously passed (marker: ${DEMO_PASSED_MARKER}). Skipping re-run."
    success "To force a re-run: rm ${DEMO_PASSED_MARKER} && ./tt-xla-bootstrap.sh"
else

info "Executing: python3 ${DEMO_SCRIPT}"
info ""
info "What to expect:"
info "  - First, ResNet50 pretrained weights download (~100 MB) — one-time only"
info "  - Then, TT-XLA compiles the model — takes 30–120 seconds on first run"
info "  - A sample dog image is downloaded and run through the model"
info "  - Top-5 ImageNet predictions are printed at the end"
info ""
info "⚠️  If the script appears to pause for 30–120 seconds at 'Compiling...',"
info "    this is NORMAL. Do not interrupt. The compiled binary is cached for future runs."

python3 "${DEMO_SCRIPT}" \
    || {
        error "ResNet50 demo failed. See the error output above."
        error ""
        error "Common fixes:"
        error "  - If 'No TT devices found': check driver with 'ls ${DEV_DIR}/'"
        error "  - If 'ImportError: torch_plugin_tt': re-install pjrt-plugin-tt (Step 7)"
        error "  - If 'hugepages error': run 'sudo sysctl -w vm.nr_hugepages=4'"
        error ""
        error "Full troubleshooting guide: docs/manuals/tt-xla-linux-manual.md (Section 11)"
        die "Demo failed."
    }

touch "${DEMO_PASSED_MARKER}"
info "Demo pass recorded at ${DEMO_PASSED_MARKER}"

fi  # end: if demo not yet passed

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  TT-XLA bootstrap complete! (BOS A0 target)                  ║${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║  Hardware:     ${HW_ARCH}${NC}"
echo -e "${GREEN}║  Device dir:   ${DEV_DIR}${NC}"
echo -e "${GREEN}║  Virtual env:  ${VENV_DIR}${NC}"
echo -e "${GREEN}║  Demo script:  $(pwd)/${DEMO_SCRIPT}${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║  To reactivate the environment in a new shell:               ║${NC}"
echo -e "${GREEN}║    source ${VENV_DIR}/bin/activate${NC}"
echo -e "${GREEN}║                                                              ║${NC}"
echo -e "${GREEN}║  For more examples:                                          ║${NC}"
echo -e "${GREEN}║    https://github.com/bos-semi/tt-xla/tree/release/a0/demos ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
