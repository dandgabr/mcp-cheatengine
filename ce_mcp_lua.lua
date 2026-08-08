-- Wrapper de compatibilidade para ce_mcp_lua.lua na raiz do repositório
local luaSubfolderPath = getCheatEngineDir() .. "lua\\ce_mcp_lua.lua"
local f = io.open(luaSubfolderPath, "r")
if f then
    f:close()
    dofile(luaSubfolderPath)
else
    -- Executa o script diretamente caso não esteja na pasta de instalação do CE
    local rootPath = "lua/ce_mcp_lua.lua"
    local f2 = io.open(rootPath, "r")
    if f2 then
        f2:close()
        dofile(rootPath)
    else
        print("[ERRO] Não foi possível encontrar lua/ce_mcp_lua.lua")
    end
end
