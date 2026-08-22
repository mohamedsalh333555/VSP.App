@echo off
title Samsung Galaxy Emulator
echo Starting Samsung Galaxy Mobile Emulator...
cd /d "%LOCALAPPDATA%\Android\Sdk\emulator"
start "" "%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe" -avd Samsung_Galaxy -gpu host -no-snapshot-load
echo Emulator process started!
