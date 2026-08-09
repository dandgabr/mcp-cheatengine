<#
.SYNOPSIS
    Launcher e Configurador Automático do Cheat Engine MCP Server
.DESCRIPTION
    Detecta a instalação do Cheat Engine, acopla a ponte Lua no autorun do CE,
    configura os clientes de IA (Claude, Antigravity, Cursor, VS Code) e inicia o Cheat Engine.
#>

param(
    [string]$TargetAI = "all", # 'claude', 'antigravity', 'cursor', 'vscode', 'all', 'none'
    [string]$AutoLaunch = "true",
    [string]$DebugLogs = "true"
)

$ErrorActionPreference = "Stop"

$shouldLogDebug = ($DebugLogs -eq "true" -or $DebugLogs -eq "1" -or $DebugLogs -eq "yes" -or $DebugLogs -eq "True")

function Write-Log([string]$message, [string]$level = "DEBUG") {
    if (-not $shouldLogDebug -and $level -eq "DEBUG") { return }
    $timestamp = Get-Date -Format "HH:mm:ss"
    $color = "Cyan"
    if ($level -eq "INFO") { $color = "Green" }
    elseif ($level -eq "WARN") { $color = "Yellow" }
    elseif ($level -eq "ERROR") { $color = "Red" }
    
    Write-Host "[$level][$timestamp][PS] $message" -ForegroundColor $color
}

Write-Log "Inicializando Launcher (DebugLogs=$DebugLogs)..." "INFO"

$shouldLaunch = ($AutoLaunch -eq "true" -or $AutoLaunch -eq "1" -or $AutoLaunch -eq "yes")

# Verificar se está rodando como Administrador
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Log "Solicitando privilégios de Administrador para acessar C:\Program Files..." "WARN"
    $scriptPath = $MyInvocation.MyCommand.Path
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -TargetAI `"$TargetAI`" -AutoLaunch `"$AutoLaunch`" -DebugLogs `"$DebugLogs`""
    Start-Process powershell -Verb RunAs -ArgumentList $argList
    exit
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  🎮 CHEAT ENGINE MCP SERVER LAUNCHER & CONFIGURATOR" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Obter diretório raiz do repositório
$RepoDir = Resolve-Path (Join-Path $PSScriptRoot "..")
Write-Host "[+] Diretório do projeto: $RepoDir" -ForegroundColor Green

# 2. Verificar/Configurar Python & Virtualenv
$VenvPython = Join-Path $RepoDir "venv\Scripts\python.exe"
if (-not (Test-Path $VenvPython)) {
    Write-Host "[!] Criando ambiente virtual Python em 'venv'..." -ForegroundColor Yellow
    python -m venv (Join-Path $RepoDir "venv")
}

Write-Host "[+] Instalando/Verificando dependências Python..." -ForegroundColor Green
& $VenvPython -m pip install -r (Join-Path $RepoDir "requirements.txt") --quiet

# 3. Localizar Instalação do Cheat Engine no Windows
Write-Host "[+] Buscando instalação do Cheat Engine no sistema..." -ForegroundColor Green

$CEPath = $null

# Procurar no Registro do Windows
$RegPaths = @(
    "HKLM:\SOFTWARE\Cheat Engine",
    "HKLM:\SOFTWARE\WOW6432Node\Cheat Engine",
    "HKCU:\Software\Cheat Engine"
)

foreach ($regPath in $RegPaths) {
    if (Test-Path $regPath) {
        $installDir = (Get-ItemProperty -Path $regPath -ErrorAction SilentlyContinue).InstallFolder
        if ($installDir -and (Test-Path $installDir)) {
            $CEPath = $installDir
            break
        }
    }
}

# Procurar em diretórios comuns de instalação se não encontrado no Registro
if (-not $CEPath) {
    $CommonPaths = @(
        "C:\Program Files\Cheat Engine",
        "C:\Program Files\Cheat Engine 7.6",
        "C:\Program Files\Cheat Engine 7.5",
        "C:\Program Files\Cheat Engine 7.4",
        "C:\Program Files (x86)\Cheat Engine",
        "C:\Cheat Engine"
    )
    foreach ($path in $CommonPaths) {
        if (Test-Path $path) {
            $CEPath = $path
            break
        }
    }
}

if (-not $CEPath) {
    Write-Host "[!] Cheat Engine não foi localizado automaticamente." -ForegroundColor Red
    $CEPath = Read-Host "[-] Digite o caminho completo do diretório do Cheat Engine (ex: C:\Program Files\Cheat Engine)"
}

if (-not (Test-Path $CEPath)) {
    Write-Error "Caminho do Cheat Engine inválido ou não encontrado: $CEPath"
}

Write-Host "[SUCESSO] Cheat Engine localizado em: $CEPath" -ForegroundColor Green

# 4. Acoplar a Ponte Lua no Autorun do Cheat Engine
$CEAutorunDir = Join-Path $CEPath "autorun"
if (-not (Test-Path $CEAutorunDir)) {
    New-Item -ItemType Directory -Path $CEAutorunDir -Force | Out-Null
}

