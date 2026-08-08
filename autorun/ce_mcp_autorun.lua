-- Script de autorun de compatibilidade na raiz
local scriptPath = getCheatEngineDir() .. "lua\\ce_mcp_lua.lua"
local fileExists = io.open(scriptPath, "r")
if fileExists then
    fileExists:close()
    dofile(scriptPath)
else
    local localAutorunPath = getCheatEngineDir() .. "autorun\\ce_mcp_autorun.lua"
    local f = io.open(localAutorunPath, "r")
    if f then
        f:close()
        dofile(localAutorunPath)
    else
        print("[MCP Autorun] Arquivo lua/ce_mcp_lua.lua não encontrado.")
    end
end
