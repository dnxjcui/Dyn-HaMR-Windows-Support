"""Quick environment verification script"""
import os
import sys

print(f"Python: {sys.version}")

import pandas; print(f"pandas: {pandas.__version__}")
import numpy; print(f"numpy: {numpy.__version__}")
import torch; print(f"torch: {torch.__version__}")
print(f"CUDA: {torch.cuda.is_available()}")
if torch.cuda.is_available():
    print(f"GPU: {torch.cuda.get_device_name(0)}")
    x = torch.randn(2,2).cuda()
    print(f"GPU compute: OK (device={x.device})")

from ultralytics import YOLO; print("YOLO/ultralytics: OK")
import mmcv; print(f"mmcv: {mmcv.__version__}")
import smplx; print("smplx: OK")
import hydra; print("hydra-core: OK")

# Try HaMeR imports
try:
    from hamer.models import HAMER, load_hamer; print("HaMeR models: OK")
    from hamer.utils import recursive_to; print("HaMeR utils: OK")
    from hamer.datasets.vitdet_dataset import ViTDetDataset; print("HaMeR ViTDetDataset: OK")
except Exception as e:
    print(f"HaMeR: ISSUE ({type(e).__name__}: {e})")

# Try the main dyn-hamr imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'dyn-hamr'))
try:
    from data import get_dataset_from_cfg, expand_source_paths; print("dyn-hamr data: OK")
except Exception as e:
    print(f"dyn-hamr data: ISSUE ({type(e).__name__}: {e})")

print()
print("Verification complete!")
