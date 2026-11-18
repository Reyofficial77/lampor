@echo off
setlocal
title LAMPOR: Malam Jahanam
echo ===================================================
echo           LAMPOR: MALAM JAHANAM
echo   Indonesian Folklore Horror Survival Game
echo ===================================================
echo Memulai permainan menggunakan Godot Engine 4...

set "GODOT_EXE="
for %%G in ("%USERPROFILE%\Desktop\godot-*.exe") do if exist "%%~fG" set "GODOT_EXE=%%~fG"
if not defined GODOT_EXE for %%G in ("%USERPROFILE%\Documents\Godot\Godot_v4*.exe") do if exist "%%~fG" set "GODOT_EXE=%%~fG"
if not defined GODOT_EXE for %%G in (godot.exe godot4.exe) do (where %%G >nul 2>&1 && set "GODOT_EXE=%%G" && goto :found)

:found
if not defined GODOT_EXE (
  echo Godot Engine 4 tidak ditemukan.
  echo Letakkan godot-*.exe di Desktop atau Godot_v4*.exe di Documents\Godot,
  echo atau tambahkan Godot ke PATH.
  pause
  exit /b 1
)
start "" "%GODOT_EXE%" --path "%~dp0"
endlocal
