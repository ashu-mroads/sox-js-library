REM =============================================================================
REM Script: commit-push.bat
REM Purpose:
REM   Stage ONLY modified (tracked) + new (untracked) files (ignore deletions),
REM   create a commit, and push to a branch (current or specified).
REM
REM Usage:
REM   commit-push.bat "feat: add X"
REM   commit-push.bat -b feature/new-flow "feat: implement new flow"
REM   commit-push.bat -b hotfix/issue-123 Fix production issue
REM   commit-push.bat                (prompts for commit message)
REM 
REM Options:
REM   -b <branch>   Use or create the given branch (push sets upstream if new).
REM
REM Notes:
REM   - Deletions are not staged. To include them, replace staging loops with:
REM       git add -u & git add .
REM   - Remote branch auto-detected; first push uses -u if branch absent.
REM =============================================================================
@echo off
setlocal EnableExtensions

REM ------------------------------------------------------------
REM commit-push.bat
REM Stages ONLY modified (tracked) + new (untracked) files,
REM commits with provided message, and pushes.
REM Supports optional -b <branchName> to specify branch.
REM Deletions intentionally ignored.
REM ------------------------------------------------------------
REM Usage:
REM   commit-push.bat "feat: add X"
REM   commit-push.bat -b feature/my-branch "feat: add Y"
REM   commit-push.bat -b hotfix/issue123 Fix urgent bug
REM   commit-push.bat   (prompts for message)
REM ------------------------------------------------------------

REM --- Parse arguments: -b <branch> + commit message (rest) ---
set "BRANCH="
set "COMMIT_MSG="

:parse_args
if "%~1"=="" goto done_parse
if /i "%~1"=="-b" (
    shift
    if "%~1"=="" (
        echo Missing branch name after -b
        exit /b 1
    )
    set "BRANCH=%~1"
    shift
    goto parse_args
)
REM Accumulate commit message tokens
if defined COMMIT_MSG (set "COMMIT_MSG=%COMMIT_MSG% %~1") else set "COMMIT_MSG=%~1"
shift
goto parse_args
:done_parse

REM --- Ensure in git repo ---
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
  echo Not inside a Git repository.
  exit /b 1
)

REM --- If no commit message collected, prompt ---
if not defined COMMIT_MSG (
  set /p "COMMIT_MSG=Enter commit message: "
)
if not defined COMMIT_MSG (
  echo Commit message is required.
  exit /b 1
)

REM --- Resolve branch if not supplied ---
if not defined BRANCH (
  for /f "delims=" %%B in ('git rev-parse --abbrev-ref HEAD') do set "BRANCH=%%B"
)

REM --- Create branch locally if it does not exist ---
git show-ref --verify --quiet "refs/heads/%BRANCH%"
if errorlevel 1 (
  echo Local branch %BRANCH% does not exist. Creating...
  git checkout -b "%BRANCH%" >nul 2>&1
  if errorlevel 1 (
    echo Failed to create branch %BRANCH%.
    exit /b 1
  )
) else (
  REM Ensure we are on that branch
  for /f "delims=" %%C in ('git rev-parse --abbrev-ref HEAD') do set "CURRENT_BRANCH=%%C"
  if /i not "%CURRENT_BRANCH%"=="%BRANCH%" (
    git checkout "%BRANCH%" >nul
    if errorlevel 1 (
      echo Failed to checkout branch %BRANCH%.
      exit /b 1
    )
  )
)

echo.
echo Target branch: %BRANCH%

echo.
echo Collecting modified tracked files...
set /a staged=0

REM --- Stage modified (tracked) files ---
for /f "delims=" %%F in ('git ls-files -m') do call :StageFile "M" "%%F"

echo Collecting new (untracked) files...
for /f "delims=" %%F in ('git ls-files --others --exclude-standard') do call :StageFile "A" "%%F"

REM --- Anything staged? ---
git diff --cached --quiet
if not errorlevel 1 (
  echo.
  echo Nothing (added/modified) to commit. (Deletions ignored.)
  exit /b 0
)

echo.
echo Committing %staged% file^(s^) on %BRANCH% ...
git commit -m "%COMMIT_MSG%"
if errorlevel 1 (
  echo Commit failed.
  exit /b 1
)

REM --- Determine if remote branch exists ---
git ls-remote --exit-code --heads origin "%BRANCH%" >nul 2>&1
if errorlevel 1 (
  echo Remote branch does not exist. Pushing with -u origin %BRANCH% ...
  git push -u origin "%BRANCH%"
) else (
  echo Pushing to origin/%BRANCH% ...
  git push origin "%BRANCH%"
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