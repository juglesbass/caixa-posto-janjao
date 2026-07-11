"""Gerenciamento de cores, temas e paletas de cores."""

import os
from types import SimpleNamespace
import flet as ft


# ─────────────────────────────────────────────────────────────────────────────
# CORES E CONSTANTES
# ─────────────────────────────────────────────────────────────────────────────

# Acentos (funcionam em ambos os temas)
C_GREEN   = "#34d399"
C_BLUE    = "#60a5fa"
C_PURPLE  = "#a78bfa"
C_ORANGE  = "#fb923c"
C_BROWN   = "#d4a27a"
C_TEAL    = "#2dd4bf"
C_RED     = "#f87171"
C_INDIGO  = "#818cf8"
C_INDIGO2 = "#a5b4fc"
C_AMBER   = "#fbbf24"
C_AMBER2  = "#fde68a"

# Dimensões
RADIUS    = 18
RADIUS_SM = 12

# Filtro de entrada para valores monetários
FILTRO_VALOR_MONETARIO = ft.InputFilter(
    allow=True,
    regex_string=r"^[\d.,]*$",
    replacement_string="",
)

# Mapeamento de cores por tipo de pagamento
CORES_POR_TIPO = {
    "Dinheiro":             C_GREEN,
    "Pix":                  C_BLUE,
    "Requisição":           C_PURPLE,
    "Sodexo":               C_TEAL,
    "Depósito Global":      C_BROWN,
    "Despesas":             C_RED,
    "Master Crédito":       C_RED,
    "Master Débito":        C_ORANGE,
    "Visa Crédito":         C_INDIGO,
    "Visa Débito":          C_INDIGO2,
    "Elo Crédito":          C_AMBER,
    "Elo Débito":           C_AMBER2,
    "Alelo Multibenefícios": C_PURPLE,
}

# Mapeamento de ícones por tipo
ICONES_POR_TIPO = {
    "Dinheiro":        ft.Icons.MONEY,
    "Pix":             ft.Icons.PIX,
    "Requisição":      ft.Icons.RECEIPT_LONG,
    "Sodexo":          ft.Icons.LUNCH_DINING,
    "Depósito Global": ft.Icons.ACCOUNT_BALANCE,
    "Despesas":        ft.Icons.MONEY_OFF,
}


def _app_mobile() -> bool:
    """Verifica se está rodando em mobile."""
    return os.environ.get("FLET_PLATFORM", "") in ("ios", "android")


def criar_paleta(escuro: bool) -> SimpleNamespace:
    """
    Cria uma paleta de cores baseada no tema.
    
    Args:
        escuro: True para tema escuro, False para claro
        
    Returns:
        SimpleNamespace com cores da paleta
    """
    if escuro:
        return SimpleNamespace(
            bg="#0a0a0f",
            surface=ft.Colors.with_opacity(0.06, ft.Colors.WHITE),
            border=ft.Colors.with_opacity(0.11, ft.Colors.WHITE),
            border_strong=ft.Colors.with_opacity(0.35, ft.Colors.WHITE),
            text_pri="#e2e8f0", 
            text_sec=ft.Colors.with_opacity(0.80, "#e2e8f0"),
            text_ter=ft.Colors.with_opacity(0.65, "#e2e8f0"),
            sheet_bg=ft.Colors.with_opacity(0.97, "#1c1c1e"),
        )
    return SimpleNamespace(
        bg="#f2f2f7",
        surface=ft.Colors.WHITE,
        border=ft.Colors.with_opacity(0.10, ft.Colors.BLACK),
        border_strong=ft.Colors.with_opacity(0.20, ft.Colors.BLACK),
        text_pri="#1c1c1e",
        text_sec=ft.Colors.with_opacity(0.72, "#1c1c1e"),
        text_ter=ft.Colors.with_opacity(0.50, "#1c1c1e"),
        sheet_bg=ft.Colors.WHITE,
    )


def borda_all(largura: float, cor: str) -> ft.Border:
    """
    Cria uma borda em todos os lados.
    
    Args:
        largura: Largura da borda em pixels
        cor: Cor da borda
        
    Returns:
        Objeto Border do Flet
    """
    return ft.Border(
        left=ft.BorderSide(largura, cor),
        right=ft.BorderSide(largura, cor),
        top=ft.BorderSide(largura, cor),
        bottom=ft.BorderSide(largura, cor),
    )


def cor_tipo(tipo: str) -> str:
    """Retorna a cor para um tipo de pagamento."""
    return CORES_POR_TIPO.get(tipo, C_ORANGE)


def icone_tipo(tipo: str):
    """Retorna o ícone para um tipo de pagamento."""
    return ICONES_POR_TIPO.get(tipo, ft.Icons.CREDIT_CARD)


def glass_container(paleta, content, padding=16, radius=RADIUS_SM, border_color=None, bgcolor=None):
    """
    Cria um container com efeito glass (blur).
    
    Args:
        paleta: Paleta de cores
        content: Conteúdo do container
        padding: Preenchimento interno
        radius: Raio da borda
        border_color: Cor da borda
        bgcolor: Cor de fundo
        
    Returns:
        Container com efeito glass
    """
    if border_color is None:
        border_color = paleta.border
    if bgcolor is None:
        bgcolor = paleta.surface
        
    return ft.Container(
        content=content,
        bgcolor=bgcolor,
        border_radius=radius,
        border=borda_all(1, border_color),
        padding=padding,
        blur=ft.Blur(10, 10, ft.BlurTileMode.MIRROR),
    )
