# 🚀 Guia de Início Rápido (Quickstart)

Este guia cobre o passo a passo completo para instalar, configurar e colocar em execução o **Cheat Engine MCP Server**.

---

## 📋 Pré-requisitos

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

Existem **duas opções** para rodar o script Lua no Cheat Engine:

### Opção A: Execução Manual (Ideal para testes rápidos)
1. Abra o **Cheat Engine**.
2. Abra a janela Lua pressionando **Ctrl + Alt + L** (ou no menu *Table -> Show Lua Engine*).
3. Clique em **Open file** e selecione o arquivo [`lua/ce_mcp_lua.lua`](file:///B:/Code/mcp-cheatengine/lua/ce_mcp_lua.lua).
4. Clique em **Execute script**.
5. No console do Cheat Engine, confirme se apareceu a mensagem:
   ```text
   [SUCESSO] Servidor Cheat Engine MCP rodando em 127.0.0.1:52737
   [SUCESSO] Loop de eventos do Cheat Engine MCP ativado!
   ```

### Opção B: Autorun Automático (Recomendado para uso contínuo)
1. Copie o arquivo `lua/ce_mcp_lua.lua` para a pasta de instalação do Cheat Engine (ex: `C:\Program Files\Cheat Engine 7.5\`).
2. Copie o arquivo `lua/autorun/ce_mcp_autorun.lua` para a pasta `autorun` do Cheat Engine (ex: `C:\Program Files\Cheat Engine 7.5\autorun\`).
3. Toda vez que você abrir o Cheat Engine, o servidor MCP iniciará automaticamente em segundo plano!

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
