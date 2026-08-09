import os
import sys
import ctypes

sys.stdout.reconfigure(encoding="utf-8")

dll_path = r"C:\Program Files\Cheat Engine\luaclient-x86_64.dll"
print(f"[*] Verificando DLL do LuaClient em: {dll_path}")
if not os.path.exists(dll_path):
    print("[-] luaclient-x86_64.dll não encontrada.")
    sys.exit(1)

try:
    luaclient = ctypes.WinDLL(dll_path)
    # BOOL CELUA_Initialize(char *name)
    luaclient.CELUA_Initialize.argtypes = [ctypes.c_char_p]
    luaclient.CELUA_Initialize.restype = ctypes.c_bool

    # UINT_PTR CELUA_ExecuteFunction(char *luacode, UINT_PTR parameter)
    luaclient.CELUA_ExecuteFunction.argtypes = [ctypes.c_char_p, ctypes.c_size_t]
    luaclient.CELUA_ExecuteFunction.restype = ctypes.c_size_t

    pipe_name = b"CheatEngineMCP"
    print(f"[*] Inicializando conexão CELUA_Initialize('{pipe_name.decode()}')...")
    init_res = luaclient.CELUA_Initialize(pipe_name)
    print(f"[+] CELUA_Initialize retornou: {init_res}")

    if init_res:
        lua_code = "print('[MCP] Conexao via luaclient-x86_64.dll com SUCESSO!') return 1337".encode("utf-8")
        print(f"[*] Executando código Lua no Cheat Engine: {lua_code.decode('utf-8')}...")
        res = luaclient.CELUA_ExecuteFunction(lua_code, 0)
        print(f"[+] CELUA_ExecuteFunction retornou: {res}")
except Exception as e:
    print(f"[-] Exceção: {e}")
