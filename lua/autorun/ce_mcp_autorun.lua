-- ============================================================================
-- Cheat Engine MCP Bridge - Autorun Script
-- ============================================================================
-- Coloque este arquivo na pasta 'autorun' do Cheat Engine para que o MCP
-- servidor inicie automaticamente sempre que o Cheat Engine for aberto.
-- Exemplo de caminho: C:\Program Files\Cheat Engine 7.5\autorun\ce_mcp_autorun.lua
-- ============================================================================

local paths = {
    getCheatEngineDir() .. "lua\\ce_mcp_lua.lua",
    getCheatEngineDir() .. "ce_mcp_lua.lua",
    getCheatEngineDir() .. "autorun\\ce_mcp_lua.lua",
}

local loaded = false
for _, scriptPath in ipairs(paths) do
    local f = io.open(scriptPath, "r")
    if f then
        f:close()
        dofile(scriptPath)
        loaded = true
        print("[MCP Autorun] Arquivo Lua carregado a partir de: " .. scriptPath)
        break
    end
end

if not loaded then
    print("[MCP Autorun] ERRO: ce_mcp_lua.lua não encontrado nos caminhos buscados.")
end
