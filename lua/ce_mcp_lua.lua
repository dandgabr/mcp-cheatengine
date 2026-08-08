-- ============================================================================
-- Cheat Engine MCP Bridge - Lua Socket Server
-- ============================================================================
-- Este script cria um servidor TCP JSON-RPC dentro do Cheat Engine na porta 52737.
-- Permite que servidores MCP (Model Context Protocol) controlem o Cheat Engine via IA.
-- ============================================================================

local PORT = 52737
local HOST = "127.0.0.1"

print("==================================================")
print(" Inicializando Cheat Engine MCP Bridge...")
print("==================================================")

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

-- Tenta carregar luasocket do Cheat Engine
local socket = nil
local status, res = pcall(require, "socket")
if status and res then
    socket = res
else
    print("[ERRO] Módulo luasocket não encontrado no Cheat Engine!")
    return
end

-- Bind do servidor TCP
if CE_MCP_SERVER_SOCKET then
    pcall(function() CE_MCP_SERVER_SOCKET:close() end)
    CE_MCP_SERVER_SOCKET = nil
end

local server, err = socket.bind(HOST, PORT)
if not server then
    print("[ERRO] Não foi possível iniciar o servidor na porta " .. PORT .. ": " .. tostring(err))
    return
end

server:settimeout(0) -- Não bloqueia a interface do Cheat Engine
CE_MCP_SERVER_SOCKET = server
print("[SUCESSO] Servidor Cheat Engine MCP rodando em " .. HOST .. ":" .. PORT)

-- ----------------------------------------------------------------------------
-- Handlers das Operações do Cheat Engine
-- ----------------------------------------------------------------------------
local handlers = {}

function handlers.ping(params)
    return {
        status = "ok",
        ce_version = getCEVersion and getCEVersion() or "Unknown",
        process = process or "None",
        process_id = getOpenedProcessID and getOpenedProcessID() or 0
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

    return {
        success = true,
        id = mr.ID,
        description = mr.Description,
        address = mr.Address
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
    elseif dataType == "double" then
        success = writeDouble(addr, tonumber(val))
    elseif dataType == "string" then
        success = writeString(addr, tostring(val))
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

    local finalVal = readInteger(current)
    return {
        base_address = baseStr,
        final_address = string.format("0x%X", current),
        final_value_int32 = finalVal,
        steps = steps
    }
end

function handlers.aob_scan(params)
    local pattern = params.pattern
    if not pattern then error("Parâmetro 'pattern' é obrigatório") end

    local ms = AOBScan(pattern, params.protection_flags or "+W-C", params.alignment_type or 0, params.start_address or "", params.stop_address or "")
    local results = {}
    if ms then
        for i = 0, ms.Count - 1 do
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

    local instructions = {}
    local curr = addr
    for i = 1, count do
        local disasm = disassemble(curr)
        local bytesHex = ""
        local bytesTable = readBytes(curr, getInstructionSize(curr), true)
        if bytesTable then
            local hexes = {}
            for _, b in ipairs(bytesTable) do table.insert(hexes, string.format("%02X", b)) end
            bytesHex = table.concat(hexes, " ")
        end

        table.insert(instructions, {
            address = string.format("0x%X", curr),
            bytes = bytesHex,
            instruction = disasm
        })
        curr = curr + getInstructionSize(curr)
    end

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
        error("Falha ao executar Auto Assemble script.")
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
-- Processamento de Requisições via Socket
-- ----------------------------------------------------------------------------
local clients = {}

local timer = createTimer(nil, false)
timer.Interval = 20 -- Executa a cada 20ms no thread principal do CE (sem congelar a UI)

timer.OnTimer = function()
    if not CE_MCP_SERVER_SOCKET then return end

    local client = CE_MCP_SERVER_SOCKET:accept()
    if client then
        client:settimeout(0)
        table.insert(clients, { socket = client, buffer = "" })
    end

    for i = #clients, 1, -1 do
        local c = clients[i]
        local data, err, part = c.socket:receive("*l")
        local line = data or part

        if line and line ~= "" then
            c.buffer = c.buffer .. line
            local req = json.decode(c.buffer)
            c.buffer = ""

            if req and req.method then
                local response = { id = req.id, jsonrpc = "2.0" }
                local handler = handlers[req.method]
                if handler then
                    local status, res = pcall(handler, req.params or {})
                    if status then
                        response.result = res
                    else
                        response.error = { code = -32603, message = tostring(res) }
                    end
                else
                    response.error = { code = -32601, message = "Método não encontrado: " .. tostring(req.method) }
                end

                local respStr = json.encode(response) .. "\n"
                pcall(function() c.socket:send(respStr) end)
            end
        end

        if err == "closed" then
            table.remove(clients, i)
        end
    end
end

timer.Enabled = true
print("[SUCESSO] Loop de eventos do Cheat Engine MCP ativado!")
