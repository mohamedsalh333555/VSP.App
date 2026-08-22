@echo off
set ANDROID_AVD_HOME=K:\Android_AVD
set TEMP=K:\Temp
set TMP=K:\Temp
cd /d "%LOCALAPPDATA%\Android\Sdk\emulator"
start "" "%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe" -avd Pixel_9 -gpu host