$LuaBridgeSource = Join-Path $RepoDir "lua\ce_mcp_lua.lua"
$LuaAutorunSource = Join-Path $RepoDir "lua\autorun\ce_mcp_autorun.lua"

# Remover cópia antiga no autorun se existir para evitar execução duplicada
$OldAutorunLua = Join-Path $CEAutorunDir "ce_mcp_lua.lua"
if (Test-Path $OldAutorunLua) {
    Remove-Item -Path $OldAutorunLua -Force -ErrorAction SilentlyContinue
}

Copy-Item -Path $LuaBridgeSource -Destination (Join-Path $CEPath "ce_mcp_lua.lua") -Force
Copy-Item -Path $LuaAutorunSource -Destination (Join-Path $CEAutorunDir "ce_mcp_autorun.lua") -Force

Write-Host "[SUCESSO] Ponte Lua acoplada com sucesso no Autorun do Cheat Engine!" -ForegroundColor Green

# 5. Configurar Clientes MCP de IA
$PythonExec = $VenvPython.ToString().Replace('\', '/')
$ServerScript = (Join-Path $RepoDir "ce_mcp_server.py").ToString().Replace('\', '/')
$SrcDir = (Join-Path $RepoDir "src").ToString().Replace('\', '/')

$McpConfigTemplate = @{
    mcpServers = @{
        cheat_engine = @{
            command = $PythonExec
            args = @($ServerScript)
            env = @{
                PYTHONPATH = $SrcDir
                CE_HOST = "127.0.0.1"
                CE_PORT = "52737"
            }
        }
    }
}

function Inject-McpConfig([string]$configPath, [string]$clientName) {
    try {
        $parentDir = Split-Path $configPath -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }

        $existingConfig = @{ mcpServers = @{} }
        if (Test-Path $configPath) {
            try {
                $rawJson = Get-Content $configPath -Raw
                if ($rawJson -and $rawJson.Trim() -ne "") {
                    $parsed = $rawJson | ConvertFrom-Json
                    if ($parsed.PSObject.Properties['mcpServers']) {
                        $existingConfig.mcpServers = $parsed.mcpServers
                    }
                }
            } catch {
                Write-Host "[!] Aviso ao ler $configPath. Criando nova estrutura MCP." -ForegroundColor Yellow
            }
        }

        # Adiciona a entrada cheat_engine
        $existingConfig.mcpServers | Add-Member -MemberType NoteProperty -Name "cheat_engine" -Value $McpConfigTemplate.mcpServers.cheat_engine -Force
        
        $jsonOutput = $existingConfig | ConvertTo-Json -Depth 10
        Set-Content -Path $configPath -Value $jsonOutput -Encoding UTF8
        Write-Host "[SUCESSO] Configuração MCP configurada para $clientName em: $configPath" -ForegroundColor Green
    } catch {
        $errMsg = $_.Exception.Message
        Write-Host "[!] Erro ao injetar configuração para ${clientName}: ${errMsg}" -ForegroundColor Red
    }
}

if ($TargetAI -eq "all" -or $TargetAI -eq "claude") {
    $ClaudeConfig = Join-Path $env:APPDATA "Claude\claude_desktop_config.json"
    Inject-McpConfig $ClaudeConfig "Claude Desktop"
}

if ($TargetAI -eq "all" -or $TargetAI -eq "antigravity") {
    $GeminiConfig = Join-Path $env:USERPROFILE ".gemini\mcp_config.json"
    Inject-McpConfig $GeminiConfig "Antigravity CLI / IDE"
}

if ($TargetAI -eq "all" -or $TargetAI -eq "cursor") {
    $CursorConfig = Join-Path $RepoDir ".cursor\mcp.json"
    Inject-McpConfig $CursorConfig "Cursor IDE"
}

if ($TargetAI -eq "all" -or $TargetAI -eq "vscode") {
    $VSCodeConfig = Join-Path $RepoDir ".vscode\mcp.json"
    Inject-McpConfig $VSCodeConfig "VS Code"
}

# 6. Iniciar o Cheat Engine com o MCP pré-acoplado
if ($shouldLaunch) {
    $CEExe = Join-Path $CEPath "cheatengine-x86_64.exe"
    if (-not (Test-Path $CEExe)) {
        $CEExe = Join-Path $CEPath "Cheat Engine.exe"
    }

    Write-Host "[+] Carregando o Cheat Engine com o MCP acoplado..." -ForegroundColor Cyan
    Start-Process -FilePath $CEExe
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  ✅ CHEAT ENGINE MCP PRONTO E INICIALIZADO!" -ForegroundColor Green
Write-Host "  Servidor Lua ativo em: 127.0.0.1:52737" -ForegroundColor Yellow
Write-Host "  Agora você pode abrir e utilizar o seu assistente de IA favorito!" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan
