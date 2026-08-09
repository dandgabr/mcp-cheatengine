@echo off
setlocal enabledelayedexpansion
title "Cheat Engine MCP Server - Launcher & Configurator"

:: Verificar se tem privilégios de Administrador
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Elevando privilegios para Administrador para acessar pasta do Cheat Engine...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

cd /d "%~dp0"
set CE_MCP_DEBUG=true
echo ============================================================
echo   Iniciando Launcher do Cheat Engine MCP Server (DEBUG=ON)...
echo ============================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\launcher.ps1" -DebugLogs 1

echo.
echo Pressione qualquer tecla para fechar este terminal...
pause >nul
