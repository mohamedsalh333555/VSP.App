@echo off
title Pixel 9 Mobile Emulator
echo Setting up environment on Drive K (2.8 TB Free Space)...
set ANDROID_AVD_HOME=K:\Android_AVD
set TEMP=K:\Temp
set TMP=K:\Temp
cd /d "%LOCALAPPDATA%\Android\Sdk\emulator"
echo Launching Pixel 9 Emulator...
start "" "%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe" -avd Pixel_9 -gpu host
echo Done!
