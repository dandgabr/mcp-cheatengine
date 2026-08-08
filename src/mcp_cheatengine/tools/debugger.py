import json
from mcp.server.fastmcp import FastMCP
from mcp_cheatengine.rpc_client import default_client


def register_debugger_tools(mcp: FastMCP) -> None:
    """Registra ferramentas de depuração e breakpoints."""

    @mcp.tool()
    def ce_set_breakpoint(address: str, size: int = 1, trigger: int = 0) -> str:
        """
        Define um breakpoint de hardware/software em um endereço de memória.

        :param address: Endereço Hexadecimal do breakpoint.
        :param size: Tamanho do breakpoint (1, 2, 4 ou 8 bytes).
        :param trigger: Condição do breakpoint (0=bptExecute, 1=bptWrite, 2=bptAccess).
        """
        params = {"address": address, "size": size, "trigger": trigger}
        res = default_client.send_request("set_breakpoint", params)
        return json.dumps(res, indent=2, ensure_ascii=False)
