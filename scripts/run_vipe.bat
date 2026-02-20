@echo off
REM ============================================================
REM  Run VIPE camera estimation on a video
REM  Usage: run_vipe.bat <video_path> [output_dir]
REM
REM  Example:
REM    run_vipe.bat C:\Users\cuiln\Desktop\rewind\Dyn-HaMR\test\videos\demo1.mp4
REM ============================================================
setlocal enabledelayedexpansion

set "PROJECT_ROOT=%~dp0.."
set "VIPE_ROOT=%PROJECT_ROOT%\third-party\vipe"
set "DEFAULT_OUTPUT=%VIPE_ROOT%\vipe_results"

if "%~1"=="" (
    echo Usage: run_vipe.bat ^<video_path^> [output_dir]
    echo.
    echo Arguments:
    echo   video_path   Path to input video file
    echo   output_dir   (Optional) Directory for VIPE results
    echo                Default: %DEFAULT_OUTPUT%
    exit /b 1
)

set "VIDEO_PATH=%~1"
set "OUTPUT_DIR=%~2"
if "%OUTPUT_DIR%"=="" set "OUTPUT_DIR=%DEFAULT_OUTPUT%"

if not exist "%VIDEO_PATH%" (
    echo ERROR: Video not found: %VIDEO_PATH%
    exit /b 1
)

echo ============================================================
echo  VIPE Camera Estimation
echo ============================================================
echo  Video:  %VIDEO_PATH%
echo  Output: %OUTPUT_DIR%
echo  VIPE:   %VIPE_ROOT%
echo ============================================================
echo.

REM Use conda run to execute in the vipe environment
conda run -n vipe --cwd "%VIPE_ROOT%" vipe infer "%VIDEO_PATH%"

if %ERRORLEVEL% neq 0 (
    echo.
    echo ERROR: VIPE failed with exit code %ERRORLEVEL%
    echo.
    echo Troubleshooting:
    echo   1. Make sure the 'vipe' conda environment exists:
    echo      conda env list
    echo   2. Try running manually:
    echo      conda activate vipe
    echo      cd %VIPE_ROOT%
    echo      vipe infer %VIDEO_PATH%
    exit /b %ERRORLEVEL%
)

echo.
echo VIPE completed successfully!
echo Results saved to: %OUTPUT_DIR%
endlocal
