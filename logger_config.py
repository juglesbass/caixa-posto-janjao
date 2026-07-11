"""Configuração de logging centralizado para auditoria e debug."""

import logging
import os
from datetime import datetime
import db


def setup_logger(name: str = "caixa") -> logging.Logger:
    """
    Configura e retorna logger com handlers para arquivo e console.
    
    Args:
        name: Nome do logger
        
    Returns:
        Logger configurado
    """
    logger = logging.getLogger(name)
    
    # Evita handlers duplicados
    if logger.handlers:
        return logger
    
    logger.setLevel(logging.DEBUG)
    
    # Caminho do arquivo de log
    log_dir = os.path.join(db.caminho_backups(), "logs")
    os.makedirs(log_dir, exist_ok=True)
    
    timestamp = datetime.now().strftime("%Y%m%d")
    log_file = os.path.join(log_dir, f"caixa_{timestamp}.log")
    
    # Formato do log
    formatter = logging.Formatter(
        fmt="%(asctime)s - %(levelname)s - [%(funcName)s:%(lineno)d] - %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    
    # Handler para arquivo
    try:
        file_handler = logging.FileHandler(log_file, encoding="utf-8")
        file_handler.setLevel(logging.DEBUG)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
    except (OSError, IOError) as e:
        print(f"Aviso: Não foi possível criar arquivo de log: {e}")
    
    # Handler para console (apenas warnings e acima)
    console_handler = logging.StreamHandler()
    console_handler.setLevel(logging.WARNING)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    return logger


# Logger global
logger = setup_logger()
