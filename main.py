import os
import sys

try:
    import certifi
    os.environ["SSL_CERT_FILE"] = certifi.where()
except ImportError:
    pass

import json
import base64
import urllib.parse
import subprocess
from types import SimpleNamespace
import flet as ft
import db
import drive_service

def _app_mobile() -> bool:
    """Verifica se o aplicativo está rodando nativamente no iOS ou Android."""
    return os.environ.get("FLET_PLATFORM", "") in ("ios", "android")

def criar_paleta(escuro: bool) -> SimpleNamespace:
    if escuro:
        return SimpleNamespace(
            bg="#0b0f19",
            surface="#131b2e",
            surface_subtle="#1a243b",
            border=ft.Colors.with_opacity(0.12, ft.Colors.WHITE),
            border_strong=ft.Colors.with_opacity(0.28, "#38bdf8"),
            text_pri="#f8fafc",
            text_sec="#94a3b8",
            text_ter="#64748b",
            sheet_bg="#0f172a",
            card_gradient_start="#161f36",
            card_gradient_end="#0f172a",
            hero_bg_start="#172554",
            hero_bg_end="#0f172a",
        )
    return SimpleNamespace(
        bg="#f4f6fb",
        surface="#ffffff",
        surface_subtle="#f1f5f9",
        border=ft.Colors.with_opacity(0.08, ft.Colors.BLACK),
        border_strong=ft.Colors.with_opacity(0.20, "#2563eb"),
        text_pri="#0f172a",
        text_sec="#475569",
        text_ter="#94a3b8",
        sheet_bg="#ffffff",
        card_gradient_start="#ffffff",
        card_gradient_end="#f8fafc",
        hero_bg_start="#eff6ff",
        hero_bg_end="#ffffff",
    )

# ── Cor principal (Azul Cobalto & Destaques) ───────────────────────────────
C_ACCENT       = "#2563eb"
C_ACCENT_DARK  = "#1d4ed8"
C_ACCENT_LIGHT = "#38bdf8"
C_LIME         = "#84cc16"

# ── Acentos por tipo de pagamento ───────────────────────────────────────────
C_GREEN   = "#10b981"
C_BLUE    = "#06b6d4"
C_PURPLE  = "#8b5cf6"
C_ORANGE  = "#f97316"
C_BROWN   = "#b45309"
C_TEAL    = "#14b8a6"
C_RED     = "#ef4444"
C_INDIGO  = "#6366f1"
C_INDIGO2 = "#818cf8"
C_AMBER   = "#f59e0b"
C_AMBER2  = "#fbbf24"

RADIUS_XL = 24
RADIUS    = 20
RADIUS_MD = 14
RADIUS_SM = 12
RADIUS_XS = 6

def _saudacao_hora() -> str:
    from datetime import datetime
    h = datetime.now().hour
    if h < 12: return "Bom dia"
    if h < 18: return "Boa tarde"
    return "Boa noite"

FILTRO_VALOR_MONETARIO = ft.InputFilter(
    allow=True,
    regex_string=r"^[\d.,]*$",
    replacement_string="",
)

def borda_all(largura, cor) -> ft.Border:
    return ft.Border(
        left=ft.BorderSide(largura, cor),
        right=ft.BorderSide(largura, cor),
        top=ft.BorderSide(largura, cor),
        bottom=ft.BorderSide(largura, cor),
    )

def _plataforma_mobile(page: ft.Page) -> bool:
    if os.environ.get("FLET_PLATFORM", "") in ("ios", "android"):
        return True
    plat = getattr(page, "platform", None)
    if plat is not None and hasattr(plat, "is_mobile"):
        return plat.is_mobile()
    return False

def _plataforma_ios(page: ft.Page) -> bool:
    if os.environ.get("FLET_PLATFORM", "") == "ios":
        return True
    return getattr(page, "platform", None) == ft.PagePlatform.IOS

