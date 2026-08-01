@echo off
@chcp 65001 >nul 2>&1
@setlocal
@cd /d "%~dp0"

@where dart >nul 2>&1
@if errorlevel 1 (
    echo [错误] 未检测到 Dart SDK，请先安装并加入 PATH。
    echo 下载：https://dart.dev/get-dart
    pause
    exit /b 1
)

@dart git_sync.dart
@set EXITCODE=%errorlevel%
@endlocal & exit /b %EXITCODE%