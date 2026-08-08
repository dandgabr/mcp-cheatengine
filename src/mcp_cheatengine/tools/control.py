import json
from typing import Optional
from mcp.server.fastmcp import FastMCP
from mcp_cheatengine.rpc_client import default_client


def register_control_tools(mcp: FastMCP) -> None:
    """Registra ferramentas de controle de execução de processo, alocação de memória e speedhack."""

    @mcp.tool()
    def ce_pause_process() -> str:
        """Pausa a execução do processo atualmente anexado no Cheat Engine."""
        res = default_client.send_request("pause_process")
        return json.dumps(res, indent=2, ensure_ascii=False)

    @mcp.tool()
    def ce_unpause_process() -> str:
        """Retoma a execução do processo atualmente pausado no Cheat Engine."""
        res = default_client.send_request("unpause_process")
        return json.dumps(res, indent=2, ensure_ascii=False)

    @mcp.tool()
    def ce_allocate_memory(size: int, base_address: Optional[str] = None) -> str:
        """
        Aloca uma nova região de memória no processo alvo (máximo de 10MB por chamada).

        :param size: Tamanho em bytes a ser alocado (ex: 4096 para 4KB).
        :param base_address: Endereço Hexadecimal de preferência para alocação (opcional).
        """
        params = {"size": size, "base_address": base_address}
        res = default_client.send_request("allocate_memory", params)
        return json.dumps(res, indent=2, ensure_ascii=False)

    @mcp.tool()
    def ce_free_memory(address: str) -> str:
        """
        Libera uma região de memória previamente alocada no processo alvo.

        :param address: Endereço Hexadecimal da memória a ser liberada.
        """
        params = {"address": address}
        res = default_client.send_request("free_memory", params)
        return json.dumps(res, indent=2, ensure_ascii=False)

    @mcp.tool()
    def ce_set_speedhack(speed: float = 1.0) -> str:
        """
        Altera o multiplicador de velocidade (Speedhack) do processo alvo.

        :param speed: Multiplicador de velocidade (ex: 1.0 = normal, 2.0 = 2x rápido, 0.5 = metade da velocidade, máx: 500.0).
        """
        params = {"speed": speed}
        res = default_client.send_request("set_speedhack", params)
        return json.dumps(res, indent=2, ensure_ascii=False)

    @mcp.tool()
    def ce_dump_memory_to_file(address: str, size: int, filename: str) -> str:
        """
        Salva um bloco de memória do processo em um arquivo seguro dentro do diretório de dumps (máx: 50MB).

        :param address: Endereço Hexadecimal inicial.
        :param size: Tamanho em bytes a ser exportado.
        :param filename: Nome do arquivo (apenas o nome do arquivo, salvo em diretório de dumps isolado).
        """
        params = {"address": address, "size": size, "filename": filename}
        res = default_client.send_request("dump_memory_to_file", params)
        return json.dumps(res, indent=2, ensure_ascii=False)

    @mcp.tool()
    def ce_load_memory_from_file(address: str, filename: str) -> str:
        """
        Carrega dados de um arquivo de dump previamente salvo no diretório isolado para a memória do processo.

        :param address: Endereço Hexadecimal de destino.
        :param filename: Nome do arquivo presente no diretório seguro de dumps.
        """
        params = {"address": address, "filename": filename}
        res = default_client.send_request("load_memory_from_file", params)
        return json.dumps(res, indent=2, ensure_ascii=False)
