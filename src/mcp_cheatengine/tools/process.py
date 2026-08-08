import json
from mcp.server.fastmcp import FastMCP
from mcp_cheatengine.rpc_client import default_client


def register_process_tools(mcp: FastMCP) -> None:
    """Registra ferramentas de gerenciamento de processos."""

    @mcp.tool()
    def ce_ping() -> str:
        """Verifica se o servidor Lua do Cheat Engine está ativo e operando."""
        res = default_client.send_request("ping")
        return json.dumps(res, indent=2, ensure_ascii=False)

    @mcp.tool()
    def ce_list_processes() -> str:
        """Retorna a lista de todos os processos em execução no sistema com PID e Nome."""
        res = default_client.send_request("list_processes")
        return json.dumps(res, indent=2, ensure_ascii=False)

    @mcp.tool()
    def ce_attach_process(target: str) -> str:
        """
        Anexa o Cheat Engine a um processo em execução.

        :param target: Nome do processo (ex: 'gta5.exe') ou PID numérico (ex: 1234).
        """
        res = default_client.send_request("attach_process", {"target": target})
        return json.dumps(res, indent=2, ensure_ascii=False)

    @mcp.tool()
    def ce_get_attached_process() -> str:
        """Retorna o ID e o nome do processo atualmente anexado no Cheat Engine."""
        res = default_client.send_request("get_attached_process")
        return json.dumps(res, indent=2, ensure_ascii=False)
