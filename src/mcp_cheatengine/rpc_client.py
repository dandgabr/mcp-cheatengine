import json
import socket
from typing import Any, Dict, Optional
from mcp_cheatengine.config import Config


class CERPCClient:
    """Cliente para comunicação com o servidor TCP Lua no Cheat Engine via JSON-RPC 2.0."""

    def __init__(self, host: Optional[str] = None, port: Optional[int] = None):
        self.host = host or Config.CE_HOST
        self.port = port or Config.CE_PORT

    def send_request(
        self,
        method: str,
        params: Optional[Dict[str, Any]] = None,
        timeout: Optional[float] = None
    ) -> Dict[str, Any]:
        """
        Envia uma requisição JSON-RPC via TCP para o servidor Lua no Cheat Engine.
        """
        timeout_val = timeout if timeout is not None else Config.DEFAULT_TIMEOUT
        payload = {
            "jsonrpc": "2.0",
            "id": 1,
            "method": method,
            "params": params or {}
        }

        try:
            with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as client:
                client.settimeout(timeout_val)
                client.connect((self.host, self.port))

                message = json.dumps(payload) + "\n"
                client.sendall(message.encode("utf-8"))

                buffer = ""
                while True:
                    chunk = client.recv(4096).decode("utf-8")
                    if not chunk:
                        break
                    buffer += chunk
                    if "\n" in buffer:
                        break

                if not buffer:
                    raise Exception("Resposta vazia recebida do Cheat Engine.")

                res = json.loads(buffer.strip())
                if "error" in res and res["error"]:
                    err_msg = res["error"].get("message", str(res["error"]))
                    raise Exception(f"Erro no Cheat Engine: {err_msg}")

                return res.get("result", {})

        except ConnectionRefusedError:
            raise Exception(
                f"Não foi possível conectar ao Cheat Engine em {self.host}:{self.port}. "
                "Certifique-se de que o Cheat Engine está aberto e que o script 'lua/ce_mcp_lua.lua' foi executado."
            )
        except socket.timeout:
            raise Exception("Tempo limite atingido aguardando resposta do Cheat Engine (Timeout).")
        except Exception as e:
            raise Exception(f"Erro de comunicação com Cheat Engine: {str(e)}")


default_client = CERPCClient()
