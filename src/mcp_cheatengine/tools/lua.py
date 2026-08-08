import json
from mcp.server.fastmcp import FastMCP
from mcp_cheatengine.rpc_client import default_client


def register_lua_tools(mcp: FastMCP) -> None:
    """Registra ferramenta para execução arbitrária de código Lua."""

    @mcp.tool()
    def ce_execute_lua(code: str) -> str:
        """
        Executa código Lua customizado arbitrário diretamente dentro do ambiente do Cheat Engine.

        :param code: Código Lua a ser executado.
        """
        params = {"code": code}
        res = default_client.send_request("execute_lua", params)
        return json.dumps(res, indent=2, ensure_ascii=False)
