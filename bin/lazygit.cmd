@echo off
setlocal

if "%USERPROFILE%"=="" (
  echo USERPROFILE not set; cannot locate WinGet lazygit 1>&2
  exit /b 1
)

set "WINGET_DIR=%USERPROFILE%\AppData\Local\Microsoft\WinGet\Packages"
for /f "delims=" %%F in ('dir /b /s "%WINGET_DIR%\JesseDuffield.lazygit_*\lazygit.exe" 2^>nul') do (
  "%%~fF" %*
  exit /b %ERRORLEVEL%
)

echo lazygit.exe not found under %WINGET_DIR% 1>&2
exit /b 1
