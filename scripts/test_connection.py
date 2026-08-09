import sys
import os
import json

# Garante suporte a UTF-8 no stdout do console Windows
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

# Adiciona o diretório src ao path do Python
src_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "src"))
if src_dir not in sys.path:
    sys.path.insert(0, src_dir)

from mcp_cheatengine.rpc_client import default_client
from mcp_cheatengine.logger import log_info


def test_ce_connection():
    print("============================================================")
    print(" [TESTE DE CONEXAO PING - CHEAT ENGINE MCP]")
    print("============================================================")

    try:
        log_info("Enviando requisição JSON-RPC 'ping'...")
        res = default_client.send_request("ping")

        print("\n[+] CONEXAO ESTABELECIDA COM SUCESSO!")
        print("------------------------------------------------------------")
        print(json.dumps(res, indent=2, ensure_ascii=False))
        print("------------------------------------------------------------")
        print("Cheat Engine pronto para receber comandos da IA!")
        return True
    except Exception as e:
        print(f"\n[-] ERRO NA CONEXAO: {e}")
        return False


if __name__ == "__main__":
    success = test_ce_connection()
    sys.exit(0 if success else 1)
