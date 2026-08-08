# 💡 Exemplos Práticos e Engenharias de Prompt

Este guia apresenta cenários reais de análise de processos, engenharia reversa e modificação de memória utilizando o **Cheat Engine MCP Server**.

---

## 🎮 Cenário 1: Localização e Alteração de Vida/Pontuação

### Prompt Sugerido para a IA:
> *"Anexe o Cheat Engine ao processo `game.exe`. Procure por um valor de 4 bytes contendo `100` no endereço `0x140050000` ou próximo a ele, e modifique para `999999`."*

### Sequência de Ações Executadas:
1. `ce_attach_process(target="game.exe")`
2. `ce_read_memory(address="0x140050000", data_type="int32")`
3. `ce_write_memory(address="0x140050000", value=999999, data_type="int32")`

---

## 🔗 Cenário 2: Análise e Resolução de Cadeia de Ponteiros (Pointer Chain)

### Prompt Sugerido para a IA:
> *"Resolva a cadeia de ponteiros a partir do endereço base `game.exe+0x01F82A0` utilizando a sequência de offsets `[0x10, 0x48, 0x8]`. Mostre o endereço final calculado e o valor lido."*

### Sequência de Ações Executadas:
1. `ce_read_pointer_chain(base_address="game.exe+0x01F82A0", offsets=[16, 72, 8])`

---

## 🔍 Cenário 3: Varredura por Assinatura de Bytes (AOB Scan) e NOP de Instrução

### Prompt Sugerido para a IA:
> *"Faça um AOB Scan na memória por `48 8B 05 ?? ?? ?? ??`. Em seguida, desensamble 5 instruções no primeiro endereço encontrado e injete 2 bytes NOP (`90 90`)."*

### Sequência de Ações Executadas:
1. `ce_aob_scan(pattern="48 8B 05 ?? ?? ?? ??")`
2. `ce_disassemble(address="0x140012345", count=5)`
3. `ce_write_memory(address="0x140012345", value="90 90", data_type="bytes")`

---

## 💉 Cenário 4: Injeção de Código via Script Auto Assemble

### Prompt Sugerido para a IA:
> *"Crie um script Auto Assemble para desabilitar a instrução de decremento de munição em `game.exe+0x54321` e execute-o."*

### Script Auto Assemble Gerado:
```ini
[ENABLE]
game.exe+0x54321:
  nop
  nop

[DISABLE]
game.exe+0x54321:
  sub [rax+0x18], ecx
```

### Ferramenta Executada:
`ce_auto_assemble(script="...", enable=True)`

---

## 🧪 Cenário 5: Automação Avançada com Script Lua

### Prompt Sugerido para a IA:
> *"Execute um script Lua no Cheat Engine para listar as DLLs carregadas no jogo que iniciam com 'steam'."*

### Ferramenta Executada:
`ce_execute_lua(code="for _, m in ipairs(enumModules()) do if m.Name:lower():find('steam') then print(m.Name, string.format('0x%X', m.Address)) end end")`
