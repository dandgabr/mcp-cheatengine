# 📐 Arquitetura do Projeto: Cheat Engine MCP Server

O **Cheat Engine MCP Server** possibilita a integração bidirecional entre modelos de Inteligência Artificial (LLMs) e o ambiente interno do Cheat Engine por meio do protocolo **Model Context Protocol (MCP)** da Anthropic.

---

## 🏗️ Visão Geral do Sistema

A solução utiliza uma arquitetura distribuída em camadas separadas por protocolo de rede local TCP/IP:

```mermaid
flowchart TD
    subgraph Launcher_Layer [Camada de Automação Windows & Scripting]
        BAT["Launcher Batch (start_mcp_ce.bat)\nElevação UAC RunAs"]
        PS1["Script PowerShell (scripts/launcher.ps1)\nDescoberta de Registro & Injeção JSON"]
    end

    subgraph Cliente_AI [Ambiente do Cliente IA]
        LLM[IA / Assistente LLM\nClaude / Antigravity / Cursor / VS Code]
    end

    subgraph MCP_Layer [Camada de Transporte MCP]
        PyMCP["Servidor Python MCP (FastMCP)\nsrc/mcp_cheatengine/server.py"]
        RPCClient["Cliente RPC TCP\nsrc/mcp_cheatengine/rpc_client.py"]
    end

    subgraph CE_Layer [Ambiente Cheat Engine]
        LuaServer["Bridge Lua Socket (TCP 127.0.0.1:52737)\nlua/ce_mcp_lua.lua"]
        TimerLoop["Loop de Eventos Assíncrono (Timer 20ms)\nCE Main Thread"]
        CE_API["APIs Internas Cheat Engine\n(readBytes, writeBytes, AOBScan, etc)"]
    end

    subgraph OS_Layer [Sistema Operacional Windows]
        TargetProc["Processo Alvo / Jogo\n(notepad.exe / game.exe)"]
    end

    BAT --> PS1
    PS1 -->|Copia Ponte Lua para CE Autorun| LuaServer
    PS1 -->|Injeta Configuração mcpServers| LLM
    LLM <-->|Protocolo MCP via Stdio| PyMCP
    PyMCP --> RPCClient
    RPCClient <-->|JSON-RPC 2.0 via TCP Socket| LuaServer
    LuaServer --> TimerLoop
    TimerLoop --> CE_API
    CE_API <-->|Windows API / OpenProcess / VirtualProtect| TargetProc
```

---

## 🧩 Componentes do Sistema

### 1. Camada de Automação & Scripts (`start_mcp_ce.bat` & `scripts/launcher.ps1`)
- **`start_mcp_ce.bat`**: Script Batch raiz que eleva privilégios administrativos no Windows (UAC) e executa o instalador/launcher.
- **`scripts/launcher.ps1`**: Script PowerShell que realiza:
  - Localização automática da instalação do Cheat Engine via Registro do Windows (`HKLM`/`HKCU`) e caminhos padrões.
  - Instalação automática e acoplamento da ponte Lua (`ce_mcp_lua.lua` e `ce_mcp_autorun.lua`) na pasta `autorun` do Cheat Engine.
  - Injeção das pré-configurações JSON para clientes MCP (Claude Desktop, Antigravity, Cursor, VS Code).
  - Inicialização garantida do Cheat Engine com a ponte ativada na porta `127.0.0.1:52737`.

### 2. Camada MCP Python (`src/mcp_cheatengine/`)
- **`server.py`**: Instancia a aplicação FastMCP e expõe as 21 ferramentas para a IA via transporte `stdio`.
- **`rpc_client.py`**: Gerencia sockets TCP para enviar requisições formatadas em JSON-RPC 2.0 e aguarda respostas do Cheat Engine com controle de *timeouts*.
- **`config.py`**: Centraliza parâmetros como host (`127.0.0.1`), porta (`52737`), e tempo limite de varreduras.
- **`tools/`**: Módulos divididos por domínio funcional (Processos, Memória, Scanner, Assembly, Lua, Depuração, Controle, Tabela).

### 3. Camada Bridge Lua (`lua/ce_mcp_lua.lua`)
- **JSON Parser/Encoder Nativo**: Parser escrito em Lua puro que garante funcionamento sem a necessidade de bibliotecas C binárias externas.
- **LuaSocket Bind**: Abre um escutador TCP na porta `52737` em modo não-bloqueante (`settimeout(0)`).
- **Timer Non-Blocking**: Roda no loop gráfico do Cheat Engine a cada 20ms. Isso evita que o Cheat Engine trave ou congele a interface enquanto escuta requisições da IA.
- **API Wrapper**: Mapeia métodos JSON-RPC para chamadas nativas como `readInteger`, `AOBScan`, `autoAssemble`, `debug_setBreakpoint`, `writeRegionToFile` (Sandboxed).

---

## 📡 Protocolo de Comunicação JSON-RPC 2.0

A comunicação entre o cliente Python e o servidor Lua segue estritamente a especificação **JSON-RPC 2.0** delimitada por caractere de nova linha (`\n`).

### Formato da Requisição (Python -> Lua):
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "read_memory",
  "params": {
    "address": "0x140012345",
    "type": "int32"
  }
}
```

### Formato da Resposta de Sucesso (Lua -> Python):
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "address": "0x140012345",
    "type": "int32",
    "value": 99999,
    "value_hex": "0x1869F"
  }
}
```

### Formato de Resposta de Erro (Lua -> Python):
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32603,
    "message": "Endereço inválido: 0x0"
  }
}
```

---

## 🔒 Considerações de Segurança e Performance

1. **Escopo de Rede**: O servidor escuta exclusivamente na interface `127.0.0.1` (loopback local), impedindo conexões remotas não autorizadas pela rede externa.
2. **Execução Assíncrona no CE**: A rotina `Timer.OnTimer` roda a cada 20ms em *non-blocking mode*, permitindo ao usuário continuar usando o Cheat Engine normalmente durante as análises da IA.
3. **Privilégios de Administrador**: Operações de memória exigem que o Cheat Engine (e opcionalmente o servidor Python) tenham permissões elevadas de Administrador no Windows (`SeDebugPrivilege`).
4. **Sandboxing de Arquivos**: Manipulação de dumps de memória via PowerShell/Lua restrita à subpasta segura `dumps\` com extensões autorizadas (`.dmp` e `.bin`).
