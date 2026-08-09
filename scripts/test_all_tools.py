import os
import sys
import json
import time

sys.stdout.reconfigure(encoding="utf-8")

# Adiciona src ao path de busca
sys.path.insert(0, os.path.abspath("src"))

from mcp_cheatengine.rpc_client import default_client

def run_test(name, func):
    print(f"\n==================================================")
    print(f" [*] EXECUTANDO TESTE: {name}")
    print(f"==================================================")
    try:
        res = func()
        print(f"[+] SUCESSO no teste '{name}':")
        print(json.dumps(res, indent=2, ensure_ascii=False))
        return True
    except Exception as e:
        print(f"[-] ERRO no teste '{name}': {e}")
        return False

tests_passed = 0
tests_failed = 0

# 1. Teste ping
if run_test("ce_ping", lambda: default_client.send_request("ping")):
    tests_passed += 1
else:
    tests_failed += 1

# 2. Teste list_processes
if run_test("ce_list_processes", lambda: default_client.send_request("list_processes")):
    tests_passed += 1
else:
    tests_failed += 1

# 3. Teste get_attached_process
if run_test("ce_get_attached_process", lambda: default_client.send_request("get_attached_process")):
    tests_passed += 1
else:
    tests_failed += 1

# 4. Teste attach_process (anexa ao próprio Cheat Engine como processo seguro)
ce_pid = None
def test_attach():
    global ce_pid
    res = default_client.send_request("attach_process", {"target": "cheatengine-x86_64.exe"})
    ce_pid = res.get("process_id")
    return res

if run_test("ce_attach_process", test_attach):
    tests_passed += 1
else:
    tests_failed += 1

# 5. Teste get_address (obter módulo base)
base_addr = None
def test_get_address():
    global base_addr
    res = default_client.send_request("get_address", {"symbol": "cheatengine-x86_64.exe"})
    base_addr = res.get("address")
    return res

if run_test("ce_get_address", test_get_address):
    tests_passed += 1
else:
    tests_failed += 1

# 6. Teste enum_modules
if run_test("ce_enum_modules", lambda: default_client.send_request("enum_modules")):
    tests_passed += 1
else:
    tests_failed += 1

# 7. Teste allocate_memory
alloc_addr = None
def test_allocate():
    global alloc_addr
    res = default_client.send_request("allocate_memory", {"size": 4096})
    alloc_addr = res.get("address")
    return res

if run_test("ce_allocate_memory", test_allocate):
    tests_passed += 1
else:
    tests_failed += 1

# 8. Teste write_memory
if alloc_addr:
    if run_test("ce_write_memory", lambda: default_client.send_request("write_memory", {"address": alloc_addr, "type": "int32", "value": 13371337})):
        tests_passed += 1
    else:
        tests_failed += 1

# 9. Teste read_memory
if alloc_addr:
    if run_test("ce_read_memory", lambda: default_client.send_request("read_memory", {"address": alloc_addr, "type": "int32"})):
        tests_passed += 1
    else:
        tests_failed += 1

# 10. Teste read_pointer_chain
if alloc_addr:
    if run_test("ce_read_pointer_chain", lambda: default_client.send_request("read_pointer_chain", {"base_address": alloc_addr, "offsets": [0]})):
        tests_passed += 1
    else:
        tests_failed += 1

# 11. Teste disassemble
if base_addr:
    if run_test("ce_disassemble", lambda: default_client.send_request("disassemble", {"address": base_addr, "count": 3})):
        tests_passed += 1
    else:
        tests_failed += 1

# 12. Teste execute_lua
if run_test("ce_execute_lua", lambda: default_client.send_request("execute_lua", {"code": "return 'Hello from MCP Lua Test!'"})):
    tests_passed += 1
else:
    tests_failed += 1

# 13. Teste add_address_list_entry
entry_id = None
def test_add_entry():
    global entry_id
    res = default_client.send_request("add_address_list_entry", {"address": alloc_addr or "0x1000", "description": "MCP Automated Test Entry"})
    entry_id = res.get("id")
    return res

if run_test("ce_add_address_list_entry", test_add_entry):
    tests_passed += 1
else:
    tests_failed += 1

# 14. Teste get_address_list
if run_test("ce_get_address_list", lambda: default_client.send_request("get_address_list")):
    tests_passed += 1
else:
    tests_failed += 1

# 15. Teste toggle_freeze
if entry_id:
    if run_test("ce_toggle_freeze", lambda: default_client.send_request("toggle_freeze", {"target": entry_id, "active": False})):
        tests_passed += 1
    else:
        tests_failed += 1

# 16. Teste dump_memory_to_file
if alloc_addr:
    if run_test("ce_dump_memory_to_file", lambda: default_client.send_request("dump_memory_to_file", {"address": alloc_addr, "size": 64, "filename": "mcp_test_dump.bin"})):
        tests_passed += 1
    else:
        tests_failed += 1

# 17. Teste load_memory_from_file
if alloc_addr:
    if run_test("ce_load_memory_from_file", lambda: default_client.send_request("load_memory_from_file", {"address": alloc_addr, "filename": "mcp_test_dump.bin"})):
        tests_passed += 1
    else:
        tests_failed += 1

# 18. Teste set_speedhack
if run_test("ce_set_speedhack", lambda: default_client.send_request("set_speedhack", {"speed": 1.0})):
    tests_passed += 1
else:
    tests_failed += 1

# 19. Teste pause_process & unpause_process
if run_test("ce_pause_process", lambda: default_client.send_request("pause_process")):
    tests_passed += 1
    run_test("ce_unpause_process", lambda: default_client.send_request("unpause_process"))
else:
    tests_failed += 1

# 20. Teste free_memory
if alloc_addr:
    if run_test("ce_free_memory", lambda: default_client.send_request("free_memory", {"address": alloc_addr})):
        tests_passed += 1
    else:
        tests_failed += 1

print(f"\n==================================================")
print(f" [SUMÁRIO DA BATERIA DE TESTES DO CHEAT ENGINE MCP]")
print(f"==================================================")
print(f" Testes Aprovados: {tests_passed}")
print(f" Testes Falhos:    {tests_failed}")
print(f" Total de Testes:  {tests_passed + tests_failed}")
print(f"==================================================")
