"""Configurações centralizadas da aplicação Caixa."""

import os
from dataclasses import dataclass


@dataclass
class Config:
    """Classe de configuração com variáveis de ambiente."""
    
    # Server
    PORT: int = int(os.environ.get("PORT", 5000))
    HOST: str = os.environ.get("HOST", "0.0.0.0")
    
    # Banco de dados
    DB_PATH: str = os.environ.get("CAIXA_DB_PATH", "meu_caixa.db")
    
    # Backup
    BACKUP_DIR: str = os.environ.get("CAIXA_BACKUP_DIR", "backups/")
    
    # Segurança
    PIN: str = os.environ.get("CAIXA_PIN", "").strip()
    
    # UI
    TEMA_PADRAO: str = os.environ.get("CAIXA_TEMA", "dark")
    
    # Plataforma
    PLATAFORMA: str = os.environ.get("FLET_PLATFORM", "")
    
    @property
    def pin_configurado(self) -> bool:
        """Verifica se PIN está configurado."""
        return bool(self.PIN)
    
    @property
    def eh_mobile(self) -> bool:
        """Verifica se está rodando em mobile."""
        return self.PLATAFORMA in ("ios", "android")


# Instância global de configuração
config = Config()
