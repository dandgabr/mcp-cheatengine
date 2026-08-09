-- ============================================================================
-- Cheat Engine MCP Bridge - Autorun Script
-- ============================================================================
-- Coloque este arquivo na pasta 'autorun' do Cheat Engine para que o MCP
-- servidor inicie automaticamente sempre que o Cheat Engine for aberto.
-- ============================================================================

local DEBUG_LOGS = true

local function mcp_log(level, tag, msg)
    if not DEBUG_LOGS and level == "DEBUG" then return end
    local timeStr = os.date and os.date("%H:%M:%S") or "00:00:00"
    print(string.format("[%s][%s][%s] %s", level, timeStr, tag, tostring(msg)))
end

mcp_log("DEBUG", "AUTORUN", "Iniciando verificação do MCP Autorun...")

local paths = {
    getCheatEngineDir() .. "ce_mcp_lua.lua",
    getCheatEngineDir() .. "lua\\ce_mcp_lua.lua",
    getCheatEngineDir() .. "autorun\\ce_mcp_lua.lua",
}

local loaded = false
for _, scriptPath in ipairs(paths) do
    mcp_log("DEBUG", "AUTORUN", "Procurando script em: " .. scriptPath)
    local f = io.open(scriptPath, "r")
    if f then
        f:close()
        mcp_log("INFO", "AUTORUN", "Carregando script Lua a partir de: " .. scriptPath)
        dofile(scriptPath)
        loaded = true
        break
    end
end

if not loaded then
    mcp_log("ERROR", "AUTORUN", "ERRO: ce_mcp_lua.lua não foi encontrado nos diretórios configurados.")
end
