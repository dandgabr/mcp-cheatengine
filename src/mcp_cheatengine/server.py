from mcp.server.fastmcp import FastMCP
from mcp_cheatengine.tools.process import register_process_tools
from mcp_cheatengine.tools.memory import register_memory_tools
from mcp_cheatengine.tools.scanner import register_scanner_tools
from mcp_cheatengine.tools.assembly import register_assembly_tools
from mcp_cheatengine.tools.lua import register_lua_tools
from mcp_cheatengine.tools.debugger import register_debugger_tools
from mcp_cheatengine.tools.control import register_control_tools
from mcp_cheatengine.tools.table import register_table_tools


def create_server() -> FastMCP:
    """Cria e configura a instância do FastMCP Server com todas as ferramentas de inspeção, controle e depuração."""
    mcp = FastMCP(
        name="Cheat Engine MCP Server",
        instructions="""
Servidor MCP para interação bidirecional com o Cheat Engine.
Permite listar processos, anexar a processos, pausar/retomar execução, alocar e liberar memória, alterar velocidade (speedhack),
ler e escrever memória, resolver cadeias de ponteiros, fazer AOB scans, desensamblar instruções, gerenciar a Address List (Cheat Table),
dump/load seguro de memória, executar scripts Auto Assemble e scripts Lua no Cheat Engine.
"""
    )

    register_process_tools(mcp)
    register_memory_tools(mcp)
    register_scanner_tools(mcp)
    register_assembly_tools(mcp)
    register_lua_tools(mcp)
    register_debugger_tools(mcp)
    register_control_tools(mcp)
    register_table_tools(mcp)

    return mcp


def main():
    server = create_server()
    server.run(transport="stdio")


if __name__ == "__main__":
    main()
