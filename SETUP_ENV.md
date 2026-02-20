# Dyn-HaMR Environment Setup (Windows 11 + RTX 5080)

This documents the full environment setup for running Dyn-HaMR on Windows with an NVIDIA RTX 5080 GPU. The official install script (`scripts/install_conda.sh`) targets Linux with PyTorch 1.13.0 + CUDA 11.7, which is incompatible with this hardware.

## Hardware & Software

- **OS**: Windows 11 Pro (10.0.22631)
- **GPU**: NVIDIA GeForce RTX 5080 (Blackwell architecture, compute capability sm_120)
- **CUDA Driver**: 12.8
- **Conda**: Anaconda

## Architecture

Two separate conda environments:

| Environment | Purpose | Status |
|---|---|---|
| `dynhamr` | Main pipeline: HaMeR hand tracking + dyn-hamr optimization | Working |
| `vipe` | VIPE camera estimation (standalone CLI tool) | Not yet created |

**Why two environments?** HaMeR is imported directly in Python during optimization (`from hamer.models import HAMER`), so it must share an environment with dyn-hamr. VIPE has 9 CUDA source files with its own Eigen/CUDA dependencies and runs as an independent CLI tool, so it must be separate.

---

## 1. Original Errors & Root Causes

### Error 1: numpy/pandas binary incompatibility
```
ValueError: numpy.dtype size changed, may indicate binary incompatibility. Expected 96 from C header, got 88 from PyObject
```
**Cause**: `pandas==1.4.0` was compiled against numpy 1.x (dtype size 88), but `numpy==2.2.6` was installed (dtype size 96). These are ABI-incompatible.

### Error 2: PyTorch + RTX 5080 compatibility
The RTX 5080 uses Blackwell architecture (sm_120). This requires very recent PyTorch builds:
- PyTorch 2.6.0+cu126: **no sm_120 kernels** - `RuntimeError: CUDA error: no kernel image is available`
- PyTorch 2.10.0+cu128: **compiled against numpy 2.x ABI** - DLL loading fails with numpy 1.x on Windows
- **PyTorch 2.7.0+cu128**: the sweet spot - supports sm_120 AND works with numpy 1.x

### Error 3: pyrender/EGL crash on Windows
```
ImportError: Unable to load EGL library
```
**Cause**: `dyn-hamr/vis/viewer.py` hardcoded `os.environ["PYOPENGL_PLATFORM"] = "egl"`, which is for headless Linux rendering. Windows uses WGL, not EGL.

### Error 4: Dead imports referencing missing packages
- `import mano` in `optim/base_scene.py` - only used in commented-out code
- `from human_body_prior.tools.model_loader import load_model` in `run_opt.py` - the installed `human_body_prior==0.8.5.0` doesn't have this function (it exists in unreleased v0.9+); only used in commented-out VPoser code

---

## 2. Conda Environment: `dynhamr`

### Golden Package Versions

| Package | Version | Why this version |
|---|---|---|
| Python | 3.10 | Required by project |
| PyTorch | 2.7.0+cu128 | Supports sm_120 (RTX 5080) + numpy 1.x ABI |
| torchvision | 0.22.0+cu128 | Matches PyTorch 2.7.0 |
| numpy | 1.26.4 | Last 1.x release; required by pandas 1.4.0 |
| pandas | 1.4.0 | Pinned by project requirements |
| opencv-python | 4.10.0.84 | Must be < 4.11 (4.11+ requires numpy >= 2) |
| mmcv | 1.3.9 | Pure Python version; works with any PyTorch |
| timm | 0.4.9 | Pinned by project |
| ultralytics | 8.1.34 | Pinned by project |
| smplx | 0.1.28 | Pinned by project |
| PyOpenGL | 3.1.0 | Pulled by human_body_prior; works on Windows with WGL |
| human_body_prior | 0.8.5.0 | Provides `copy2cpu` utility for HMP module |

### Installation Steps