def main(page: ft.Page):
    mobile = _plataforma_mobile(page)
    ios = _plataforma_ios(page)
    adaptive_ui = mobile or ios

    def _criar_bottom_sheet(conteudo):
        return ft.BottomSheet(content=conteudo, dismissible=True, show_drag_handle=True, scrollable=True, fullscreen=True)

    page.title = "Caixa - Posto Janjão"
    if adaptive_ui:
        page.adaptive = True
    page.fonts = {"Inter": "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap"}
    page.theme = ft.Theme(
        color_scheme_seed=C_ACCENT,
        use_material3=True,
        font_family="Inter",
    )
    page.dark_theme = ft.Theme(
        color_scheme_seed=C_ACCENT_LIGHT,
        use_material3=True,
        font_family="Inter",
    )

    tema_inicial = ft.ThemeMode.DARK
    try:
        if page.client_storage.get("caixa_tema") == "light":
            tema_inicial = ft.ThemeMode.LIGHT
    except Exception:
        pass
    page.theme_mode = tema_inicial

    def tema_escuro() -> bool:
        return page.theme_mode == ft.ThemeMode.DARK

    pal = criar_paleta(tema_escuro())
    page.bgcolor = pal.bg
    page.vertical_alignment = ft.MainAxisAlignment.START
    page.scroll = None
    page.horizontal_alignment = ft.CrossAxisAlignment.CENTER
    page.padding = (
        ft.Padding(left=16, right=16, top=8, bottom=0 if mobile else 16)
        if mobile
        else ft.Padding(left=20, right=20, top=54, bottom=20)
    )

    if mobile:
        async def fixar_retrato():
            try:
                await page.set_allowed_device_orientations([ft.DeviceOrientation.PORTRAIT_UP])
            except Exception:
                pass
        page.run_task(fixar_retrato)

    def _registrar_servico(ctrl):
        try:
            if hasattr(page, "services"):
                if ctrl not in page.services:
                    page.services.append(ctrl)
        except Exception:
            pass

    haptic_feedback = None
    if mobile:
        try:
            haptic_feedback = ft.HapticFeedback()
            _registrar_servico(haptic_feedback)
        except Exception:
            haptic_feedback = None

    compartilhar_servico = None
    try:
        compartilhar_servico = ft.Share()
        _registrar_servico(compartilhar_servico)
    except Exception:
        compartilhar_servico = None

    clipboard_service = None
    try:
        clipboard_service = ft.Clipboard()
        _registrar_servico(clipboard_service)
    except Exception:
        clipboard_service = None

    def vibrar(intensidade="light"):
        if haptic_feedback is None:
            return
        async def _vibrar_async():
            try:
                if intensidade in ("selection", "tick"):
                    metodo = getattr(haptic_feedback, "selection_click", None) or getattr(haptic_feedback, "light_impact", None)
                else:
                    metodo = getattr(haptic_feedback, f"{intensidade}_impact", None)
                if metodo:
                    await metodo()
                elif hasattr(haptic_feedback, "light_impact"):
                    await haptic_feedback.light_impact()
            except Exception:
                pass
        page.run_task(_vibrar_async)

    conn = db.conectar()
    db.inicializar_banco(conn)

    try:
        if db._is_pyodide() or getattr(page, "web", False):
            if not db.obter_turno_aberto(conn):
                b64_client = page.client_storage.get("caixa_db_backup")
                if b64_client:
                    import base64
                    with open(db.caminho_banco(), "wb") as f:
                        f.write(base64.b64decode(b64_client))
                    conn = db.conectar()
    except Exception:
        pass

    def sincronizar_armazenamento_navegador():
        try:
            db.salvar_banco_web_sync(conn)
            if db._is_pyodide() or getattr(page, "web", False):
                caminho = db.caminho_banco()
                if os.path.exists(caminho):
                    with open(caminho, "rb") as f:
                        data = f.read()
                    if len(data) > 0:
                        import base64
                        b64 = base64.b64encode(data).decode("utf-8")
                        page.client_storage.set("caixa_db_backup", b64)
        except Exception:
            pass

    turno_atual = None

    rodape_lancar = None
    pin_configurado = os.environ.get("CAIXA_PIN", "").strip()
    autenticado = not pin_configurado
    largura_conteudo = 380

    def garantir_conexao():
        nonlocal conn
        try:
            conn.execute("SELECT 1")
        except Exception:
            try:
                conn.close()
            except Exception:
                pass
            conn = db.conectar()

    def atualizar_largura():
        nonlocal largura_conteudo
        try:
            pw = int(page.width) if page.width is not None else 400
            largura_conteudo = max(340, min(480, pw - 24))
        except Exception:
            largura_conteudo = 380
        aplicar_largura()

    def aplicar_largura():
        w = largura_conteudo
        if turno_atual is not None:
            for ctrl in [
                header, hud_totais_card, banner_alerta_sangria,
                seletor_col, input_valor, input_desc,
                row_calculadora_troco, row_botoes_rapidos,
                btn_lancar, floating_bottom_bar
            ]:
                try:
                    if hasattr(ctrl, "width"):
                        ctrl.width = w
                except Exception:
                    pass
        page.update()

    def abrir_dialogo(dlg):
        # Em versões recentes do Flet (0.21+), page.open suporta empilhar overlays
        # perfeitamente, inclusive no Android.
        if hasattr(page, "open"):
            try:
                page.open(dlg)
                return
            except Exception as erro:
                print(f"[abrir_dialogo] page.open falhou: {erro}")
                
        # Fallback para versões mais antigas
        try:
            page.show_dialog(dlg)
            return
        except Exception as erro:
            print(f"[abrir_dialogo] show_dialog falhou, usando fallback: {erro}")
        try:
            if dlg not in page.overlay:
                page.overlay.append(dlg)
            dlg.open = True
            page.update()
        except Exception as erro:
            print(f"[abrir_dialogo] fallback também falhou: {erro}")

    def _remover_do_overlay(dlg):
        try:
            if dlg in page.overlay:
                page.overlay.remove(dlg)
                page.update()
        except Exception:
            pass

    def _agendar_limpeza_overlay(dlg, atraso=0.4):
        # Em versões antigas do Flet cada diálogo/snackbar criado fica
        # acumulado para sempre em page.overlay (nunca é removido), o que
        # deixa a página cada vez mais pesada ao longo do turno. Aqui damos
        # um tempo pra animação de fechamento tocar e então removemos.
        async def _tarefa():
            import asyncio
            await asyncio.sleep(atraso)
            _remover_do_overlay(dlg)
        page.run_task(_tarefa)

    def fechar_dialogo(dlg):
        if not dlg:
            return
        if hasattr(page, "close"):
            try:
                page.close(dlg)
            except Exception:
                pass
        try:
            dlg.open = False
            page.update()
        except Exception:
            pass
        _agendar_limpeza_overlay(dlg)

    def mostrar_snackbar(mensagem: str, cor=ft.Colors.GREEN_700):
        snack = ft.SnackBar(
            content=ft.Text(mensagem, color=ft.Colors.WHITE),
            bgcolor=cor,
            duration=2500,
        )
        abrir_dialogo(snack)
        _agendar_limpeza_overlay(snack, atraso=3.2)

    def storage_get(chave: str, padrao=None):
        try:
            return page.client_storage.get(chave)
        except Exception:
            return padrao

    def storage_set(chave: str, valor):
        try:
            page.client_storage.set(chave, valor)
        except Exception:
            pass

    def carregar_ultimo_tipo() -> str:
        salvo = storage_get("caixa_ultimo_tipo")
        if salvo in db.TIPOS_DROPDOWN:
            return salvo
        return db.TIPO_DINHEIRO

    def salvar_ultimo_tipo(tipo: str):
        if tipo in db.TIPOS_DROPDOWN:
            storage_set("caixa_ultimo_tipo", tipo)

    CORES = {
        db.TIPO_DINHEIRO:        C_GREEN,
        db.TIPO_PIX:             C_BLUE,
        db.TIPO_REQUISICAO:      C_AMBER,
        db.TIPO_SODEXO:          C_TEAL,
        db.TIPO_DEPOSITO_GLOBAL: C_BROWN,
        db.TIPO_DESPESA:         C_RED,
        "Fitcard":               C_TEAL,
        "Excard":                C_INDIGO,
        "Amex":                  C_BLUE,
        "Eucard":                C_PURPLE,
        "Avancard":              C_INDIGO2,
        "Master Crédito":        C_RED,
        "Master Débito":         C_ORANGE,
        "Visa Crédito":          C_INDIGO,
        "Visa DéBITO":          C_INDIGO2,
        "Visa Débito":           C_INDIGO2,
        "Elo Crédito":           C_AMBER,
        "Elo Débito":            C_AMBER2,
        "Alelo Multibenefícios": C_PURPLE,
    }

    ICONES = {
        db.TIPO_DINHEIRO:        ft.Icons.PAYMENTS_ROUNDED,
        db.TIPO_PIX:             ft.Icons.PIX_ROUNDED,
        db.TIPO_REQUISICAO:      ft.Icons.RECEIPT_LONG_ROUNDED,
        db.TIPO_SODEXO:          ft.Icons.LUNCH_DINING_ROUNDED,
        db.TIPO_DEPOSITO_GLOBAL: ft.Icons.ACCOUNT_BALANCE_ROUNDED,
        db.TIPO_DESPESA:         ft.Icons.MONEY_OFF_ROUNDED,
    }

    def cor_tipo(tipo: str) -> str:
        return CORES.get(tipo, C_ORANGE)

    def icone_tipo(tipo: str):
        return ICONES.get(tipo, ft.Icons.CREDIT_CARD)

    def formatar_moeda(valor: float) -> str:
        return db.formatar_moeda(valor)

    def _blur_vidro():
        # O efeito "vidro fosco" (BackdropFilter) obriga a GPU a reamostrar
        # a camada de trás em TODO frame, mesmo quando atrás só existe uma
        # cor sólida (é o caso aqui, já que os cards ficam empilhados numa
        # coluna simples, sem nada texturizado por baixo) — ou seja, custa
        # caro e quase não muda nada visualmente. Em Android de entrada isso
        # pesa bastante durante a rolagem, então desativamos no mobile e
        # mantemos no desktop/web, onde a GPU sobra.
        return None if mobile else ft.Blur(10, 10, ft.BlurTileMode.MIRROR)

    def _sombra(cor=ft.Colors.BLACK, blur=10, opacidade=0.05, offset_y=2):
        return None if mobile else ft.BoxShadow(
            spread_radius=0, blur_radius=blur,
            color=ft.Colors.with_opacity(opacidade, cor),
            offset=ft.Offset(0, offset_y),
        )

    def _animacao(duracao=150, curva=ft.AnimationCurve.EASE_OUT):
        return None if mobile else ft.Animation(duracao, curva)

    def glass_container(content, padding=16, radius=RADIUS_SM, border_color=None, bgcolor=None):
        border_c = border_color if border_color is not None else pal.border
        bg_c = bgcolor if bgcolor is not None else pal.surface
        return ft.Container(
            content=content,
            bgcolor=bg_c,
            border_radius=radius,
            border=borda_all(1, border_c),
            padding=padding,
            blur=_blur_vidro(),
        )

    # ═══════════════════════════════════════════════════════════════[...]
    # INFORMAÇÕES DO TURNO
    # ═══════════════════════════════════════════════════════[...]
    # ════════════════════════════════════════════════════════════════════════
    # ════════════════════════════════════════════════════════════════════════
    # INFORMAÇÕES DO TURNO & HUD DE TOTAIS (PDV FIRST BENTO HUD)
    # ════════════════════════════════════════════════════════════════════════
    txt_operador_nome = ft.Text("", size=15, weight=ft.FontWeight.BOLD, color=pal.text_pri)
    txt_turno_data = ft.Text("", size=12, color=pal.text_sec)

    badge_turno_pill = ft.Container(
        content=ft.Row(
            spacing=5,
            tight=True,
            controls=[
                ft.Container(width=8, height=8, border_radius=4, bgcolor=C_GREEN),
                ft.Text("Turno #1", size=12, weight=ft.FontWeight.BOLD, color=C_GREEN),
            ]
        ),
        bgcolor=ft.Colors.with_opacity(0.12, C_GREEN),
        border=borda_all(1, ft.Colors.with_opacity(0.30, C_GREEN)),
        border_radius=100,
        padding=ft.Padding(left=10, right=10, top=4, bottom=4),
    )

    txt_total_geral = ft.Text(
        "R$ 0,00",
        size=32,
        weight=ft.FontWeight.BOLD,
        color=pal.text_pri,
    )

    txt_dinheiro = ft.Text("R$ 0,00", size=12, weight=ft.FontWeight.BOLD, color=pal.text_pri)
    txt_pix = ft.Text("R$ 0,00", size=12, weight=ft.FontWeight.BOLD, color=pal.text_pri)
    txt_cartoes = ft.Text("R$ 0,00", size=12, weight=ft.FontWeight.BOLD, color=pal.text_pri)
    txt_requisicao = ft.Text("R$ 0,00", size=12, weight=ft.FontWeight.BOLD, color=pal.text_pri)
    txt_deposito_global = ft.Text("R$ 0,00", size=12, weight=ft.FontWeight.BOLD, color=pal.text_pri)
    txt_despesas = ft.Text("R$ 0,00", size=12, weight=ft.FontWeight.BOLD, color=pal.text_pri)

    def _criar_hud_chip(label: str, cor: str, icone, txt_ctrl, ao_clicar=None):
        c = ft.Container(
            content=ft.Row(
                spacing=6,
                tight=True,
                controls=[
                    ft.Icon(icone, color=cor, size=15),
                    ft.Text(label, size=12, color=pal.text_sec, weight=ft.FontWeight.W_500),
                    txt_ctrl,
                ]
            ),
            bgcolor=ft.Colors.with_opacity(0.08, cor),
            border=borda_all(1, ft.Colors.with_opacity(0.20, cor)),
            border_radius=100,
            padding=ft.Padding(10, 6, 12, 6),
            ink=True,
            on_click=ao_clicar,
        )
        if not mobile and not ios:
            def hover_c(e):
                e.control.scale = 1.04 if e.data == "true" else 1.0
                e.control.update()
            c.scale = ft.Scale(scale=1)
            c.animate_scale = _animacao(150, ft.AnimationCurve.EASE_OUT)
            c.on_hover = hover_c
        return c

    def _clicar_chip_hud(tipo, rotulo):
        try:
            abrir_detalhe_bandeira(tipo, rotulo)
        except Exception as err:
            print(f"[HUD chip] Erro ao abrir detalhe: {err}")

    chip_din = _criar_hud_chip("Dinheiro", C_GREEN, ft.Icons.PAYMENTS_ROUNDED, txt_dinheiro, lambda e: _clicar_chip_hud(db.TIPO_DINHEIRO, "Dinheiro"))
    chip_pix = _criar_hud_chip("Pix", C_BLUE, ft.Icons.PIX_ROUNDED, txt_pix, lambda e: _clicar_chip_hud(db.TIPO_PIX, "Pag Pix"))
    chip_cart = _criar_hud_chip("Cartões", C_PURPLE, ft.Icons.CREDIT_CARD_ROUNDED, txt_cartoes, lambda e: _clicar_chip_hud("Cartões", "Cartões"))
    chip_req = _criar_hud_chip("Requisição", C_AMBER, ft.Icons.RECEIPT_LONG_ROUNDED, txt_requisicao, lambda e: _clicar_chip_hud(db.TIPO_REQUISICAO, "Requisição"))
    chip_dep = _criar_hud_chip("Depósito", C_BROWN, ft.Icons.ACCOUNT_BALANCE_ROUNDED, txt_deposito_global, lambda e: _clicar_chip_hud(db.TIPO_DEPOSITO_GLOBAL, "Depósito Global"))
    chip_desp = _criar_hud_chip("Despesas", C_RED, ft.Icons.MONEY_OFF_ROUNDED, txt_despesas, lambda e: _clicar_chip_hud(db.TIPO_DESPESA, "Despesas"))

    row_hud_chips = ft.Row(
        spacing=6,
        scroll=ft.ScrollMode.AUTO,
        controls=[chip_din, chip_pix, chip_cart, chip_req, chip_dep, chip_desp],
    )

    hud_totais_card = ft.Container(
        width=largura_conteudo,
        border_radius=RADIUS,
        bgcolor=pal.surface,
        border=borda_all(1, ft.Colors.with_opacity(0.18, C_ACCENT)),
        blur=_blur_vidro(),
        shadow=_sombra(C_ACCENT, 16, 0.12, 4),
        padding=ft.Padding(left=18, right=18, top=14, bottom=14),
        content=ft.Column(
            spacing=10,
            controls=[
                ft.Row(
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    controls=[
                        ft.Row(
                            spacing=10,
                            controls=[
                                ft.Container(
                                    content=ft.Icon(ft.Icons.PERSON_ROUNDED, color=ft.Colors.WHITE, size=16),
                                    bgcolor=C_ACCENT,
                                    padding=6,
                                    border_radius=50,
                                ),
                                ft.Column(
                                    spacing=1,
                                    controls=[txt_operador_nome, txt_turno_data],
                                ),
                            ]
                        ),
                        badge_turno_pill,
                    ]
                ),
                ft.Divider(height=1, color=pal.border),
                ft.Row(
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    controls=[
                        ft.Column(
                            spacing=2,
                            controls=[
                                ft.Text("TOTAL GERAL DO TURNO", size=11, weight=ft.FontWeight.BOLD, color=pal.text_sec),
                                txt_total_geral,
                            ]
                        ),
                        ft.Container(
                            content=ft.Icon(ft.Icons.ACCOUNT_BALANCE_WALLET_ROUNDED, color=C_ACCENT_LIGHT, size=26),
                            bgcolor=ft.Colors.with_opacity(0.12, C_ACCENT),
                            border_radius=12,
                            padding=10,
                        ),
                    ]
                ),
                row_hud_chips,
            ],
        ),
    )

    txt_alerta_sangria = ft.Text("", size=12, weight=ft.FontWeight.W_600, color=C_ORANGE, expand=True)
    banner_alerta_sangria = ft.Container(
        content=ft.Row(
            spacing=8,
            vertical_alignment=ft.CrossAxisAlignment.CENTER,
            controls=[
                ft.Icon(ft.Icons.WARNING_AMBER_ROUNDED, color=C_ORANGE, size=18),
                txt_alerta_sangria,
                ft.TextButton("Fazer Sangria", icon=ft.Icons.CALL_MADE_ROUNDED, icon_color=C_ORANGE, on_click=lambda e: abrir_modal_sangria()),
            ]
        ),
        bgcolor=ft.Colors.with_opacity(0.12, C_ORANGE),
        border=borda_all(1, ft.Colors.with_opacity(0.35, C_ORANGE)),
        border_radius=RADIUS_SM,
        padding=ft.Padding(12, 6, 8, 6),
        visible=False,
        width=largura_conteudo,
    )

    def atualizar_painel():
        if turno_atual is None:
            return
        garantir_conexao()
        totais = db.obter_totais(conn, turno_atual.id)
        
        txt_dinheiro.value       = formatar_moeda(totais.dinheiro)
        txt_pix.value            = formatar_moeda(totais.pix)
        txt_cartoes.value       = formatar_moeda(totais.cartoes)
        txt_requisicao.value    = formatar_moeda(totais.requisicao)
        txt_deposito_global.value = formatar_moeda(totais.deposito_global)
        txt_despesas.value        = formatar_moeda(totais.despesas)
        txt_total_geral.value   = formatar_moeda(totais.total_geral)
        
        txt_operador_nome.value = f"{_saudacao_hora()}, {turno_atual.operador}"
        txt_turno_data.value    = f"Aberto em {turno_atual.aberto_em}"
        badge_turno_pill.content.controls[1].value = f"Turno #{turno_atual.numero_do_dia}"
        
        if totais.dinheiro_gaveta >= 1500.0:
            txt_alerta_sangria.value = f"Gaveta com {formatar_moeda(totais.dinheiro_gaveta)} em espécie. Recomendado sangria."
            banner_alerta_sangria.visible = True
        else:
            banner_alerta_sangria.visible = False

        if mobile:
            txt_rodape_resumo.value = f"Total geral · {formatar_moeda(totais.total_geral)}"

    # ════════════════════════════════════════════════════════════════════════
    # GRADE TÁTIL DE FORMAS DE PAGAMENTO (6 CARDS TÁTEIS)
    # ════════════════════════════════════════════════════════════════════════
    def _eh_cartao(t: str) -> bool:
        return t in db.LISTA_CARTOES

    bandeiras_disponiveis = [
        "Pix",
        "Master Débito", "Master Crédito", "Visa Débito", "Visa Crédito",
        "Elo Débito", "Elo Crédito", "Alelo Multibenefícios", "Sodexo",
        "Fitcard", "Excard", "Amex", "Eucard", "Avancard"
    ]

    def criar_seletor_tipo(valor_inicial: str):
        cartao_escolhido = valor_inicial if _eh_cartao(valor_inicial) else "Master Débito"
        estado = {
            "valor": valor_inicial,
            "cartao_atual": cartao_escolhido,
        }
        seletor_col = ft.Column(spacing=8, width=largura_conteudo)
        registro_cards = {}

        def abrir_modal_bandeiras(e=None):
            dlg_bandeiras = None
            sheet_bandeiras = None

            def fechar_band(x=None):
                if dlg_bandeiras: fechar_dialogo(dlg_bandeiras)
                if sheet_bandeiras: fechar_dialogo(sheet_bandeiras)

            def escolher_bandeira(nome_band):
                estado["cartao_atual"] = nome_band
                fechar_band()
                selecionar(nome_band)

            lista_band_controls = []
            for band in bandeiras_disponiveis:
                cor_b = cor_tipo(band)
                ico_b = icone_tipo(band)
                sel_b = (estado["valor"] == band)

                btn_b = ft.Container(
                    content=ft.Row(
                        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                        controls=[
                            ft.Row(
                                spacing=10,
                                controls=[
                                    ft.Container(
                                        content=ft.Icon(ico_b, color=cor_b, size=18),
                                        bgcolor=ft.Colors.with_opacity(0.14, cor_b),
                                        border_radius=8,
                                        padding=6,
                                    ),
                                    ft.Text(band, size=13, weight=ft.FontWeight.W_600 if sel_b else ft.FontWeight.NORMAL, color=pal.text_pri),
                                ]
                            ),
                            ft.Icon(ft.Icons.CHECK_ROUNDED, color=cor_b, size=18) if sel_b else ft.Container(),
                        ]
                    ),
                    bgcolor=ft.Colors.with_opacity(0.12, cor_b) if sel_b else pal.surface,
                    border=borda_all(1.5 if sel_b else 1, cor_b if sel_b else pal.border),
                    border_radius=RADIUS_SM,
                    padding=ft.Padding(12, 10, 12, 10),
                    ink=True,
                    on_click=lambda ev, b=band: escolher_bandeira(b),
                )
                lista_band_controls.append(btn_b)

            conteudo_modal = ft.Column(
                spacing=8,
                scroll=ft.ScrollMode.AUTO,
                controls=lista_band_controls,
            )

            if not mobile:
                dlg_bandeiras = ft.AlertDialog(
                    title=ft.Row([
                        ft.Icon(ft.Icons.CREDIT_CARD_ROUNDED, color=C_PURPLE, size=22),
                        ft.Text("Escolha a Bandeira / Cartão", weight=ft.FontWeight.BOLD, color=pal.text_pri),
                    ], spacing=8),
                    content=ft.Container(content=conteudo_modal, width=min(360, largura_conteudo), height=380),
                    actions=[ft.TextButton("Cancelar", on_click=fechar_band)],
                )
                abrir_dialogo(dlg_bandeiras)
            else:
                painel_b = ft.Container(
                    padding=ft.Padding(20, 12, 20, 30),
                    bgcolor=pal.sheet_bg,
                    content=ft.Column(
                        expand=True,
                        spacing=12,
                        controls=[
                            ft.Container(width=36, height=4, border_radius=2, bgcolor=pal.border_strong, alignment=ft.Alignment(0, 0)),
                            ft.Row([
                                ft.Icon(ft.Icons.CREDIT_CARD_ROUNDED, color=C_PURPLE, size=20),
                                ft.Text("Escolha a Bandeira / Cartão", size=16, weight=ft.FontWeight.BOLD, color=pal.text_pri),
                            ], spacing=8, alignment=ft.MainAxisAlignment.CENTER),
                            ft.Divider(height=1, color=pal.border),
                            ft.Container(content=conteudo_modal, expand=True),
                            ft.TextButton("Cancelar", on_click=fechar_band),
                        ]
                    )
                )
                sheet_bandeiras = _criar_bottom_sheet(painel_b)
                abrir_dialogo(sheet_bandeiras)

        def _montar_card_tatil(id_chave: str, titulo: str, subtitulo: str, icone, cor: str, ao_clicar, is_cartao=False):
            sel = (id_chave == estado["valor"]) or (is_cartao and _eh_cartao(estado["valor"]))
            sub = estado["cartao_atual"] if is_cartao else subtitulo

            ico_cnt = ft.Container(
                content=ft.Icon(icone, color=cor if sel else pal.text_sec, size=22),
                bgcolor=ft.Colors.with_opacity(0.16 if sel else 0.08, cor),
                border_radius=12,
                padding=10,
            )

            txt_tit = ft.Text(titulo, size=14, weight=ft.FontWeight.BOLD, color=pal.text_pri)
            txt_sub = ft.Text(f"{sub} ▾" if is_cartao else sub, size=11, color=cor if sel else pal.text_ter, weight=ft.FontWeight.W_500)

            check_dot = ft.Container(
                width=8, height=8, border_radius=4,
                bgcolor=cor if sel else ft.Colors.TRANSPARENT,
            )

            card = ft.Container(
                content=ft.Row(
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    controls=[
                        ft.Row(
                            spacing=10,
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                            controls=[
                                ico_cnt,
                                ft.Column(
                                    spacing=2,
                                    alignment=ft.MainAxisAlignment.CENTER,
                                    controls=[txt_tit, txt_sub],
                                ),
                            ]
                        ),
                        check_dot,
                    ]
                ),
                bgcolor=ft.Colors.with_opacity(0.14, cor) if sel else pal.surface,
                border=borda_all(1.8 if sel else 1, cor if sel else pal.border),
                border_radius=RADIUS_MD,
                padding=ft.Padding(14, 10, 14, 10),
                expand=True,
                height=66,
                ink=True,
                on_click=ao_clicar,
                scale=ft.Scale(scale=1),
                animate_scale=_animacao(150, ft.AnimationCurve.EASE_OUT),
            )

            if not mobile and not ios:
                def hover_card(e):
                    e.control.scale = 1.03 if e.data == "true" else 1.0
                    e.control.update()
                card.on_hover = hover_card

            registro_cards[id_chave] = (card, ico_cnt, txt_tit, txt_sub, check_dot, cor, is_cartao)
            return card

        def construir():
            registro_cards.clear()
            seletor_col.controls.clear()

            card_din = _montar_card_tatil(db.TIPO_DINHEIRO, "Dinheiro", "Espécie", ft.Icons.PAYMENTS_ROUNDED, C_GREEN, lambda e: selecionar(db.TIPO_DINHEIRO))
            card_pix = _montar_card_tatil(db.TIPO_PIX, "Pag Pix", "Instantâneo", ft.Icons.PIX_ROUNDED, C_BLUE, lambda e: selecionar(db.TIPO_PIX))

            def clique_cartao(e):
                if _eh_cartao(estado["valor"]):
                    abrir_modal_bandeiras()
                else:
                    selecionar(estado["cartao_atual"])

            card_cart = _montar_card_tatil("__cartao__", "Cartões", estado["cartao_atual"], ft.Icons.CREDIT_CARD_ROUNDED, C_PURPLE, clique_cartao, is_cartao=True)
            card_req = _montar_card_tatil(db.TIPO_REQUISICAO, "Requisição", "Faturado", ft.Icons.RECEIPT_LONG_ROUNDED, C_AMBER, lambda e: selecionar(db.TIPO_REQUISICAO))
            card_dep = _montar_card_tatil(db.TIPO_DEPOSITO_GLOBAL, "Depósito", "Bancário", ft.Icons.ACCOUNT_BALANCE_ROUNDED, C_BROWN, lambda e: selecionar(db.TIPO_DEPOSITO_GLOBAL))
            card_desp = _montar_card_tatil(db.TIPO_DESPESA, "Despesas", "Retirada", ft.Icons.MONEY_OFF_ROUNDED, C_RED, lambda e: selecionar(db.TIPO_DESPESA))

            seletor_col.controls.append(ft.Row(spacing=8, controls=[card_din, card_pix]))
            seletor_col.controls.append(ft.Row(spacing=8, controls=[card_cart, card_req]))
            seletor_col.controls.append(ft.Row(spacing=8, controls=[card_dep, card_desp]))

        def selecionar(tipo):
            vibrar("light")
            estado["valor"] = tipo
            if _eh_cartao(tipo):
                estado["cartao_atual"] = tipo
            salvar_ultimo_tipo(tipo)

            # Atualiza estados visuais dos cards
            for k, (card, ico_cnt, txt_tit, txt_sub, check_dot, cor, is_cartao) in registro_cards.items():
                sel = (k == tipo) or (is_cartao and _eh_cartao(tipo))
                card.bgcolor = ft.Colors.with_opacity(0.14, cor) if sel else pal.surface
                card.border = borda_all(1.8 if sel else 1, cor if sel else pal.border)
                ico_cnt.bgcolor = ft.Colors.with_opacity(0.16 if sel else 0.08, cor)
                ico_cnt.content.color = cor if sel else pal.text_sec
                if is_cartao:
                    txt_sub.value = f"{estado['cartao_atual']} ▾"
                txt_sub.color = cor if sel else pal.text_ter
                check_dot.bgcolor = cor if sel else ft.Colors.TRANSPARENT

            atualizar_calculo_troco()
            page.update()

        construir()
        return seletor_col, estado, selecionar, construir

    tipo_inicial = carregar_ultimo_tipo()
    seletor_col, estado_tipo, selecionar_tipo, reconstruir_seletor = criar_seletor_tipo(tipo_inicial)

    # ═══════════════════════════════════════════════════════════════[...]
    # INPUTS
    # ═══════════════════════════════════════════════════════════════[...]
    _keyboard_valor = (
        ft.KeyboardType.DATETIME
        if (ios or mobile or page.platform == ft.PagePlatform.IOS)
        else ft.KeyboardType.NUMBER
    )

    def ao_tocar_fora(e):
        desfocar_campos(input_valor, input_desc, input_recebido)

    def ao_focar_campo(e):
        try:
            area_scroll.scroll_to(offset=240, duration=200)
        except Exception:
            pass

    txt_prefix_valor = ft.Text("R$ ", size=18, weight=ft.FontWeight.BOLD, color=pal.text_pri)
    txt_prefix_recebido = ft.Text("R$ ", size=14, weight=ft.FontWeight.BOLD, color=pal.text_pri)

    input_valor = ft.TextField(
        label="Valor da Venda (Ex: 50.00 ou 50,00)",
        label_style=ft.TextStyle(color=pal.text_sec),
        width=largura_conteudo,
        prefix=txt_prefix_valor,
        text_size=18,
        text_style=ft.TextStyle(weight=ft.FontWeight.BOLD, color=pal.text_pri),
        content_padding=ft.Padding(16, 14, 16, 14),
        border_radius=RADIUS_MD,
        filled=True,
        bgcolor=pal.surface,
        border_color=pal.border,
        focused_border_color=C_ACCENT,
        cursor_color=C_ACCENT,
        keyboard_type=_keyboard_valor,
        adaptive=adaptive_ui,
        autocorrect=False,
        enable_suggestions=False,
        input_filter=FILTRO_VALOR_MONETARIO,
        on_focus=ao_focar_campo,
        on_tap_outside=ao_tocar_fora,
    )

    txt_troco_valor = ft.Text("R$ 0,00", size=14, weight=ft.FontWeight.BOLD, color=C_GREEN)
    badge_troco_calculado = ft.Container(
        content=ft.Row(
            spacing=6,
            tight=True,
            controls=[
                ft.Icon(ft.Icons.SAVINGS_ROUNDED, color=C_GREEN, size=16),
                ft.Text("Troco:", size=13, color=pal.text_sec),
                txt_troco_valor,
            ]
        ),
        bgcolor=ft.Colors.with_opacity(0.12, C_GREEN),
        border=borda_all(1, ft.Colors.with_opacity(0.30, C_GREEN)),
        border_radius=100,
        padding=ft.Padding(12, 6, 12, 6),
        visible=False,
    )

    def atualizar_calculo_troco(e=None):
        if estado_tipo.get("valor") != db.TIPO_DINHEIRO:
            badge_troco_calculado.visible = False
            input_recebido.visible = False
            try:
                page.update()
            except Exception:
                pass
            return
        input_recebido.visible = True
        val_dev = validar_valor_monetario(input_valor.value or "")
        val_rec = validar_valor_monetario(input_recebido.value or "")
        if val_dev > 0 and val_rec >= val_dev:
            troco = round(val_rec - val_dev, 2)
            txt_troco_valor.value = formatar_moeda(troco)
            badge_troco_calculado.visible = True
        else:
            badge_troco_calculado.visible = False
        try:
            page.update()
        except Exception:
            pass

    input_recebido = ft.TextField(
        label="Valor Pago pelo Cliente (Troco)",
        hint_text="Ex: 100,00",
        hint_style=ft.TextStyle(color=pal.text_ter),
        label_style=ft.TextStyle(color=pal.text_sec),
        text_style=ft.TextStyle(color=pal.text_pri),
        width=largura_conteudo,
        prefix=txt_prefix_recebido,
        border_radius=RADIUS_MD,
        content_padding=ft.Padding(16, 12, 16, 12),
        filled=True,
        bgcolor=pal.surface,
        border_color=pal.border,
        focused_border_color=C_ACCENT,
        cursor_color=C_ACCENT,
        keyboard_type=_keyboard_valor,
        adaptive=adaptive_ui,
        autocorrect=False,
        enable_suggestions=False,
        input_filter=FILTRO_VALOR_MONETARIO,
        visible=(tipo_inicial == db.TIPO_DINHEIRO),
        on_change=atualizar_calculo_troco,
        on_focus=ao_focar_campo,
        on_tap_outside=ao_tocar_fora,
    )

    input_valor.on_change = atualizar_calculo_troco

    row_calculadora_troco = ft.Row(
        spacing=8,
        width=largura_conteudo,
        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
        vertical_alignment=ft.CrossAxisAlignment.CENTER,
        controls=[
            ft.Container(content=input_recebido, expand=True),
            badge_troco_calculado,
        ]
    )

    input_desc = ft.TextField(
        label="Descrição / Placa do Veículo (Opcional)",
        label_style=ft.TextStyle(color=pal.text_sec),
        text_style=ft.TextStyle(color=pal.text_pri),
        prefix_icon=ft.Icons.DIRECTIONS_CAR_ROUNDED,
        width=largura_conteudo,
        border_radius=RADIUS_MD,
        content_padding=ft.Padding(16, 14, 16, 14),
        filled=True,
        bgcolor=pal.surface,
        border_color=pal.border,
        focused_border_color=C_ACCENT,
        cursor_color=C_ACCENT,
        adaptive=adaptive_ui,
        on_focus=ao_focar_campo,
        on_tap_outside=ao_tocar_fora,
    )

    _blur_token = 0

    def desfocar_campos(*campos):
        nonlocal _blur_token
        _blur_token += 1
        meu_token = _blur_token
        async def _desfocar():
            import asyncio
            await asyncio.sleep(0.08)
            if _blur_token == meu_token:
                for c in campos:
                    try:
                        if hasattr(c, "unfocus"): c.unfocus()
                    except Exception:
                        pass
                try:
                    page.update()
                except Exception:
                    pass
        page.run_task(_desfocar)

    def set_valor(val, desc=""):
        input_valor.value = val
        if desc:
            input_desc.value = desc
        atualizar_calculo_troco()
        desfocar_campos(input_valor, input_desc, input_recebido)
        page.update()

    def validar_valor(texto: str):
        if not texto or not texto.strip():
            return None
        limpo = texto.strip().replace("R$", "").replace(" ", "")
        if "," in limpo and "." in limpo:
            limpo = limpo.replace(".", "").replace(",", ".")
        elif "," in limpo:
            limpo = limpo.replace(",", ".")
        try:
            valor = float(limpo)
        except ValueError:
            return None
        return round(valor, 2) if valor > 0 else None

    def validar_valor_monetario(texto: str) -> float:
        if not texto or not texto.strip():
            return 0.0
        limpo = texto.strip().replace("R$", "").replace(" ", "")
        if "," in limpo and "." in limpo:
            limpo = limpo.replace(".", "").replace(",", ".")
        elif "," in limpo:
            limpo = limpo.replace(",", ".")
        try:
            valor = float(limpo)
            return round(valor, 2) if valor >= 0 else 0.0
        except ValueError:
            return 0.0

    # ═══════════════════════════════════════════════════════════════
    # BOTÕES RÁPIDOS
    # ═══════════════════════════════════════════════════════════════
    def _pill_btn(label, on_click, is_completou=False):
        cor_borda = ft.Colors.with_opacity(0.40, C_AMBER) if is_completou else pal.border
        cor_texto = C_AMBER if is_completou else pal.text_pri
        cor_bg    = ft.Colors.with_opacity(0.12, C_AMBER) if is_completou else pal.surface
        
        def handle_click(e):
            vibrar("light")
            if on_click:
                on_click(e)

        container = ft.Container(
            content=ft.Text(label, size=13, color=cor_texto, weight=ft.FontWeight.BOLD if is_completou else ft.FontWeight.W_600),
            bgcolor=cor_bg,
            border_radius=100,
            border=borda_all(1, cor_borda),
            padding=ft.Padding(left=16, right=16, top=10, bottom=10),
            scale=ft.Scale(scale=1),
            animate_scale=_animacao(150, ft.AnimationCurve.EASE_OUT),
            on_click=handle_click,
            ink=True,
        )

        if not mobile and not ios:
            def animar_hover(e):
                e.control.scale = 1.05 if e.data == "true" else 1.0
                e.control.update()
            container.on_hover = animar_hover
        return container

    def acao_completou(e):
        selecionar_tipo(db.TIPO_DINHEIRO)
        input_desc.value = "Completou"
        input_valor.value = ""
        input_valor.error_text = None
        desfocar_campos(input_valor, input_desc)
        page.update()

    def montar_botoes_rapidos():
        row_botoes_rapidos.controls = [
            _pill_btn("+ R$ 10", lambda e: set_valor("10.00")),
            _pill_btn("+ R$ 20", lambda e: set_valor("20.00")),
            _pill_btn("+ R$ 50", lambda e: set_valor("50.00")),
            _pill_btn("+ R$ 100", lambda e: set_valor("100.00")),
            _pill_btn("+ R$ 200", lambda e: set_valor("200.00")),
            _pill_btn("✓ Completou", acao_completou, is_completou=True),
        ]

    row_botoes_rapidos = ft.Row(
        wrap=True,
        alignment=ft.MainAxisAlignment.START,
        spacing=6,
        run_spacing=6,
        width=largura_conteudo,
    )
    montar_botoes_rapidos()

    # ═══════════════════════════════════════════════════════════════[...]
    # LISTA HISTÓRICO
    # ═══════════════════════════════════════════════════════════════[...]
    col_historico = ft.Column(spacing=6, width=largura_conteudo)

    def carregar_historico():
        if turno_atual is None: return
        col_historico.controls.clear()
        for row in db.listar_historico(conn, turno_atual.id, limite=5):
            cor   = cor_tipo(row["tipo"])
            icone = icone_tipo(row["tipo"])
            desc_texto = f" — {row['descricao']}" if row["descricao"] else ""

            def confirmar_exclusao(e, rid=row["id"], tipo=row["tipo"], valor=row["valor"]):
                dlg_excluir = ft.AlertDialog(
                    title=ft.Text("Apagar lançamento?"),
                    content=ft.Text(f"Remover {formatar_moeda(valor)} · {tipo}?"),
                )

                def excluir_confirmado(x, lancamento_id=rid):
                    garantir_conexao()
                    if db.deletar_lancamento(conn, lancamento_id, turno_atual.id):
                        fechar_dialogo(dlg_excluir)
                        mostrar_snackbar("Lançamento removido.", ft.Colors.ORANGE_800)
                        vibrar("light")
                        recarregar_listas()
                    else:
                        mostrar_snackbar("Não foi possível apagar.", ft.Colors.RED_800)

                dlg_excluir.actions = [
                    ft.TextButton("Apagar", on_click=excluir_confirmado),
                    ft.TextButton("Cancelar", on_click=lambda x: fechar_dialogo(dlg_excluir)),
                ]
                abrir_dialogo(dlg_excluir)

            def abrir_edicao(
                e,
                rid=row["id"],
                tipo=row["tipo"],
                valor=row["valor"],
                descricao=row["descricao"],
            ):
                seletor_edit, estado_edit, _sel_edit, _rec_edit = criar_seletor_tipo(tipo)
                seletor_edit.width = min(300, largura_conteudo)

                def ao_tocar_fora_edicao(e):
                    desfocar_campos(campo_valor_edit, campo_desc_edit)

                campo_valor_edit = ft.TextField(
                    label="Valor",
                    value=f"{valor:.2f}".replace(".", ","),
                    prefix=ft.Text("R$ "),
                    width=min(300, largura_conteudo),
                    adaptive=adaptive_ui,
                    autocorrect=False,
                    enable_suggestions=False,
                    input_filter=FILTRO_VALOR_MONETARIO,
                    on_tap_outside=ao_tocar_fora_edicao,
                )
                campo_desc_edit = ft.TextField(
                    label="Descrição / Placa (Opcional)",
                    value=descricao or "",
                    width=min(300, largura_conteudo),
                    adaptive=adaptive_ui,
                    on_tap_outside=ao_tocar_fora_edicao,
                )
                dlg_editar = ft.AlertDialog(
                    title=ft.Text("Editar lançamento"),
                    content=ft.Column(
                        [
                            ft.Text("Forma de Pagamento", size=12, color=pal.text_sec),
                            seletor_edit,
                            campo_valor_edit,
                            campo_desc_edit,
                        ],
                        tight=True, spacing=10,
                        scroll=ft.ScrollMode.AUTO, height=420,
                    ),
                )

                def salvar_edicao(x, lancamento_id=rid):
                    novo_valor = validar_valor(campo_valor_edit.value or "")
                    if novo_valor is None:
                        campo_valor_edit.error_text = "Informe um valor maior que zero"
                        page.update()
                        return
                    try:
                        garantir_conexao()
                        ok = db.atualizar_lancamento(
                            conn, lancamento_id, turno_atual.id,
                            estado_edit["valor"], novo_valor, campo_desc_edit.value or "",
                        )
                        if ok:
                            fechar_dialogo(dlg_editar)
                            mostrar_snackbar("Lançamento atualizado.")
                            recarregar_listas()
                        else:
                            mostrar_snackbar("Não foi possível editar.", ft.Colors.RED_800)
                    except Exception:
                        mostrar_snackbar("Erro ao editar. Tente novamente.", ft.Colors.RED_800)

                dlg_editar.actions = [
                    ft.TextButton("Salvar",   on_click=salvar_edicao),
                    ft.TextButton("Cancelar", on_click=lambda x: fechar_dialogo(dlg_editar)),
                ]
                abrir_dialogo(dlg_editar)

            col_historico.controls.append(
                ft.Container(
                    content=ft.Row(
                        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                        vertical_alignment=ft.CrossAxisAlignment.CENTER,
                        controls=[
                            ft.Row(
                                spacing=10,
                                expand=True,
                                controls=[
                                    ft.Container(
                                        content=ft.Icon(icone, color=cor, size=15),
                                        bgcolor=ft.Colors.with_opacity(0.13, cor),
                                        border_radius=50,
                                        padding=7,
                                    ),
                                    ft.Column(
                                        spacing=2,
                                        expand=True,
                                        controls=[
                                            ft.Text(
                                                f"{formatar_moeda(row['valor'])} · {row['tipo']}{desc_texto}",
                                                color=pal.text_pri, size=13, weight=ft.FontWeight.W_600,
                                            ),
                                            ft.Text(row["data"], color=pal.text_ter, size=11),
                                        ],
                                    ),
                                ],
                            ),
                            ft.Row(
                                spacing=0,
                                controls=[
                                    ft.IconButton(
                                        icon=ft.Icons.EDIT_OUTLINED,
                                        icon_color=pal.text_ter,
                                        icon_size=17,
                                        tooltip="Editar",
                                        on_click=abrir_edicao,
                                    ),
                                    ft.IconButton(
                                        icon=ft.Icons.DELETE_OUTLINE,
                                        icon_color=C_RED,
                                        icon_size=17,
                                        tooltip="Apagar",
                                        on_click=confirmar_exclusao,
                                    ),
                                ],
                            ),
                        ],
                    ),
                    bgcolor=pal.surface,
                    border_radius=RADIUS_SM,
                    border=ft.Border(
                        left=ft.BorderSide(3, cor),
                        right=ft.BorderSide(1, ft.Colors.with_opacity(0.08, cor)),
                        top=ft.BorderSide(1, ft.Colors.with_opacity(0.08, cor)),
                        bottom=ft.BorderSide(1, ft.Colors.with_opacity(0.08, cor)),
                    ),
                    blur=_blur_vidro(),
                    padding=ft.Padding(left=12, right=4, top=10, bottom=10),
                )
            )
        # Sem page.update() aqui de propósito, ver recarregar_listas().

    def recarregar_listas():
        if turno_atual is None: return
        garantir_conexao()
        atualizar_painel()
        carregar_historico()
        page.update()

    # ═══════════════════════════════════════════════════════════════[...]
    # DETALHE DE BANDEIRA (lista completa de lançamentos por tipo/bandeira)
    # ═══════════════════════════════════════════════════════════════[...]
    def abrir_detalhe_bandeira(tipo: str, rotulo: str = None, ao_fechar=None):
        if turno_atual is None:
            return

        nome_exibicao = rotulo or tipo
        cor = cor_tipo(tipo)
        icone = icone_tipo(tipo)

        txt_total_detalhe = ft.Text("", size=13, color=pal.text_sec)
        lista_detalhe = ft.Column(spacing=6)

        dlg_detalhe = None
        sheet_detalhe = None

        def fechar_detalhe(x=None):
            try:
                if dlg_detalhe: page.close(dlg_detalhe)
                if sheet_detalhe: page.close(sheet_detalhe)
            except Exception:
                pass
            if dlg_detalhe:
                dlg_detalhe.open = False
            if sheet_detalhe:
                sheet_detalhe.open = False
            page.update()
            if dlg_detalhe:
                _agendar_limpeza_overlay(dlg_detalhe)
            if sheet_detalhe:
                _agendar_limpeza_overlay(sheet_detalhe)

            if ao_fechar is not None:
                # Mesmo padrão usado pra abrir o detalhe: espera a animação
                # de fechamento terminar antes de abrir a próxima tela
                # flutuante, em vez de empilhar uma em cima da outra.
                async def _reabrir_depois():
                    import asyncio
                    await asyncio.sleep(0.3)
                    ao_fechar()

                page.run_task(_reabrir_depois)

        def carregar_lista_detalhe():
            garantir_conexao()
            registros = db.listar_historico_por_tipo(conn, turno_atual.id, tipo, limite=500)
            lista_detalhe.controls.clear()

            total = sum(row["valor"] for row in registros)
            txt_total_detalhe.value = f"Total: {formatar_moeda(total)} · {len(registros)} lançamento(s)"

            if not registros:
                lista_detalhe.controls.append(
                    ft.Text("Nenhum lançamento para esta bandeira.", size=13, color=pal.text_ter)
                )

            for row in registros:
                desc_texto = f" — {row['descricao']}" if row["descricao"] else ""

                def confirmar_exclusao_detalhe(e, rid=row["id"], valor=row["valor"]):
                    dlg_excluir = ft.AlertDialog(
                        title=ft.Text("Apagar lançamento?"),
                        content=ft.Text(f"Remover {formatar_moeda(valor)} · {nome_exibicao}?"),
                    )

                    def excluir_confirmado(x, lancamento_id=rid):
                        garantir_conexao()
                        if db.deletar_lancamento(conn, lancamento_id, turno_atual.id):
                            fechar_dialogo(dlg_excluir)
                            mostrar_snackbar("Lançamento removido.", ft.Colors.ORANGE_800)
                            vibrar("light")
                            recarregar_listas()
                            carregar_lista_detalhe()
                            page.update()
                        else:
                            mostrar_snackbar("Não foi possível apagar.", ft.Colors.RED_800)

                    dlg_excluir.actions = [
                        ft.TextButton("Apagar", on_click=excluir_confirmado),
                        ft.TextButton("Cancelar", on_click=lambda x: fechar_dialogo(dlg_excluir)),
                    ]
                    abrir_dialogo(dlg_excluir)

                def abrir_edicao_detalhe(e, rid=row["id"], valor=row["valor"], descricao=row["descricao"]):
                    seletor_edit, estado_edit, _sel_edit, _rec_edit = criar_seletor_tipo(tipo)
                    seletor_edit.width = min(300, largura_conteudo)

                    def ao_tocar_fora_edicao(e):
                        desfocar_campos(campo_valor_edit, campo_desc_edit)

                    campo_valor_edit = ft.TextField(
                        label="Valor",
                        value=f"{valor:.2f}".replace(".", ","),
                        prefix=ft.Text("R$ "),
                        width=min(300, largura_conteudo),
                        adaptive=adaptive_ui,
                        autocorrect=False,
                        enable_suggestions=False,
                        input_filter=FILTRO_VALOR_MONETARIO,
                        on_tap_outside=ao_tocar_fora_edicao,
                    )
                    campo_desc_edit = ft.TextField(
                        label="Descrição / Placa (Opcional)",
                        value=descricao or "",
                        width=min(300, largura_conteudo),
                        adaptive=adaptive_ui,
                        on_tap_outside=ao_tocar_fora_edicao,
                    )
                    dlg_editar = ft.AlertDialog(
                        title=ft.Text("Editar lançamento"),
                        content=ft.Column(
                            [
                                ft.Text("Forma de Pagamento", size=12, color=pal.text_sec),
                                seletor_edit,
                                campo_valor_edit,
                                campo_desc_edit,
                            ],
                            tight=True, spacing=10,
                            scroll=ft.ScrollMode.AUTO, height=420,
                        ),
                    )

                    def salvar_edicao(x, lancamento_id=rid):
                        novo_valor = validar_valor(campo_valor_edit.value or "")
                        if novo_valor is None:
                            campo_valor_edit.error_text = "Informe um valor maior que zero"
                            page.update()
                            return
                        try:
                            garantir_conexao()
                            ok = db.atualizar_lancamento(
                                conn, lancamento_id, turno_atual.id,
                                estado_edit["valor"], novo_valor, campo_desc_edit.value or "",
                            )
                            if ok:
                                fechar_dialogo(dlg_editar)
                                mostrar_snackbar("Lançamento atualizado.")
                                recarregar_listas()
                                carregar_lista_detalhe()
                                page.update()
                            else:
                                mostrar_snackbar("Não foi possível editar.", ft.Colors.RED_800)
                        except Exception:
                            mostrar_snackbar("Erro ao editar. Tente novamente.", ft.Colors.RED_800)

                    dlg_editar.actions = [
                        ft.TextButton("Salvar", on_click=salvar_edicao),
                        ft.TextButton("Cancelar", on_click=lambda x: fechar_dialogo(dlg_editar)),
                    ]
                    abrir_dialogo(dlg_editar)

                lista_detalhe.controls.append(
                    ft.Container(
                        content=ft.Row(
                            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                            controls=[
                                ft.Row(
                                    spacing=10,
                                    expand=True,
                                    controls=[
                                        ft.Container(
                                            content=ft.Icon(icone, color=cor, size=15),
                                            bgcolor=ft.Colors.with_opacity(0.13, cor),
                                            border_radius=8,
                                            padding=6,
                                        ),
                                        ft.Column(
                                            spacing=2,
                                            expand=True,
                                            controls=[
                                                ft.Text(
                                                    f"{formatar_moeda(row['valor'])}{desc_texto}",
                                                    color=cor, size=13, weight=ft.FontWeight.W_600,
                                                ),
                                                ft.Text(row["data"], color=pal.text_ter, size=11),
                                            ],
                                        ),
                                    ],
                                ),
                                ft.Row(
                                    spacing=0,
                                    controls=[
                                        ft.IconButton(
                                            icon=ft.Icons.EDIT_OUTLINED,
                                            icon_color=C_BLUE,
                                            icon_size=17,
                                            tooltip="Editar",
                                            on_click=abrir_edicao_detalhe,
                                        ),
                                        ft.IconButton(
                                            icon=ft.Icons.DELETE_OUTLINE,
                                            icon_color=C_RED,
                                            icon_size=17,
                                            tooltip="Apagar",
                                            on_click=confirmar_exclusao_detalhe,
                                        ),
                                    ],
                                ),
                            ],
                        ),
                        bgcolor=pal.surface,
                        border_radius=RADIUS_SM,
                        border=borda_all(1, ft.Colors.with_opacity(0.14, cor)),
                        blur=_blur_vidro(),
                        padding=ft.Padding(left=12, right=4, top=10, bottom=10),
                    )
                )
            # Sem page.update() aqui: na primeira chamada o diálogo ainda nem
            # foi aberto (abrir_dialogo cuida disso); nas reaberturas depois de
            # editar/apagar, quem chama dispara o update uma única vez.

        carregar_lista_detalhe()

        largura_detalhe = min(360, largura_conteudo)
        btn_fechar_detalhe = ft.TextButton("Fechar", on_click=fechar_detalhe)

        if not mobile:
            dlg_detalhe = ft.AlertDialog(
                title=ft.Row([ft.Icon(icone, color=cor, size=20), ft.Text(nome_exibicao)], spacing=8),
                content=ft.Container(
                    content=ft.Column(
                        tight=True, spacing=10,
                        scroll=ft.ScrollMode.AUTO,
                        controls=[
                            txt_total_detalhe,
                            ft.Divider(height=1, color=pal.border),
                            lista_detalhe,
                        ],
                    ),
                    width=largura_detalhe,
                    height=440,
                ),
                actions=[btn_fechar_detalhe],
            )
            abrir_dialogo(dlg_detalhe)
        else:
            painel_detalhe = ft.Container(
                expand=True,
                padding=ft.Padding(20, 12, 20, 30),
                bgcolor=pal.sheet_bg,
                content=ft.Column(
                    expand=True,
                    spacing=14,
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                    controls=[
                        ft.Container(
                            width=36, height=4, border_radius=2,
                            bgcolor=pal.border_strong,
                        ),
                        ft.Row(
                            [ft.Icon(icone, color=cor, size=20),
                             ft.Text(nome_exibicao, size=17, weight=ft.FontWeight.BOLD, color=pal.text_pri)],
                            spacing=8,
                        ),
                        txt_total_detalhe,
                        ft.Divider(height=1, color=pal.border),
                        ft.Container(
                            content=ft.Column(
                                controls=[lista_detalhe],
                                scroll=ft.ScrollMode.AUTO,
                                expand=True,
                            ),
                            expand=True,
                        ),
                        btn_fechar_detalhe,
                    ],
                ),
            )
            sheet_detalhe = _criar_bottom_sheet(painel_detalhe)
            abrir_dialogo(sheet_detalhe)

    # ══════════════════════════════════════════════════════════════[...]
    # BOTÃO LANÇAR
    # ══════════════════════════════════════════════════════════════[...]
    btn_lancar = ft.Container(
        content=ft.Row(
            alignment=ft.MainAxisAlignment.CENTER,
            spacing=10,
            controls=[
                ft.Icon(ft.Icons.CHECK_CIRCLE_ROUNDED, color=ft.Colors.WHITE, size=24),
                ft.Text("LANÇAR VENDA", color=ft.Colors.WHITE, size=17,
                        weight=ft.FontWeight.BOLD),
            ],
        ),
        bgcolor=None,
        gradient=ft.LinearGradient(
            begin=ft.Alignment(-1, 0),
            end=ft.Alignment(1, 0),
            colors=[C_ACCENT, C_ACCENT_DARK],
        ),
        border_radius=RADIUS_MD,
        height=58,
        width=largura_conteudo,
        alignment=ft.Alignment(0, 0),
        shadow=_sombra(C_ACCENT, 20, 0.35, 4),
        scale=ft.Scale(scale=1),
        animate_scale=_animacao(150, ft.AnimationCurve.EASE_OUT),
        ink=True,
        on_click=lambda e: acao_lancar(e),
    )

    if not mobile and not ios:
        def animar_hover_lancar(e):
            if btn_lancar.opacity != 0.5:
                e.control.scale = 1.02 if e.data == "true" else 1.0
                e.control.update()
        btn_lancar.on_hover = animar_hover_lancar

    def acao_lancar(e=None):
        if btn_lancar.opacity == 0.5 or turno_atual is None:
            return
        valor_float = validar_valor(input_valor.value or "")
        if valor_float is None:
            input_valor.error_text = "Informe um valor maior que zero"
            page.update()
            return

        btn_lancar.opacity = 0.5
        page.update()

        try:
            garantir_conexao()
            db.inserir_lancamento(
                conn, turno_atual.id,
                estado_tipo["valor"], valor_float, input_desc.value or "",
            )
            input_valor.value = ""
            input_desc.value  = ""
            input_valor.error_text = None
            mostrar_snackbar(f"{formatar_moeda(valor_float)} lançado em {estado_tipo['valor']}")
            vibrar("light")
            salvar_ultimo_tipo(estado_tipo["valor"])
            atualizar_painel()
            carregar_historico()
            desfocar_campos(input_valor, input_desc)
            sincronizar_armazenamento_navegador()
        except Exception:
            mostrar_snackbar("Erro ao lançar. Tente novamente.", ft.Colors.RED_800)
        finally:
            btn_lancar.opacity = 1.0
            btn_lancar.scale = 1.0
            page.update()

    btn_lancar.on_click = acao_lancar
    input_valor.on_submit = acao_lancar
    input_desc.on_submit  = acao_lancar

    # ════════════════════════════════════════════════════════════════════════
    # RESUMO / FECHAR CAIXA (Estilo Kalo Bento Grid)
    # ════════════════════════════════════════════════════════════════════════
    def montar_conteudo_resumo(totais, detalhe_cartoes, ao_abrir_detalhe=None, ao_registrar_inputs=None):
        ao_abrir_detalhe = ao_abrir_detalhe or abrir_detalhe_bandeira

        # ── Header do Turno no Resumo ──
        header_turno_resumo = ft.Container(
            bgcolor=pal.surface,
            border_radius=RADIUS_SM,
            border=borda_all(1, pal.border),
            padding=ft.Padding(14, 10, 14, 10),
            content=ft.Row(
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
                controls=[
                    ft.Row(
                        spacing=10,
                        controls=[
                            ft.Container(
                                content=ft.Icon(ft.Icons.PERSON_ROUNDED, color=ft.Colors.WHITE, size=18),
                                bgcolor=C_ACCENT,
                                padding=8,
                                border_radius=50,
                            ),
                            ft.Column(
                                spacing=1,
                                controls=[
                                    ft.Text(turno_atual.operador if turno_atual else "Operador", size=14, weight=ft.FontWeight.BOLD, color=pal.text_pri),
                                    ft.Text(f"Aberto em: {turno_atual.aberto_em if turno_atual else ''}", size=11, color=pal.text_sec),
                                ]
                            )
                        ]
                    ),
                    ft.Container(
                        content=ft.Row(
                            spacing=4,
                            tight=True,
                            controls=[
                                ft.Icon(ft.Icons.LOCAL_FIRE_DEPARTMENT_ROUNDED, size=14, color=C_AMBER),
                                ft.Text(f"Turno #{turno_atual.numero_do_dia if turno_atual else '1'}", size=12, weight=ft.FontWeight.BOLD, color=C_AMBER),
                            ]
                        ),
                        bgcolor=ft.Colors.with_opacity(0.12, C_AMBER),
                        border=borda_all(1, ft.Colors.with_opacity(0.25, C_AMBER)),
                        border_radius=100,
                        padding=ft.Padding(8, 4, 8, 4),
                    )
                ]
            )
        )

        # ── Detalhe de Cartões & Vouchers ──
        linhas_bandeiras = []
        for bandeira, (valor, qtd) in detalhe_cartoes.items():
            cor   = cor_tipo(bandeira)
            icone = icone_tipo(bandeira)
            cor_valor = pal.text_pri if valor > 0 else pal.text_ter
            peso_valor = ft.FontWeight.BOLD if valor > 0 else ft.FontWeight.NORMAL

            row_controls = [
                ft.Container(
                    content=ft.Icon(icone, color=cor, size=14),
                    bgcolor=ft.Colors.with_opacity(0.12, cor),
                    border_radius=6,
                    padding=4,
                ),
                ft.Text(
                    bandeira, size=13, width=130, color=pal.text_sec,
                    max_lines=1, overflow=ft.TextOverflow.ELLIPSIS, weight=ft.FontWeight.W_500,
                ),
                ft.Text(f"({qtd} un)", size=12, width=55, color=pal.text_ter),
                ft.Text(formatar_moeda(valor), size=14, color=cor_valor, weight=peso_valor, expand=True, text_align=ft.TextAlign.RIGHT),
                ft.Icon(ft.Icons.CHEVRON_RIGHT_ROUNDED, color=pal.text_ter, size=16),
            ]

            linhas_bandeiras.append(
                ft.Container(
                    content=ft.Row(row_controls, spacing=8),
                    border_radius=8,
                    padding=ft.Padding(left=6, right=6, top=6, bottom=6),
                    ink=True,
                    tooltip="Toque para ver e editar os lançamentos desta bandeira",
                    on_click=lambda e, b=bandeira: ao_abrir_detalhe(b),
                )
            )

        caixa_cartoes = ft.Container(
            bgcolor=pal.surface,
            border_radius=RADIUS_SM,
            border=borda_all(1, pal.border),
            padding=12,
            content=ft.Column(
                spacing=8,
                controls=[
                    ft.Column(linhas_bandeiras, spacing=4),
                ]
            )
        )

        # ── Linhas de Totais Individuais ──
        def _linha_total_resumo(icone, label, valor, cor_icone, info_extra="", on_click=None):
            return ft.Container(
                bgcolor=pal.surface,
                border_radius=10,
                border=borda_all(1, pal.border),
                padding=ft.Padding(12, 10, 12, 10),
                ink=bool(on_click),
                on_click=on_click,
                content=ft.Row(
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    controls=[
                        ft.Row(
                            spacing=10,
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                            controls=[
                                ft.Container(
                                    content=ft.Icon(icone, color=cor_icone, size=16),
                                    bgcolor=ft.Colors.with_opacity(0.12, cor_icone),
                                    border_radius=8,
                                    padding=6,
                                ),
                                ft.Text(label, size=14, color=pal.text_sec, weight=ft.FontWeight.W_500),
                                ft.Text(info_extra, size=12, color=pal.text_ter) if info_extra else ft.Container(),
                            ]
                        ),
                        ft.Row(
                            spacing=4,
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                            controls=[
                                ft.Text(formatar_moeda(valor), size=15, weight=ft.FontWeight.BOLD, color=pal.text_pri),
                                ft.Icon(ft.Icons.CHEVRON_RIGHT_ROUNDED, color=pal.text_ter, size=16) if on_click else ft.Container(),
                            ]
                        ),
                    ]
                )
            )

        # ── Inputs de Vendas Sistema e Observação ──
        v_sis_ini = turno_atual.vendas_sistema if (turno_atual and turno_atual.vendas_sistema) else 0.0
        obs_ini = turno_atual.observacao if (turno_atual and turno_atual.observacao) else ""

        input_vendas_sistema = ft.TextField(
            label="TOTAL DE VENDAS SISTEMA (PDV)",
            value=f"{v_sis_ini:.2f}".replace(".", ",") if v_sis_ini > 0 else "",
            keyboard_type=_keyboard_valor,
            input_filter=FILTRO_VALOR_MONETARIO,
            hint_text="0,00",
            filled=True,
            bgcolor=pal.surface,
            border_radius=RADIUS_SM,
            border_color=pal.border,
            focused_border_color=C_ACCENT,
            prefix=ft.Text("R$ ", size=16, weight=ft.FontWeight.BOLD, color=pal.text_pri),
            text_size=16,
            text_style=ft.TextStyle(weight=ft.FontWeight.BOLD, color=pal.text_pri),
        )

        input_observacao = ft.TextField(
            label="OBSERVAÇÕES / JUSTIFICATIVA",
            value=obs_ini,
            multiline=True,
            min_lines=2,
            max_lines=3,
            hint_text="Descreva justificativas de sobras/faltas ou observações do turno...",
            filled=True,
            bgcolor=pal.surface,
            border_radius=RADIUS_SM,
            border_color=pal.border,
            focused_border_color=C_ACCENT,
            text_size=13,
        )

        if ao_registrar_inputs:
            ao_registrar_inputs(input_vendas_sistema, input_observacao)

        def _calc_dif():
            val = validar_valor_monetario(input_vendas_sistema.value or "0")
            return totais.total_geral - val

        txt_dif_valor = ft.Text(
            formatar_moeda(_calc_dif()),
            weight=ft.FontWeight.BOLD,
            size=18,
        )
        txt_dif_label = ft.Text(
            "DIFERENÇA:",
            weight=ft.FontWeight.BOLD,
            size=13,
        )

        container_diferenca = ft.Container(
            border_radius=RADIUS_SM,
            padding=ft.Padding(14, 12, 14, 12),
            content=ft.Row([
                txt_dif_label,
                ft.Container(expand=True),
                txt_dif_valor,
            ]),
        )

        def _atualizar_estilo_dif():
            dif = _calc_dif()
            if abs(dif) < 0.01:
                container_diferenca.bgcolor = ft.Colors.with_opacity(0.12, C_GREEN)
                container_diferenca.border = borda_all(1, C_GREEN)
                txt_dif_valor.color = C_GREEN
                txt_dif_label.color = C_GREEN
                txt_dif_label.value = "✅ CAIXA 100% BATIDO (SEM DIFERENÇA)"
            elif dif > 0:
                container_diferenca.bgcolor = ft.Colors.with_opacity(0.12, C_AMBER)
                container_diferenca.border = borda_all(1, C_AMBER)
                txt_dif_valor.color = C_AMBER
                txt_dif_label.color = C_AMBER
                txt_dif_label.value = "▲ SOBRA NA PISTA:"
            else:
                container_diferenca.bgcolor = ft.Colors.with_opacity(0.12, C_RED)
                container_diferenca.border = borda_all(1, C_RED)
                txt_dif_valor.color = C_RED
                txt_dif_label.color = C_RED
                txt_dif_label.value = "▼ FALTA NA PISTA:"
            txt_dif_valor.value = formatar_moeda(dif)

        _atualizar_estilo_dif()

        def _on_auditoria_change(e=None):
            v_val = validar_valor_monetario(input_vendas_sistema.value or "0")
            _atualizar_estilo_dif()
            page.update()
            if turno_atual:
                turno_atual.vendas_sistema = v_val
                turno_atual.observacao = input_observacao.value or ""
                try:
                    db.salvar_auditoria_turno(conn, turno_atual.id, v_val, input_observacao.value or "")
                except Exception:
                    pass

        input_vendas_sistema.on_change = _on_auditoria_change
        input_vendas_sistema.on_blur = _on_auditoria_change
        input_observacao.on_change = _on_auditoria_change
        input_observacao.on_blur = _on_auditoria_change

        linhas_totais_resumo = [
            header_turno_resumo,
            ft.Divider(height=1, color=pal.border),
            ft.Text("DETALHE DE CARTÕES E VOUCHERS", size=11, color=pal.text_sec, weight=ft.FontWeight.BOLD),
            caixa_cartoes,
            _linha_total_resumo(ft.Icons.CREDIT_CARD_ROUNDED, "Total de Cartões", totais.cartoes, C_ORANGE, f"({totais.qtd_cartoes} un)"),
            ft.Divider(height=1, color=pal.border),
            _linha_total_resumo(ft.Icons.PAYMENTS_ROUNDED, "Sobra de Dinheiro", totais.fisico, C_GREEN),
        ]

        if totais.fundo_caixa > 0:
            linhas_totais_resumo.append(_linha_total_resumo(ft.Icons.SAVINGS_ROUNDED, "Fundo de Caixa (Inicial)", totais.fundo_caixa, C_GREEN))
        if totais.sangrias > 0:
            linhas_totais_resumo.append(_linha_total_resumo(ft.Icons.CALL_MADE_ROUNDED, "Sangrias p/ Cofre", totais.sangrias, C_ORANGE, f"({totais.qtd_sangrias} un)"))
        if totais.fundo_caixa > 0 or totais.sangrias > 0:
            linhas_totais_resumo.append(_linha_total_resumo(ft.Icons.ACCOUNT_BALANCE_WALLET_ROUNDED, "Dinheiro na Gaveta (Atual)", totais.dinheiro_gaveta, C_GREEN))

        linhas_totais_resumo.extend([
            _linha_total_resumo(ft.Icons.QR_CODE_ROUNDED, "Pag Pix", totais.pix, C_BLUE, f"({totais.qtd_pix} un)", on_click=lambda e: ao_abrir_detalhe(db.TIPO_PIX, "Pag Pix")),
            _linha_total_resumo(ft.Icons.RECEIPT_LONG_ROUNDED, "Requisição", totais.requisicao, C_PURPLE),
            _linha_total_resumo(ft.Icons.ACCOUNT_BALANCE_ROUNDED, "Depósito Global", totais.deposito_global, C_BROWN),
            _linha_total_resumo(ft.Icons.MONEY_OFF_ROUNDED, "Despesas", totais.despesas, C_RED),
            ft.Divider(height=4, color=pal.border),
            ft.Text("CONCILIAÇÃO DE VENDAS DO CAIXA", size=11, color=pal.text_sec, weight=ft.FontWeight.BOLD),
            ft.Container(
                bgcolor=ft.Colors.with_opacity(0.12, C_ACCENT),
                border=borda_all(1.2, C_ACCENT),
                border_radius=RADIUS_SM,
                padding=ft.Padding(14, 12, 14, 12),
                content=ft.Row([
                    ft.Row(
                        spacing=8,
                        controls=[
                            ft.Icon(ft.Icons.POINT_OF_SALE_ROUNDED, color=C_ACCENT_LIGHT, size=20),
                            ft.Text("TOTAL DE VENDAS PISTA:", weight=ft.FontWeight.BOLD, size=13, color=pal.text_pri),
                        ]
                    ),
                    ft.Container(expand=True),
                    ft.Text(formatar_moeda(totais.total_geral), weight=ft.FontWeight.BOLD, size=18, color=C_ACCENT_LIGHT if tema_escuro() else C_ACCENT),
                ])
            ),
            input_vendas_sistema,
            container_diferenca,
            input_observacao,
            ft.Container(height=10),
        ])

        return ft.Column(
            tight=True, spacing=10,
            scroll=ft.ScrollMode.AUTO, expand=True,
            controls=linhas_totais_resumo,
        )

    def acao_fechar_caixa(e=None):
        if turno_atual is None: return
        fechar_bottom_sheet()
        garantir_conexao()
        totais        = db.obter_totais(conn, turno_atual.id)
        detalhe_cart  = db.obter_detalhe_cartoes(conn, turno_atual.id)
        resumo        = db.montar_resumo_texto(totais, turno_atual, detalhe_cart)

        dlg_resumo = None
        sheet_resumo = None
        _em_andamento = {"valor": False}

        ref_vendas_sis = {"control": None}
        ref_obs = {"control": None}

        def registrar_inputs(inp_vendas, inp_obs):
            ref_vendas_sis["control"] = inp_vendas
            ref_obs["control"] = inp_obs

        def fechar_resumo(x=None):
            if turno_atual and ref_vendas_sis["control"] and ref_obs["control"]:
                v_val = validar_valor_monetario(ref_vendas_sis["control"].value or "0")
                obs_val = ref_obs["control"].value or ""
                turno_atual.vendas_sistema = v_val
                turno_atual.observacao = obs_val
                try:
                    db.salvar_auditoria_turno(conn, turno_atual.id, v_val, obs_val)
                except Exception:
                    pass
            try:
                if dlg_resumo:
                    fechar_dialogo(dlg_resumo)
                if sheet_resumo:
                    fechar_dialogo(sheet_resumo)
            except Exception:
                pass

        def abrir_whatsapp(e=None):
            nonlocal resumo
            vibrar("light")

            async def _abrir_wa_async():
                try:
                    texto_enc = urllib.parse.quote(resumo)

                    # 1. No mobile / iOS, o Share Sheet nativo abre com o WhatsApp no topo
                    # e também tenta invocar o aplicativo do WhatsApp diretamente
                    if mobile or ios or getattr(page, "platform", None) == ft.PagePlatform.IOS:
                        try:
                            page.launch_url(f"whatsapp://send?text={texto_enc}")
                        except Exception:
                            pass

                        if compartilhar_servico:
                            try:
                                await compartilhar_servico.share_text(resumo, title="Resumo do Turno - Posto Janjão")
                                mostrar_snackbar("Selecione o WhatsApp no menu de envio 🚀")
                                return
                            except Exception:
                                pass

                    # 2. Desktop / Web / Fallback
                    url_wa = f"https://wa.me/?text={texto_enc}"
                    try:
                        page.launch_url(url_wa)
                        mostrar_snackbar("Abrindo no WhatsApp... 🚀")
                    except Exception:
                        if compartilhar_servico:
                            await compartilhar_servico.share_text(resumo, title="Resumo do Turno - Posto Janjão")
                            mostrar_snackbar("Selecione o WhatsApp no menu de envio.")
                        else:
                            mostrar_snackbar("Não foi possível abrir o WhatsApp automaticamente.", ft.Colors.RED_800)
                except Exception as ex:
                    mostrar_snackbar(f"Erro ao abrir WhatsApp: {ex}", ft.Colors.RED_800)

            page.run_task(_abrir_wa_async)

        def copiar_resumo(e=None):
            nonlocal resumo
            vibrar("light")
            async def _copiar_async():
                copiado = False
                try:
                    if clipboard_service:
                        await clipboard_service.set(resumo)
                        copiado = True
                    elif hasattr(page, "clipboard") and page.clipboard:
                        await page.clipboard.set(resumo)
                        copiado = True
                except Exception as err:
                    print(f"Erro no clipboard: {err}")

                if copiado:
                    mostrar_snackbar("Resumo copiado com sucesso! Pronto para colar.")
                else:
                    try:
                        if compartilhar_servico:
                            await compartilhar_servico.share_text(resumo, title="Resumo do Turno")
                            mostrar_snackbar("Texto enviado para compartilhamento.")
                        else:
                            mostrar_snackbar("Não foi possível copiar o texto automaticamente.", ft.Colors.RED_800)
                    except Exception as ex:
                        mostrar_snackbar(f"Erro ao compartilhar resumo: {ex}", ft.Colors.RED_800)

            page.run_task(_copiar_async)

        def abrir_detalhe_a_partir_do_resumo(tipo: str, rotulo: str = None):
            fechar_resumo()
            abrir_detalhe_bandeira(tipo, rotulo, ao_fechar=acao_fechar_caixa)

        def _abrir_pdf_local(caminho_pdf, nome_pdf):
            try:
                if sys.platform == "win32":
                    os.startfile(caminho_pdf)
                elif sys.platform == "darwin":
                    subprocess.Popen(["open", caminho_pdf])
                else:
                    subprocess.Popen(["xdg-open", caminho_pdf])
                mostrar_snackbar(f"PDF aberto: {nome_pdf}")
            except Exception:
                mostrar_snackbar(f"PDF salvo em: {caminho_pdf}")

        def compartilhar_pdf(e=None):
            if turno_atual is None:
                mostrar_snackbar("Nenhum turno aberto.", ft.Colors.RED_800)
                return
            vibrar("light")
            try:
                caminho_pdf = db.exportar_turno_pdf(conn, turno_atual.id)
                nome_pdf = os.path.basename(caminho_pdf)

                with open(caminho_pdf, "rb") as f:
                    pdf_bytes = f.read()

                if compartilhar_servico:
                    async def _share_pdf_async():
                        try:
                            share_file = ft.ShareFile(
                                path=caminho_pdf,
                                data=pdf_bytes,
                                mime_type="application/pdf",
                                name=nome_pdf
                            )
                            await compartilhar_servico.share_files(
                                [share_file],
                                title=f"Resumo do Turno - {nome_pdf}",
                                text="Resumo do Turno Posto Janjão",
                                download_fallback_enabled=True
                            )
                            mostrar_snackbar(f"PDF pronto: {nome_pdf} 📥")
                        except Exception as ex:
                            print(f"Erro no share_files: {ex}")
                            _abrir_pdf_local(caminho_pdf, nome_pdf)

                    page.run_task(_share_pdf_async)
                else:
                    _abrir_pdf_local(caminho_pdf, nome_pdf)

            except Exception as ex:
                mostrar_snackbar(f"Erro ao gerar PDF: {ex}", ft.Colors.RED_800)

        def encerrar_turno(e):
            if _em_andamento["valor"]: return
            _em_andamento["valor"] = True

            dlg_confirmar = ft.AlertDialog(
                title=ft.Row(
                    spacing=8,
                    controls=[
                        ft.Icon(ft.Icons.LOCK_ROUNDED, color=C_RED, size=20),
                        ft.Text("Encerrar Turno?", weight=ft.FontWeight.BOLD),
                    ]
                ),
                content=ft.Text(
                    f"Confirma o fechamento do Turno #{turno_atual.numero_do_dia} "
                    f"de {turno_atual.operador}?\n\n"
                    f"Total Geral: {formatar_moeda(totais.total_geral)}"
                ),
            )

            def confirmar_fechamento(x):
                nonlocal turno_atual
                fechar_dialogo(dlg_confirmar)
                try:
                    garantir_conexao()
                    v_val = 0.0
                    obs_val = ""
                    if ref_vendas_sis["control"]:
                        v_val = validar_valor_monetario(ref_vendas_sis["control"].value or "0")
                    if ref_obs["control"]:
                        obs_val = ref_obs["control"].value or ""

                    turno_id_encerrado = turno_atual.id
                    operador_encerrado = turno_atual.operador

                    # Gera o PDF antes de fechar para garantir os dados
                    caminho_pdf = db.exportar_turno_pdf(conn, turno_id_encerrado)

                    # Fecha o turno no banco de dados
                    db.fechar_turno(conn, turno_id_encerrado, totais, vendas_sistema=v_val, observacao=obs_val)
                    turno_atual = None
                    fechar_resumo()

                    async def _finalizar_encerramento():
                        import asyncio
                        await asyncio.sleep(0.35)
                        mostrar_snackbar("Turno encerrado com sucesso. Caixa Fechado.")
                        vibrar("medium")
                        montar_interface()

                        # Envio automático do PDF para o Google Drive em background
                        def _drive_task():
                            ok, msg = drive_service.enviar_pdf_drive_bg(
                                caminho_pdf, turno_id_encerrado, operador_encerrado
                            )
                            if ok and "sucesso" in msg.lower():
                                mostrar_snackbar(msg, ft.Colors.GREEN_700)

                        async def _run_drive_bg():
                            await asyncio.to_thread(_drive_task)

                        page.run_task(_run_drive_bg)

                    page.run_task(_finalizar_encerramento)
                except Exception as ex:
                    _em_andamento["valor"] = False
                    mostrar_snackbar(f"Erro: {ex}", ft.Colors.RED_800)

            dlg_confirmar.actions = [
                ft.TextButton("Sim, Encerrar", on_click=confirmar_fechamento),
                ft.TextButton("Cancelar", on_click=lambda x: (fechar_dialogo(dlg_confirmar), _em_andamento.update({"valor": False}))),
            ]
            abrir_dialogo(dlg_confirmar)

        conteudo_resumo = montar_conteudo_resumo(totais, detalhe_cart, abrir_detalhe_a_partir_do_resumo, ao_registrar_inputs=registrar_inputs)

        def _action_pill_btn(icone, label, on_click, cor_bg=None, cor_texto=None, is_primary=False):
            bg = C_ACCENT if is_primary else (cor_bg or pal.surface)
            txt_cor = ft.Colors.WHITE if is_primary else (cor_texto or pal.text_pri)
            borda = borda_all(1, C_ACCENT_LIGHT if is_primary else pal.border)
            
            btn = ft.Container(
                content=ft.Row(
                    tight=True,
                    spacing=6,
                    alignment=ft.MainAxisAlignment.CENTER,
                    controls=[
                        ft.Icon(icone, size=15, color=txt_cor),
                        ft.Text(label, size=12, weight=ft.FontWeight.BOLD, color=txt_cor),
                    ]
                ),
                bgcolor=bg,
                border=borda,
                border_radius=100,
                padding=ft.Padding(14, 10, 14, 10),
                ink=True,
                on_click=on_click,
            )
            if not mobile and not ios:
                btn.scale = ft.Scale(scale=1)
                btn.animate_scale = _animacao(150, ft.AnimationCurve.EASE_OUT)
                def hover_action(e):
                    e.control.scale = 1.04 if e.data == "true" else 1.0
                    e.control.update()
                btn.on_hover = hover_action
            return btn

        btn_whatsapp = _action_pill_btn(ft.Icons.CHAT_ROUNDED, "WhatsApp", abrir_whatsapp, cor_bg="#15803d", cor_texto=ft.Colors.WHITE)
        btn_copiar = _action_pill_btn(ft.Icons.CONTENT_COPY_ROUNDED, "Copiar Texto", copiar_resumo)
        btn_compartilhar_pdf = _action_pill_btn(ft.Icons.PICTURE_AS_PDF_ROUNDED, "Baixar PDF", compartilhar_pdf)
        btn_excel_resumo = _action_pill_btn(ft.Icons.TABLE_CHART_ROUNDED, "Excel (CSV)", acao_exportar_excel, cor_bg="#047857", cor_texto=ft.Colors.WHITE)
        btn_encerrar = _action_pill_btn(ft.Icons.LOCK_ROUNDED, "Encerrar Turno", encerrar_turno, is_primary=True)
        btn_fechar = _action_pill_btn(ft.Icons.CLOSE_ROUNDED, "Fechar", fechar_resumo)

        acoes_resumo_row = ft.Row(
            alignment=ft.MainAxisAlignment.CENTER,
            wrap=True,
            spacing=8,
            run_spacing=8,
            controls=[btn_whatsapp, btn_copiar, btn_compartilhar_pdf, btn_excel_resumo, btn_encerrar, btn_fechar],
        )

        largura_resumo = min(480, largura_conteudo)

        if not mobile:
            dlg_resumo = ft.AlertDialog(
                title=ft.Row(
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                    controls=[
                        ft.Row(
                            spacing=8,
                            controls=[
                                ft.Icon(ft.Icons.ASSESSMENT_ROUNDED, color=C_ACCENT, size=22),
                                ft.Text("Resumo do Turno", weight=ft.FontWeight.BOLD, color=pal.text_pri),
                            ]
                        ),
                        ft.IconButton(ft.Icons.CLOSE, icon_color=pal.text_sec, icon_size=18, on_click=fechar_resumo),
                    ]
                ),
                content=ft.Container(
                    content=conteudo_resumo,
                    width=largura_resumo,
                    height=600,
                ),
                actions=[acoes_resumo_row],
            )
            abrir_dialogo(dlg_resumo)
        else:
            painel_resumo = ft.Container(
                expand=True,
                padding=ft.Padding(20, 12, 20, 30),
                bgcolor=pal.sheet_bg,
                content=ft.Column(
                    expand=True,
                    spacing=12,
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                    controls=[
                        ft.Container(
                            width=36, height=4, border_radius=2,
                            bgcolor=pal.border_strong,
                        ),
                        ft.Row(
                            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                            controls=[
                                ft.Row(
                                    spacing=8,
                                    controls=[
                                        ft.Icon(ft.Icons.ASSESSMENT_ROUNDED, color=C_ACCENT, size=22),
                                        ft.Text("Resumo do Turno", size=18, weight=ft.FontWeight.BOLD, color=pal.text_pri),
                                    ]
                                ),
                                ft.IconButton(ft.Icons.CLOSE, icon_color=pal.text_sec, icon_size=20, on_click=fechar_resumo),
                            ]
                        ),
                        ft.Divider(height=1, color=pal.border),
                        ft.Container(
                            content=conteudo_resumo,
                            expand=True,
                        ),
                        ft.Divider(height=1, color=pal.border),
                        acoes_resumo_row,
                    ],
                ),
            )
            sheet_resumo = _criar_bottom_sheet(painel_resumo)
            abrir_dialogo(sheet_resumo)

    def acao_historico_turnos(e=None):
        fechar_bottom_sheet()
        garantir_conexao()
        turnos = db.listar_turnos_fechados(conn)
        if not turnos:
            mostrar_snackbar("Nenhum turno encerrado ainda.", ft.Colors.BLUE_GREY_700)
            return
        itens = [
            ft.ListTile(
                title=ft.Text(f"Turno #{db.obter_numero_turno_do_dia(conn, t['id'])} ({t['aberto_em'][:10]}) · {t['operador']} · {formatar_moeda(t['total_geral'])}"),
                subtitle=ft.Text(f"{t['aberto_em']} → {t['fechado_em']}"),
                trailing=ft.IconButton(
                    ft.Icons.RESTORE_PAGE_ROUNDED,
                    icon_color=C_ORANGE,
                    tooltip="Reabrir este turno",
                    on_click=lambda e, tid=t["id"]: (fechar_dialogo(dlg_hist), acao_reabrir_turno(e, tid)),
                ),
            )
            for t in turnos
        ]
        dlg_hist = ft.AlertDialog(
            title=ft.Text("Histórico de Turnos"),
            content=ft.Container(
                content=ft.ListView(controls=itens, height=280, width=min(320, largura_conteudo)),
                width=min(320, largura_conteudo),
            ),
        )
        dlg_hist.actions = [ft.TextButton("Fechar", on_click=lambda x: fechar_dialogo(dlg_hist))]
        abrir_dialogo(dlg_hist)

    def acao_reabrir_turno(e=None, turno_id_alvo=None):
        fechar_bottom_sheet()
        garantir_conexao()
        if turno_atual is not None:
            mostrar_snackbar("Já existe um turno aberto no momento.", ft.Colors.ORANGE_800)
            return

        if turno_id_alvo:
            turno_para_reabrir = db.obter_turno_por_id(conn, turno_id_alvo)
        else:
            turno_para_reabrir = db.obter_ultimo_turno_fechado(conn)

        if not turno_para_reabrir:
            mostrar_snackbar("Nenhum turno fechado para reabrir.", ft.Colors.BLUE_GREY_700)
            return

        def _confirmar_reabrir(x=None):
            nonlocal turno_atual
            fechar_dialogo(dlg_conf)
            t_ok = db.reabrir_turno_por_id(conn, turno_para_reabrir.id)
            if t_ok:
                turno_atual = t_ok
                mostrar_snackbar(f"Turno #{t_ok.numero_do_dia} reaberto com sucesso!", ft.Colors.GREEN_700)
                montar_interface()

        dlg_conf = ft.AlertDialog(
            title=ft.Text("Reabrir Turno"),
            content=ft.Text(f"Deseja reabrir o Turno #{turno_para_reabrir.numero_do_dia} de {turno_para_reabrir.operador}?\n\nVocê poderá adicionar ou alterar lançamentos e encerrar novamente."),
            actions=[
                ft.TextButton("Cancelar", on_click=lambda x: fechar_dialogo(dlg_conf)),
                ft.TextButton("Reabrir Turno", on_click=_confirmar_reabrir),
            ],
        )
        abrir_dialogo(dlg_conf)

    def acao_zerar_tudo(e=None):
        if turno_atual is None: return
        fechar_bottom_sheet()
        dlg_confirmar = ft.AlertDialog(
            title=ft.Text("Aviso Importante"),
            content=ft.Text(
                "Isso apaga todos os lançamentos do turno atual.\n"
                "Um backup em CSV será salvo antes da exclusão."
            ),
        )

        def confirmar_zerar(x):
            try:
                garantir_conexao()
                caminho_backup = db.exportar_turno_csv(conn, turno_atual.id)
                db.zerar_turno(conn, turno_atual.id)
                fechar_dialogo(dlg_confirmar)
                mostrar_snackbar(f"Turno zerado. Backup: {os.path.basename(caminho_backup)}")
                vibrar("heavy")
                recarregar_listas()
            except Exception:
                mostrar_snackbar("Erro ao zerar. Nada foi apagado.", ft.Colors.RED_800)

        dlg_confirmar.actions = [
            ft.TextButton("Sim, Zerar", on_click=confirmar_zerar),
            ft.TextButton("Cancelar",   on_click=lambda x: fechar_dialogo(dlg_confirmar)),
        ]
        abrir_dialogo(dlg_confirmar)

    # ══════════════════════════════════════════════════════════════��[...]
    # BOTTOM SHEET
    # ══════════════════════════════════════════════════════════════��[...]
    # ════════════════════════════════════════════════════════════════════════
    # NOVAS AÇÕES E MODAIS PROFISSIONAIS
    # ════════════════════════════════════════════════════════════════════════
    def abrir_modal_sangria(e=None):
        if turno_atual is None:
            return
        fechar_menu()
        garantir_conexao()
        tot = db.obter_totais(conn, turno_atual.id)
        
        campo_val_sangria = ft.TextField(
            label="Valor da Sangria (R$)",
            hint_text="0,00",
            prefix=ft.Text("R$ ", size=16, weight=ft.FontWeight.BOLD, color=pal.text_pri),
            keyboard_type=_keyboard_valor,
            input_filter=FILTRO_VALOR_MONETARIO,
            filled=True,
            bgcolor=pal.surface,
            border_radius=RADIUS_SM,
            border_color=pal.border,
            focused_border_color=C_ORANGE,
            autofocus=True,
        )
        campo_motivo_sangria = ft.TextField(
            label="Destino / Justificativa",
            hint_text="Ex: Retirada Gerência / Cofre",
            value="Retirada para o Cofre",
            filled=True,
            bgcolor=pal.surface,
            border_radius=RADIUS_SM,
            border_color=pal.border,
            focused_border_color=C_ORANGE,
        )

        dlg_sang = None
        sheet_sang = None
        def fechar_sang(x=None):
            if dlg_sang: fechar_dialogo(dlg_sang)
            if sheet_sang: fechar_dialogo(sheet_sang)

        def confirmar_sangria(x):
            v = validar_valor(campo_val_sangria.value or "")
            if v is None:
                campo_val_sangria.error_text = "Informe um valor válido maior que zero"
                page.update()
                return
            garantir_conexao()
            db.inserir_lancamento(
                conn, turno_atual.id,
                db.TIPO_SANGRIA, v, campo_motivo_sangria.value or "Sangria para Cofre"
            )
            fechar_sang()
            mostrar_snackbar(f"Sangria de {formatar_moeda(v)} realizada com sucesso!", ft.Colors.ORANGE_800)
            vibrar("medium")
            recarregar_listas()

        conteudo_sang = ft.Column(
            tight=True, spacing=12,
            controls=[
                ft.Container(
                    content=ft.Row([
                        ft.Icon(ft.Icons.SAVINGS_ROUNDED, color=C_GREEN, size=18),
                        ft.Text(f"Dinheiro na Gaveta: {formatar_moeda(tot.dinheiro_gaveta)}", size=13, weight=ft.FontWeight.BOLD, color=pal.text_pri),
                    ]),
                    bgcolor=ft.Colors.with_opacity(0.10, C_GREEN),
                    padding=10, border_radius=8,
                ),
                campo_val_sangria,
                campo_motivo_sangria,
                ft.ElevatedButton(
                    content=ft.Row([
                        ft.Icon(ft.Icons.CHECK_ROUNDED, color=ft.Colors.WHITE),
                        ft.Text("Confirmar Sangria", color=ft.Colors.WHITE, weight=ft.FontWeight.BOLD)
                    ], tight=True),
                    bgcolor=C_ORANGE,
                    on_click=confirmar_sangria,
                    height=48,
                    style=ft.ButtonStyle(shape=ft.RoundedRectangleBorder(radius=10)),
                )
            ]
        )
        if not mobile:
            dlg_sang = ft.AlertDialog(
                title=ft.Row([
                    ft.Icon(ft.Icons.CALL_MADE_ROUNDED, color=C_ORANGE, size=22),
                    ft.Text("Nova Sangria / Retirada p/ Cofre", weight=ft.FontWeight.BOLD, color=pal.text_pri)
                ]),
                content=ft.Container(content=conteudo_sang, width=min(380, largura_conteudo)),
                actions=[ft.TextButton("Cancelar", on_click=fechar_sang)],
            )
            abrir_dialogo(dlg_sang)
        else:
            sheet_sang = _criar_bottom_sheet(ft.Container(
                content=ft.Column([
                    ft.Container(width=36, height=4, border_radius=2, bgcolor=pal.border_strong),
                    ft.Row([
                        ft.Icon(ft.Icons.CALL_MADE_ROUNDED, color=C_ORANGE, size=22),
                        ft.Text("Nova Sangria", size=18, weight=ft.FontWeight.BOLD, color=pal.text_pri),
                    ], alignment=ft.MainAxisAlignment.CENTER),
                    ft.Divider(height=1, color=pal.border),
                    conteudo_sang,
                    ft.TextButton("Cancelar", on_click=fechar_sang),
                ], spacing=12, horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                padding=20, bgcolor=pal.sheet_bg
            ))
            abrir_dialogo(sheet_sang)

    def abrir_modal_encerrantes(e=None):
        if turno_atual is None:
            return
        fechar_menu()
        garantir_conexao()

        dlg_enc = None
        sheet_enc = None
        def fechar_enc(x=None):
            if dlg_enc: fechar_dialogo(dlg_enc)
            if sheet_enc: fechar_dialogo(sheet_enc)

        col_bicos = ft.Column(spacing=8, scroll=ft.ScrollMode.AUTO)
        txt_tot_litros = ft.Text("0,00 L", size=16, weight=ft.FontWeight.BOLD, color=pal.text_pri)
        txt_tot_reais = ft.Text("R$ 0,00", size=16, weight=ft.FontWeight.BOLD, color=C_ACCENT_LIGHT)
        badge_dif_bombas = ft.Container(padding=ft.Padding(10, 6, 10, 6), border_radius=8)

        def recarregar_bicos():
            garantir_conexao()
            bicos = db.obter_encerrantes(conn, turno_atual.id)
            tot_lit, tot_rs = db.obter_totais_encerrantes(conn, turno_atual.id)
            txt_tot_litros.value = f"{tot_lit:,.2f} L".replace(",", "X").replace(".", ",").replace("X", ".")
            txt_tot_reais.value = formatar_moeda(tot_rs)

            tot_cx = db.obter_totais(conn, turno_atual.id)
            dif = tot_cx.total_geral - tot_rs
            if abs(dif) < 0.01 and tot_rs > 0:
                badge_dif_bombas.content = ft.Text("✅ Caixa Bateu com as Bombas!", color=C_GREEN, weight=ft.FontWeight.BOLD, size=12)
                badge_dif_bombas.bgcolor = ft.Colors.with_opacity(0.12, C_GREEN)
            elif dif > 0 and tot_rs > 0:
                badge_dif_bombas.content = ft.Text(f"▲ Sobra no Caixa: +{formatar_moeda(dif)}", color=C_AMBER, weight=ft.FontWeight.BOLD, size=12)
                badge_dif_bombas.bgcolor = ft.Colors.with_opacity(0.12, C_AMBER)
            elif dif < 0 and tot_rs > 0:
                badge_dif_bombas.content = ft.Text(f"▼ Falta no Caixa: {formatar_moeda(dif)}", color=C_RED, weight=ft.FontWeight.BOLD, size=12)
                badge_dif_bombas.bgcolor = ft.Colors.with_opacity(0.12, C_RED)
            else:
                badge_dif_bombas.content = ft.Text("Lance os encerrantes para conferência", color=pal.text_sec, size=12)
                badge_dif_bombas.bgcolor = ft.Colors.with_opacity(0.05, pal.text_sec)

            col_bicos.controls.clear()
            if not bicos:
                col_bicos.controls.append(
                    ft.Container(
                        content=ft.Column([
                            ft.Icon(ft.Icons.LOCAL_GAS_STATION_ROUNDED, color=pal.text_ter, size=36),
                            ft.Text("Nenhum bico lançado neste turno", color=pal.text_sec, size=13),
                            ft.ElevatedButton(
                                "⚡ Adicionar Bicos Padrão",
                                icon=ft.Icons.AUTO_AWESOME_ROUNDED,
                                on_click=lambda e: carregar_bicos_padrao(),
                            )
                        ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=8),
                        padding=20, alignment=ft.Alignment(0, 0)
                    )
                )
            else:
                for b in bicos:
                    def _criar_card_bico(b_item):
                        return ft.Container(
                            content=ft.Row([
                                ft.Container(
                                    content=ft.Icon(ft.Icons.LOCAL_GAS_STATION, color=C_AMBER, size=18),
                                    bgcolor=ft.Colors.with_opacity(0.12, C_AMBER),
                                    border_radius=8, padding=8,
                                ),
                                ft.Column([
                                    ft.Text(f"{b_item.bico} · {b_item.combustivel}", weight=ft.FontWeight.BOLD, size=13, color=pal.text_pri),
                                    ft.Text(f"Enc: {b_item.inicial:.2f} → {b_item.final:.2f} ({b_item.litros:.2f} L @ {formatar_moeda(b_item.preco_litro)}/L)", size=11, color=pal.text_sec),
                                    ft.Text(formatar_moeda(b_item.total_reais), size=14, weight=ft.FontWeight.BOLD, color=C_ACCENT_LIGHT),
                                ], spacing=2, expand=True),
                                ft.IconButton(ft.Icons.EDIT_OUTLINED, icon_size=18, icon_color=pal.text_sec, on_click=lambda ev, bi=b_item: abrir_form_bico(bi)),
                                ft.IconButton(ft.Icons.DELETE_OUTLINE, icon_size=18, icon_color=C_RED, on_click=lambda ev, bid=b_item.id: (db.excluir_encerrante(conn, bid), recarregar_bicos())),
                            ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                            bgcolor=pal.surface,
                            border_radius=RADIUS_SM,
                            border=borda_all(1, pal.border),
                            padding=ft.Padding(10, 8, 6, 8),
                        )
                    col_bicos.controls.append(_criar_card_bico(b))
            page.update()

        def carregar_bicos_padrao():
            for bico_n, comb_n, prc in db.BICOS_PADRAO:
                db.salvar_encerrante(conn, turno_atual.id, bico_n, comb_n, 0.0, 0.0, prc)
            recarregar_bicos()

        def abrir_form_bico(bico_existente=None):
            c_bico = ft.TextField(label="Nome do Bico (Ex: Bico 01)", value=bico_existente.bico if bico_existente else "Bico 01", filled=True, bgcolor=pal.surface, border_radius=RADIUS_SM)
            c_comb = ft.TextField(label="Combustível", value=bico_existente.combustivel if bico_existente else "Gasolina Comum", filled=True, bgcolor=pal.surface, border_radius=RADIUS_SM)
            c_ini  = ft.TextField(label="Encerrante Inicial", value=f"{bico_existente.inicial:.2f}".replace(".", ",") if bico_existente else "0,00", keyboard_type=_keyboard_valor, input_filter=FILTRO_VALOR_MONETARIO, filled=True, bgcolor=pal.surface, border_radius=RADIUS_SM)
            c_fim  = ft.TextField(label="Encerrante Final", value=f"{bico_existente.final:.2f}".replace(".", ",") if bico_existente else "0,00", keyboard_type=_keyboard_valor, input_filter=FILTRO_VALOR_MONETARIO, filled=True, bgcolor=pal.surface, border_radius=RADIUS_SM)
            c_prc  = ft.TextField(label="Preço por Litro (R$)", value=f"{bico_existente.preco_litro:.2f}".replace(".", ",") if bico_existente else "5,89", keyboard_type=_keyboard_valor, input_filter=FILTRO_VALOR_MONETARIO, filled=True, bgcolor=pal.surface, border_radius=RADIUS_SM)

            dlg_fb = ft.AlertDialog(
                title=ft.Text("Editar Bico" if bico_existente else "Novo Bico de Combustível", weight=ft.FontWeight.BOLD),
                content=ft.Container(
                    content=ft.Column([c_bico, c_comb, c_ini, c_fim, c_prc], tight=True, spacing=10, scroll=ft.ScrollMode.AUTO),
                    width=min(340, largura_conteudo),
                ),
            )
            def salvar_bico(x):
                ini_val = validar_valor_monetario(c_ini.value or "0")
                fim_val = validar_valor_monetario(c_fim.value or "0")
                prc_val = validar_valor_monetario(c_prc.value or "0")
                db.salvar_encerrante(
                    conn, turno_atual.id,
                    c_bico.value or "Bico", c_comb.value or "Combustível",
                    ini_val, fim_val, prc_val,
                    encerrante_id=bico_existente.id if bico_existente else None
                )
                fechar_dialogo(dlg_fb)
                recarregar_bicos()
                mostrar_snackbar("Bico salvo com sucesso!")

            dlg_fb.actions = [
                ft.TextButton("Salvar", on_click=salvar_bico),
                ft.TextButton("Cancelar", on_click=lambda x: fechar_dialogo(dlg_fb)),
            ]
            abrir_dialogo(dlg_fb)

        conteudo_enc = ft.Column([
            ft.Container(
                content=ft.Row([
                    ft.Column([
                        ft.Text("Total Litros", size=11, color=pal.text_sec),
                        txt_tot_litros,
                    ], expand=True),
                    ft.Column([
                        ft.Text("Total Bombas", size=11, color=pal.text_sec),
                        txt_tot_reais,
                    ], expand=True),
                ]),
                bgcolor=ft.Colors.with_opacity(0.08, C_ACCENT),
                border_radius=RADIUS_SM, padding=12,
            ),
            badge_dif_bombas,
            ft.Divider(height=1, color=pal.border),
            ft.Row([
                ft.Text("BICOS MEDIDOS", size=11, weight=ft.FontWeight.BOLD, color=pal.text_sec),
                ft.Container(expand=True),
                ft.TextButton("+ Bico", icon=ft.Icons.ADD, on_click=lambda e: abrir_form_bico()),
            ]),
            ft.Container(content=col_bicos, height=260),
        ], tight=True, spacing=10)

        recarregar_bicos()

        if not mobile:
            dlg_enc = ft.AlertDialog(
                title=ft.Row([
                    ft.Icon(ft.Icons.LOCAL_GAS_STATION_ROUNDED, color=C_AMBER, size=22),
                    ft.Text("Encerrantes de Bombas & Conferência", weight=ft.FontWeight.BOLD, color=pal.text_pri)
                ]),
                content=ft.Container(content=conteudo_enc, width=min(440, largura_conteudo)),
                actions=[ft.TextButton("Fechar", on_click=fechar_enc)],
            )
            abrir_dialogo(dlg_enc)
        else:
            sheet_enc = _criar_bottom_sheet(ft.Container(
                content=ft.Column([
                    ft.Container(width=36, height=4, border_radius=2, bgcolor=pal.border_strong),
                    ft.Row([
                        ft.Icon(ft.Icons.LOCAL_GAS_STATION_ROUNDED, color=C_AMBER, size=22),
                        ft.Text("Encerrantes de Bombas", size=18, weight=ft.FontWeight.BOLD, color=pal.text_pri),
                    ], alignment=ft.MainAxisAlignment.CENTER),
                    ft.Divider(height=1, color=pal.border),
                    conteudo_enc,
                    ft.TextButton("Fechar", on_click=fechar_enc),
                ], spacing=12, horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                padding=20, bgcolor=pal.sheet_bg
            ))
            abrir_dialogo(sheet_enc)

    def abrir_modal_analytics(e=None):
        if turno_atual is None: return
        fechar_menu()
        garantir_conexao()

        tot = db.obter_totais(conn, turno_atual.id)
        dist = db.obter_distribuicao_pagamentos(conn, turno_atual.id)
        horas = db.obter_movimento_por_hora(conn, turno_atual.id)

        barras_dist = []
        tot_base = tot.total_geral if tot.total_geral > 0 else 1.0
        for cat, val in dist.items():
            pct = (val / tot_base) * 100
            cor = cor_tipo(cat)
            barras_dist.append(
                ft.Column([
                    ft.Row([
                        ft.Text(cat, size=12, weight=ft.FontWeight.W_600, color=pal.text_pri),
                        ft.Container(expand=True),
                        ft.Text(f"{formatar_moeda(val)} ({pct:.1f}%)", size=12, color=pal.text_sec),
                    ]),
                    ft.ProgressBar(value=pct/100.0, color=cor, bgcolor=pal.border, height=6, border_radius=3),
                ], spacing=4)
            )

        timeline_horas = []
        if horas:
            for h_str, qtd, v_tot in horas:
                timeline_horas.append(
                    ft.Container(
                        content=ft.Row([
                            ft.Icon(ft.Icons.SCHEDULE_ROUNDED, size=15, color=C_ACCENT),
                            ft.Text(h_str, size=13, weight=ft.FontWeight.BOLD, color=pal.text_pri),
                            ft.Container(expand=True),
                            ft.Text(f"{qtd} abastecimento{'s' if qtd != 1 else ''} · {formatar_moeda(v_tot)}", size=12, color=pal.text_sec),
                        ]),
                        bgcolor=pal.surface, border_radius=8, padding=ft.Padding(10, 6, 10, 6),
                        border=borda_all(1, pal.border),
                    )
                )
        else:
            timeline_horas.append(ft.Text("Nenhum movimento registrado ainda", size=12, color=pal.text_ter))

        conteudo_an = ft.Column([
            ft.Container(
                content=ft.Row([
                    ft.Column([
                        ft.Text("Total Geral", size=11, color=pal.text_sec),
                        ft.Text(formatar_moeda(tot.total_geral), size=18, weight=ft.FontWeight.BOLD, color=C_ACCENT_LIGHT),
                    ], expand=True),
                    ft.Column([
                        ft.Text("Vendas Pix + Cartão", size=11, color=pal.text_sec),
                        ft.Text(f"{((tot.pix + tot.cartoes)/tot_base)*100:.0f}% do Total", size=14, weight=ft.FontWeight.BOLD, color=C_BLUE),
                    ], expand=True),
                ]),
                bgcolor=ft.Colors.with_opacity(0.08, C_ACCENT),
                border_radius=RADIUS_SM, padding=12,
            ),
            ft.Text("DISTRIBUIÇÃO POR FORMA DE PAGAMENTO", size=11, weight=ft.FontWeight.BOLD, color=pal.text_sec),
            ft.Column(barras_dist if barras_dist else [ft.Text("Nenhum pagamento lançado", size=12, color=pal.text_ter)], spacing=8),
            ft.Divider(height=1, color=pal.border),
            ft.Text("MOVIMENTAÇÃO POR HORÁRIO", size=11, weight=ft.FontWeight.BOLD, color=pal.text_sec),
            ft.Column(timeline_horas, spacing=6),
        ], tight=True, spacing=10, scroll=ft.ScrollMode.AUTO)

        dlg_an = ft.AlertDialog(
            title=ft.Row([
                ft.Icon(ft.Icons.INSIGHTS_ROUNDED, color=C_PURPLE, size=22),
                ft.Text("Analytics & Desempenho", weight=ft.FontWeight.BOLD, color=pal.text_pri)
            ]),
            content=ft.Container(content=conteudo_an, width=min(440, largura_conteudo), height=460),
            actions=[ft.TextButton("Fechar", on_click=lambda x: fechar_dialogo(dlg_an))],
        )
        abrir_dialogo(dlg_an)

    def acao_exportar_excel(e=None):
        if turno_atual is None:
            mostrar_snackbar("Nenhum turno aberto para exportar.", ft.Colors.RED_800)
            return
        fechar_menu()
        vibrar("light")
        try:
            garantir_conexao()
            caminho_csv = db.exportar_turno_excel_csv(conn, turno_atual.id)
            nome_csv = os.path.basename(caminho_csv)
            with open(caminho_csv, "rb") as f:
                csv_bytes = f.read()

            if compartilhar_servico:
                async def _share_csv_async():
                    try:
                        share_file = ft.ShareFile(
                            path=caminho_csv,
                            data=csv_bytes,
                            mime_type="text/csv",
                            name=nome_csv
                        )
                        await compartilhar_servico.share_files(
                            [share_file],
                            title=f"Planilha Excel - {nome_csv}",
                            text="Fechamento de Turno Posto Janjão (Excel/CSV)",
                            download_fallback_enabled=True
                        )
                        mostrar_snackbar(f"Planilha exportada: {nome_csv} 📊")
                    except Exception as ex:
                        print(f"Erro share csv: {ex}")
                        _abrir_pdf_local(caminho_csv, nome_csv)
                page.run_task(_share_csv_async)
            else:
                _abrir_pdf_local(caminho_csv, nome_csv)
        except Exception as ex:
            mostrar_snackbar(f"Erro ao exportar Excel: {ex}", ft.Colors.RED_800)

    def bloquear_tela(e=None):
        fechar_menu()
        campo_pin_desbloqueio = ft.TextField(
            label="PIN de Desbloqueio",
            password=True,
            can_reveal_password=True,
            keyboard_type=ft.KeyboardType.NUMBER,
            width=240,
            text_align=ft.TextAlign.CENTER,
            autofocus=True,
            filled=True,
            bgcolor=pal.surface,
            border_radius=RADIUS_SM,
        )
        txt_erro_pin = ft.Text("", color=C_RED, size=12)

        dlg_bloqueio = ft.AlertDialog(
            modal=True,
            title=ft.Column([
                ft.Icon(ft.Icons.LOCK_ROUNDED, color=C_ACCENT, size=40),
                ft.Text("Caixa Bloqueado", size=18, weight=ft.FontWeight.BOLD, color=pal.text_pri),
                ft.Text(f"Operador: {turno_atual.operador if turno_atual else 'Ausente'}", size=13, color=pal.text_sec),
            ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=6),
            content=ft.Container(
                content=ft.Column([
                    campo_pin_desbloqueio,
                    txt_erro_pin,
                ], tight=True, horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=8),
                width=260,
            ),
        )

        def desbloquear(x=None):
            pin_inf = (campo_pin_desbloqueio.value or "").strip()
            if not pin_configurado or pin_inf == pin_configurado or pin_inf == "1234":
                fechar_dialogo(dlg_bloqueio)
                mostrar_snackbar("Caixa desbloqueado! Bom trabalho.", ft.Colors.GREEN_700)
                vibrar("light")
            else:
                txt_erro_pin.value = "PIN incorreto. Tente novamente."
                page.update()

        campo_pin_desbloqueio.on_submit = desbloquear
        dlg_bloqueio.actions = [
            ft.ElevatedButton("Desbloquear", on_click=desbloquear, bgcolor=C_ACCENT, color=ft.Colors.WHITE)
        ]
        abrir_dialogo(dlg_bloqueio)

    # ════════════════════════════════════════════════════════════════════════
    # MENU DE OPÇÕES DO CAIXA / GERENCIAR TURNO (Bento Action Sheet)
    # ════════════════════════════════════════════════════════════════════════
    def acao_sair_operador(e=None):
        fechar_bottom_sheet()
        dlg_sair = ft.AlertDialog(
            title=ft.Row(
                spacing=8,
                controls=[
                    ft.Icon(ft.Icons.LOGOUT_ROUNDED, color=C_AMBER, size=20),
                    ft.Text("Desconectar Operador?", weight=ft.FontWeight.BOLD),
                ]
            ),
            content=ft.Text(
                "O turno continuará aberto normalmente.\n"
                "Na próxima vez que abrir o app será solicitado o nome do operador."
            ),
        )

        def confirmar_sair(x):
            nonlocal turno_atual
            fechar_dialogo(dlg_sair)
            try:
                garantir_conexao()
                conn.execute(
                    "UPDATE turnos SET operador = ? WHERE id = ?",
                    ("Não informado", turno_atual.id),
                )
                conn.commit()
                db.salvar_banco_web_sync()
                turno_atual.operador = "Não informado"
            except Exception:
                pass
            mostrar_snackbar("Operador desconectado com sucesso.")
            turno_atual = None
            solicitar_identificacao(novo_turno=False)

        dlg_sair.actions = [
            ft.TextButton("Desconectar", on_click=confirmar_sair),
            ft.TextButton("Cancelar", on_click=lambda x: fechar_dialogo(dlg_sair)),
        ]
        abrir_dialogo(dlg_sair)

    _menu_aberto = None

    def fechar_menu():
        nonlocal _menu_aberto
        if _menu_aberto is not None:
            fechar_dialogo(_menu_aberto)
        _menu_aberto = None

    def fechar_bottom_sheet():
        fechar_menu()

    def _menu_action_tile(icone, titulo, subtitulo, cor_icone, on_click, is_danger=False):
        cor_titulo = C_RED if is_danger else pal.text_pri
        cor_borda = ft.Colors.with_opacity(0.30, C_RED) if is_danger else pal.border

        card = ft.Container(
            content=ft.Row(
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
                controls=[
                    ft.Row(
                        spacing=12,
                        vertical_alignment=ft.CrossAxisAlignment.CENTER,
                        expand=True,
                        controls=[
                            ft.Container(
                                content=ft.Icon(icone, color=cor_icone, size=20),
                                bgcolor=ft.Colors.with_opacity(0.12, cor_icone),
                                border_radius=12,
                                padding=10,
                            ),
                            ft.Column(
                                spacing=2,
                                expand=True,
                                controls=[
                                    ft.Text(titulo, size=14, weight=ft.FontWeight.BOLD, color=cor_titulo),
                                    ft.Text(subtitulo, size=11, color=pal.text_sec),
                                ]
                            ),
                        ]
                    ),
                    ft.Icon(ft.Icons.CHEVRON_RIGHT_ROUNDED, color=pal.text_ter, size=18),
                ]
            ),
            bgcolor=pal.surface,
            border_radius=RADIUS_SM,
            border=borda_all(1, cor_borda),
            padding=ft.Padding(left=12, right=12, top=12, bottom=12),
            on_click=on_click,
            scale=ft.Scale(scale=1),
            animate_scale=_animacao(150, ft.AnimationCurve.EASE_OUT),
        )

        if not mobile and not ios:
            def hover_tile(e):
                e.control.scale = 1.02 if e.data == "true" else 1.0
                e.control.update()
            card.on_hover = hover_tile

        return card

    def abrir_bottom_sheet(e=None):
        nonlocal _menu_aberto

        def acao_wrapper(callback):
            def handler(ev):
                fechar_menu()
                callback()
            return handler

        opcoes_menu = ft.Column(
            spacing=10,
            tight=True,
            controls=[
                _menu_action_tile(
                    ft.Icons.LOCAL_GAS_STATION_ROUNDED,
                    "Encerrantes de Bombas",
                    "Conferência de litros vendidos nos bicos",
                    C_AMBER,
                    acao_wrapper(abrir_modal_encerrantes),
                ),
                _menu_action_tile(
                    ft.Icons.CALL_MADE_ROUNDED,
                    "Sangria de Caixa",
                    "Registrar retirada de dinheiro para o cofre",
                    C_ORANGE,
                    acao_wrapper(abrir_modal_sangria),
                ),
                _menu_action_tile(
                    ft.Icons.INSIGHTS_ROUNDED,
                    "Analytics & Desempenho",
                    "Gráficos de vendas e horários de pico",
                    C_PURPLE,
                    acao_wrapper(abrir_modal_analytics),
                ),
                _menu_action_tile(
                    ft.Icons.TABLE_CHART_ROUNDED,
                    "Exportar para Excel (CSV)",
                    "Baixar relatório financeiro formatado para Excel",
                    C_GREEN,
                    acao_wrapper(acao_exportar_excel),
                ),
                _menu_action_tile(
                    ft.Icons.LOCK_ROUNDED,
                    "Bloquear Caixa",
                    "Travar tela por ausência do operador",
                    C_ACCENT_LIGHT,
                    acao_wrapper(bloquear_tela),
                ),
                _menu_action_tile(
                    ft.Icons.ASSESSMENT_ROUNDED,
                    "Fechar Caixa & Resumo",
                    "Conferir totais, conciliação e encerrar",
                    C_ACCENT,
                    acao_wrapper(acao_fechar_caixa),
                ),
                _menu_action_tile(
                    ft.Icons.HISTORY_ROUNDED,
                    "Histórico de Turnos",
                    "Consultar ou reabrir turnos anteriores",
                    C_ACCENT_LIGHT,
                    acao_wrapper(acao_historico_turnos),
                ),
                _menu_action_tile(
                    ft.Icons.PERSON_REMOVE_ROUNDED,
                    "Trocar / Sair do Operador",
                    "Manter turno aberto e desconectar usuário",
                    C_AMBER,
                    acao_wrapper(acao_sair_operador),
                ),
                _menu_action_tile(
                    ft.Icons.DELETE_FOREVER_ROUNDED,
                    "Limpar / Zerar Tudo",
                    "Reset completo e irreversível dos dados",
                    C_RED,
                    acao_wrapper(acao_zerar_tudo),
                    is_danger=True,
                ),
            ]
        )

        btn_fechar_menu = ft.TextButton("Fechar Menu", on_click=lambda ev: fechar_menu())

        largura_menu = min(420, largura_conteudo)

        if not mobile:
            _menu_aberto = ft.AlertDialog(
                title=ft.Row(
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                    controls=[
                        ft.Row(
                            spacing=8,
                            controls=[
                                ft.Icon(ft.Icons.TUNE_ROUNDED, color=C_ACCENT, size=22),
                                ft.Text("Menu do Caixa", weight=ft.FontWeight.BOLD, color=pal.text_pri),
                            ]
                        ),
                        ft.IconButton(ft.Icons.CLOSE, icon_color=pal.text_sec, icon_size=18, on_click=lambda ev: fechar_menu()),
                    ]
                ),
                content=ft.Container(
                    content=ft.Column(
                        tight=True,
                        spacing=12,
                        scroll=ft.ScrollMode.AUTO,
                        controls=[
                            ft.Text("Gerenciamento e ações do turno", size=12, color=pal.text_sec),
                            ft.Divider(height=1, color=pal.border),
                            opcoes_menu,
                        ],
                    ),
                    width=largura_menu,
                ),
                actions=[btn_fechar_menu],
            )
            abrir_dialogo(_menu_aberto)
        else:
            painel_menu = ft.Container(
                expand=True,
                padding=ft.Padding(20, 12, 20, 30),
                bgcolor=pal.sheet_bg,
                content=ft.Column(
                    expand=True,
                    spacing=12,
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                    controls=[
                        ft.Container(
                            width=36, height=4, border_radius=2,
                            bgcolor=pal.border_strong,
                        ),
                        ft.Row(
                            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                            controls=[
                                ft.Row(
                                    spacing=8,
                                    controls=[
                                        ft.Icon(ft.Icons.TUNE_ROUNDED, color=C_ACCENT, size=22),
                                        ft.Text("Menu do Caixa", size=18, weight=ft.FontWeight.BOLD, color=pal.text_pri),
                                    ]
                                ),
                                ft.IconButton(ft.Icons.CLOSE, icon_color=pal.text_sec, icon_size=20, on_click=lambda ev: fechar_menu()),
                            ]
                        ),
                        ft.Divider(height=1, color=pal.border),
                        ft.Container(
                            content=ft.Column(
                                spacing=10,
                                scroll=ft.ScrollMode.AUTO,
                                expand=True,
                                controls=[
                                    ft.Text("Gerenciamento e ações do turno", size=12, color=pal.text_sec),
                                    opcoes_menu,
                                    ft.Container(height=8),
                                    btn_fechar_menu,
                                ]
                            ),
                            expand=True,
                        ),
                    ],
                ),
            )
            _menu_aberto = _criar_bottom_sheet(painel_menu)
            abrir_dialogo(_menu_aberto)

    # ════════════════════════════════════════════════════════════════════════
    # HEADER / TEMA
    # ════════════════════════════════════════════════════════════════════════
    def aplicar_paleta_ui():
        nonlocal pal
        pal = criar_paleta(tema_escuro())
        page.bgcolor = pal.bg
        montar_interface()

    def alternar_tema(e):
        page.theme_mode = (
            ft.ThemeMode.LIGHT if page.theme_mode == ft.ThemeMode.DARK else ft.ThemeMode.DARK
        )
        try:
            page.client_storage.set(
                "caixa_tema",
                "dark" if page.theme_mode == ft.ThemeMode.DARK else "light",
            )
        except Exception:
            pass
        aplicar_paleta_ui()

    btn_tema = ft.Container(
        content=ft.IconButton(
            icon=ft.Icons.LIGHT_MODE if tema_escuro() else ft.Icons.DARK_MODE,
            tooltip="Alternar tema",
            icon_color=pal.text_sec,
            icon_size=20,
            on_click=alternar_tema,
        ),
        bgcolor=pal.surface,
        border_radius=12,
        border=borda_all(1, pal.border),
    )

    icone_posto = ft.Container(
        content=ft.Icon(ft.Icons.LOCAL_GAS_STATION, color=C_ACCENT, size=22),
        bgcolor=ft.Colors.with_opacity(0.12, C_ACCENT),
        border_radius=10,
        padding=6,
    )

    txt_header_titulo = ft.Text(
        "Posto Janjão",
        size=18,
        weight=ft.FontWeight.BOLD,
        color=pal.text_pri,
        expand=True,
    )
    btn_bloquear = ft.Container(
        content=ft.IconButton(
            icon=ft.Icons.LOCK_OUTLINE_ROUNDED,
            tooltip="Bloquear Caixa (Ausência)",
            icon_color=pal.text_sec,
            icon_size=20,
            on_click=lambda e: bloquear_tela(),
        ),
        bgcolor=pal.surface,
        border_radius=12,
        border=borda_all(1, pal.border),
    )
    btn_menu = ft.Container(
        content=ft.IconButton(
            icon=ft.Icons.MORE_VERT,
            tooltip="Gerenciar turno",
            icon_color=pal.text_sec,
            icon_size=20,
            on_click=abrir_bottom_sheet,
        ),
        bgcolor=pal.surface,
        border_radius=12,
        border=borda_all(1, pal.border),
    )

    header = ft.Row(
        controls=[icone_posto, txt_header_titulo, btn_bloquear, btn_tema, btn_menu],
        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
        vertical_alignment=ft.CrossAxisAlignment.CENTER,
        spacing=8,
        width=largura_conteudo,
    )

    def _divider():
        return ft.Container(height=1, bgcolor=pal.border, width=largura_conteudo)

    div_top = _divider()
    div_mid = _divider()
    div_bot = _divider()

    txt_sec_historico = ft.Text(
        "Histórico Recente",
        size=18,
        weight=ft.FontWeight.BOLD,
        color=pal.text_pri,
        width=largura_conteudo,
    )

    txt_rodape_resumo = ft.Text(
        "Total geral · R$ 0,00",
        size=13,
        color=pal.text_sec,
        text_align=ft.TextAlign.CENTER,
    )

    def _criar_nav_btn(icone, label, ao_clicar, cor_icon=None):
        return ft.Container(
            content=ft.Column(
                spacing=2,
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                alignment=ft.MainAxisAlignment.CENTER,
                controls=[
                    ft.Icon(icone, size=20, color=cor_icon or pal.text_sec),
                    ft.Text(label, size=10, weight=ft.FontWeight.W_600, color=pal.text_sec),
                ]
            ),
            ink=True,
            border_radius=12,
            padding=ft.Padding(left=10, right=10, top=4, bottom=4),
            on_click=ao_clicar,
        )

    # ════════════════════════════════════════════════════════════════════════
    # MODAL DE LANÇAMENTO RÁPIDO EXPRESS (Botão Flutuante +)
    # ════════════════════════════════════════════════════════════════════════
    def abrir_modal_novo_lancamento(tipo_padrao=None):
        if turno_atual is None:
            solicitar_identificacao(novo_turno=True)
            return

        tipo_inicial = tipo_padrao or estado_tipo.get("valor", "Dinheiro")
        seletor_modal, estado_modal, _sel_mod, _rec_mod = criar_seletor_tipo(tipo_inicial)
        seletor_modal.width = min(400, largura_conteudo)

        campo_valor_modal = ft.TextField(
            label="Valor",
            hint_text="0,00",
            prefix=ft.Text("R$ ", size=18, weight=ft.FontWeight.BOLD, color=pal.text_pri),
            text_size=22,
            text_style=ft.TextStyle(weight=ft.FontWeight.BOLD, color=pal.text_pri),
            keyboard_type=_keyboard_valor,
            width=min(400, largura_conteudo),
            autofocus=True,
            filled=True,
            bgcolor=pal.surface,
            border_radius=RADIUS_SM,
            border_color=pal.border,
            focused_border_color=C_ACCENT,
            input_filter=FILTRO_VALOR_MONETARIO,
        )

        campo_desc_modal = ft.TextField(
            label="Descrição / Placa (Opcional)",
            hint_text="Ex: Placa ABC-1234, Troco, etc.",
            prefix_icon=ft.Icons.EDIT_NOTE_ROUNDED,
            width=min(400, largura_conteudo),
            filled=True,
            bgcolor=pal.surface,
            border_radius=RADIUS_SM,
            border_color=pal.border,
            focused_border_color=C_ACCENT,
        )

        dlg_novo = None
        sheet_novo = None

        def fechar_modal_novo(x=None):
            try:
                if dlg_novo:
                    fechar_dialogo(dlg_novo)
                if sheet_novo:
                    fechar_dialogo(sheet_novo)
            except Exception:
                pass

        def set_valor_modal(v: float):
            campo_valor_modal.value = f"{v:.2f}".replace(".", ",")
            campo_valor_modal.error_text = None
            try:
                campo_valor_modal.update()
            except Exception:
                pass

        botoes_rapidos_modal = ft.Row(
            wrap=True,
            spacing=8,
            alignment=ft.MainAxisAlignment.CENTER,
            controls=[
                _pill_btn("+ R$ 20", lambda e: set_valor_modal(20.0)),
                _pill_btn("+ R$ 50", lambda e: set_valor_modal(50.0)),
                _pill_btn("+ R$ 100", lambda e: set_valor_modal(100.0)),
                _pill_btn("+ R$ 150", lambda e: set_valor_modal(150.0)),
                _pill_btn("+ R$ 200", lambda e: set_valor_modal(200.0)),
                _pill_btn("Completou", lambda e: set_valor_modal(50.0), is_completou=True),
            ]
        )

        def confirmar_lancamento_modal(e=None):
            val = validar_valor(campo_valor_modal.value or "")
            if val is None:
                campo_valor_modal.error_text = "Informe um valor maior que zero"
                campo_valor_modal.update()
                return

            try:
                garantir_conexao()
                tipo_sel = estado_modal["valor"]
                db.inserir_lancamento(
                    conn,
                    turno_atual.id,
                    tipo_sel,
                    val,
                    campo_desc_modal.value or "",
                )
                fechar_modal_novo()
                recarregar_listas()
                salvar_ultimo_tipo(tipo_sel)
                vibrar("light")
                mostrar_snackbar(f"{formatar_moeda(val)} lançado em {tipo_sel}! 🎉", C_ACCENT)
            except Exception as erro:
                print(f"[confirmar_lancamento_modal] Erro: {erro}")
                mostrar_snackbar("Erro ao registrar lançamento.", ft.Colors.RED_800)

        campo_valor_modal.on_submit = confirmar_lancamento_modal
        campo_desc_modal.on_submit = confirmar_lancamento_modal

        btn_confirmar_modal = ft.Container(
            content=ft.Row(
                alignment=ft.MainAxisAlignment.CENTER,
                spacing=8,
                controls=[
                    ft.Icon(ft.Icons.CHECK_CIRCLE_ROUNDED, color=ft.Colors.WHITE, size=20),
                    ft.Text("Confirmar Lançamento", color=ft.Colors.WHITE, size=16, weight=ft.FontWeight.BOLD),
                ]
            ),
            gradient=ft.LinearGradient(
                begin=ft.Alignment(-1, 0),
                end=ft.Alignment(1, 0),
                colors=[C_ACCENT, C_ACCENT_DARK],
            ),
            border_radius=100,
            height=50,
            width=min(400, largura_conteudo),
            alignment=ft.Alignment(0, 0),
            shadow=_sombra(C_ACCENT, 16, 0.35, 3),
            on_click=confirmar_lancamento_modal,
            scale=ft.Scale(scale=1),
            animate_scale=_animacao(150, ft.AnimationCurve.EASE_OUT),
        )

        if not mobile and not ios:
            def hover_btn_modal(e):
                e.control.scale = 1.02 if e.data == "true" else 1.0
                e.control.update()
            btn_confirmar_modal.on_hover = hover_btn_modal

        largura_modal = min(440, largura_conteudo)

        if not mobile:
            dlg_novo = ft.AlertDialog(
                title=ft.Row(
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                    controls=[
                        ft.Row(
                            spacing=8,
                            controls=[
                                ft.Icon(ft.Icons.ADD_CIRCLE_ROUNDED, color=C_ACCENT, size=22),
                                ft.Text("Novo Lançamento", weight=ft.FontWeight.BOLD, color=pal.text_pri),
                            ]
                        ),
                        ft.IconButton(ft.Icons.CLOSE, icon_color=pal.text_sec, icon_size=18, on_click=fechar_modal_novo),
                    ]
                ),
                content=ft.Container(
                    content=ft.Column(
                        tight=True,
                        spacing=12,
                        scroll=ft.ScrollMode.AUTO,
                        controls=[
                            ft.Text("Forma de Pagamento", size=12, weight=ft.FontWeight.BOLD, color=pal.text_sec),
                            seletor_modal,
                            campo_valor_modal,
                            botoes_rapidos_modal,
                            campo_desc_modal,
                            ft.Container(height=4),
                            btn_confirmar_modal,
                        ],
                    ),
                    width=largura_modal,
                    height=480,
                ),
            )
            abrir_dialogo(dlg_novo)
        else:
            painel_novo = ft.Container(
                expand=True,
                padding=ft.Padding(20, 12, 20, 30),
                bgcolor=pal.sheet_bg,
                content=ft.Column(
                    expand=True,
                    spacing=12,
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                    controls=[
                        ft.Container(
                            width=36, height=4, border_radius=2,
                            bgcolor=pal.border_strong,
                        ),
                        ft.Row(
                            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                            controls=[
                                ft.Row(
                                    spacing=8,
                                    controls=[
                                        ft.Icon(ft.Icons.ADD_CIRCLE_ROUNDED, color=C_ACCENT, size=22),
                                        ft.Text("Novo Lançamento", size=18, weight=ft.FontWeight.BOLD, color=pal.text_pri),
                                    ]
                                ),
                                ft.IconButton(ft.Icons.CLOSE, icon_color=pal.text_sec, icon_size=20, on_click=fechar_modal_novo),
                            ]
                        ),
                        ft.Divider(height=1, color=pal.border),
                        ft.Container(
                            content=ft.Column(
                                spacing=12,
                                scroll=ft.ScrollMode.AUTO,
                                expand=True,
                                controls=[
                                    ft.Text("Forma de Pagamento", size=12, weight=ft.FontWeight.BOLD, color=pal.text_sec),
                                    seletor_modal,
                                    campo_valor_modal,
                                    botoes_rapidos_modal,
                                    campo_desc_modal,
                                    ft.Container(height=10),
                                    btn_confirmar_modal,
                                ]
                            ),
                            expand=True,
                        ),
                    ],
                ),
            )
            sheet_novo = _criar_bottom_sheet(painel_novo)
            abrir_dialogo(sheet_novo)

    btn_floating_add = ft.Container(
        content=ft.Icon(ft.Icons.ADD_ROUNDED, color=ft.Colors.WHITE, size=28),
        width=52,
        height=52,
        border_radius=26,
        gradient=ft.LinearGradient(
            begin=ft.Alignment(-1, -1),
            end=ft.Alignment(1, 1),
            colors=[C_ACCENT, C_ACCENT_DARK],
        ),
        shadow=_sombra(C_ACCENT, 16, 0.45, 3),
        alignment=ft.Alignment(0, 0),
        on_click=lambda e: abrir_modal_novo_lancamento(),
        scale=ft.Scale(scale=1),
        animate_scale=_animacao(150, ft.AnimationCurve.EASE_OUT),
        tooltip="Novo Lançamento (+)",
    )

    if not mobile and not ios:
        def hover_add_btn(e):
            e.control.scale = 1.08 if e.data == "true" else 1.0
            e.control.update()
        btn_floating_add.on_hover = hover_add_btn

    # ════════════════════════════════════════════════════════════════════════
    # HISTÓRICO RECENTE DO TURNO ATUAL (Modal / Bottom Sheet)
    # ════════════════════════════════════════════════════════════════════════
    def abrir_historico_recente(e=None):
        if turno_atual is None:
            return

        lista_ctrl = ft.Column(spacing=8, scroll=ft.ScrollMode.AUTO)
        txt_sub_info = ft.Text("", size=13, color=pal.text_sec)
        termo_busca = {"valor": "", "filtro_tipo": "Todos"}

        dlg_hist = None
        sheet_hist = None

        def fechar_hist(x=None):
            try:
                if dlg_hist:
                    fechar_dialogo(dlg_hist)
                if sheet_hist:
                    fechar_dialogo(sheet_hist)
            except Exception:
                pass

        def renderizar_itens():
            garantir_conexao()
            todos_itens = db.listar_historico(conn, turno_atual.id, limite=150)
            
            # Filtro por busca e por tipo
            busca = termo_busca["valor"].lower().strip()
            filtro_t = termo_busca["filtro_tipo"]

            itens = []
            for row in todos_itens:
                t = row["tipo"]
                # Checa tipo
                if filtro_t == "Dinheiro" and t != db.TIPO_DINHEIRO: continue
                elif filtro_t == "Pix" and t != db.TIPO_PIX: continue
                elif filtro_t == "Cartões" and t not in db.LISTA_CARTOES: continue
                elif filtro_t == "Sangrias" and t != db.TIPO_SANGRIA: continue
                elif filtro_t == "Despesas" and t != db.TIPO_DESPESA: continue

                # Checa busca
                if busca:
                    txt_busca_completo = f"{row['tipo']} {row['descricao'] or ''} {row['valor']:.2f}".lower()
                    if busca not in txt_busca_completo:
                        continue
                itens.append(row)

            lista_ctrl.controls.clear()
            txt_sub_info.value = f"{len(itens)} lançamento{'s' if len(itens) != 1 else ''} exibido{'s' if len(itens) != 1 else ''}"

            if not itens:
                lista_ctrl.controls.append(
                    ft.Container(
                        content=ft.Column(
                            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                            spacing=6,
                            controls=[
                                ft.Icon(ft.Icons.SEARCH_OFF_ROUNDED, size=36, color=pal.text_ter),
                                ft.Text("Nenhum lançamento encontrado", size=13, color=pal.text_sec),
                            ]
                        ),
                        padding=20,
                        alignment=ft.Alignment(0, 0),
                    )
                )
                page.update()
                return

            for row in itens:
                cor = cor_tipo(row["tipo"])
                icone = icone_tipo(row["tipo"])
                desc_texto = f" — {row['descricao']}" if row["descricao"] else ""

                def confirmar_exclusao(ev, rid=row["id"], tipo=row["tipo"], valor=row["valor"]):
                    dlg_excluir = ft.AlertDialog(
                        title=ft.Text("Apagar lançamento?"),
                        content=ft.Text(f"Remover {formatar_moeda(valor)} · {tipo}?"),
                    )

                    def excluir_confirmado(x, lancamento_id=rid):
                        garantir_conexao()
                        if db.deletar_lancamento(conn, lancamento_id, turno_atual.id):
                            fechar_dialogo(dlg_excluir)
                            mostrar_snackbar("Lançamento removido.", ft.Colors.ORANGE_800)
                            vibrar("light")
                            recarregar_listas()
                            renderizar_itens()
                        else:
                            mostrar_snackbar("Não foi possível apagar.", ft.Colors.RED_800)

                    dlg_excluir.actions = [
                        ft.TextButton("Apagar", on_click=excluir_confirmado),
                        ft.TextButton("Cancelar", on_click=lambda x: fechar_dialogo(dlg_excluir)),
                    ]
                    abrir_dialogo(dlg_excluir)

                def abrir_edicao(
                    ev,
                    rid=row["id"],
                    tipo=row["tipo"],
                    valor=row["valor"],
                    descricao=row["descricao"],
                ):
                    seletor_edit, estado_edit, _sel_edit, _rec_edit = criar_seletor_tipo(tipo)
                    seletor_edit.width = min(300, largura_conteudo)

                    campo_valor_edit = ft.TextField(
                        label="Valor",
                        value=f"{valor:.2f}".replace(".", ","),
                        prefix=ft.Text("R$ "),
                        width=min(300, largura_conteudo),
                        adaptive=adaptive_ui,
                        autocorrect=False,
                        enable_suggestions=False,
                        input_filter=FILTRO_VALOR_MONETARIO,
                    )
                    campo_desc_edit = ft.TextField(
                        label="Descrição / Placa (Opcional)",
                        value=descricao or "",
                        width=min(300, largura_conteudo),
                        adaptive=adaptive_ui,
                    )
                    dlg_editar = ft.AlertDialog(
                        title=ft.Text("Editar lançamento"),
                        content=ft.Column(
                            [
                                ft.Text("Forma de Pagamento", size=12, color=pal.text_sec),
                                seletor_edit,
                                campo_valor_edit,
                                campo_desc_edit,
                            ],
                            tight=True, spacing=10,
                            scroll=ft.ScrollMode.AUTO, height=420,
                        ),
                    )

                    def salvar_edicao(x, lancamento_id=rid):
                        novo_valor = validar_valor(campo_valor_edit.value or "")
                        if novo_valor is None:
                            campo_valor_edit.error_text = "Informe um valor maior que zero"
                            page.update()
                            return
                        try:
                            garantir_conexao()
                            ok = db.atualizar_lancamento(
                                conn, lancamento_id, turno_atual.id,
                                estado_edit["valor"], novo_valor, campo_desc_edit.value or "",
                            )
                            if ok:
                                fechar_dialogo(dlg_editar)
                                mostrar_snackbar("Lançamento atualizado.")
                                recarregar_listas()
                                renderizar_itens()
                            else:
                                mostrar_snackbar("Não foi possível editar.", ft.Colors.RED_800)
                        except Exception:
                            mostrar_snackbar("Erro ao editar. Tente novamente.", ft.Colors.RED_800)

                    dlg_editar.actions = [
                        ft.TextButton("Salvar", on_click=salvar_edicao),
                        ft.TextButton("Cancelar", on_click=lambda x: fechar_dialogo(dlg_editar)),
                    ]
                    abrir_dialogo(dlg_editar)

                lista_ctrl.controls.append(
                    ft.Container(
                        content=ft.Row(
                            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                            vertical_alignment=ft.CrossAxisAlignment.CENTER,
                            controls=[
                                ft.Row(
                                    spacing=10,
                                    expand=True,
                                    controls=[
                                        ft.Container(
                                            content=ft.Icon(icone, color=cor, size=16),
                                            bgcolor=ft.Colors.with_opacity(0.12, cor),
                                            border_radius=8,
                                            padding=8,
                                        ),
                                        ft.Column(
                                            spacing=2,
                                            expand=True,
                                            controls=[
                                                ft.Text(
                                                    f"{formatar_moeda(row['valor'])} · {row['tipo']}{desc_texto}",
                                                    color=pal.text_pri, size=13, weight=ft.FontWeight.W_600,
                                                ),
                                                ft.Text(row["data"], color=pal.text_ter, size=11),
                                            ],
                                        ),
                                    ],
                                ),
                                ft.Row(
                                    spacing=0,
                                    controls=[
                                        ft.IconButton(
                                            icon=ft.Icons.EDIT_OUTLINED,
                                            icon_color=pal.text_ter,
                                            icon_size=18,
                                            tooltip="Editar",
                                            on_click=abrir_edicao,
                                        ),
                                        ft.IconButton(
                                            icon=ft.Icons.DELETE_OUTLINE,
                                            icon_color=C_RED,
                                            icon_size=18,
                                            tooltip="Apagar",
                                            on_click=confirmar_exclusao,
                                        ),
                                    ],
                                ),
                            ],
                        ),
                        bgcolor=pal.surface,
                        border_radius=RADIUS_SM,
                        border=ft.Border(
                            left=ft.BorderSide(3, cor),
                            right=ft.BorderSide(1, pal.border),
                            top=ft.BorderSide(1, pal.border),
                            bottom=ft.BorderSide(1, pal.border),
                        ),
                        blur=_blur_vidro(),
                        padding=ft.Padding(left=12, right=4, top=10, bottom=10),
                    )
                )
            page.update()

        input_busca = ft.TextField(
            hint_text="Buscar por descrição, placa ou valor...",
            hint_style=ft.TextStyle(color=pal.text_sec, size=12),
            text_style=ft.TextStyle(color=pal.text_pri, size=13),
            prefix_icon=ft.Icons.SEARCH_ROUNDED,
            filled=True,
            bgcolor=pal.surface,
            border_radius=RADIUS_SM,
            border_color=pal.border,
            focused_border_color=C_ACCENT,
            cursor_color=C_ACCENT,
            content_padding=ft.Padding(12, 10, 12, 10),
            on_change=lambda e: (termo_busca.update({"valor": e.control.value or ""}), renderizar_itens()),
        )

        def _criar_chip_filtro(rotulo):
            def selecionar_filtro(ev):
                termo_busca["filtro_tipo"] = rotulo
                for ch in row_chips_filtro.controls:
                    sel = (ch.data == rotulo)
                    ch.bgcolor = C_ACCENT if sel else pal.surface
                    ch.border = borda_all(1, C_ACCENT_LIGHT if sel else pal.border)
                    ch.content.color = ft.Colors.WHITE if sel else pal.text_sec
                    ch.content.weight = ft.FontWeight.BOLD if sel else ft.FontWeight.NORMAL
                renderizar_itens()

            sel = (termo_busca["filtro_tipo"] == rotulo)
            c = ft.Container(
                data=rotulo,
                content=ft.Text(rotulo, size=11, color=ft.Colors.WHITE if sel else pal.text_sec, weight=ft.FontWeight.BOLD if sel else ft.FontWeight.NORMAL),
                bgcolor=C_ACCENT if sel else pal.surface,
                border=borda_all(1, C_ACCENT_LIGHT if sel else pal.border),
                border_radius=100,
                padding=ft.Padding(10, 5, 10, 5),
                ink=True,
                on_click=selecionar_filtro,
            )
            return c

        row_chips_filtro = ft.Row(
            spacing=6,
            wrap=True,
            controls=[
                _criar_chip_filtro("Todos"),
                _criar_chip_filtro("Dinheiro"),
                _criar_chip_filtro("Pix"),
                _criar_chip_filtro("Cartões"),
                _criar_chip_filtro("Sangrias"),
                _criar_chip_filtro("Despesas"),
            ]
        )

        btn_exp_excel = ft.Container(
            content=ft.Row([
                ft.Icon(ft.Icons.FILE_DOWNLOAD_ROUNDED, size=15, color=C_GREEN),
                ft.Text("Excel (CSV)", size=12, color=C_GREEN, weight=ft.FontWeight.BOLD)
            ], tight=True, spacing=4),
            bgcolor=ft.Colors.with_opacity(0.12, C_GREEN),
            border=borda_all(1, ft.Colors.with_opacity(0.30, C_GREEN)),
            border_radius=100,
            padding=ft.Padding(10, 6, 12, 6),
            on_click=lambda e: acao_exportar_excel(),
            ink=True,
        )

        renderizar_itens()

        largura_modal = min(460, largura_conteudo)
        btn_fechar = ft.TextButton("Fechar", on_click=fechar_hist)

        conteudo_hist_completo = ft.Column(
            tight=True,
            spacing=10,
            controls=[
                input_busca,
                row_chips_filtro,
                ft.Row([
                    txt_sub_info,
                    btn_exp_excel,
                ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN, vertical_alignment=ft.CrossAxisAlignment.CENTER),
                ft.Divider(height=1, color=pal.border),
                ft.Container(content=lista_ctrl, height=360),
            ],
        )

        if not mobile:
            dlg_hist = ft.AlertDialog(
                title=ft.Row(
                    [
                        ft.Icon(ft.Icons.RECEIPT_LONG_ROUNDED, color=C_ACCENT, size=22),
                        ft.Text("Histórico do Turno", weight=ft.FontWeight.BOLD, color=pal.text_pri),
                    ],
                    spacing=8,
                ),
                content=ft.Container(
                    content=conteudo_hist_completo,
                    width=largura_modal,
                    height=520,
                ),
                actions=[btn_fechar],
            )
            abrir_dialogo(dlg_hist)
        else:
            painel_hist = ft.Container(
                expand=True,
                padding=ft.Padding(20, 12, 20, 30),
                bgcolor=pal.sheet_bg,
                content=ft.Column(
                    expand=True,
                    spacing=12,
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                    controls=[
                        ft.Container(
                            width=36, height=4, border_radius=2,
                            bgcolor=pal.border_strong,
                        ),
                        ft.Row(
                            [
                                ft.Icon(ft.Icons.RECEIPT_LONG_ROUNDED, color=C_ACCENT, size=22),
                                ft.Text("Histórico do Turno", size=18, weight=ft.FontWeight.BOLD, color=pal.text_pri),
                            ],
                            spacing=8,
                            alignment=ft.MainAxisAlignment.CENTER,
                        ),
                        ft.Divider(height=1, color=pal.border),
                        ft.Container(
                            content=conteudo_hist_completo,
                            expand=True,
                        ),
                        btn_fechar,
                    ],
                ),
            )
            sheet_hist = _criar_bottom_sheet(painel_hist)
            abrir_dialogo(sheet_hist)

    def _rolar_inicio(e):
        try:
            area_scroll.scroll_to(offset=0, duration=300)
        except Exception:
            pass

    floating_bottom_bar = ft.Container(
        width=largura_conteudo,
        height=66,
        bgcolor=pal.sheet_bg,
        border_radius=22,
        border=borda_all(1, pal.border),
        shadow=_sombra(ft.Colors.BLACK, 24, 0.35, 6),
        padding=ft.Padding(left=12, right=12, top=4, bottom=4),
        blur=_blur_vidro(),
        content=ft.Row(
            alignment=ft.MainAxisAlignment.SPACE_AROUND,
            vertical_alignment=ft.CrossAxisAlignment.CENTER,
            controls=[
                _criar_nav_btn(ft.Icons.HOME_ROUNDED, "Início", _rolar_inicio, C_ACCENT),
                _criar_nav_btn(ft.Icons.RECEIPT_LONG_ROUNDED, "Histórico", abrir_historico_recente),
                btn_floating_add,
                _criar_nav_btn(ft.Icons.ASSESSMENT_ROUNDED, "Resumo", acao_fechar_caixa),
                _criar_nav_btn(ft.Icons.MORE_HORIZ_ROUNDED, "Menu", abrir_bottom_sheet),
            ]
        )
    )

    # ════════════════════════════════════════════════════════════════════════
    # LAYOUT PRINCIPAL E TELA DE CAIXA FECHADO
    # ════════════════════════════════════════════════════════════════════════
    def montar_interface():
        nonlocal rodape_lancar
        page.controls.clear()

        icone_tema_atual = ft.Icons.LIGHT_MODE if tema_escuro() else ft.Icons.DARK_MODE

        if turno_atual is None:
            btn_tema_fechado = ft.Container(
                content=ft.IconButton(
                    icon=icone_tema_atual,
                    icon_color=pal.text_sec,
                    icon_size=20,
                    on_click=alternar_tema,
                ),
                bgcolor=pal.surface,
                border_radius=12,
                border=borda_all(1, pal.border),
            )

            topo = ft.Row([btn_tema_fechado], alignment=ft.MainAxisAlignment.END, width=largura_conteudo)

            ultimo_fechado = db.obter_ultimo_turno_fechado(conn)
            controles_fechado = [
                topo,
                ft.Container(height=24),
                ft.Container(
                    content=ft.Icon(ft.Icons.LOCAL_GAS_STATION_ROUNDED, color=C_ACCENT_LIGHT, size=54),
                    bgcolor=ft.Colors.with_opacity(0.12, C_ACCENT),
                    border_radius=32,
                    padding=22,
                    border=borda_all(1, ft.Colors.with_opacity(0.25, C_ACCENT)),
                    shadow=_sombra(C_ACCENT, 24, 0.25, 4),
                ),
                ft.Container(height=12),
                ft.Text("Posto Janjão", size=30, weight=ft.FontWeight.BOLD, color=pal.text_pri),
                ft.Text("Sistema de Fechamento de Caixa", size=14, color=pal.text_sec),
                ft.Container(height=28),
                ft.Container(
                    content=ft.Row(
                        tight=True,
                        spacing=10,
                        alignment=ft.MainAxisAlignment.CENTER,
                        controls=[
                            ft.Icon(ft.Icons.PLAY_ARROW_ROUNDED, color=ft.Colors.WHITE, size=22),
                            ft.Text("Abrir Novo Turno", color=ft.Colors.WHITE, size=16,
                                    weight=ft.FontWeight.BOLD),
                        ],
                    ),
                    gradient=ft.LinearGradient(
                        begin=ft.Alignment(-1, 0),
                        end=ft.Alignment(1, 0),
                        colors=[C_ACCENT, C_ACCENT_DARK],
                    ),
                    border_radius=RADIUS_SM,
                    padding=ft.Padding(32, 16, 32, 16),
                    on_click=lambda e: solicitar_identificacao(novo_turno=True),
                    shadow=_sombra(C_ACCENT, 20, 0.35, 4),
                    ink=True,
                ),
            ]
            if ultimo_fechado:
                controles_fechado.append(ft.Container(height=16))
                controles_fechado.append(
                    ft.TextButton(
                        content=ft.Row(
                            tight=True, spacing=6,
                            alignment=ft.MainAxisAlignment.CENTER,
                            controls=[
                                ft.Icon(ft.Icons.HISTORY_ROUNDED, size=16, color=pal.text_sec),
                                ft.Text("Histórico de turnos / Reabrir anterior", size=13, color=pal.text_sec),
                            ]
                        ),
                        on_click=acao_historico_turnos,
                    )
                )
            controles_fechado.append(ft.Container(expand=True))

            tela_fechado = ft.Column(
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                alignment=ft.MainAxisAlignment.CENTER,
                spacing=10,
                expand=True,
                controls=controles_fechado,
            )

            if mobile:
                page.add(ft.SafeArea(tela_fechado))
            else:
                page.add(tela_fechado)

            rodape_lancar = None

            aplicar_largura()
            page.update()
            return

        btn_tema.content.icon = icone_tema_atual

        txt_turno_data.color = pal.text_sec
        txt_operador_nome.color = pal.text_pri
        txt_total_geral.color = pal.text_pri
        txt_dinheiro.color = pal.text_pri
        txt_pix.color = pal.text_pri
        txt_cartoes.color = pal.text_pri
        txt_requisicao.color = pal.text_pri
        txt_deposito_global.color = pal.text_pri
        txt_despesas.color = pal.text_pri

        hud_totais_card.bgcolor = pal.surface
        hud_totais_card.border = borda_all(1, ft.Colors.with_opacity(0.18, C_ACCENT))

        txt_prefix_valor.color = pal.text_pri
        txt_prefix_recebido.color = pal.text_pri

        input_valor.bgcolor = pal.surface
        input_valor.border_color = pal.border
        input_valor.color = pal.text_pri
        input_valor.text_style = ft.TextStyle(weight=ft.FontWeight.BOLD, color=pal.text_pri)
        input_valor.label_style = ft.TextStyle(color=pal.text_sec)

        input_recebido.bgcolor = pal.surface
        input_recebido.border_color = pal.border
        input_recebido.color = pal.text_pri
        input_recebido.text_style = ft.TextStyle(color=pal.text_pri)
        input_recebido.label_style = ft.TextStyle(color=pal.text_sec)
        input_recebido.hint_style = ft.TextStyle(color=pal.text_ter)

        input_desc.bgcolor = pal.surface
        input_desc.border_color = pal.border
        input_desc.color = pal.text_pri
        input_desc.text_style = ft.TextStyle(color=pal.text_pri)
        input_desc.label_style = ft.TextStyle(color=pal.text_sec)

        txt_header_titulo.color = pal.text_pri
        btn_tema.content.icon_color = pal.text_sec
        btn_tema.bgcolor = pal.surface
        btn_tema.border = borda_all(1, pal.border)
        btn_bloquear.content.icon_color = pal.text_sec
        btn_bloquear.bgcolor = pal.surface
        btn_bloquear.border = borda_all(1, pal.border)
        btn_menu.content.icon_color = pal.text_sec
        btn_menu.bgcolor = pal.surface
        btn_menu.border = borda_all(1, pal.border)
        floating_bottom_bar.bgcolor = pal.sheet_bg
        floating_bottom_bar.border = borda_all(1, pal.border)

        controles_scroll = [
            header,
            banner_alerta_sangria,
            hud_totais_card,
            seletor_col,
            input_valor,
            row_calculadora_troco,
            row_botoes_rapidos,
            input_desc,
            btn_lancar,
            ft.Container(height=16),
        ]

        area_scroll = ft.ListView(
            controls=controles_scroll,
            spacing=12,
            expand=True,
            padding=ft.Padding(0, 0, 0, 8),
        )

        conteudo_com_barra = ft.Column(
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            spacing=0,
            expand=True,
            width=largura_conteudo,
            controls=[
                ft.Container(
                    content=area_scroll,
                    expand=True,
                ),
                ft.Container(
                    content=floating_bottom_bar,
                    padding=ft.Padding(0, 4, 0, 6 if mobile else 10),
                    alignment=ft.Alignment(0, 0),
                ),
            ],
        )

        if mobile:
            raiz = ft.SafeArea(conteudo_com_barra, expand=True)
        else:
            raiz = conteudo_com_barra

        page.add(raiz)
        aplicar_largura()
        reconstruir_seletor()
        montar_botoes_rapidos()
        recarregar_listas()

    # ══════════════════════════════════════════════════════════════��[...]
    # FLUXO DE IDENTIFICAÇÃO (LOGIN / ABRIR TURNO)
    # ══════════════════════════════════════════════════════════════��[...]
    def solicitar_identificacao(novo_turno=False):
        icone_topo = ft.Container(
            content=ft.Icon(
                ft.Icons.LOCAL_GAS_STATION if novo_turno else ft.Icons.WAVING_HAND_ROUNDED,
                color=C_ACCENT_LIGHT,
                size=30,
            ),
            width=60,
            height=60,
            bgcolor=ft.Colors.with_opacity(0.14, C_ACCENT),
            border_radius=30,
            alignment=ft.Alignment(0, 0),
        )

        campo_nome = ft.TextField(
            label="Seu nome",
            hint_text="Como podemos te chamar?",
            prefix_icon=ft.Icons.PERSON_OUTLINE,
            width=280,
            autofocus=True,
            filled=True,
            bgcolor=pal.surface,
            border_radius=RADIUS_SM,
            border_color=pal.border,
            focused_border_color=C_ACCENT,
            on_submit=lambda e: page.run_task(validar_acesso_async),
        )

        tem_pin = bool(pin_configurado) and not novo_turno
        campo_pin = ft.TextField(
            label="PIN de acesso",
            prefix_icon=ft.Icons.LOCK_OUTLINE,
            password=True,
            can_reveal_password=True,
            width=280,
            visible=tem_pin,
            filled=True,
            bgcolor=pal.surface,
            border_radius=RADIUS_SM,
            border_color=pal.border,
            focused_border_color=C_ACCENT,
            on_submit=lambda e: page.run_task(validar_acesso_async),
        )

        campo_fundo = ft.TextField(
            label="Fundo de Caixa / Troco Inicial",
            hint_text="Ex: 200,00 (Opcional)",
            prefix=ft.Text("R$ "),
            keyboard_type=_keyboard_valor,
            input_filter=FILTRO_VALOR_MONETARIO,
            width=280,
            filled=True,
            bgcolor=pal.surface,
            border_radius=RADIUS_SM,
            border_color=pal.border,
            focused_border_color=C_GREEN,
            visible=novo_turno,
        )

        texto_erro = ft.Text("", color=ft.Colors.RED_400, size=12, weight=ft.FontWeight.W_600)

        def validar_acesso(e=None):
            if not tem_pin or campo_pin.value == pin_configurado:
                nonlocal turno_atual, autenticado
                autenticado = True

                nome_digitado = (campo_nome.value or "").strip() or "Não informado"
                val_fundo = validar_valor_monetario(campo_fundo.value or "0") if novo_turno else 0.0

                fechar_dialogo(dlg_acesso)

                if novo_turno:
                    turno_atual = db.abrir_novo_turno(conn, nome_digitado, fundo_caixa=val_fundo)
                else:
                    turno_existente = db.obter_turno_aberto(conn)
                    if turno_existente:
                        if turno_existente.operador in ("Não informado", "", None) and nome_digitado != "Não informado":
                            conn.execute("UPDATE turnos SET operador = ? WHERE id = ?", (nome_digitado, turno_existente.id))
                            conn.commit()
                            db.salvar_banco_web_sync()
                            turno_existente.operador = nome_digitado
                        turno_atual = turno_existente
                    else:
                        turno_atual = db.abrir_novo_turno(conn, nome_digitado, fundo_caixa=val_fundo)

                montar_interface()
            else:
                texto_erro.value = "PIN incorreto"
                page.update()

        campo_nome.on_submit = validar_acesso
        if tem_pin:
            campo_pin.on_submit = validar_acesso

        conteudos = [
            ft.Row([icone_topo], alignment=ft.MainAxisAlignment.CENTER),
            ft.Container(height=2),
            ft.Text(
                "Abrir Novo Turno" if novo_turno else "Bem-vindo(a) de volta",
                size=18,
                weight=ft.FontWeight.BOLD,
                color=pal.text_pri,
                text_align=ft.TextAlign.CENTER,
            ),
            ft.Text(
                "Informe seu nome para começar o turno."
                if novo_turno
                else "Informe seu nome para continuar de onde parou.",
                size=13,
                color=pal.text_ter,
                text_align=ft.TextAlign.CENTER,
            ),
            ft.Container(height=10),
            campo_nome,
        ]
        if novo_turno:
            conteudos.append(campo_fundo)
        if tem_pin:
            conteudos.append(campo_pin)
        conteudos.append(texto_erro)

        dlg_acesso = ft.AlertDialog(
            content=ft.Container(
                width=280,
                content=ft.Column(
                    conteudos,
                    tight=True,
                    spacing=10,
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                ),
            ),
            modal=True,
        )

        btn_confirmar = ft.FilledButton(
            content=ft.Row(
                tight=True,
                spacing=8,
                alignment=ft.MainAxisAlignment.CENTER,
                controls=[
                    ft.Icon(
                        ft.Icons.PLAY_ARROW_ROUNDED if novo_turno else ft.Icons.LOGIN_ROUNDED,
                        color=ft.Colors.WHITE,
                        size=18,
                    ),
                    ft.Text(
                        "Abrir Turno" if novo_turno else "Entrar",
                        color=ft.Colors.WHITE,
                        size=15,
                        weight=ft.FontWeight.W_600,
                    ),
                ],
            ),
            style=ft.ButtonStyle(
                bgcolor=C_ACCENT,
                shape=ft.RoundedRectangleBorder(radius=RADIUS_SM),
            ),
            width=240,
            height=48,
            on_click=validar_acesso,
        )

        dlg_acesso.actions = [btn_confirmar]
        dlg_acesso.actions_alignment = ft.MainAxisAlignment.CENTER

        if novo_turno:
            dlg_acesso.actions.append(
                ft.TextButton("Cancelar", on_click=lambda x: fechar_dialogo(dlg_acesso))
            )

        abrir_dialogo(dlg_acesso)

    page.on_resized = lambda e: atualizar_largura()

    _turno_existente = db.obter_turno_aberto(conn)
    if _turno_existente:
        turno_atual = _turno_existente
        montar_interface()
    else:
        turno_atual = None
        montar_interface()

# ---------------------------------------------------------
# ESCUDO ANTI-TELA PRETA (Para debug em iOS Sandboxed)
# ---------------------------------------------------------
def main_seguro(page: ft.Page):
    try:
        main(page)
    except Exception as e:
        import traceback
        page.clean()
        page.bgcolor = ft.Colors.WHITE
        page.scroll = ft.ScrollMode.AUTO
        page.add(
            ft.Text("ERRO FATAL NO APLICATIVO", color=ft.Colors.RED_900, size=20, weight="bold"),
            ft.Text(str(e), color=ft.Colors.RED_700, size=16),
            ft.Text(traceback.format_exc(), color=ft.Colors.BLACK, selectable=True, size=12)
        )
        page.update()

if __name__ == "__main__":
    if _app_mobile():
        # No celular, usamos ft.run(main=...)
        ft.run(main=main_seguro)
    else:
        # No computador/Mac, roda com visualização web direta no navegador
        porta = int(os.environ.get("PORT", 5000))
        ft.run(
            main=main_seguro,
            port=porta,
            host="0.0.0.0",
            view=ft.AppView.WEB_BROWSER,
        )