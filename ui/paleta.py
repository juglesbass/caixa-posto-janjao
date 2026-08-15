"""Gerenciamento de cores, temas e paletas de cores refinadas para o Caixa Posto Janjão."""

import os
from types import SimpleNamespace
import flet as ft

# ─────────────────────────────────────────────────────────────────────────────
# CORES E CONSTANTES DE DESIGN SYSTEM
# ─────────────────────────────────────────────────────────────────────────────

# Cor Principal / Destaques
C_ACCENT       = "#2563eb"  # Azul Cobalto Elétrico
C_ACCENT_DARK  = "#1d4ed8"  # Azul Cobalto Profundo
C_ACCENT_LIGHT = "#38bdf8"  # Sky Blue / Ciano Claro
C_LIME         = "#84cc16"  # Verde Lima

# Cores Semânticas por Tipo de Pagamento
C_GREEN   = "#10b981"  # Verde Esmeralda (Dinheiro)
C_BLUE    = "#06b6d4"  # Ciano / Azul Elétrico (Pix)
C_PURPLE  = "#8b5cf6"  # Violeta / Roxo (Cartões / Vouchers)
C_ORANGE  = "#f97316"  # Laranja Intenso (Master Débito)
C_BROWN   = "#b45309"  # Âmbar Profundo / Depósito Global
C_TEAL    = "#14b8a6"  # Verde Petróleo (Sodexo / Fitcard)
C_RED     = "#ef4444"  # Vermelho Coral (Despesas / Master Crédito)
C_INDIGO  = "#6366f1"  # Índigo / Visa Crédito
C_INDIGO2 = "#818cf8"  # Azul Índigo Suave / Visa Débito
C_AMBER   = "#f59e0b"  # Âmbar / Elo Crédito / Requisição
C_AMBER2  = "#fbbf24"  # Dourado Suave / Elo Débito

# Dimensões e Raios de Curvatura (Design System)
RADIUS_XL = 24
RADIUS    = 18
RADIUS_MD = 14
RADIUS_SM = 10
RADIUS_XS = 6

# Filtro de entrada para valores monetários
FILTRO_VALOR_MONETARIO = ft.InputFilter(
    allow=True,
    regex_string=r"^[\d.,]*$",
    replacement_string="",
)

# Mapeamento de cores vibrantes por tipo de pagamento
CORES_POR_TIPO = {
    "Dinheiro":              C_GREEN,
    "Pix":                   C_BLUE,
    "Requisição":            C_AMBER,
    "Sodexo":                C_TEAL,
    "Depósito Global":       C_BROWN,
    "Despesas":              C_RED,
    "Sangria":               C_ORANGE,
    "Suprimento":            C_GREEN,
    "Fitcard":               C_TEAL,
    "Excard":                C_INDIGO,
    "Amex":                  C_BLUE,
    "Eucard":                C_PURPLE,
    "Avancard":              C_INDIGO2,
    "Master Crédito":        C_RED,
    "Master Débito":         C_ORANGE,
    "Visa Crédito":          C_INDIGO,
    "Visa Débito":           C_INDIGO2,
    "Elo Crédito":           C_AMBER,
    "Elo Débito":            C_AMBER2,
    "Alelo Multibenefícios":  C_PURPLE,
}

# Mapeamento de ícones modernos por tipo
ICONES_POR_TIPO = {
    "Dinheiro":              ft.Icons.PAYMENTS_ROUNDED,
    "Pix":                   ft.Icons.PIX_ROUNDED,
    "Requisição":            ft.Icons.RECEIPT_LONG_ROUNDED,
    "Sodexo":                ft.Icons.LUNCH_DINING_ROUNDED,
    "Depósito Global":       ft.Icons.ACCOUNT_BALANCE_ROUNDED,
    "Despesas":              ft.Icons.MONEY_OFF_ROUNDED,
    "Sangria":               ft.Icons.CALL_MADE_ROUNDED,
    "Suprimento":            ft.Icons.CALL_RECEIVED_ROUNDED,
    "Fitcard":               ft.Icons.DIRECTIONS_CAR_ROUNDED,
    "Excard":                ft.Icons.CREDIT_CARD_ROUNDED,
    "Amex":                  ft.Icons.CONTACTLESS_ROUNDED,
    "Eucard":                ft.Icons.CARD_MEMBERSHIP_ROUNDED,
    "Avancard":              ft.Icons.CREDIT_SCORE_ROUNDED,
    "Master Crédito":        ft.Icons.CREDIT_CARD_ROUNDED,
    "Master Débito":         ft.Icons.CREDIT_CARD_ROUNDED,
    "Visa Crédito":          ft.Icons.CREDIT_CARD_ROUNDED,
    "Visa Débito":           ft.Icons.CREDIT_CARD_ROUNDED,
    "Elo Crédito":           ft.Icons.CREDIT_CARD_ROUNDED,
    "Elo Débito":            ft.Icons.CREDIT_CARD_ROUNDED,
    "Alelo Multibenefícios":  ft.Icons.LOCAL_GROCERY_STORE_ROUNDED,
}


