@echo off
REM ============================================================
REM  Run Dyn-HaMR optimization pipeline
REM  Usage: run_dynhamr.bat <sequence_name> [data_config] [extra_args]
REM
REM  Examples:
REM    run_dynhamr.bat demo1
REM    run_dynhamr.bat demo1 video_vipe
REM    run_dynhamr.bat demo1 video_vipe "run_prior=True"
REM ============================================================
setlocal enabledelayedexpansion

set "PROJECT_ROOT=%~dp0.."
set "DYNHAMR_DIR=%PROJECT_ROOT%\dyn-hamr"

if "%~1"=="" (
    echo Usage: run_dynhamr.bat ^<sequence_name^> [data_config] [extra_args]
    echo.
    echo Arguments:
    echo   sequence_name  Name of the video sequence (e.g., demo1)
    echo   data_config    Config name: video_vipe (default) or video_driod
    echo   extra_args     Additional Hydra overrides (e.g., "run_prior=True")
    echo.
    echo The video should be at: test\videos\^<sequence_name^>.mp4
    exit /b 1
)

set "SEQ=%~1"
set "DATA_CFG=%~2"
if "%DATA_CFG%"=="" set "DATA_CFG=video_vipe"
set "EXTRA=%~3"

echo ============================================================
echo  Dyn-HaMR Optimization Pipeline
echo ============================================================
echo  Sequence:  %SEQ%
echo  Config:    %DATA_CFG%
echo  Extra:     %EXTRA%
echo  WorkDir:   %DYNHAMR_DIR%
echo ============================================================
echo.

REM Run using conda run in the dynhamr environment
conda run -n dynhamr --cwd "%DYNHAMR_DIR%" python run_opt.py data=%DATA_CFG% run_opt=True data.seq=%SEQ% %EXTRA%

if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: Dyn-HaMR failed with exit code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

echo.
echo Dyn-HaMR completed successfully!
endlocal