```bash
# 1. Create environment
conda create -n dynhamr python=3.10 -y
conda activate dynhamr

# 2. PyTorch (must be first - other packages may pull wrong versions)
pip install torch==2.7.0 torchvision==0.22.0 --index-url https://download.pytorch.org/whl/cu128

# 3. numpy/pandas compatibility pair
pip install "numpy<2" pandas==1.4.0

# 4. Core scientific stack
pip install scipy scikit-image matplotlib "opencv-python<4.11"

# 5. ML/DL utilities
pip install tensorboard einops tqdm cython joblib dill

# 6. Config & data
pip install hydra-core pyyaml gdown

# 7. Pinned project dependencies
pip install mmcv==1.3.9 timm==0.4.9 ultralytics==8.1.34

# 8. 3D / rendering
pip install smplx==0.1.28 pyrender open3d imageio-ffmpeg trimesh

# 9. Other
pip install motmetrics xtcocotools yacs

# 10. GitHub-hosted packages
pip install git+https://github.com/nghorbani/configer
pip install --no-build-isolation git+https://github.com/mattloper/chumpy

# 11. HMP dependencies
pip install loguru human_body_prior plyfile

# 12. Re-pin numpy (some packages may have upgraded it)
pip install "numpy<2"

# 13. Install HaMeR (detectron2 removed from setup.py - not needed)
cd third-party/hamer
pip install -e .[all]

# 14. Install ViTPose
cd third-party/ViTPose
pip install -v -e .

# 15. Install dyn-hamr
cd ../../..
pip install -e .
```

### Packages Deliberately Skipped

| Package | Why skipped |
|---|---|
| detectron2 | Not needed at runtime - `run.py` uses YOLO/WiLoR exclusively |
| torch-scatter | Only needed for DROID-SLAM path (we use VIPE) |
| setuptools==59.5.0 | Too old; breaks modern pip |

---

## 3. Code Changes for Windows Compatibility

### Subprocess & Shell Fixes

| File | Change | Reason |
|---|---|---|
| `dyn-hamr/data/vidproc.py` | `run_vipe()`: replaced `source conda.sh && conda activate vipe` with `conda run -n vipe` | bash-only syntax doesn't work on Windows |
| `dyn-hamr/data/vidproc.py` | DROID-SLAM call: use `env=` param on `subprocess.call()` | `CUDA_VISIBLE_DEVICES=X cmd` inline syntax is Linux-only |
| `dyn-hamr/preproc/launch_hamer.py` | Use `subprocess.call(cmd, cwd=HAMER_DIR, env=env)` | Replaced `cd DIR;` (Linux) + inline env vars. Also switched path construction to `os.path.join()` |
| `dyn-hamr/preproc/launch_slam.py` | Use `env=` param on `subprocess.call()` | Same inline env var fix |
| `dyn-hamr/preproc/extract_frames.py` | `shutil.copytree()` instead of `os.system("cp -r ...")` | `cp` is a Unix command |
| `dyn-hamr/HMP/fitting_utils.py` | `ffmpeg` instead of `/usr/bin/ffmpeg` | Hardcoded Linux path; `ffmpeg` works if it's on PATH |

### Rendering / OpenGL Fixes

| File | Change | Reason |
|---|---|---|
| `dyn-hamr/vis/viewer.py` | Skip `PYOPENGL_PLATFORM=egl` on `sys.platform == "win32"` | EGL is Linux-only; Windows uses WGL natively |
| `third-party/hamer/hamer/utils/__init__.py` | Wrapped renderer imports in `try/except ImportError` | Prevents pyrender crash from blocking all HaMeR imports |

### Dead Import Removal

| File | Change | Reason |
|---|---|---|
| `dyn-hamr/optim/base_scene.py` | Removed `import mano` | Only used in commented-out code; `mano` package not installed |
| `dyn-hamr/run_opt.py` | Removed `from human_body_prior.tools.model_loader import load_model` and `from human_body_prior.models.vposer_model import VPoser` | `load_model` doesn't exist in installed v0.8.5.0; only used in commented-out VPoser loading code (`pose_prior = None` is the actual value) |
| `dyn-hamr/run_opt.py` | Removed `sys.path.append('src/human_body_prior')` | Directory doesn't exist in project |