def _app_mobile() -> bool:
    """Verifica se está rodando em mobile nativo."""
    return os.environ.get("FLET_PLATFORM", "") in ("ios", "android")


def criar_paleta(escuro: bool) -> SimpleNamespace:
    """
    Cria uma paleta de cores moderna e refinada baseada no tema ativo (Dark Obsidian / Clean iOS).
    """
    if escuro:
        return SimpleNamespace(
            bg="#08090f",
            surface="#111420",
            surface_subtle="#181d2e",
            surface_elevated="#20273d",
            border=ft.Colors.with_opacity(0.10, ft.Colors.WHITE),
            border_strong=ft.Colors.with_opacity(0.35, "#38bdf8"),
            text_pri="#f8fafc",
            text_sec="#94a3b8",
            text_ter="#64748b",
            sheet_bg="#0d101a",
            card_gradient_start="#141826",
            card_gradient_end="#0e111c",
            hero_bg_start="#11182c",
            hero_bg_end="#0c0e18",
            hud_bg="#0f1322",
        )
    return SimpleNamespace(
        bg="#f4f6fb",
        surface="#ffffff",
        surface_subtle="#f1f5f9",
        surface_elevated="#e2e8f0",
        border=ft.Colors.with_opacity(0.08, ft.Colors.BLACK),
        border_strong=ft.Colors.with_opacity(0.25, "#2563eb"),
        text_pri="#0f172a",
        text_sec="#475569",
        text_ter="#94a3b8",
        sheet_bg="#ffffff",
        card_gradient_start="#ffffff",
        card_gradient_end="#f8fafc",
        hero_bg_start="#eff6ff",
        hero_bg_end="#ffffff",
        hud_bg="#ffffff",
    )


def borda_all(largura: float, cor: str) -> ft.Border:
    """Cria uma borda uniforme em todos os lados."""
    return ft.Border(
        left=ft.BorderSide(largura, cor),
        right=ft.BorderSide(largura, cor),
        top=ft.BorderSide(largura, cor),
        bottom=ft.BorderSide(largura, cor),
    )


# Cores específicas de Máquinas
C_REDE        = "#ef4444"  # Vermelho Rede
C_CIELO       = "#0284c7"  # Azul Cielo
C_REDE_TEXT   = "#dc2626"
C_CIELO_TEXT  = "#0369a1"


def cor_tipo(tipo: str) -> str:
    """Retorna a cor associada a um tipo de pagamento."""
    if not tipo:
        return C_ACCENT
    if tipo.startswith("Rede "):
        bandeira = tipo[5:]
        return CORES_POR_TIPO.get(bandeira, C_REDE)
    if tipo.startswith("Cielo "):
        bandeira = tipo[6:]
        return CORES_POR_TIPO.get(bandeira, C_CIELO)
    return CORES_POR_TIPO.get(tipo, C_ACCENT)


def icone_tipo(tipo: str):
    """Retorna o ícone associado a um tipo de pagamento."""
    if not tipo:
        return ft.Icons.CREDIT_CARD_ROUNDED
    limpo = tipo
    if tipo.startswith("Rede "):
        limpo = tipo[5:]
    elif tipo.startswith("Cielo "):
        limpo = tipo[6:]
    return ICONES_POR_TIPO.get(limpo, ft.Icons.CREDIT_CARD_ROUNDED)


def glass_container(paleta, content, padding=16, radius=RADIUS_MD, border_color=None, bgcolor=None):
    """Cria um container com acabamento refinado."""
    b_color = border_color if border_color is not None else paleta.border
    bg_color = bgcolor if bgcolor is not None else paleta.surface
        
    return ft.Container(
        content=content,
        bgcolor=bg_color,
        border_radius=radius,
        border=borda_all(1, b_color),
        padding=padding,
    )
