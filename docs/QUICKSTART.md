# 🚀 Guia de Início Rápido (Quickstart)

Este guia cobre o passo a passo completo para instalar, configurar e colocar em execução o **Cheat Engine MCP Server**.

---

## ⚡ Método Automático (Recomendado)

O repositório inclui um inicializador automático que realiza todas as pré-configurações em um único clique:

1. Dê um duplo clique no arquivo [`start_mcp_ce.bat`](file:///B:/Code/mcp-cheatengine/start_mcp_ce.bat) na raiz do projeto (ou execute `.\scripts\launcher.ps1` no PowerShell).
2. O script irá automaticamente:
   - Criar o ambiente virtual Python (`venv`) e instalar as dependências.
   - Localizar onde o **Cheat Engine** está instalado no seu sistema.
   - Acoplar a ponte Lua no diretório `autorun` do Cheat Engine.
   - Injetar as configurações do servidor MCP para **Claude Desktop**, **Antigravity CLI/IDE**, **Cursor** e **VS Code**.
   - Inicializar o **Cheat Engine** com o MCP ativado e pronto para conexão em `127.0.0.1:52737`.
3. Abra o seu assistente de IA preferido e comece a usar!

---

## 📋 Pré-requisitos (Método Manual)

1. **Cheat Engine 7.0+** instalado (recomendado 7.5 ou superior).
2. **Python 3.10+** (com `pip` atualizado).
3. **Cliente de IA compatível com MCP**:
   - Claude Desktop
   - Antigravity CLI / IDE
   - Cursor
   - VS Code (com extensão MCP)

---

## 🛠️ Passo 1: Instalar Dependências Python

Abra o terminal na pasta raiz do projeto e crie o ambiente virtual:

```bash
# Criar ambiente virtual
python -m venv venv

# Ativar no Windows (PowerShell)
.\venv\Scripts\Activate.ps1

# Instalar dependências
pip install -r requirements.txt

# (Opcional) Instalar o pacote em modo editável
pip install -e .
```

---

## 🎮 Passo 2: Executar o Bridge Lua no Cheat Engine

### Execução Manual no Cheat Engine
1. Abra o **Cheat Engine**.
2. Abra a janela Lua pressionando **Ctrl + Alt + L** (ou no menu *Table -> Show Lua Engine*).
3. Clique em **Open file** e selecione o arquivo [`lua/ce_mcp_lua.lua`](file:///B:/Code/mcp-cheatengine/lua/ce_mcp_lua.lua).
4. Clique em **Execute script**.
5. No console do Cheat Engine, confirme se apareceu a mensagem:
   ```text
   [SUCESSO] Servidor Cheat Engine MCP rodando em 127.0.0.1:52737
   [SUCESSO] Loop de eventos do Cheat Engine MCP ativado!
   ```

---

## ⚙️ Passo 3: Configurar seu Cliente MCP

Adicione as configurações do servidor no seu cliente de IA favorito:

### 1. Claude Desktop
Adicione ao arquivo `%APPDATA%\Claude\claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "cheat_engine": {
      "command": "python",
      "args": [
        "B:/Code/mcp-cheatengine/ce_mcp_server.py"
      ],
      "env": {
        "PYTHONPATH": "B:/Code/mcp-cheatengine/src",
        "CE_HOST": "127.0.0.1",
        "CE_PORT": "52737"
      }
    }
  }
}
```

### 2. Antigravity / Cursor / VS Code
No arquivo `.gemini/mcp_config.json` ou `mcp.json` do seu ambiente:

```json
{
  "mcpServers": {
    "cheat_engine": {
      "command": "python",
      "args": [
        "-m",
        "mcp_cheatengine"
      ],
      "env": {
        "PYTHONPATH": "B:/Code/mcp-cheatengine/src"
      }
    }
  }
}
```

---

## ✅ Passo 4: Validação da Conexão

No seu cliente de IA, faça a primeira pergunta de teste:

> *"Use a ferramenta `ce_ping` para testar a comunicação com o Cheat Engine."*

Se a resposta contiver `"status": "ok"` e a versão do Cheat Engine, sua configuração está concluída com sucesso! 🎉
