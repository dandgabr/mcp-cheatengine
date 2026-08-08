# 📖 Referência da API e Ferramentas MCP

O **Cheat Engine MCP Server** disponibiliza **21 ferramentas MCP** para controle de memória, depuração, desensamblagem, automação e gerenciamento da Address List.

---

## 📑 Sumário das Ferramentas Expostas

| Ferramenta | Categoria | Descrição Curta |
| :--- | :--- | :--- |
| [`ce_ping`](#ce_ping) | Gerenciamento | Verifica o estado de saúde do servidor Lua no Cheat Engine |
| [`ce_list_processes`](#ce_list_processes) | Gerenciamento | Retorna todos os processos em execução com PID e Nome |
| [`ce_attach_process`](#ce_attach_process) | Gerenciamento | Anexa o Cheat Engine a um processo alvo por PID ou Nome |
| [`ce_get_attached_process`](#ce_get_attached_process) | Gerenciamento | Retorna informações sobre o processo anexado no momento |
| [`ce_read_memory`](#ce_read_memory) | Memória | Lê valores de memória em vários formatos de dados |
| [`ce_write_memory`](#ce_write_memory) | Memória | Altera o conteúdo da memória em um endereço especificado |
| [`ce_read_pointer_chain`](#ce_read_pointer_chain) | Memória | Resolve estruturas de ponteiros multinível com offsets |
| [`ce_aob_scan`](#ce_aob_scan) | Scanner | Varreduras por padrões de bytes (AOB Scan com wildcards) |
| [`ce_get_address`](#ce_get_address) | Scanner | Converte símbolos/expressões em endereços hexadecimais |
| [`ce_enum_modules`](#ce_enum_modules) | Scanner | Enumera módulos e DLLs carregadas no processo |
| [`ce_disassemble`](#ce_disassemble) | Assembly | Desensambla instruções x86/x64 a partir de um endereço |
| [`ce_auto_assemble`](#ce_auto_assemble) | Assembly | Injeta scripts de Auto Assemble (Code Cave, Hooks, Allocs) |
| [`ce_execute_lua`](#ce_execute_lua) | Automação | Executa scripts Lua diretamente no interpretador do CE |
| [`ce_set_breakpoint`](#ce_set_breakpoint) | Depuração | Configura breakpoints de hardware/software na memória |
| [`ce_pause_process`](#ce_pause_process) | Controle | Pausa a execução do processo anexado |
| [`ce_unpause_process`](#ce_unpause_process) | Controle | Retoma a execução do processo pausado |
| [`ce_allocate_memory`](#ce_allocate_memory) | Controle | Aloca uma região de memória no processo alvo (máx: 10MB) |
| [`ce_free_memory`](#ce_free_memory) | Controle | Libera uma região de memória alocada previamente |
| [`ce_set_speedhack`](#ce_set_speedhack) | Controle | Altera o multiplicador de velocidade (0.0 a 500.0x) |
| [`ce_get_address_list`](#ce_get_address_list) | Cheat Table | Retorna todos os itens da Address List (Cheat Table) |
| [`ce_add_address_list_entry`](#ce_add_address_list_entry) | Cheat Table | Adiciona um novo endereço/registro à Address List |
| [`ce_toggle_freeze`](#ce_toggle_freeze) | Cheat Table | Congela/descongela (ativa/desativa) um registro da tabela |
| [`ce_dump_memory_to_file`](#ce_dump_memory_to_file) | Snapshots | Exporta bloco de memória para pasta segura `dumps\` (.dmp/.bin) |
| [`ce_load_memory_from_file`](#ce_load_memory_from_file) | Snapshots | Carrega dados de dump da pasta `dumps\` para a memória |

---

## 🛠️ Detalhamento Técnico das Novas Ferramentas

### `ce_pause_process`
Pausa a execução de todas as threads do processo anexado.
- **Parâmetros**: Nenhum

### `ce_unpause_process`
Retoma a execução do processo pausado.
- **Parâmetros**: Nenhum

### `ce_allocate_memory`
Aloca um bloco de memória no processo alvo.
- **Parâmetros**:
  - `size` (*int*, obrigatório): Tamanho em bytes (máximo 10MB por chamada).
  - `base_address` (*string*, opcional): Endereço preferencial em Hex.

### `ce_free_memory`
Libera a memória alocada no processo alvo.
- **Parâmetros**:
  - `address` (*string*, obrigatório): Endereço Hexadecimal da alocação.

### `ce_set_speedhack`
Modifica o multiplicador do Speedhack.
- **Parâmetros**:
  - `speed` (*float*, opcional, padrão: `1.0`): Fator de velocidade (entre `0.0` e `500.0`).

### `ce_get_address_list`
Retorna todos os itens cadastrados na Address List do Cheat Engine.
- **Parâmetros**: Nenhum

### `ce_add_address_list_entry`
Insere um novo endereço na Address List.
- **Parâmetros**:
  - `address` (*string*, obrigatório): Endereço Hexadecimal ou símbolo.
  - `description` (*string*, opcional): Descrição textual (máx 100 chars).
  - `data_type` (*string*, opcional): Tipo de dado do CE (ex: `"vtDword"`, `"vtFloat"`).

### `ce_toggle_freeze`
Congela ou descongela a atualização contínua de um valor na tabela.
- **Parâmetros**:
  - `target` (*string*, obrigatório): ID numérico ou Descrição do item.
  - `active` (*boolean*, opcional, padrão: `true`): `true` para congelar, `false` para descongelar.

### `ce_dump_memory_to_file`
Exporta com segurança um trecho de memória para arquivo `.dmp` ou `.bin` isolado no diretório `dumps\`.
- **Parâmetros**:
  - `address` (*string*, obrigatório): Endereço Hexadecimal.
  - `size` (*int*, obrigatório): Tamanho em bytes (máximo 50MB).
  - `filename` (*string*, obrigatório): Nome do arquivo com extensão `.dmp` ou `.bin`.

### `ce_load_memory_from_file`
Restaura um dump isolado previamente salvo para a memória do processo.
- **Parâmetros**:
  - `address` (*string*, obrigatório): Endereço de destino em Hex.
  - `filename` (*string*, obrigatório): Nome do arquivo presente no diretório `dumps\`.
