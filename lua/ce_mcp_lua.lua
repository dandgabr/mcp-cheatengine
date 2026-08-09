-- ============================================================================
-- Cheat Engine MCP Bridge - Lua Socket Server
-- ============================================================================
-- Este script cria um servidor TCP JSON-RPC dentro do Cheat Engine na porta 52737.
-- Permite que servidores MCP (Model Context Protocol) controlem o Cheat Engine via IA.
-- ============================================================================

local PORT = 52737
local HOST = "127.0.0.1"

-- ============================================================================
-- FEATURE FLAG & ARQUIVO DE LOG DO TERMINAL
-- ============================================================================
local DEBUG_LOGS = true
local LOG_FILE_PATH = getCheatEngineDir() .. "ce_mcp_lua.log"

-- Limpa o arquivo de log toda vez que o script Lua inicia
pcall(function()
    local logFileInit = io.open(LOG_FILE_PATH, "w")
    if logFileInit then
        logFileInit:write("=== CHEAT ENGINE MCP LUA LOG INICIADO: " .. (os.date("%Y-%m-%d %H:%M:%S") or "") .. " ===\n")
        logFileInit:close()
    end
end)

local function mcp_log(level, tag, msg)
    if not DEBUG_LOGS and level == "DEBUG" then return end
    local timeStr = os.date and os.date("%H:%M:%S") or "00:00:00"
    local formatted = string.format("[%s][%s][%s] %s", level, timeStr, tag, tostring(msg))
    
    -- Exibe no console gráfico do Cheat Engine
    print(formatted)
    
    -- Grava no arquivo de log em disco
    pcall(function()
        local f = io.open(LOG_FILE_PATH, "a")
        if f then
            f:write(formatted .. "\n")
            f:close()
        end
    end)
end

mcp_log("INFO", "INIT", "==================================================")
mcp_log("INFO", "INIT", " Inicializando Cheat Engine MCP Bridge (Debug Logs = " .. tostring(DEBUG_LOGS) .. ")...")
mcp_log("INFO", "INIT", "==================================================")

-- ----------------------------------------------------------------------------
-- Parser e Serializador JSON em Lua Puro (Garante funcionamento sem libs externas)
-- ----------------------------------------------------------------------------
local json = {}

