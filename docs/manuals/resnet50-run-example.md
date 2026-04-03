# ResNet50 Run Example

**Goal:** Run ResNet50 on TT-XLA after installation is complete.

This file covers runtime execution only. It assumes:

- TT-XLA is already installed
- the BOS device is visible
- the Python environment works

If that is not true yet, start with `tt-xla-installation-manual.md`.

---

## 1. Quick Verification Before Running

```bash
source ~/.tt-xla-venv/bin/activate
python3 -c "import jax; print(jax.devices('tt'))"
python3 -c "import torch_plugin_tt; print('torch_plugin_tt loaded OK')"
ls /dev/bos/
```

---

## 2. Create the Runtime Script

```bash
cd ~/bos-ai-compiler-demo
nano run_resnet50_tt.py
```

Paste:

```python
#!/usr/bin/env python3

import os
import urllib.request

import torch
import torchvision.models as models
import torchvision.transforms as transforms
from PIL import Image
import torch_plugin_tt  # noqa: F401


print("[INFO] torch_plugin_tt backend registered.")

weights = models.ResNet50_Weights.IMAGENET1K_V1
model = models.resnet50(weights=weights)
model.eval()
print("[OK] ResNet50 loaded.")

compiled_model = torch.compile(model, backend="tt")
print("[OK] Model compiled.")

sample_img_path = "/tmp/tt_xla_sample_dog.jpg"
sample_img_url = (
    "https://upload.wikimedia.org/wikipedia/commons/thumb/4/43/"
    "Cute_dog.jpg/320px-Cute_dog.jpg"
)

if not os.path.exists(sample_img_path):
    urllib.request.urlretrieve(sample_img_url, sample_img_path)

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
input_tensor = preprocess(img).unsqueeze(0)

with torch.no_grad():
    output = compiled_model(input_tensor)

print(f"[OK] Output shape: {output.shape}")

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
    prob = top5_prob[i].item() * 100
    print(f"  {i+1}. {label:<40} {prob:.2f}%")
```

---

## 3. Run the Script

```bash
cd ~/bos-ai-compiler-demo
source ~/.tt-xla-venv/bin/activate
python run_resnet50_tt.py
```

---

## 4. Expected Runtime Output

You should see output similar to:

```text
[INFO] torch_plugin_tt backend registered.
[OK] ResNet50 loaded.
[OK] Model compiled.
[OK] Output shape: torch.Size([1, 1000])

[RESULT] Top-5 ImageNet Predictions:
  1. golden retriever                          ...
  2. Labrador retriever                        ...
  3. kuvasz                                    ...
  4. Great Pyrenees                            ...
  5. clumber spaniel                           ...
```

The exact probabilities can change. The important checks are:

- the script compiles without failing
- the output shape is `torch.Size([1, 1000])`
- top-5 predictions are printed

---

## 5. Optional Smoke Test

If you want a smaller check before using an image:

```python
import torch
import torchvision.models as models
import torch_plugin_tt  # noqa: F401

model = models.resnet50(weights=None)
model.eval()
compiled_model = torch.compile(model, backend="tt")

dummy_input = torch.randn(1, 3, 224, 224)
with torch.no_grad():
    out = compiled_model(dummy_input)

print(out.shape)
```

Expected result:

```text
torch.Size([1, 1000])
```
