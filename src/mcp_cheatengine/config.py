import os

class Config:
    """Configurações globais para o servidor MCP Cheat Engine."""
    CE_HOST: str = os.getenv("CE_HOST", "127.0.0.1")
    CE_PORT: int = int(os.getenv("CE_PORT", "52737"))
    DEFAULT_TIMEOUT: float = float(os.getenv("CE_TIMEOUT", "5.0"))
    SCAN_TIMEOUT: float = float(os.getenv("CE_SCAN_TIMEOUT", "15.0"))