### HaMeR Model / Renderer Fixes

| File | Change | Reason |
|---|---|---|
| `third-party/hamer/hamer/utils/renderer.py` | Skip `PYOPENGL_PLATFORM=egl` on Windows | EGL is Linux-only |
| `third-party/hamer/hamer/utils/mesh_renderer.py` | Skip `PYOPENGL_PLATFORM=egl` on Windows | EGL is Linux-only |
| `third-party/hamer/hamer/models/hamer.py` | Wrapped renderer init in try/except | `MeshRenderer` uses `pyrender.OffscreenRenderer` which needs EGL; gracefully falls back to `None` on Windows |
| `third-party/hamer/run.py` | Lazy import for `Renderer`/`cam_crop_to_full` | Prevents import-time crash when pyrender can't load EGL |

### Config Path Updates

| File | Change |
|---|---|
| `dyn-hamr/confs/data/video_vipe.yaml` | `root:` and `vipe_dir:` updated to `C:/Users/cuiln/Desktop/rewind/Dyn-HaMR/...` |
| `dyn-hamr/confs/data/video_driod.yaml` | `root:` updated to Windows path |

### HaMeR setup.py

| File | Change | Reason |
|---|---|---|
| `third-party/hamer/setup.py` | Commented out `detectron2 @ git+...` from `install_requires` | `run.py` uses YOLO/WiLoR, not detectron2 |

---

## 4. Batch Scripts

Created in `scripts/` for running the pipeline without manual environment switching:

| Script | Usage | Description |
|---|---|---|
| `run_vipe.bat` | `run_vipe.bat <video_path>` | Runs VIPE camera estimation in the `vipe` env |
| `run_dynhamr.bat` | `run_dynhamr.bat <seq_name> [config] [extra_args]` | Runs dyn-hamr optimization in `dynhamr` env |
| `run_pipeline.bat` | `run_pipeline.bat <seq_name>` | Full pipeline: VIPE then dyn-hamr |
| `setup_env.bat` | `setup_env.bat status\|test\|install` | Environment status, testing, install instructions |

---

## 5. Verification

```bash
conda activate dynhamr
python test_env.py
```

Expected output:
```
pandas: 1.4.0
numpy: 1.26.4
torch: 2.7.0+cu128
CUDA: True
GPU: NVIDIA GeForce RTX 5080
GPU compute: OK (device=cuda:0)
YOLO/ultralytics: OK
mmcv: 1.3.9
smplx: OK
hydra-core: OK
HaMeR models: OK
HaMeR utils: OK
HaMeR ViTDetDataset: OK
dyn-hamr data: OK
```

Full pipeline test:
```bash
cd dyn-hamr
python run_opt.py data=video_vipe run_opt=True data.seq=demo1
```
This should get past all imports and only fail on `FileNotFoundError: _DATA/BMC/bone_len_max.npy` (missing model checkpoints - see below).

---

## 6. Remaining Setup

### VIPE Conda Environment (not yet created)

Prerequisites: CUDA Toolkit 12.x system-wide, Visual Studio Build Tools (C++ workload).

```bash
conda create -n vipe python=3.10 -y
conda activate vipe
pip install torch==2.7.0 torchvision --index-url https://download.pytorch.org/whl/cu128
conda install -c conda-forge eigen ninja -y
cd third-party/vipe
pip install -r envs/requirements.txt
pip install --no-build-isolation -e .
```

### Model Checkpoints

The following data files need to be downloaded to `_DATA/`:

| Data | Location | Source |
|---|---|---|
| BMC constraints | `_DATA/BMC/` | Comes with HMP model download |
| HaMeR pretrained | `_DATA/` | `gdown` from project README |
| HMP model | `_DATA/hmp_model/` | `gdown` from project README |
| MANO model | `_DATA/data/mano/MANO_RIGHT.pkl` | From MANO website |
| WiLoR detector | `third-party/hamer/pretrained_models/detector.pt` | From WiLoR release |

### Known Warnings (non-blocking)

- `pkg_resources is deprecated as an API` from mmcv - cosmetic warning, can be suppressed by pinning `setuptools<81`
