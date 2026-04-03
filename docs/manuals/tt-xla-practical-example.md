# TT-XLA Practical Example

**Goal:** Generate TT-XLA compiler artifacts for ResNet50 and stop before runtime execution.

This file is intentionally limited to artifact generation. It does not cover:

- image preprocessing
- model execution on hardware
- prediction decoding
- accuracy checks

Use `tt-xla-installation-manual.md` first.
Use `resnet50-run-example.md` later if you want to execute the model.

---

## 1. Scope

The practical example ends after these outputs are generated:

- SHLO
- optimized SHLO
- TTIR
- TTNN IR
- final `.ttnn` executable

### Artifact stages

| Step | Stage | Description | Input | Tool | Output | Artifact example |
|------|-------|-------------|-------|------|--------|------------------|
| 1 | Model input | User provides model | PyTorch / ONNX | - | - | - |
| 2 | Frontend lowering | Convert to compiler IR | Model | tt-xla | SHLO | `shlo_frontend_*.mlir` |
| 3 | Graph optimization | Clean and optimize graph | SHLO | tt-xla | Optimized SHLO | `shlo_resnet50_*.mlir` |
| 4 | TTIR generation | Lower to TTIR | SHLO | tt-mlir | TTIR | `ttir_*.mlir` |
| 5 | TTNN IR | Add runtime semantics | TTIR | tt-mlir | TTNN IR | `ttnn_*.mlir` |
| 6 | Executable generation | Generate binary | TTNN IR | tt-mlir | Executable | `.ttnn` |

---

## 2. Model Input

Use the BOS ResNet50 package as the source model input:

`https://github.com/bos-semi-release/tt-metal/tree/develop/models/bos_model/resnet50`

Prepare the workspace:

```bash
mkdir -p ~/bos-ai-compiler-demo
cd ~/bos-ai-compiler-demo

git clone --branch develop https://github.com/bos-semi-release/tt-metal.git

export MODEL_ROOT=~/bos-ai-compiler-demo/tt-metal/models/bos_model/resnet50
echo "MODEL_ROOT=$MODEL_ROOT"
find "$MODEL_ROOT" -maxdepth 2 -type f | sort
```

If your environment uses a private mirror or SSH remote, keep the same `MODEL_ROOT` path and only
change the clone URL.

---

## 3. Artifact Workspace

```bash
source ~/.tt-xla-venv/bin/activate

export EXAMPLE_ROOT=~/bos-ai-compiler-demo/resnet50_tt_xla_artifacts

mkdir -p \
  "$EXAMPLE_ROOT"/00-raw-codegen \
  "$EXAMPLE_ROOT"/01-frontend-shlo \
  "$EXAMPLE_ROOT"/02-optimized-shlo \
  "$EXAMPLE_ROOT"/03-ttir \
  "$EXAMPLE_ROOT"/04-ttnn-ir \
  "$EXAMPLE_ROOT"/06-executable \
  "$EXAMPLE_ROOT"/logs
```

---

## 4. Frontend Lowering Driver

Create the driver script:

```bash
cd ~/bos-ai-compiler-demo
nano export_resnet50_artifacts.py
```

Paste:

