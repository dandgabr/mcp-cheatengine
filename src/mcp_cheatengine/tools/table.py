import json
from typing import Any, Optional
from mcp.server.fastmcp import FastMCP
from mcp_cheatengine.rpc_client import default_client


def register_table_tools(mcp: FastMCP) -> None:
    """Registra ferramentas de gerenciamento da Address List (Cheat Table) do Cheat Engine."""

    @mcp.tool()
    def ce_get_address_list() -> str:
        """Lista todos os registros atuais da Address List (tabela de cheats) do Cheat Engine."""
        res = default_client.send_request("get_address_list")
        return json.dumps(res, indent=2, ensure_ascii=False)

    @mcp.tool()
    def ce_add_address_list_entry(
        address: str,
        description: str = "MCP Entry",
        data_type: str = "vtDword"
    ) -> str:
        """
        Adiciona um novo registro/endereço de memória à Address List do Cheat Engine.

        :param address: Endereço Hexadecimal ou expressão (ex: '0x140012345', 'game.exe+0x10').
        :param description: Descrição amigável para o registro na tabela.
        :param data_type: Tipo de dado do CE (ex: 'vtByte', 'vtWord', 'vtDword', 'vtSingle', 'vtDouble', 'vtString').
        """
        params = {
            "address": address,
            "description": description,
            "type": data_type
        }
        res = default_client.send_request("add_address_list_entry", params)
        return json.dumps(res, indent=2, ensure_ascii=False)

    @mcp.tool()
    def ce_toggle_freeze(target: str, active: bool = True) -> str:
        """
        Ativa ou desativa o congelamento (freeze) de um valor de memória da Address List.

        :param target: ID numérico do registro ou Descrição exata do item na tabela.
        :param active: True para congelar/ativar o registro, False para descongelar/desativar.
        """
        params = {"target": target, "active": active}
        res = default_client.send_request("toggle_freeze", params)
        return json.dumps(res, indent=2, ensure_ascii=False)
