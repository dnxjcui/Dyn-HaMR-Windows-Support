@echo off
REM ============================================================
REM  Full Dyn-HaMR Pipeline: VIPE cameras -> Dyn-HaMR optimization
REM  Usage: run_pipeline.bat <sequence_name> [extra_dynhamr_args]
REM
REM  This script:
REM    1. Runs VIPE in the 'vipe' conda env to estimate cameras
REM    2. Runs Dyn-HaMR in the 'dynhamr' conda env for optimization
REM
REM  Example:
REM    run_pipeline.bat demo1
REM    run_pipeline.bat demo1 "run_prior=True"
REM ============================================================
setlocal enabledelayedexpansion

set "PROJECT_ROOT=%~dp0.."
set "SCRIPTS_DIR=%~dp0"

if "%~1"=="" (
    echo Usage: run_pipeline.bat ^<sequence_name^> [extra_dynhamr_args]
    echo.
    echo The video should be at: test\videos\^<sequence_name^>.mp4
    exit /b 1
)

set "SEQ=%~1"
set "EXTRA=%~2"
set "VIDEO_PATH=%PROJECT_ROOT%\test\videos\%SEQ%.mp4"

if not exist "%VIDEO_PATH%" (
    echo ERROR: Video not found: %VIDEO_PATH%
    echo Please place your video at: test\videos\%SEQ%.mp4
    exit /b 1
)

echo ============================================================
echo  Full Dyn-HaMR Pipeline
echo ============================================================
echo  Sequence: %SEQ%
echo  Video:    %VIDEO_PATH%
echo ============================================================
echo.

REM --- Step 1: VIPE Camera Estimation ---
echo [Step 1/2] Running VIPE camera estimation...
echo.
call "%SCRIPTS_DIR%run_vipe.bat" "%VIDEO_PATH%"
if %ERRORLEVEL% neq 0 (
    echo.
    echo Pipeline aborted: VIPE failed.
    echo You can skip VIPE if camera results already exist.
    exit /b 1
)
echo.

REM --- Step 2: Dyn-HaMR Optimization ---
echo [Step 2/2] Running Dyn-HaMR optimization...
echo.
call "%SCRIPTS_DIR%run_dynhamr.bat" "%SEQ%" video_vipe %EXTRA%
if %ERRORLEVEL% neq 0 (
    echo.
    echo Pipeline aborted: Dyn-HaMR optimization failed.
    exit /b 1
)

echo.
echo ============================================================
echo  Pipeline completed successfully!
echo  Results are in: %PROJECT_ROOT%\outputs\
echo ============================================================
endlocal
