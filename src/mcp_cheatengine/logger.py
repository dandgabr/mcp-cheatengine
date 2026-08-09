import sys
import logging
from mcp_cheatengine.config import Config

# Configuração do Logger unificado do Cheat Engine MCP
logger = logging.getLogger("mcp_cheatengine")

if not logger.handlers:
    handler = logging.StreamHandler(sys.stderr)
    formatter = logging.Formatter(
        "[MCP DEBUG %(asctime)s][%(filename)s:%(lineno)d] %(message)s",
        datefmt="%H:%M:%S"
    )
    handler.setFormatter(formatter)
    logger.addHandler(handler)

if Config.DEBUG_LOGS:
    logger.setLevel(logging.DEBUG)
else:
    logger.setLevel(logging.WARNING)


def log_debug(msg: str, *args, **kwargs):
    if Config.DEBUG_LOGS:
        logger.debug(msg, *args, **kwargs)


def log_info(msg: str, *args, **kwargs):
    logger.info(msg, *args, **kwargs)


def log_warning(msg: str, *args, **kwargs):
    logger.warning(msg, *args, **kwargs)


def log_error(msg: str, *args, **kwargs):
    logger.error(msg, *args, **kwargs)
