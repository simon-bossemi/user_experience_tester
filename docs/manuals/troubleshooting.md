# TT-XLA Troubleshooting

This file covers troubleshooting that is not purely installation setup.

For hardware, driver, wheel-install, Docker, or source-build setup issues, use
`tt-xla-installation-manual.md`.

This file focuses on:

- artifact generation issues
- practical-example issues
- runtime execution issues

---

## 1. Artifact Generation Issues

### `Compile option 'export_path' must be provided`

Your export driver did not set TT-XLA codegen options before compile time.

Check:

```bash
grep -n "export_path" ~/bos-ai-compiler-demo/export_resnet50_artifacts.py
```

The script should define:

```python
options = {
    "backend": "codegen_py",
    "export_path": str(EXPORT_PATH),
}
```

### `MODEL_ROOT` is wrong or empty

```bash
echo "$MODEL_ROOT"
find "$MODEL_ROOT" -maxdepth 2 -type f | sort
```

If the directory is wrong, re-clone:

```bash
cd ~/bos-ai-compiler-demo
rm -rf tt-metal
git clone --branch develop https://github.com/bos-semi-release/tt-metal.git
export MODEL_ROOT=~/bos-ai-compiler-demo/tt-metal/models/bos_model/resnet50
```

### No TTIR file is generated

```bash
find "$EXAMPLE_ROOT"/00-raw-codegen -name 'ttir*.mlir' -ls
sed -n '1,200p' "$EXAMPLE_ROOT/logs/frontend_codegen.log"
```

If no TTIR appears, inspect the frontend log before retrying.

### `ttmlir-opt` or `ttmlir-translate` is missing

```bash
ls -l /workspace/xla-dev/tt-mlir/build/bin/ttmlir-opt
ls -l /workspace/xla-dev/tt-mlir/build/bin/ttmlir-translate
```

If they do not exist, return to the source-build section in the installation manual and rebuild
TT-MLIR.

### Frontend compile appears to hang

The first compile can take time.

Check whether the process is still active:

```bash
top -b -n 1 | head -20
```

---

## 2. Runtime Execution Issues

### `No chips detected in the cluster`

The Python packages are installed, but runtime device discovery still fails.

Check:

```bash
ls /dev/bos/
ls /sys/class/bos
python3 -c "import jax; print(jax.devices('tt'))"
```

If `/sys/class/bos` exists but `/dev/bos/` is missing, fix the device-node setup first.

### `torch.compile` takes a long time

That is normal on the first full compile. Wait for the compile to finish before interrupting the
process.

### Runtime script fails to download the sample image

Your system may not have public network access.

Replace the remote image URL with a local file path and update the script to open that local image.

### Output shape is wrong

The ResNet50 example expects:

```text
torch.Size([1, 1000])
```

If you get a different shape, check:

- the model definition
- the input tensor shape
- whether you accidentally changed preprocessing

### No top-5 predictions are printed

Check that:

- the output tensor was produced
- `imagenet_classes.txt` downloaded successfully
- the category file contains 1000 labels

---

## 3. JAX Runtime Checks

If you want a fast runtime sanity check:

```python
import jax
import jax.numpy as jnp
import jax_plugin_tt  # noqa: F401

print(jax.devices("tt"))

@jax.jit
def matmul(a, b):
    return jnp.matmul(a, b)

a = jnp.ones((128, 128))
b = jnp.ones((128, 128))
print(matmul(a, b).shape)
```

Expected result:

- one or more TT devices are listed
- the matrix multiplication result shape is `(128, 128)`
