@echo off
title VSP Android Emulator Launcher
echo Starting Oppo A95 Mobile Emulator...
cd /d "%LOCALAPPDATA%\Android\Sdk\emulator"
start "" "%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe" -avd Oppo_A95
echo Emulator launch command sent!
