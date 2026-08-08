import json
from mcp.server.fastmcp import FastMCP
from mcp_cheatengine.config import Config
from mcp_cheatengine.rpc_client import default_client


def register_scanner_tools(mcp: FastMCP) -> None:
    """Registra ferramentas de varredura (AOB scan), símbolos e enumeração de módulos."""

    @mcp.tool()
    def ce_aob_scan(
        pattern: str,
        protection_flags: str = "+W-C",
        alignment_type: int = 0,
        start_address: str = "",
        stop_address: str = ""
    ) -> str:
        """
        Realiza uma busca por Array de Bytes (AOB Scan) na memória do processo.

        :param pattern: Padrão de bytes em Hexadecimal (ex: '48 8B 05 ?? ?? ?? ??').
        :param protection_flags: Flags de proteção de memória (padrão: '+W-C').
        :param alignment_type: Alinhamento de busca (0=Qualquer, 1=Fast 2 bytes, 2=Fast 4 bytes, etc).
        :param start_address: Endereço inicial da busca em Hex (opcional).
        :param stop_address: Endereço final da busca em Hex (opcional).
        """
        params = {
            "pattern": pattern,
            "protection_flags": protection_flags,
            "alignment_type": alignment_type,
            "start_address": start_address,
            "stop_address": stop_address
        }
        res = default_client.send_request("aob_scan", params, timeout=Config.SCAN_TIMEOUT)
        return json.dumps(res, indent=2, ensure_ascii=False)

    @mcp.tool()
    def ce_get_address(symbol: str) -> str:
        """
        Resolve uma expressão de módulo/símbolo para um endereço Hexadecimal exato.

        :param symbol: Expressão de símbolo (ex: 'kernel32.dll+0x10', 'player_base').
        """
        res = default_client.send_request("get_address", {"symbol": symbol})
        return json.dumps(res, indent=2, ensure_ascii=False)

    @mcp.tool()
    def ce_enum_modules() -> str:
        """Lista todos os módulos (DLLs e Executável) carregados no processo anexado."""
        res = default_client.send_request("enum_modules")
        return json.dumps(res, indent=2, ensure_ascii=False)
