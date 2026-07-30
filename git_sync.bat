@echo off
setlocal enabledelayedexpansion

:: Multi-repo Git sync tool for Windows
:: Place in repo dir or parent dir, double-click to run

set "SD=%~dp0"
set "FL="

echo ============================================
echo   Git Multi-Repo Sync Tool
echo ============================================
echo.

:: Scan repos (check self first, then sibling dirs)
set "RC=0"
if exist "%SD%.git" (
    set /a RC+=1
    set "R1=%SD:~0,-1%"
    echo   [1] %SD:~0,-1%
)
for /d %%D in ("%SD%*") do (
    if exist "%%D\.git" (
        set /a RC+=1
        set "R!RC!=%%D"
        echo   [!RC!] %%~nxD
    )
)

if %RC%==0 (
    echo No Git repos found.
    pause
    exit /b 1
)

echo.
echo Found %RC% repo(s).
echo.

:: --- Main menu ---
:menu
echo ============================================
echo   [1] Fetch + Rebase
echo   [2] Commit + Push
echo   [3] All (Fetch, Commit, Push)
echo   [0] Exit
echo ============================================
choice /c 1230 /n /m "Choose: "
set "C=!errorlevel!"
if "!C!"=="4" goto :exit
if "!C!"=="1" goto :fetch_phase
if "!C!"=="2" goto :commit_phase
if "!C!"=="3" goto :fetch_phase
goto :menu

:: --- Fetch + Rebase ---
:fetch_phase
echo.
echo --------------------------------------------
echo   Fetch + Rebase
echo --------------------------------------------

set "I=0"
:fetch
set /a I+=1
if !I! gtr %RC% goto :fetch_done
set "P=!R%I%!"
for %%N in ("!P!") do set "N=%%~nxN"
echo [!N!]
pushd "!P!"
set "STASHED="
git fetch --all >nul 2>&1
if !errorlevel! equ 0 goto :rebase
echo   [FAIL] fetch
set "FL=!FL! !N!"
popd
echo.
goto :fetch
:rebase
git stash --include-untracked >nul 2>&1
if !errorlevel! equ 0 (
    set "STASHED=1"
) else (
    set "STASHED="
)
git rebase >nul 2>&1
if !errorlevel! equ 0 goto :rebase_ok
echo   [CONFLICT] rebase skipped
git rebase --abort >nul 2>&1
if defined STASHED (
    git stash pop >nul 2>&1
    if !errorlevel! neq 0 (
        echo   [WARN] stash pop conflict, dropping stash
        git checkout -- . >nul 2>&1
        git clean -fd >nul 2>&1
        git stash drop >nul 2>&1
    )
)
set "FL=!FL! !N!"
popd
echo.
goto :fetch
:rebase_ok
if defined STASHED (
    git stash pop >nul 2>&1
    if !errorlevel! neq 0 (
        echo   [WARN] stash pop conflict, dropping stash
        git checkout -- . >nul 2>&1
        git clean -fd >nul 2>&1
        git stash drop >nul 2>&1
    )
)
echo   [OK]
popd
echo.
goto :fetch

:fetch_done
echo.
goto :menu

:: --- Commit + Push ---
:commit_phase
echo.
echo --------------------------------------------
echo   Commit + Push
echo --------------------------------------------

:: Check changes
set "HC=0"
set "I=0"
:check
set /a I+=1
if !I! gtr %RC% goto :check_done
set "P=!R%I%!"
set "CC=0"
pushd "!P!"
for /f %%C in ('git status --porcelain 2^>nul ^| find /c /v ""') do set "CC=%%C"
popd
if not !CC! gtr 0 goto :check_next
for %%N in ("!P!") do set "N=%%~nxN"
echo   !N!: !CC! file(s) changed
set "HC=1"
:check_next
goto :check

:check_done
if !HC!==0 (
    echo No changes to commit.
    goto :push_phase
)

