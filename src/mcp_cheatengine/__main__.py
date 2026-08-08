import sys
import os

# Adiciona o diretório src ao sys.path se necessário
src_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
if src_dir not in sys.path:
    sys.path.insert(0, src_dir)

from mcp_cheatengine.server import main

if __name__ == "__main__":
    main()
