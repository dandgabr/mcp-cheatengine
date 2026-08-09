import os
import json
import socket
import time
import ctypes
import concurrent.futures
from ctypes import wintypes
from typing import Any, Dict, Optional
from mcp_cheatengine.config import Config
from mcp_cheatengine.logger import log_debug, log_info, log_error

GENERIC_READ = 0x80000000
GENERIC_WRITE = 0x40000000
OPEN_EXISTING = 3
FILE_ATTRIBUTE_NORMAL = 0x80
INVALID_HANDLE_VALUE = -1


# Protótipos de Funções Win32 API para Ctypes em 64-bit
kernel32 = ctypes.windll.kernel32
kernel32.CreateFileW.restype = wintypes.HANDLE
kernel32.CreateFileW.argtypes = [
    wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
    ctypes.c_void_p, wintypes.DWORD, wintypes.DWORD, wintypes.HANDLE
]
kernel32.WriteFile.restype = wintypes.BOOL
kernel32.WriteFile.argtypes = [
    wintypes.HANDLE, ctypes.c_char_p, wintypes.DWORD,
    ctypes.POINTER(wintypes.DWORD), ctypes.c_void_p
]
kernel32.ReadFile.restype = wintypes.BOOL
kernel32.ReadFile.argtypes = [
    wintypes.HANDLE, ctypes.c_char_p, wintypes.DWORD,
    ctypes.POINTER(wintypes.DWORD), ctypes.c_void_p
]
kernel32.FlushFileBuffers.restype = wintypes.BOOL
kernel32.FlushFileBuffers.argtypes = [wintypes.HANDLE]
kernel32.CloseHandle.restype = wintypes.BOOL
kernel32.CloseHandle.argtypes = [wintypes.HANDLE]
kernel32.WaitNamedPipeW.restype = wintypes.BOOL
kernel32.WaitNamedPipeW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD]


def _is_invalid_handle(h) -> bool:
    if h is None or h == 0 or h == -1:
        return True
    val = getattr(h, "value", h)
    if val in (-1, 0, 0xFFFFFFFF, 0xFFFFFFFFFFFFFFFF):
        return True
    return False


