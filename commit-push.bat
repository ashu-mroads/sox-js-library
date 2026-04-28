@echo off
setlocal EnableExtensions

REM ------------------------------------------------------------
REM commit-push-fixed.bat
REM Stages ONLY modified (tracked) + new (untracked) files,
REM commits, and pushes. Deletions are intentionally ignored.
REM This version avoids the "to was unexpected at this time." error
REM by not using parenthesized DO blocks and by calling a subroutine
REM per file (safer for paths with parentheses & special chars).
REM ------------------------------------------------------------

REM --- Validate git repo ---
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
  echo Not inside a Git repository.
  exit /b 1
)

REM --- Get commit message (args or prompt) ---
set "COMMIT_MSG=%*"
if not defined COMMIT_MSG set /p "COMMIT_MSG=Enter commit message: "
if not defined COMMIT_MSG (
  echo Commit message is required.
  exit /b 1
)

REM --- Strip double quotes & escape meta-chars so commit -m is safe ---
set "COMMIT_MSG=%COMMIT_MSG:"=%"
set "MSG_ESC=%COMMIT_MSG%"
set "MSG_ESC=%MSG_ESC:^=^^%"
set "MSG_ESC=%MSG_ESC:&=^&%"
set "MSG_ESC=%MSG_ESC:|=^|%"
set "MSG_ESC=%MSG_ESC:<=^<%"
set "MSG_ESC=%MSG_ESC:>=^>%"

echo.
echo Collecting modified tracked files...
set /a staged=0

REM --- Stage modified (tracked) files ---
for /f "usebackq delims=" %%F in (`git ls-files -m`) do call :StageFile "M" "%%F"

echo Collecting new (untracked) files...
for /f "usebackq delims=" %%F in (`git ls-files --others --exclude-standard`) do call :StageFile "A" "%%F"


echo Committing %staged% file(s)...
git commit -m "%MSG_ESC%"
if errorlevel 1 (
  echo Commit failed.
  exit /b 1
)

for /f "usebackq delims=" %%B in (`git rev-parse --abbrev-ref HEAD`) do set "BRANCH=%%B"
echo Pushing branch %BRANCH% ...
git push origin "%BRANCH%"
if errorlevel 1 (
  echo Push failed.
  exit /b 1
)


if errorlevel 1 (
  echo Push failed.
  exit /b 1
)

echo.
echo Done. Pushed branch %BRANCH%.
exit /b 0

REM ================= Subroutines =================
:StageFile
REM %1 = marker (M/A), %2 = filename
echo   %~1  %~2
git add "%~2" >nul
if not errorlevel 1 set /a staged+=1
goto :eof
