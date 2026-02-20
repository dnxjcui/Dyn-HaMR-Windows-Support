@echo off
REM ============================================================
REM  Dyn-HaMR Environment Manager
REM  Usage: setup_env.bat <command>
REM
REM  Commands:
REM    status    Show status of all environments
REM    dynhamr   Activate dynhamr env (prints activation command)
REM    vipe      Activate vipe env (prints activation command)
REM    test      Run environment verification tests
REM    install   Install/reinstall a specific environment
REM ============================================================
setlocal enabledelayedexpansion

set "PROJECT_ROOT=%~dp0.."

if "%~1"=="" goto :usage

if /i "%~1"=="status" goto :status
if /i "%~1"=="dynhamr" goto :activate_dynhamr
if /i "%~1"=="vipe" goto :activate_vipe
if /i "%~1"=="test" goto :test
if /i "%~1"=="install" goto :install
goto :usage

REM ---- Status ----
:status
echo.
echo === Conda Environments ===
conda env list 2>nul | findstr /i "dynhamr vipe"
echo.

echo === dynhamr Environment ===
conda run -n dynhamr python -c "import torch; print(f'  PyTorch: {torch.__version__}'); print(f'  CUDA: {torch.cuda.is_available()}'); print(f'  GPU: {torch.cuda.get_device_name(0) if torch.cuda.is_available() else \"N/A\"}')" 2>nul
if %ERRORLEVEL% neq 0 echo   NOT INSTALLED or broken
echo.

echo === vipe Environment ===
conda run -n vipe python -c "import torch; print(f'  PyTorch: {torch.__version__}'); print(f'  CUDA: {torch.cuda.is_available()}')" 2>nul
if %ERRORLEVEL% neq 0 echo   NOT INSTALLED or broken
echo.

echo === Environment Architecture ===
echo   dynhamr: HaMeR + dyn-hamr optimization pipeline
echo            (PyTorch 2.7 + CUDA 12.8, numpy 1.x, pandas 1.4)
echo.
echo   vipe:    VIPE camera estimation (standalone)
echo            (PyTorch 2.7 + CUDA 12.8, separate CUDA extensions)
echo.
echo   NOTE: HaMeR must stay in dynhamr (imported directly in Python).
echo         VIPE must be separate (heavy CUDA extensions, different deps).
goto :eof

REM ---- Activate dynhamr ----
:activate_dynhamr
echo.
echo To activate the dynhamr environment, run:
echo   conda activate dynhamr
echo.
echo Then you can run:
echo   cd %PROJECT_ROOT%\dyn-hamr
echo   python run_opt.py data=video_vipe run_opt=True data.seq=demo1
echo.
echo Or use the batch script:
echo   %PROJECT_ROOT%\scripts\run_dynhamr.bat demo1
goto :eof

REM ---- Activate vipe ----
:activate_vipe
echo.
echo To activate the vipe environment, run:
echo   conda activate vipe
echo.
echo Then you can run:
echo   cd %PROJECT_ROOT%\third-party\vipe
echo   vipe infer path\to\video.mp4
echo.
echo Or use the batch script:
echo   %PROJECT_ROOT%\scripts\run_vipe.bat path\to\video.mp4
goto :eof

REM ---- Test ----
:test
echo.
echo === Testing dynhamr environment ===
conda run -n dynhamr python "%PROJECT_ROOT%\test_env.py"
echo.
echo === Testing vipe environment ===
conda run -n vipe python -c "import torch; print(f'torch: {torch.__version__}'); print(f'CUDA: {torch.cuda.is_available()}'); import vipe; print('vipe: OK')" 2>nul
if %ERRORLEVEL% neq 0 echo   vipe environment not set up yet (this is OK if you haven't installed it)
goto :eof

REM ---- Install ----
:install
if "%~2"=="" (
    echo Usage: setup_env.bat install ^<dynhamr^|vipe^>
    goto :eof
)
if /i "%~2"=="dynhamr" (
    echo.
    echo To reinstall dynhamr, follow the plan in:
    echo   %PROJECT_ROOT%\.claude\plans\hashed-frolicking-curry.md
    echo.
    echo Quick summary:
    echo   conda create -n dynhamr python=3.10 -y
    echo   conda activate dynhamr
    echo   pip install torch==2.7.0 torchvision --index-url https://download.pytorch.org/whl/cu128
    echo   pip install "numpy<2" pandas==1.4.0
    echo   ... (see plan for full steps)
)
if /i "%~2"=="vipe" (
    echo.
    echo To install vipe:
    echo   conda create -n vipe python=3.10 -y
    echo   conda activate vipe
    echo   pip install torch==2.7.0 torchvision --index-url https://download.pytorch.org/whl/cu128
    echo   cd %PROJECT_ROOT%\third-party\vipe
    echo   pip install -r envs\requirements.txt
    echo   pip install --no-build-isolation -e .
    echo.
    echo Prerequisites:
    echo   - CUDA Toolkit 12.x installed system-wide
    echo   - Visual Studio Build Tools (C++ workload)
    echo   - conda install -c conda-forge eigen ninja
)
goto :eof

REM ---- Usage ----
:usage
echo.
echo Dyn-HaMR Environment Manager
echo.
echo Usage: setup_env.bat ^<command^>
echo.
echo Commands:
echo   status    Show status of all environments
echo   dynhamr   Show how to activate dynhamr
echo   vipe      Show how to activate vipe
echo   test      Run verification tests
echo   install   Show install instructions (install dynhamr ^| install vipe)
echo.
endlocal
