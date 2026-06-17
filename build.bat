@echo off
rem ============================================================================
rem 192p Test Suite - build script
rem Builds the standard (plain GTIA) XEX into the bin\ subfolder.
rem Paths are relative to this script, so it works from any checkout/worktree.
rem ============================================================================

rem MADS path: override with the MADS env var, else fall back to local default.
if not defined MADS set "MADS=d:\RustyBits\Software_XE\Mad-Assembler-2.1.6\bin\windows_x86_64\mads.exe"
set "ROOT=%~dp0"

if not exist "%ROOT%bin" mkdir "%ROOT%bin"

"%MADS%" "%ROOT%main.asm" -o:"%ROOT%bin\192p.xex"
if errorlevel 1 (
    echo BUILD FAILED
    exit /b 1
)
echo BUILD OK -^> bin\192p.xex