echo.
choice /c YN /n /m "Commit changes? (Y/n): "
if !errorlevel! equ 2 goto :push_phase

:: Do commit
set "I=0"
:commit
set /a I+=1
if !I! gtr %RC% goto :push_phase
set "P=!R%I%!"
set "CC=0"
pushd "!P!"
for /f %%C in ('git status --porcelain 2^>nul ^| find /c /v ""') do set "CC=%%C"
if not !CC! gtr 0 goto :commit_next
for %%N in ("!P!") do set "N=%%~nxN"
for /f "tokens=1-3 delims=/ " %%a in ("%date:~0,10%") do set "TD=%%a-%%b-%%c"
set "TM=%time:~0,5%"
set "MSG=update: !CC! files changed (!TD! !TM!)"
git add -A >nul 2>&1
git commit -m "!MSG!" >nul 2>&1
if !errorlevel! equ 0 (
    echo   [!N!] committed: !MSG!
) else (
    echo   [!N!] commit failed
    set "FL=!FL! !N!"
)
:commit_next
popd
goto :commit

:: --- Push ---
:push_phase
echo.
echo --------------------------------------------
echo   Push
echo --------------------------------------------
choice /c YN /n /m "Push to remote? (Y/n): "
if !errorlevel! equ 2 goto :push_done

set "I=0"
:push
set /a I+=1
if !I! gtr %RC% goto :push_done
set "P=!R%I%!"
for %%N in ("!P!") do set "N=%%~nxN"
set "U=0"
set "STASHED="
pushd "!P!"
for /f %%C in ('git log --oneline "@{u}..HEAD" 2^>nul ^| find /c /v ""') do set "U=%%C"
if not !U! gtr 0 goto :push_skip
echo [!N!] pushing !U! commit(s)...
git push >nul 2>&1
if !errorlevel! equ 0 (
    echo   [OK]
    goto :push_next
)
echo   [RETRY] fetch + rebase then push again...
git stash --include-untracked >nul 2>&1
if !errorlevel! equ 0 (
    set "STASHED=1"
) else (
    set "STASHED="
)
git fetch --all >nul 2>&1
if !errorlevel! neq 0 (
    echo   [FAIL] fetch
    if defined STASHED (
        git stash pop >nul 2>&1
        if !errorlevel! neq 0 (
            echo   [WARN] stash pop conflict, dropping stash
            git checkout -- . >nul 2>&1
            git clean -fd >nul 2>&1
            git stash drop >nul 2>&1
        )
    )
    set "FL=!FL! !N!"
    goto :push_next
)
git rebase >nul 2>&1
if !errorlevel! neq 0 (
    echo   [CONFLICT] rebase conflict, push aborted
    git rebase --abort >nul 2>&1
    if defined STASHED (
        git stash pop >nul 2>&1
        if !errorlevel! neq 0 (
            echo   [WARN] stash pop conflict, dropping stash
            git checkout -- . >nul 2>&1
            git clean -fd >nul 2>&1
            git stash drop >nul 2>&1
        )
    )
    set "FL=!FL! !N!"
    goto :push_next
)
if defined STASHED (
    git stash pop >nul 2>&1
    if !errorlevel! neq 0 (
        echo   [WARN] stash pop conflict, dropping stash
        git checkout -- . >nul 2>&1
        git clean -fd >nul 2>&1
        git stash drop >nul 2>&1
    )
)
git push >nul 2>&1
if !errorlevel! neq 0 (
    echo   [FAIL] push
    set "FL=!FL! !N!"
) else (
    echo   [OK] push after rebase
)
goto :push_next
:push_skip
echo [!N!] up to date
:push_next
popd
goto :push

:push_done
echo.
echo ============================================
if defined FL (
    echo   Failed:!FL!
) else (
    echo   All done.
)
echo ============================================
echo.
set "FL="
goto :menu

:exit
echo.
pause
exit /b 0