```python
#!/usr/bin/env python3

from pathlib import Path

import torch
import torch_xla
import torch_xla.core.xla_model as xm
import torchvision.models as models
import torch_plugin_tt  # noqa: F401


MODEL_ROOT = Path.home() / "bos-ai-compiler-demo" / "tt-metal" / "models" / "bos_model" / "resnet50"
EXPORT_PATH = Path.home() / "bos-ai-compiler-demo" / "resnet50_tt_xla_artifacts" / "00-raw-codegen"


def build_model_from_model_root(model_root: Path) -> torch.nn.Module:
    print(f"[INFO] BOS model input directory: {model_root}")
    if not model_root.exists():
        raise FileNotFoundError(f"MODEL_ROOT does not exist: {model_root}")

    python_files = sorted(model_root.glob("*.py"))
    if python_files:
        print("[INFO] Python files available in MODEL_ROOT:")
        for path in python_files:
            print(f"  - {path.name}")

    # Replace this fallback with the exact BOS ResNet50 entrypoint from MODEL_ROOT if your
    # branch provides one.
    model = models.resnet50(weights=None)
    model.eval()
    return model


def main() -> None:
    EXPORT_PATH.mkdir(parents=True, exist_ok=True)

    options = {
        "backend": "codegen_py",
        "export_path": str(EXPORT_PATH),
    }
    torch_xla.set_custom_compile_options(options)

    device = xm.xla_device()
    model = build_model_from_model_root(MODEL_ROOT).to(device)

    if hasattr(model, "compile"):
        model.compile(backend="tt")
        compiled = model
    else:
        compiled = torch.compile(model, backend="tt")

    dummy_input = torch.randn(1, 3, 224, 224).to(device)

    with torch.no_grad():
        _ = compiled(dummy_input)

    print(f"[OK] Raw outputs written to: {EXPORT_PATH}")


if __name__ == "__main__":
    main()
```

---

## 5. Run the Artifact Export

```bash
cd ~/bos-ai-compiler-demo
source ~/.tt-xla-venv/bin/activate

export MODEL_ROOT=~/bos-ai-compiler-demo/tt-metal/models/bos_model/resnet50
export EXAMPLE_ROOT=~/bos-ai-compiler-demo/resnet50_tt_xla_artifacts

python export_resnet50_artifacts.py | tee "$EXAMPLE_ROOT/logs/frontend_codegen.log"
```

Copy the generated files into stage folders:

```bash
cp "$EXAMPLE_ROOT"/00-raw-codegen/irs/shlo_frontend_*.mlir "$EXAMPLE_ROOT"/01-frontend-shlo/ 2>/dev/null || true
cp "$EXAMPLE_ROOT"/00-raw-codegen/irs/shlo_resnet50_*.mlir "$EXAMPLE_ROOT"/02-optimized-shlo/ 2>/dev/null || true
cp "$EXAMPLE_ROOT"/00-raw-codegen/irs/ttir*.mlir "$EXAMPLE_ROOT"/03-ttir/ 2>/dev/null || true
cp "$EXAMPLE_ROOT"/00-raw-codegen/irs/ttnn*.mlir "$EXAMPLE_ROOT"/04-ttnn-ir/ 2>/dev/null || true
```

---

## 6. Generate the `.ttnn` Executable

This step needs the TT-MLIR tools built from source.

```bash
export TTMLIR_ROOT=/workspace/xla-dev/tt-mlir
export TTMLIR_OPT="$TTMLIR_ROOT/build/bin/ttmlir-opt"
export TTMLIR_TRANSLATE="$TTMLIR_ROOT/build/bin/ttmlir-translate"

TTIR_INPUT=$(find "$EXAMPLE_ROOT"/03-ttir -maxdepth 1 -name 'ttir*.mlir' | sort | head -n 1)

"$TTMLIR_OPT" \
  --ttir-to-ttnn-backend-pipeline \
  "$TTIR_INPUT" \
  -o "$EXAMPLE_ROOT/04-ttnn-ir/ttnn_backend.mlir"

"$TTMLIR_TRANSLATE" \
  --ttnn-to-flatbuffer \
  "$EXAMPLE_ROOT/04-ttnn-ir/ttnn_backend.mlir" \
  -o "$EXAMPLE_ROOT/06-executable/resnet50.ttnn"
```

---

## 7. Expected Outputs

```text
$EXAMPLE_ROOT/
  00-raw-codegen/
  01-frontend-shlo/shlo_frontend_*.mlir
  02-optimized-shlo/shlo_resnet50_*.mlir
  03-ttir/ttir_*.mlir
  04-ttnn-ir/ttnn_*.mlir
  06-executable/resnet50.ttnn
  logs/frontend_codegen.log
```

Quick verification:

```bash
find "$EXAMPLE_ROOT" -maxdepth 2 -type f | sort
```

---


