@echo off
echo Installing iPhone Farm Monitor dependencies...
pip install -r requirements.txt
if %errorlevel% neq 0 (
    echo ERROR: pip install failed. Make sure Python 3.10+ is installed.
    pause
    exit /b 1
)
echo.
echo Done! Run with:
echo   python main.py --devices 192.168.1.xxx --cols 4
pause