function json.encode(val)
    local t = type(val)
    if t == "nil" then
        return "null"
    elseif t == "boolean" then
        return val and "true" or "false"
    elseif t == "number" then
        return tostring(val)
    elseif t == "string" then
        return string.format("%q", val):gsub("\n", "\\n"):gsub("\r", "\\r")
    elseif t == "table" then
        local isArray = true
        local maxIndex = 0
        for k, v in pairs(val) do
            if type(k) ~= "number" or k <= 0 or math.floor(k) ~= k then
                isArray = false
                break
            end
            if k > maxIndex then maxIndex = k end
        end
        if isArray then
            local parts = {}
            for i = 1, maxIndex do
                table.insert(parts, json.encode(val[i]))
            end
            return "[" .. table.concat(parts, ",") .. "]"
        else
            local parts = {}
            for k, v in pairs(val) do
                table.insert(parts, json.encode(tostring(k)) .. ":" .. json.encode(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
    else
        return string.format("%q", tostring(val))
    end
end

function json.decode(str)
    if not str or str == "" then return nil end

    if json_native_decode then
        local status, res = pcall(json_native_decode, str)
        if status then return res end
    end

    local pos = 1
    local function skipWhitespace()
        while pos <= #str and str:sub(pos, pos):match("%s") do
            pos = pos + 1
        end
    end

    local function parseValue()
        skipWhitespace()
        if pos > #str then return nil end
        local c = str:sub(pos, pos)

        if c == "{" then
            pos = pos + 1
            local obj = {}
            skipWhitespace()
            if str:sub(pos, pos) == "}" then
                pos = pos + 1
                return obj
            end
            while pos <= #str do
                local key = parseValue()
                skipWhitespace()
                if str:sub(pos, pos) == ":" then
                    pos = pos + 1
                end
                local val = parseValue()
                obj[key] = val
                skipWhitespace()
                local nextC = str:sub(pos, pos)
                if nextC == "}" then
                    pos = pos + 1
                    break
                elseif nextC == "," then
                    pos = pos + 1
                end
            end
            return obj
        elseif c == "[" then
            pos = pos + 1
            local arr = {}
            skipWhitespace()
            if str:sub(pos, pos) == "]" then
                pos = pos + 1
                return arr
            end
            while pos <= #str do
                local val = parseValue()
                table.insert(arr, val)
                skipWhitespace()
                local nextC = str:sub(pos, pos)
                if nextC == "]" then
                    pos = pos + 1
                    break
                elseif nextC == "," then
                    pos = pos + 1
                end
            end
            return arr
        elseif c == '"' or c == "'" then
            local quote = c
            pos = pos + 1
            local startPos = pos
            while pos <= #str do
                local ch = str:sub(pos, pos)
                if ch == quote and str:sub(pos-1, pos-1) ~= "\\" then
                    break
                end
                pos = pos + 1
            end
            local s = str:sub(startPos, pos - 1)
            pos = pos + 1
            s = s:gsub("\\n", "\n"):gsub("\\r", "\r"):gsub('\\"', '"'):gsub("\\\\", "\\")
            return s
        elseif c:match("[%d%-]") then
            local startPos = pos
            while pos <= #str and str:sub(pos, pos):match("[%d%.%-eE]") do
                pos = pos + 1
            end
            local numStr = str:sub(startPos, pos - 1)
            return tonumber(numStr)
        elseif str:sub(pos, pos+3) == "true" then
            pos = pos + 4
            return true
        elseif str:sub(pos, pos+4) == "false" then
            pos = pos + 5
            return false
        elseif str:sub(pos, pos+3) == "null" then
            pos = pos + 4
            return nil
        else
            pos = pos + 1
            return nil
        end
    end

    return parseValue()
end

-- Tenta carregar luasocket do Cheat Engine (se instalado)
local socket = nil
local status, res = pcall(require, "socket")
if status and res then
    socket = res
    print("[MCP] LuaSocket nativo carregado com sucesso!")
else
    print("[MCP] LuaSocket não encontrado. Ativando suporte a Named Pipe nativo do Cheat Engine...")
end

-- Bind do servidor TCP (se LuaSocket estiver disponível)
if socket then
    if CE_MCP_SERVER_SOCKET then
        pcall(function() CE_MCP_SERVER_SOCKET:close() end)
        CE_MCP_SERVER_SOCKET = nil
    end

    local server, err = socket.bind(HOST, PORT)
    if server then
        server:settimeout(0) -- Não bloqueia a interface do Cheat Engine
        CE_MCP_SERVER_SOCKET = server
        print("[SUCESSO] Servidor TCP Cheat Engine MCP rodando em " .. HOST .. ":" .. PORT)
    else
        print("[AVISO] Não foi possível fazer o bind no TCP na porta " .. PORT .. ": " .. tostring(err))
    end
end

-- ----------------------------------------------------------------------------
-- Handlers das Operações do Cheat Engine
-- ----------------------------------------------------------------------------
local handlers = {}

function handlers.ping(params)
    mcp_log("DEBUG", "PING", "Requisição de ping recebida com sucesso!")
    return {
        status = "ok",
        message = "Cheat Engine MCP Server Ativo e Respondendo!",
        timestamp = os.date and os.date("%Y-%m-%d %H:%M:%S") or "Unknown",
        ce_version = getCEVersion and getCEVersion() or "Unknown",
        process_name = process or "Nenhum",
        process_id = getOpenedProcessID and getOpenedProcessID() or 0
    }
end

function handlers.close_cheat_engine(params)
    mcp_log("INFO", "CLOSE", "Encerrando Cheat Engine a pedido do cliente MCP...")
    
    local t = createTimer(nil, false)
    t.Interval = 200
    t.OnTimer = function()
        t.destroy()
        if closeCE then
            closeCE()
        elseif getMainForm then
            getMainForm().close()
        end
    end
    t.Enabled = true

    return {
        success = true,
        message = "Encerrando Cheat Engine..."
    }
end

function handlers.list_processes(params)
    local plist = getProcessList()
    local result = {}
    if plist then
        for pid, name in pairs(plist) do
            table.insert(result, {
                pid = pid,
                name = name,
                pid_hex = string.format("0x%X", pid)
            })
        end
    end
    table.sort(result, function(a, b) return a.name:lower() < b.name:lower() end)
    return result
end

function handlers.attach_process(params)
    local target = params.target
    if not target then error("Parâmetro 'target' (PID ou Nome do Processo) é obrigatório") end

    local pid = tonumber(target)
    if not pid then
        pid = getProcessIDFromProcessName(tostring(target))
    end

    if not pid or pid == 0 then
        error("Processo '" .. tostring(target) .. "' não foi encontrado.")
    end

    openProcess(pid)
    return {
        success = true,
        process_id = getOpenedProcessID(),
        process_name = process or tostring(target)
    }
end

function handlers.get_attached_process(params)
    return {
        process_id = getOpenedProcessID(),
        process_name = process or "Nenhum processo anexo",
        is_64bit = targetIs64bit and targetIs64bit() or false
    }
end

function handlers.pause_process(params)
    if not getOpenedProcessID or getOpenedProcessID() == 0 then
        error("Nenhum processo anexado para pausar.")
    end
    pause()
    return { success = true, message = "Execução do processo pausada com sucesso." }
end

function handlers.unpause_process(params)
    if not getOpenedProcessID or getOpenedProcessID() == 0 then
        error("Nenhum processo anexado para retomar.")
    end
    unpause()
    return { success = true, message = "Execução do processo retomada com sucesso." }
end

function handlers.allocate_memory(params)
    local size = tonumber(params.size)
    if not size or size <= 0 then error("Parâmetro 'size' deve ser maior que 0.") end
    if size > 10 * 1024 * 1024 then error("Tamanho máximo de alocação permitido é 10MB.") end

    local baseAddrStr = params.base_address
    local baseAddr = (baseAddrStr and baseAddrStr ~= "") and getAddress(baseAddrStr) or nil

    local allocated = allocateMemory(size, baseAddr)
    if not allocated or allocated == 0 then
        error("Falha ao alocar memória no processo alvo.")
    end

    return {
        success = true,
        address = string.format("0x%X", allocated),
        size = size
    }
end

function handlers.free_memory(params)
    local addrStr = params.address
    if not addrStr then error("Parâmetro 'address' é obrigatório.") end
    local addr = getAddress(addrStr)
    if not addr or addr == 0 then error("Endereço de memória inválido: " .. tostring(addrStr)) end

    deAlloc(addr)
    return {
        success = true,
        address = string.format("0x%X", addr),
        message = "Memória liberada com sucesso."
    }
end

function handlers.set_speedhack(params)
    local speed = tonumber(params.speed)
    if not speed or speed < 0 then error("Parâmetro 'speed' deve ser um número positivo.") end
    if speed > 500 then error("Velocidade máxima permitida é 500.0 por razões de estabilidade.") end

    speedhack_setSpeed(speed)
    return {
        success = true,
        speed = speed,
        message = "Speedhack configurado com sucesso."
    }
end

function handlers.get_address_list(params)
    local al = getAddressList()
    local records = {}
    if al then
        for i = 0, al.Count - 1 do
            local mr = al.getMemoryRecord(i)
            if mr then
                table.insert(records, {
                    id = mr.ID,
                    index = i,
                    description = mr.Description or "",
                    address = mr.AddressString or "",
                    value = mr.Value or "",
                    type = mr.Type or "",
                    active = mr.Active or false
                })
            end
        end
    end
    return { count = #records, records = records }
end

function handlers.add_address_list_entry(params)
    local addressStr = params.address
    if not addressStr then error("Parâmetro 'address' é obrigatório.") end

    local description = (params.description or "MCP Entry"):sub(1, 100)
    local al = getAddressList()
    local mr = al.createMemoryRecord()
    mr.Description = description
    mr.Address = addressStr

    local varTypeMap = {
        byte = vtByte or 0,
        int16 = vtWord or 1,
        smallint = vtWord or 1,
        word = vtWord or 1,
        int32 = vtDword or 2,
        integer = vtDword or 2,
        int = vtDword or 2,
        dword = vtDword or 2,
        int64 = vtQword or 3,
        qword = vtQword or 3,
        float = vtSingle or 4,
        single = vtSingle or 4,
        double = vtDouble or 5,
        string = vtString or 6,
        auto_assembler = vtAutoAssembler or 7
    }
    if params.type and varTypeMap[tostring(params.type):lower()] then
        mr.VarType = varTypeMap[tostring(params.type):lower()]
    end

    return {
        success = true,
        id = mr.ID,
        description = mr.Description,
        address = mr.Address,
        type = params.type or "int32"
    }
end

function handlers.toggle_freeze(params)
    local target = params.target
    if not target then error("Parâmetro 'target' (ID ou Descrição) é obrigatório.") end
    local active = params.active ~= false

    local al = getAddressList()
    local mr = nil
    if tonumber(target) then
        mr = al.getMemoryRecordByID(tonumber(target))
    else
        mr = al.getMemoryRecordByDescription(tostring(target))
    end

    if not mr then error("Registro não encontrado na AddressList: " .. tostring(target)) end

    mr.Active = active
    return {
        success = true,
        id = mr.ID,
        description = mr.Description,
        active = mr.Active
    }
end

function handlers.dump_memory_to_file(params)
    local addrStr = params.address
    local size = tonumber(params.size)
    local filename = params.filename

    if not addrStr or not size or not filename then
        error("Parâmetros 'address', 'size' e 'filename' são obrigatórios.")
    end
    if size <= 0 or size > 50 * 1024 * 1024 then
        error("Tamanho do dump deve ser entre 1 byte e 50MB.")
    end

    -- Sanitização Estrita de Caminho
    local safeName = filename:match("([^/\\\\]+)$")
    if not safeName or safeName == "." or safeName == ".." then
        error("Nome de arquivo inválido.")
    end
    if not safeName:match("%.dmp$") and not safeName:match("%.bin$") then
        error("Extensão de arquivo não permitida. Apenas .dmp ou .bin são aceitas.")
    end

    local dumpDir = getCheatEngineDir() .. "dumps\\"
    os.execute('mkdir "' .. dumpDir .. '" 2>nul')
    local fullPath = dumpDir .. safeName

    local addr = getAddress(addrStr)
    if not addr or addr == 0 then error("Endereço inválido: " .. tostring(addrStr)) end

    local bytesWritten = writeRegionToFile(fullPath, addr, size)
    return {
        success = true,
        filename = safeName,
        path = fullPath,
        bytes_written = bytesWritten,
        address = string.format("0x%X", addr)
    }
end

function handlers.load_memory_from_file(params)
    local addrStr = params.address
    local filename = params.filename

    if not addrStr or not filename then
        error("Parâmetros 'address' e 'filename' são obrigatórios.")
    end

    -- Sanitização Estrita de Caminho
    local safeName = filename:match("([^/\\\\]+)$")
    if not safeName or safeName == "." or safeName == ".." then
        error("Nome de arquivo inválido.")
    end
    if not safeName:match("%.dmp$") and not safeName:match("%.bin$") then
        error("Extensão de arquivo não permitida. Apenas .dmp ou .bin são aceitas.")
    end

    local fullPath = getCheatEngineDir() .. "dumps\\" .. safeName
    local f = io.open(fullPath, "rb")
    if not f then error("Arquivo não encontrado no diretório seguro de dumps: " .. safeName) end
    local fsize = f:seek("end")
    f:close()

    if fsize > 50 * 1024 * 1024 then
        error("Arquivo de dump excede o limite máximo permitido de 50MB.")
    end

    local addr = getAddress(addrStr)
    if not addr or addr == 0 then error("Endereço inválido: " .. tostring(addrStr)) end

    readRegionFromFile(fullPath, addr)
    return {
        success = true,
        filename = safeName,
        address = string.format("0x%X", addr),
        bytes_restored = fsize,
        message = "Memória restaurada com sucesso a partir do dump isolado."
    }
end

function handlers.read_memory(params)
    local addrStr = params.address
    local dataType = (params.type or "int32"):lower()
    local length = params.length or 256

    if not addrStr then error("Endereço é obrigatório") end
    local addr = getAddress(addrStr)
    if not addr or addr == 0 then error("Endereço inválido: " .. tostring(addrStr)) end

    local val = nil
    if dataType == "byte" then
        val = readBytes(addr, 1, false)
    elseif dataType == "bytes" then
        local count = params.count or 16
        local bytesTable = readBytes(addr, count, true)
        if bytesTable then
            local hexArray = {}
            for _, b in ipairs(bytesTable) do
                table.insert(hexArray, string.format("%02X", b))
            end
            val = table.concat(hexArray, " ")
        end
    elseif dataType == "int16" or dataType == "smallint" then
        val = readSmallInteger(addr)
    elseif dataType == "int32" or dataType == "integer" or dataType == "int" then
        val = readInteger(addr)
    elseif dataType == "int64" or dataType == "qword" then
        val = readQword(addr)
    elseif dataType == "float" then
        val = readFloat(addr)
    elseif dataType == "double" then
        val = readDouble(addr)
    elseif dataType == "string" then
        val = readString(addr, length, params.zero_terminated ~= false)
    elseif dataType == "pointer" then
        val = readPointer(addr)
        if val then
            return { address = string.format("0x%X", addr), value = string.format("0x%X", val), raw_value = val }
        end
    else
        error("Tipo de dado não suportado: " .. tostring(dataType))
    end

    if val == nil then error("Falha ao ler memória no endereço " .. string.format("0x%X", addr)) end

    return {
        address = string.format("0x%X", addr),
        type = dataType,
        value = val,
        value_hex = type(val) == "number" and string.format("0x%X", val) or nil
    }
end

function handlers.write_memory(params)
    local addrStr = params.address
    local dataType = (params.type or "int32"):lower()
    local val = params.value

    if not addrStr or val == nil then error("Parâmetros 'address' e 'value' são obrigatórios") end
    local addr = getAddress(addrStr)
    if not addr or addr == 0 then error("Endereço inválido: " .. tostring(addrStr)) end

    local success = false
    if dataType == "byte" then
        success = writeBytes(addr, tonumber(val))
    elseif dataType == "bytes" then
        local bytesTable = {}
        if type(val) == "string" then
            for hex in val:gmatch("%S+") do
                table.insert(bytesTable, tonumber(hex, 16))
            end
        elseif type(val) == "table" then
            bytesTable = val
        end
        success = writeBytes(addr, bytesTable)
    elseif dataType == "int16" or dataType == "smallint" then
        success = writeSmallInteger(addr, tonumber(val))
    elseif dataType == "int32" or dataType == "integer" or dataType == "int" then
        success = writeInteger(addr, tonumber(val))
    elseif dataType == "int64" or dataType == "qword" then
        success = writeQword(addr, tonumber(val))
    elseif dataType == "float" then
        success = writeFloat(addr, tonumber(val))
        elseif dataType == "string" then
        success = writeString(addr, tostring(val))
    elseif dataType == "pointer" then
        local ptrVal = tonumber(val) or getAddress(tostring(val))
        if not ptrVal then error("Valor de ponteiro inválido: " .. tostring(val)) end
        success = writePointer(addr, ptrVal)
    else
        error("Tipo de dado não suportado: " .. tostring(dataType))
    end

    return {
        success = success,
        address = string.format("0x%X", addr),
        type = dataType,
        written_value = val
    }
end

function handlers.read_pointer_chain(params)
    local baseStr = params.base_address
    local offsets = params.offsets or {}
    local dataType = (params.type or "int32"):lower()

    if not baseStr then error("Parâmetro 'base_address' é obrigatório") end
    local addr = getAddress(baseStr)
    if not addr or addr == 0 then error("Endereço base inválido: " .. tostring(baseStr)) end

    local current = addr
    local steps = {}
    table.insert(steps, { step = 0, address = string.format("0x%X", current) })

    for i, offset in ipairs(offsets) do
        local ptr = readPointer(current)
        if not ptr or ptr == 0 then
            error(string.format("Ponteiro nulo lido no passo %d (endereço: 0x%X)", i, current))
        end
        current = ptr + offset
        table.insert(steps, { step = i, offset = string.format("0x%X", offset), address = string.format("0x%X", current) })
    end

    local finalVal = nil
    if dataType == "int16" or dataType == "smallint" then
        finalVal = readSmallInteger(current)
    elseif dataType == "int32" or dataType == "integer" or dataType == "int" then
        finalVal = readInteger(current)
    elseif dataType == "int64" or dataType == "qword" then
        finalVal = readQword(current)
    elseif dataType == "float" then
        finalVal = readFloat(current)
    elseif dataType == "double" then
        finalVal = readDouble(current)
    elseif dataType == "string" then
        finalVal = readString(current, params.length or 256)
    elseif dataType == "pointer" then
        finalVal = readPointer(current)
    else
        finalVal = readInteger(current)
    end

    return {
        base_address = baseStr,
        final_address = string.format("0x%X", current),
        final_value = finalVal,
        type = dataType,
        steps = steps
    }
end

function handlers.aob_scan(params)
    local pattern = params.pattern
    if not pattern then error("Parâmetro 'pattern' é obrigatório") end

    local ms = AOBScan(pattern, params.protection_flags or "+W-C", params.alignment_type or 0, params.start_address or "", params.stop_address or "")
    local results = {}
    if ms then
        local maxResults = math.min(ms.Count, tonumber(params.max_results) or 1000)
        for i = 0, maxResults - 1 do
            local addr = ms[i]
            table.insert(results, string.format("0x%X", getAddress(addr)))
        end
        ms.destroy()
    end

    return {
        pattern = pattern,
        matches_count = #results,
        addresses = results
    }
end

function handlers.get_address(params)
    local symbol = params.symbol
    if not symbol then error("Parâmetro 'symbol' é obrigatório") end
    local addr = getAddress(symbol)
    if not addr or addr == 0 then
        error("Não foi possível resolver o símbolo: " .. tostring(symbol))
    end
    return {
        symbol = symbol,
        address = string.format("0x%X", addr),
        raw_address = addr
    }
end

function handlers.enum_modules(params)
    local mods = enumModules()
    local results = {}
    if mods then
        for _, m in ipairs(mods) do
            table.insert(results, {
                name = m.Name,
                address = string.format("0x%X", m.Address),
                size = m.Size,
                size_hex = string.format("0x%X", m.Size),
                path = m.Path or ""
            })
        end
    end
    return results
end

function handlers.disassemble(params)
    local addrStr = params.address
    local count = params.count or 10
    if not addrStr then error("Parâmetro 'address' é obrigatório") end

    local addr = getAddress(addrStr)
    if not addr or addr == 0 then error("Endereço inválido: " .. tostring(addrStr)) end

    local d = createDisassembler()
    local instructions = {}
    local curr = addr
    for i = 1, count do
        local disasm = d.disassemble(curr)
        local data = d.getLastDisassembleData()
        local bytesTable = data and data.bytes or {}
        local hexes = {}
        for _, b in ipairs(bytesTable) do
            table.insert(hexes, string.format("%02X", b))
        end
        local bytesHex = table.concat(hexes, " ")

        table.insert(instructions, {
            address = string.format("0x%X", curr),
            bytes = bytesHex,
            instruction = disasm
        })
        local instSize = math.max(#bytesTable, 1)
        curr = curr + instSize
    end
    if d and d.destroy then d.destroy() end

    return {
        start_address = string.format("0x%X", addr),
        count = #instructions,
        instructions = instructions
    }
end

function handlers.auto_assemble(params)
    local script = params.script
    if not script then error("Parâmetro 'script' (script AutoAssemble) é obrigatório") end

    local status, disableInfo = autoAssemble(script, params.enable ~= false)
    if not status then
        error("Falha ao executar Auto Assemble script: " .. tostring(disableInfo))
    end

    return {
        success = true,
        message = "Script Auto Assemble aplicado com sucesso."
    }
end

function handlers.execute_lua(params)
    local code = params.code
    if not code then error("Parâmetro 'code' é obrigatório") end

    local func, err = loadstring(code)
    if not func then error("Erro de sintaxe no Lua code: " .. tostring(err)) end

    local status, res = pcall(func)
    if not status then error("Erro na execução do Lua code: " .. tostring(res)) end

    return {
        success = true,
        result = res ~= nil and tostring(res) or "nil"
    }
end

function handlers.set_breakpoint(params)
    local addrStr = params.address
    if not addrStr then error("Parâmetro 'address' é obrigatório") end
    local addr = getAddress(addrStr)
    if not addr or addr == 0 then error("Endereço inválido: " .. tostring(addrStr)) end

    local size = params.size or 1
    local trigger = params.trigger or bptExecute
    local method = params.method or bpmDebugRegister

    debug_setBreakpoint(addr, size, trigger, method)
    return {
        success = true,
        address = string.format("0x%X", addr),
        message = "Breakpoint configurado."
    }
end

-- ----------------------------------------------------------------------------
-- Despachante Central de Requisições RPC com Logging
-- ----------------------------------------------------------------------------
local function dispatchRPC(req)
    if not req or not req.method then
        mcp_log("ERROR", "RPC", "Requisição JSON-RPC inválida ou método ausente.")
        return { jsonrpc = "2.0", id = req and req.id or nil, error = { code = -32600, message = "Invalid Request" } }
    end

    local response = { id = req.id, jsonrpc = "2.0" }
    local handler = handlers[req.method]

    mcp_log("DEBUG", "RPC_EXEC", "Executando método '" .. tostring(req.method) .. "'...")
    if handler then
        local st, r = pcall(handler, req.params or {})
        if st then
            mcp_log("DEBUG", "RPC_SUCCESS", "Método '" .. tostring(req.method) .. "' executado com sucesso.")
            response.result = r
        else
            mcp_log("ERROR", "RPC_EXCEPTION", "Exceção ao executar '" .. tostring(req.method) .. "': " .. tostring(r))
            response.error = { code = -32603, message = tostring(r) }
        end
    else
        mcp_log("WARNING", "RPC_NOTFOUND", "Método não encontrado: '" .. tostring(req.method) .. "'")
        response.error = { code = -32601, message = "Método não encontrado: " .. tostring(req.method) }
    end
    return response
end

local RESP_FILE_PATH = getCheatEngineDir() .. "mcp_resp.json"

function _CE_MCP_DISPATCH(jsonStr)
    mcp_log("DEBUG", "NATIVE_RECV", "Recebido via Native IPC: " .. tostring(jsonStr))
    local req = json.decode(jsonStr)
    local respStr = ""
    if req then
        local resp = dispatchRPC(req)
        respStr = json.encode(resp)
    else
        respStr = '{"jsonrpc":"2.0","error":{"code":-32700,"message":"Parse error"}}'
    end

    pcall(function()
        local f = io.open(RESP_FILE_PATH, "w")
        if f then
            f:write(respStr)
            f:close()
        end
    end)
    return #respStr
end

-- ----------------------------------------------------------------------------
-- Servidor IPC Nativo do Cheat Engine (via openLuaServer)
-- ----------------------------------------------------------------------------
local luaServerSt, luaServerRes = pcall(openLuaServer, "CheatEngineMCP")
mcp_log("INFO", "INIT", "openLuaServer('CheatEngineMCP') ativado: status=" .. tostring(luaServerSt) .. ", res=" .. tostring(luaServerRes))

-- ----------------------------------------------------------------------------
-- Servidor Named Pipe Secundário (via createPipe)
-- ----------------------------------------------------------------------------
if CE_MCP_PIPE_SERVER then
    pcall(function() CE_MCP_PIPE_SERVER.destroy() end)
    CE_MCP_PIPE_SERVER = nil
end

local pipeStatus, pipeRes = pcall(createPipe, "CheatEngineMCP", 65536, 65536)
mcp_log("DEBUG", "PIPE_INIT", "pipeStatus=" .. tostring(pipeStatus) .. ", pipeRes=" .. tostring(pipeRes) .. ", valid=" .. tostring(pipeRes and pipeRes.valid))

if pipeStatus and pipeRes and pipeRes.valid then
    CE_MCP_PIPE_SERVER = pipeRes
    mcp_log("INFO", "INIT", "Servidor Named Pipe Cheat Engine ativado (CheatEngineMCP)!")

    if CE_MCP_TIMER then
        pcall(function() CE_MCP_TIMER.destroy() end)
        CE_MCP_TIMER = nil
    end

    local pipeBuffer = ""
    local timer = createTimer(nil, false)
    CE_MCP_TIMER = timer
    timer.Interval = 50 -- Roda a cada 50ms no thread principal do CE (totalmente não-bloqueante)

    timer.OnTimer = function()
        if not CE_MCP_PIPE_SERVER then return end

        local st, bytes = pcall(function() return CE_MCP_PIPE_SERVER:readBytesMin(0, 4096) end)
        if st and bytes and #bytes > 0 then
            mcp_log("DEBUG", "PIPE_READ", "Lidos " .. tostring(#bytes) .. " bytes da Named Pipe!")
            local chunk = byteTableToString(bytes)
            if chunk then
                pipeBuffer = pipeBuffer .. chunk
                local newlinePos = pipeBuffer:find("\n")
                while newlinePos do
                    local line = pipeBuffer:sub(1, newlinePos - 1)
                    if line:sub(-1) == "\r" then line = line:sub(1, -2) end
                    pipeBuffer = pipeBuffer:sub(newlinePos + 1)

                    mcp_log("DEBUG", "PIPE_RECV", "Recebido via Named Pipe: " .. line)
                    local req = json.decode(line)
                    if req then
                        local response = dispatchRPC(req)
                        local respStr = json.encode(response) .. "\n"
                        mcp_log("DEBUG", "PIPE_SEND", "Enviando resposta via Named Pipe...")
                        local respBytes = stringToByteTable(respStr)
                        pcall(function() CE_MCP_PIPE_SERVER:writeBytes(respBytes, #respBytes) end)
                    end
                    newlinePos = pipeBuffer:find("\n")
                end
            end
        end
    end

    timer.Enabled = true
    mcp_log("INFO", "INIT", "Loop de eventos MCP não-bloqueante ativado com sucesso!")
end


