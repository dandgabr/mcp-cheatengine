import json
from mcp.server.fastmcp import FastMCP
from mcp_cheatengine.rpc_client import default_client


def register_assembly_tools(mcp: FastMCP) -> None:
    """Registra ferramentas de desensamblagem e execução de scripts Auto Assemble."""

    @mcp.tool()
    def ce_disassemble(address: str, count: int = 10) -> str:
        """
        Desensambla as instruções de código de máquina a partir de um endereço.

        :param address: Endereço Hexadecimal ou Símbolo (ex: 'game.exe+0x1000').
        :param count: Quantidade de instruções a desensamblar.
        """
        params = {"address": address, "count": count}
        res = default_client.send_request("disassemble", params)
        return json.dumps(res, indent=2, ensure_ascii=False)

    @mcp.tool()
    def ce_auto_assemble(script: str, enable: bool = True) -> str:
        """
        Executa um script Auto Assemble do Cheat Engine (Hooks, Injeção de Código, Allocations).

        :param script: Conteúdo do script Auto Assemble.
        :param enable: True para habilitar/injetar, False para desabilitar/remover.
        """
        params = {"script": script, "enable": enable}
        res = default_client.send_request("auto_assemble", params)
        return json.dumps(res, indent=2, ensure_ascii=False)
