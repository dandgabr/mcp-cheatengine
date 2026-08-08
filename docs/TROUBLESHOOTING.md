# ❓ Solução de Problemas (Troubleshooting)

Guia de solução para os erros e comportamentos inesperados mais comuns ao utilizar o **Cheat Engine MCP Server**.

---

## 🛑 Erros Frequentes e Como Resolver

### 1. `"Não foi possível conectar ao Cheat Engine em 127.0.0.1:52737"`

**Causas:**
- O Cheat Engine não está em execução.
- O script `lua/ce_mcp_lua.lua` não foi executado no Cheat Engine.
- O Firewall do Windows bloqueou a porta local `52737`.

**Solução:**
1. Abra o Cheat Engine.
2. Aperte **Ctrl + Alt + L** para abrir a janela Lua Engine.
3. Carregue e execute o arquivo `lua/ce_mcp_lua.lua`.
4. Garanta que no console do CE apareceu a mensagem:
   `[SUCESSO] Servidor Cheat Engine MCP rodando em 127.0.0.1:52737`

---

### 2. `"Falha ao ler memória" / "Access Violation"`

**Causas:**
- O Cheat Engine não tem privilégios de Administrador para acessar a memória do processo.
- O jogo/processo utiliza um sistema Anti-Cheat (ex: Easy Anti-Cheat, BattEye, Vanguard) que bloqueia `OpenProcess` / `ReadProcessMemory`.

**Solução:**
1. Feche o Cheat Engine e o cliente MCP / IA.
2. Clique com o botão direito no ícone do Cheat Engine e selecione **Executar como Administrador**.
3. Execute também o seu terminal/IDE como Administrador.

---

### 3. Conflito de Porta TCP (`Port already in use`)

**Causas:**
- Outra instância do Cheat Engine ou aplicação está usando a porta `52737`.

**Solução:**
1. Mude a porta no arquivo `lua/ce_mcp_lua.lua`:
   ```lua
   local PORT = 55555
   ```
2. Defina a variável de ambiente `CE_PORT` na configuração da IA (ex: `"CE_PORT": "55555"`).

---

### 4. Processos de 32-bit vs 64-bit

**Causas:**
- Erro ao tentar desensamblar ou ler endereços de 64 bits em um processo de 32 bits (ou vice-versa).

**Solução:**
- Verifique se a flag `is_64bit` retornada pela ferramenta `ce_get_attached_process` corresponde à arquitetura do processo.
- O Cheat Engine lida automaticamente com ponteiros de 32 ou 64 bits de acordo com a arquitetura do processo anexado.
