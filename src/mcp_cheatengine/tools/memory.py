import json
from typing import Any, List
from mcp.server.fastmcp import FastMCP
from mcp_cheatengine.rpc_client import default_client
from mcp_cheatengine.logger import log_debug


def register_memory_tools(mcp: FastMCP) -> None:
    """Registra ferramentas de leitura, escrita e resolução de ponteiros de memória."""

    @mcp.tool()
    def ce_read_memory(
        address: str,
        data_type: str = "int32",
        count: int = 16,
        length: int = 256
    ) -> str:
        """
        Lê valor da memória no endereço especificado.

        :param address: Endereço Hexadecimal ou Símbolo (ex: '0x140000000', 'game.exe+0x12345').
        :param data_type: Tipo de dado: 'byte', 'bytes', 'int16', 'int32', 'int64', 'float', 'double', 'string', 'pointer'.
        :param count: Quantidade de bytes a ler quando data_type='bytes'.
        :param length: Tamanho máximo da string quando data_type='string'.
        """
        log_debug(f"Executando tool: ce_read_memory(address='{address}', type='{data_type}', count={count}, length={length})")
        params = {
            "address": address,
            "type": data_type,
            "count": count,
            "length": length
        }
        res = default_client.send_request("read_memory", params)
        return json.dumps(res, indent=2, ensure_ascii=False)

    @mcp.tool()
    def ce_write_memory(
        address: str,
        value: Any,
        data_type: str = "int32"
    ) -> str:
        """
        Escreve um valor no endereço de memória especificado.

        :param address: Endereço Hexadecimal ou Símbolo (ex: '0x140000000', 'game.exe+0x12345').
        :param value: Valor a ser escrito (Número, String de texto, ou String de bytes em hex ex: '90 90 90').
        :param data_type: Tipo de dado: 'byte', 'bytes', 'int16', 'int32', 'int64', 'float', 'double', 'string'.
        """
        log_debug(f"Executando tool: ce_write_memory(address='{address}', value={value}, type='{data_type}')")
        params = {
            "address": address,
            "value": value,
            "type": data_type
        }
        res = default_client.send_request("write_memory", params)
        return json.dumps(res, indent=2, ensure_ascii=False)

    @mcp.tool()
    def ce_read_pointer_chain(
        base_address: str,
        offsets: List[int],
        data_type: str = "int32"
    ) -> str:
        """
        Navega por uma cadeia de ponteiros e resolve o endereço final e valor.

        :param base_address: Endereço base ou símbolo inicial (ex: 'game.exe+0x01F82A0').
        :param offsets: Lista de offsets em número decimal ou hex (ex: [0x10, 0x48, 0x8]).
        :param data_type: Tipo de dado do valor final ('int32', 'int64', 'float', 'double', 'string', 'pointer').
        """
        log_debug(f"Executando tool: ce_read_pointer_chain(base_address='{base_address}', offsets={offsets}, data_type='{data_type}')")
        params = {
            "base_address": base_address,
            "offsets": offsets,
            "type": data_type
        }
        res = default_client.send_request("read_pointer_chain", params)
        return json.dumps(res, indent=2, ensure_ascii=False)