class CERPCClient:
    """Cliente para comunicação com o servidor Lua no Cheat Engine via DLL Nativa, TCP Socket ou Named Pipe."""

    def __init__(self, host: Optional[str] = None, port: Optional[int] = None):
        self.host = host or Config.CE_HOST
        self.port = port or Config.CE_PORT
        self.pipe_name = r"\\.\pipe\CheatEngineMCP"
        log_debug(f"CERPCClient inicializado (Host={self.host}, Port={self.port}, Pipe={self.pipe_name})")

    def _send_via_pipe(self, payload_str: str) -> str:
        log_debug(f"Tentando comunicação via Named Pipe em {self.pipe_name}...")
        handle = kernel32.CreateFileW(
            self.pipe_name,
            GENERIC_READ | GENERIC_WRITE,
            0,
            None,
            OPEN_EXISTING,
            FILE_ATTRIBUTE_NORMAL,
            None
        )
        if _is_invalid_handle(handle):
            err = kernel32.GetLastError()
            log_debug(f"CreateFileW falhou com erro Windows {err}. Verificando se a Named Pipe está ocupada...")
            if err == 231:  # ERROR_PIPE_BUSY
                log_debug("Named Pipe ocupada. Aguardando até 2000ms via WaitNamedPipeW...")
                if kernel32.WaitNamedPipeW(self.pipe_name, 2000):
                    handle = kernel32.CreateFileW(
                        self.pipe_name,
                        GENERIC_READ | GENERIC_WRITE,
                        0,
                        None,
                        OPEN_EXISTING,
                        FILE_ATTRIBUTE_NORMAL,
                        None
                    )
            if _is_invalid_handle(handle):
                err = kernel32.GetLastError()
                log_error(f"Não foi possível abrir a Named Pipe {self.pipe_name}: Erro {err}")
                raise Exception(f"Erro ao abrir Named Pipe (Windows Error {err})")

        try:
            data = payload_str.encode("utf-8")
            written = wintypes.DWORD()
            log_debug(f"Escrevendo {len(data)} bytes no Named Pipe...")
            if not kernel32.WriteFile(handle, data, len(data), ctypes.byref(written), None):
                err = kernel32.GetLastError()
                log_error(f"WriteFile falhou no Named Pipe: Erro {err}")
                raise Exception(f"Erro ao enviar dados via Pipe (Error {err})")

            # Força a transmissão imediata dos bytes gravados para o servidor Named Pipe
            kernel32.FlushFileBuffers(handle)

            buf = ctypes.create_string_buffer(65536)
            read_bytes = wintypes.DWORD()
            log_debug("Aguardando resposta do Named Pipe...")
            if not kernel32.ReadFile(handle, buf, 65536, ctypes.byref(read_bytes), None) or read_bytes.value == 0:
                log_error("ReadFile retornou resposta vazia do Named Pipe.")
                raise Exception("Resposta vazia da Named Pipe do Cheat Engine.")

            raw_resp = buf.raw[:read_bytes.value].decode("utf-8")
            log_debug(f"Resposta recebida via Named Pipe ({read_bytes.value} bytes): {raw_resp.strip()}")
            return raw_resp
        finally:
            kernel32.CloseHandle(handle)

    def send_request(
        self,
        method: str,
        params: Optional[Dict[str, Any]] = None,
        timeout: Optional[float] = None
    ) -> Dict[str, Any]:
        """
        Envia uma requisição JSON-RPC para o Cheat Engine via TCP ou Named Pipe.
        """
        timeout_val = timeout if timeout is not None else Config.DEFAULT_TIMEOUT
        req_id = int(time.time() * 1000)
        payload = {
            "jsonrpc": "2.0",
            "id": req_id,
            "method": method,
            "params": params or {}
        }
        payload_str = json.dumps(payload) + "\n"
        log_debug(f"RPC Request -> Método: '{method}', Params: {params or {}}")

        # 1. Tenta comunicação nativa via luaclient-x86_64.dll com timeout de 3s
        try:
            dll_path = r"C:\Program Files\Cheat Engine\luaclient-x86_64.dll"
            if os.path.exists(dll_path):
                if not getattr(self, "luaclient", None):
                    self.luaclient = ctypes.WinDLL(dll_path)
                    self.luaclient.CELUA_Initialize.argtypes = [ctypes.c_char_p]
                    self.luaclient.CELUA_Initialize.restype = ctypes.c_bool

                    self.luaclient.CELUA_ExecuteFunction.argtypes = [ctypes.c_char_p, ctypes.c_size_t]
                    self.luaclient.CELUA_ExecuteFunction.restype = ctypes.c_size_t

                if not getattr(self, "luaclient_initialized", False):
                    init_res = self.luaclient.CELUA_Initialize(b"CheatEngineMCP")
                    log_debug(f"CELUA_Initialize('CheatEngineMCP') retornou: {init_res}")
                    self.luaclient_initialized = True

                if self.luaclient_initialized:
                    json_str = json.dumps(payload)
                    lua_code = f"return _CE_MCP_DISPATCH([[ {json_str} ]])".encode("utf-8")
                    log_debug(f"Executando via LuaClient DLL: {lua_code.decode('utf-8')}")

                    with concurrent.futures.ThreadPoolExecutor(max_workers=1) as executor:
                        future = executor.submit(self.luaclient.CELUA_ExecuteFunction, lua_code, 0)
                        res_len = future.result(timeout=3.0)

                    log_debug(f"CELUA_ExecuteFunction retornou res_len: {res_len}")
                    if res_len > 0:
                        resp_file = r"C:\Program Files\Cheat Engine\mcp_resp.json"
                        if os.path.exists(resp_file):
                            with open(resp_file, "r", encoding="utf-8") as f:
                                raw_str = f.read()
                            res = json.loads(raw_str)
                            if res.get("id") == req_id:
                                log_debug(f"Resposta recebida via LuaClient DLL ({len(raw_str)} bytes): {raw_str}")
                                if "error" in res and res["error"]:
                                    err_msg = res["error"].get("message", str(res["error"]))
                                    log_error(f"Resposta JSON-RPC de Erro (LuaClient DLL): {err_msg}")
                                    raise Exception(f"Erro no Cheat Engine: {err_msg}")
                                return res.get("result", {})
                            else:
                                log_debug(f"Stale response in mcp_resp.json (id {res.get('id')} != {req_id}). Ignorando...")
        except Exception as dll_e:
            log_debug(f"Falha ou timeout na conexão via LuaClient DLL ({dll_e}). Alternando para TCP Socket...")

        # 2. Tenta conexão via TCP Socket (LuaSocket)
        try:
            log_debug(f"Tentando conexão TCP Socket em {self.host}:{self.port}...")
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as client:
                client.settimeout(0.5)
                client.connect((self.host, self.port))
                client.settimeout(timeout_val)

                log_debug(f"TCP Conectado. Enviando payload ({len(payload_str)} bytes)...")
                client.sendall(payload_str.encode("utf-8"))

                raw_buffer = bytearray()
                while True:
                    chunk = client.recv(4096)
                    if not chunk:
                        break
                    raw_buffer.extend(chunk)
                    if b"\n" in raw_buffer:
                        break

                if raw_buffer:
                    buffer = raw_buffer.decode("utf-8")
                    log_debug(f"Resposta recebida via TCP Socket: {buffer.strip()}")
                    res = json.loads(buffer.strip())
                    if "error" in res and res["error"]:
                        err_msg = res["error"].get("message", str(res["error"]))
                        log_error(f"Resposta JSON-RPC de Erro: {err_msg}")
                        raise Exception(f"Erro no Cheat Engine: {err_msg}")
                    return res.get("result", {})
        except Exception as tcp_e:
            log_debug(f"Falha na conexão TCP Socket ({tcp_e}). Alternando para Named Pipe...")

        # 3. Fallback via Windows Named Pipe nativo do Cheat Engine
        try:
            buffer = self._send_via_pipe(payload_str)
            res = json.loads(buffer.strip())
            if "error" in res and res["error"]:
                err_msg = res["error"].get("message", str(res["error"]))
                log_error(f"Resposta JSON-RPC de Erro (Named Pipe): {err_msg}")
                raise Exception(f"Erro no Cheat Engine: {err_msg}")
            return res.get("result", {})
        except Exception as pipe_err:
            log_error(f"Falha em todos os canais de comunicação com Cheat Engine: {pipe_err}")
            raise Exception(
                f"Não foi possível conectar ao Cheat Engine via DLL nativa, TCP ({self.host}:{self.port}) ou Named Pipe ({self.pipe_name}). "
                "Certifique-se de que o Cheat Engine está aberto com o MCP ativo. "
                f"Detalhe: {str(pipe_err)}"
            )


default_client = CERPCClient()
