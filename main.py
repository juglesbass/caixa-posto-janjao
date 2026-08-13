import os
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
            bg="#0b0d14",
            surface="#161824",
            border=ft.Colors.with_opacity(0.10, ft.Colors.WHITE),
            border_strong=ft.Colors.with_opacity(0.25, "#60a5fa"),
            text_pri="#ffffff",
            text_sec="#94a3b8",
            text_ter="#64748b",
            sheet_bg=ft.Colors.with_opacity(0.98, "#12141f"),
        )
    return SimpleNamespace(
        bg="#f8fafc",
        surface="#ffffff",
        border=ft.Colors.with_opacity(0.10, ft.Colors.BLACK),
        border_strong=ft.Colors.with_opacity(0.20, "#2563eb"),
        text_pri="#0f172a",
        text_sec="#475569",
        text_ter="#94a3b8",
        sheet_bg="#ffffff",
    )

# ── Cor principal (Azul Cobalto & Destaques) ───────────────────────────────
C_ACCENT       = "#2563eb"
C_ACCENT_DARK  = "#1d4ed8"
C_ACCENT_LIGHT = "#60a5fa"
C_LIME         = "#a3e635"

# ── Acentos por tipo de pagamento ───────────────────────────────────────────
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

RADIUS    = 22
RADIUS_SM = 16

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
    page.scroll = ft.ScrollMode.HIDDEN if mobile else ft.ScrollMode.AUTO
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

    def vibrar(intensidade="light"):
        if haptic_feedback is None:
            return
        async def _vibrar_async():
            try:
                metodo = getattr(haptic_feedback, f"{intensidade}_impact", None)
                if metodo:
                    await metodo()
                else:
                    await haptic_feedback.vibrate()
            except Exception:
                pass
        page.run_task(_vibrar_async)

    conn = db.conectar()
    db.inicializar_banco(conn)
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
        largura_conteudo = max(340, min(480, int(page.width) - 24))
        aplicar_largura()

    def aplicar_largura():
        w = largura_conteudo
        if turno_atual is not None:
            header.width = w
            seletor_col.width = w
            input_valor.width = w
            input_desc.width = w
            row_botoes_rapidos.width = w
            col_historico.width = w
            btn_lancar.width = w
            info_turno_card.width = w
            total_geral_card.width = w
            stats_grid.width = w
            try:
                floating_bottom_bar.width = w
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
        db.TIPO_DINHEIRO:        C_ACCENT_LIGHT,
        db.TIPO_PIX:             C_ACCENT_LIGHT,
        db.TIPO_REQUISICAO:      C_ACCENT_LIGHT,
        db.TIPO_SODEXO:          C_ACCENT_LIGHT,
        db.TIPO_DEPOSITO_GLOBAL: C_ACCENT_LIGHT,
        db.TIPO_DESPESA:         C_RED,
        "Fitcard":               C_ACCENT_LIGHT,
        "Excard":                C_ACCENT_LIGHT,
        "Amex":                  C_ACCENT_LIGHT,
        "Eucard":                C_ACCENT_LIGHT,
        "Pix":                   C_ACCENT_LIGHT,
        "Avancard":              C_ACCENT_LIGHT,
        "Master Crédito":        C_ACCENT_LIGHT,
        "Master Débito":         C_ACCENT_LIGHT,
        "Visa Crédito":          C_ACCENT_LIGHT,
        "Visa DéBITO":          C_ACCENT_LIGHT,
        "Visa Débito":           C_ACCENT_LIGHT,
        "Elo Crédito":           C_ACCENT_LIGHT,
        "Elo Débito":            C_ACCENT_LIGHT,
        "Alelo Multibenefícios": C_ACCENT_LIGHT,
    }

    ICONES = {
        db.TIPO_DINHEIRO:        ft.Icons.MONEY,
        db.TIPO_PIX:             ft.Icons.PIX,
        db.TIPO_REQUISICAO:      ft.Icons.RECEIPT_LONG,
        db.TIPO_SODEXO:          ft.Icons.LUNCH_DINING,
        db.TIPO_DEPOSITO_GLOBAL: ft.Icons.ACCOUNT_BALANCE,
        db.TIPO_DESPESA:         ft.Icons.MONEY_OFF,
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
    # INFORMAÇÕES DO TURNO (Estilo Kalo Header Badge)
    # ════════════════════════════════════════════════════════════════════════
    txt_operador_nome = ft.Text("", size=15, weight=ft.FontWeight.W_600, color=pal.text_pri)
    txt_turno_data = ft.Text("", size=12, color=pal.text_sec)
    
    badge_turno_pill = ft.Container(
        content=ft.Row(
            spacing=4,
            tight=True,
            controls=[
                ft.Icon(ft.Icons.LOCAL_FIRE_DEPARTMENT_ROUNDED, size=15, color=C_AMBER),
                ft.Text("Turno #1", size=12, weight=ft.FontWeight.BOLD, color=C_AMBER),
            ]
        ),
        bgcolor=ft.Colors.with_opacity(0.12, C_AMBER),
        border=borda_all(1, ft.Colors.with_opacity(0.25, C_AMBER)),
        border_radius=100,
        padding=ft.Padding(left=10, right=10, top=5, bottom=5),
    )

    info_turno_card = ft.Container(
        width=largura_conteudo,
        content=ft.Row(
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            vertical_alignment=ft.CrossAxisAlignment.CENTER,
            controls=[
                ft.Row(
                    spacing=10,
                    vertical_alignment=ft.CrossAxisAlignment.CENTER,
                    controls=[
                        ft.Container(
                            content=ft.Icon(ft.Icons.PERSON_ROUNDED, color=ft.Colors.WHITE, size=18),
                            bgcolor=C_ACCENT,
                            padding=8,
                            border_radius=50,
                            shadow=_sombra(C_ACCENT, 8, 0.25, 2),
                        ),
                        ft.Column(
                            spacing=1,
                            controls=[
                                txt_operador_nome,
                                txt_turno_data,
                            ]
                        )
                    ]
                ),
                badge_turno_pill,
            ]
        ),
        padding=ft.Padding(left=4, right=4, top=4, bottom=4),
    )

    # ════════════════════════════════════════════════════════════════════════
    # STATS GRID (BENTO GRID MODULAR)
    # ════════════════════════════════════════════════════════════════════════
    def _stat_card(label: str, cor: str, icone):
        badge = ft.Container(
            content=ft.Icon(icone, color=cor, size=16),
            bgcolor=ft.Colors.with_opacity(0.12, cor),
            border_radius=8,
            padding=6,
        )
        lbl = ft.Text(label.upper(), size=11, color=pal.text_sec, weight=ft.FontWeight.BOLD)
        txt = ft.Text("R$ 0,00", size=20, weight=ft.FontWeight.BOLD, color=pal.text_pri)
        card = ft.Container(
            content=ft.Column(
                spacing=8,
                controls=[
                    ft.Row(spacing=8, vertical_alignment=ft.CrossAxisAlignment.CENTER, controls=[badge, lbl]),
                    txt,
                ],
            ),
            bgcolor=pal.surface,
            border_radius=RADIUS_SM,
            border=borda_all(1, pal.border),
            padding=ft.Padding(left=14, right=14, top=14, bottom=14),
            expand=True,
            blur=_blur_vidro(),
            shadow=_sombra(ft.Colors.BLACK, 10, 0.04, 2),
            scale=ft.Scale(scale=1),
            animate_scale=_animacao(150, ft.AnimationCurve.EASE_OUT),
        )
        def hover_card(e):
            e.control.scale = 1.02 if e.data == "true" else 1.0
            e.control.update()
        card.on_hover = hover_card
        
        return card, txt, lbl

    stat_din_card, txt_dinheiro, lbl_din = _stat_card("Dinheiro", C_ACCENT_LIGHT, ft.Icons.PAYMENTS_ROUNDED)
    stat_pix_card, txt_pix, lbl_pix = _stat_card("Pag Pix", C_ACCENT_LIGHT, ft.Icons.PIX_ROUNDED)
    stat_cart_card, txt_cartoes, lbl_cart = _stat_card("Cartões", C_ACCENT_LIGHT, ft.Icons.CREDIT_CARD_ROUNDED)
    stat_req_card, txt_requisicao, lbl_req = _stat_card("Requisição", C_ACCENT_LIGHT, ft.Icons.RECEIPT_LONG_ROUNDED)
    stat_dep_card, txt_deposito_global, lbl_dep = _stat_card("Depósito Global", C_ACCENT_LIGHT, ft.Icons.ACCOUNT_BALANCE_ROUNDED)
    stat_desp_card, txt_despesas, lbl_desp = _stat_card("Despesas", C_RED, ft.Icons.MONEY_OFF_ROUNDED)

    stats_grid = ft.Column(
        spacing=10,
        width=largura_conteudo,
        controls=[
            ft.Row(spacing=10, controls=[stat_din_card, stat_pix_card]),
            ft.Row(spacing=10, controls=[stat_cart_card, stat_req_card]),
            ft.Row(spacing=10, controls=[stat_dep_card, stat_desp_card]),
        ],
    )

    # ════════════════════════════════════════════════════════════════════════
    # TOTAL GERAL (HERO CARD BENTO - KALO STYLE)
    # ════════════════════════════════════════════════════════════════════════
    txt_total_geral = ft.Text(
        "R$ 0,00",
        size=34,
        weight=ft.FontWeight.BOLD,
        color=pal.text_pri,
    )

    txt_total_geral_label = ft.Text(
        "TOTAL GERAL DO TURNO", size=11, weight=ft.FontWeight.BOLD, color=pal.text_sec,
    )

    txt_total_geral_sub = ft.Text(
        "Movimentação consolidada do caixa", size=12, color=pal.text_ter,
    )

    total_geral_card = ft.Container(
        width=largura_conteudo,
        border_radius=RADIUS,
        bgcolor=pal.surface,
        border=borda_all(1, pal.border),
        blur=_blur_vidro(),
        shadow=_sombra(ft.Colors.BLACK, 15, 0.06, 3),
        padding=ft.Padding(left=20, right=20, top=18, bottom=18),
        content=ft.Column(
            spacing=6,
            controls=[
                ft.Row(
                    alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                    controls=[
                        txt_total_geral_label,
                        ft.Container(
                            content=ft.Icon(ft.Icons.ACCOUNT_BALANCE_WALLET_ROUNDED, color=C_ACCENT_LIGHT, size=18),
                            bgcolor=ft.Colors.with_opacity(0.12, C_ACCENT),
                            border_radius=8,
                            padding=6,
                        ),
                    ]
                ),
                txt_total_geral,
                ft.Container(
                    height=3,
                    border_radius=2,
                    gradient=ft.LinearGradient(
                        begin=ft.Alignment(-1, 0),
                        end=ft.Alignment(1, 0),
                        colors=[C_ACCENT, ft.Colors.with_opacity(0.15, C_ACCENT)],
                    ),
                    margin=ft.Margin(top=4, bottom=2, left=0, right=0),
                ),
                txt_total_geral_sub,
            ],
        ),
    )

    def atualizar_painel():
        if turno_atual is None:
            return
        garantir_conexao()
        totais = db.obter_totais(conn, turno_atual.id)
        
        txt_dinheiro.value       = formatar_moeda(totais.dinheiro)
        txt_pix.value            = formatar_moeda(totais.pix)
        txt_cartoes.value       = formatar_moeda(totais.cartoes)
        lbl_cart.value          = f"CARTÕES ({totais.qtd_cartoes})"
        txt_requisicao.value    = formatar_moeda(totais.requisicao)
        txt_deposito_global.value = formatar_moeda(totais.deposito_global)
        txt_despesas.value        = formatar_moeda(totais.despesas)
        txt_total_geral.value   = formatar_moeda(totais.total_geral)
        
        txt_operador_nome.value = f"{_saudacao_hora()}, {turno_atual.operador}"
        txt_turno_data.value    = f"Aberto em {turno_atual.aberto_em}"
        badge_turno_pill.content.controls[1].value = f"Turno #{turno_atual.numero_do_dia}"
        txt_total_geral_sub.value = f"Turno #{turno_atual.numero_do_dia} · Aberto em {turno_atual.aberto_em}"
        
        if mobile:
            txt_rodape_resumo.value = f"Total geral · {formatar_moeda(totais.total_geral)}"

    # ═══════════════════════════════════════════════════════════════
    # SELETOR DE TIPO
    # ═══════════════════════════════════════════════════════════════
    def _eh_cartao(t: str) -> bool:
        return t in db.LISTA_CARTOES

    def criar_seletor_tipo(valor_inicial: str):
        estado = {
            "valor": valor_inicial,
            "mostrar_bandeiras": _eh_cartao(valor_inicial),
        }
        seletor_col = ft.Column(spacing=8, width=largura_conteudo)
        registro_chips = {}

        def _estilo(chave: str, selecionado: bool):
            if selecionado:
                return {
                    "bgcolor": C_ACCENT,
                    "border": borda_all(1.5, C_ACCENT_LIGHT),
                    "cor_conteudo": ft.Colors.WHITE,
                    "peso_texto": ft.FontWeight.BOLD,
                }
            return {
                "bgcolor": pal.surface,
                "border": borda_all(1, pal.border),
                "cor_conteudo": pal.text_sec,
                "peso_texto": ft.FontWeight.W_500,
            }

        def _montar_chip(chave: str, rotulo: str, selecionado: bool, ao_clicar):
            estilo = _estilo(chave, selecionado)
            icone_ctrl = ft.Icon(icone_tipo(chave), size=16, color=estilo["cor_conteudo"])
            texto_ctrl = ft.Text(
                rotulo, size=14, color=estilo["cor_conteudo"], weight=estilo["peso_texto"]
            )
            container = ft.Container(
                content=ft.Row(
                    spacing=6,
                    tight=True,
                    alignment=ft.MainAxisAlignment.CENTER,
                    controls=[icone_ctrl, texto_ctrl],
                ),
                bgcolor=estilo["bgcolor"],
                border_radius=100,
                border=estilo["border"],
                height=46,
                expand=True,
                alignment=ft.Alignment(0, 0),
                on_click=ao_clicar,
                scale=ft.Scale(scale=1),
                animate_scale=_animacao(150, ft.AnimationCurve.EASE_OUT),
                animate=_animacao(150, ft.AnimationCurve.EASE_OUT),
            )
            
            def hover_chip(e):
                e.control.scale = 1.05 if e.data == "true" else 1.0
                e.control.update()
                
            container.on_hover = hover_chip
            registro_chips[chave] = (container, icone_ctrl, texto_ctrl)
            return container

        def _chip(tipo: str):
            selecionado = tipo == estado["valor"]
            return _montar_chip(
                tipo, tipo, selecionado, lambda e, t=tipo: selecionar(t)
            )

        def _chip_cartao():
            selecionado = _eh_cartao(estado["valor"])
            return _montar_chip("__cartao__", "Cartão", selecionado, _alternar_cartao)

        bandeiras_novas = ["Fitcard", "Excard", "Amex", "Eucard", "Pix", "Avancard"]
        bandeiras_tela_venda = [c for c in db.LISTA_CARTOES if c not in bandeiras_novas] + [c for c in bandeiras_novas if c in db.LISTA_CARTOES]

        def _linha(tipos):
            return ft.Row(spacing=8, controls=[_chip(t) for t in tipos])

        def construir():
            registro_chips.clear()
            seletor_col.controls.clear()

            seletor_col.controls.append(_linha([db.TIPO_DINHEIRO, db.TIPO_PIX]))
            seletor_col.controls.append(_linha([db.TIPO_REQUISICAO, db.TIPO_DEPOSITO_GLOBAL]))
            seletor_col.controls.append(
                ft.Row(spacing=8, controls=[_chip(db.TIPO_DESPESA), _chip_cartao()])
            )

            if estado["mostrar_bandeiras"]:
                seletor_col.controls.append(
                    ft.Text("Escolha a bandeira", size=12, color=pal.text_ter,
                            weight=ft.FontWeight.W_600)
                )
                for i in range(0, len(bandeiras_tela_venda), 2):
                    seletor_col.controls.append(_linha(bandeiras_tela_venda[i:i + 2]))

        def _repintar_chip(chave: str, selecionado: bool):
            registrado = registro_chips.get(chave)
            if registrado is None:
                return
            container, icone_ctrl, texto_ctrl = registrado
            estilo = _estilo(chave, selecionado)
            container.bgcolor = estilo["bgcolor"]
            container.border = estilo["border"]
            icone_ctrl.color = estilo["cor_conteudo"]
            texto_ctrl.color = estilo["cor_conteudo"]
            texto_ctrl.weight = estilo["peso_texto"]

        def selecionar(tipo):
            anterior = estado["valor"]
            if tipo == anterior:
                return
            estado["valor"] = tipo
            salvar_ultimo_tipo(tipo)

            anterior_e_cartao = _eh_cartao(anterior)
            novo_e_cartao = _eh_cartao(tipo)

            if anterior_e_cartao != novo_e_cartao:
                estado["mostrar_bandeiras"] = novo_e_cartao
                construir()
                page.update()
                return

            _repintar_chip(anterior, False)
            _repintar_chip(tipo, True)
            page.update()

        def _alternar_cartao(e=None):
            if _eh_cartao(estado["valor"]):
                estado["mostrar_bandeiras"] = not estado["mostrar_bandeiras"]
                construir()
                page.update()
            else:
                selecionar(bandeiras_tela_venda[0])

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
        desfocar_campos(input_valor, input_desc)

    input_valor = ft.TextField(
        label="Valor (Ex: 50.00 ou 50,00)",
        width=largura_conteudo,
        prefix=ft.Text("R$ "),
        keyboard_type=_keyboard_valor,
        adaptive=adaptive_ui,
        autocorrect=False,
        enable_suggestions=False,
        input_filter=FILTRO_VALOR_MONETARIO,
        on_tap_outside=ao_tocar_fora,
    )

    input_desc = ft.TextField(
        label="Descrição / Placa (Opcional)",
        width=largura_conteudo,
        adaptive=adaptive_ui,
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
        desfocar_campos(input_valor, input_desc)
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

    # ═══════════════════════════════════════════════════════════════[...]
    # BOTÕES RÁPIDOS
    # ═══════════════════════════════════════════════════════════════[...]
    def _pill_btn(label, on_click, is_completou=False):
        cor_borda = ft.Colors.with_opacity(0.35, C_AMBER) if is_completou else ft.Colors.with_opacity(0.15, C_ACCENT)
        cor_texto = C_AMBER if is_completou else pal.text_sec
        cor_bg    = ft.Colors.with_opacity(0.10, C_AMBER) if is_completou else pal.surface
        
        container = ft.Container(
            content=ft.Text(label, size=14, color=cor_texto, weight=ft.FontWeight.W_500),
            bgcolor=cor_bg,
            border_radius=100,
            border=borda_all(1, cor_borda),
            padding=ft.Padding(left=16, right=16, top=9, bottom=9),
            scale=ft.Scale(scale=1),
            animate_scale=_animacao(200, ft.AnimationCurve.BOUNCE_OUT),
            on_click=on_click,
            animate=_animacao(120, ft.AnimationCurve.EASE_OUT),
        )

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
            _pill_btn("R$ 50", lambda e: set_valor("50.00")),
            _pill_btn("R$ 100", lambda e: set_valor("100.00")),
            _pill_btn("R$ 200", lambda e: set_valor("200.00")),
            _pill_btn("R$ 300", lambda e: set_valor("300.00")),
            _pill_btn("R$ 500", lambda e: set_valor("500.00")),
            _pill_btn("✓ Completou", acao_completou, is_completou=True),
        ]

    row_botoes_rapidos = ft.Row(
        wrap=True,
        alignment=ft.MainAxisAlignment.START,
        spacing=8,
        run_spacing=8,
        width=largura_conteudo,
        controls=[],
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

    # ══════════════════════════════════════════════════════════════��[...]
    # BOTÃO LANÇAR
    # ══════════════════════════════════════════════════════════════��[...]
    btn_lancar = ft.Container(
        content=ft.Row(
            alignment=ft.MainAxisAlignment.CENTER,
            spacing=10,
            controls=[
                ft.Icon(ft.Icons.ADD_SHOPPING_CART, color=ft.Colors.WHITE, size=20),
                ft.Text("Lançar", color=ft.Colors.WHITE, size=16,
                        weight=ft.FontWeight.W_600),
            ],
        ),
        bgcolor=None,
        gradient=ft.LinearGradient(
            begin=ft.Alignment(-1, 0),
            end=ft.Alignment(1, 0),
            colors=[C_ACCENT, C_ACCENT_DARK],
        ),
        border_radius=RADIUS,
        height=56,
        width=largura_conteudo,
        alignment=ft.Alignment(0, 0),
        shadow=_sombra(C_ACCENT, 20, 0.35, 4),
        scale=ft.Scale(scale=1),
        animate_scale=_animacao(150, ft.AnimationCurve.EASE_OUT),
        animate=_animacao(120, ft.AnimationCurve.EASE_OUT),
    )

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
            # atualizar_painel/carregar_historico não fazem page.update() sozinhos
            # aqui de propósito: a conexão já foi garantida acima e o update
            # final do "finally" (que sempre roda) já cobre esse refresh,
            # evitando uma ida e volta extra ao servidor a cada lançamento.
            atualizar_painel()
            carregar_historico()
            desfocar_campos(input_valor, input_desc)
        except Exception:
            mostrar_snackbar("Erro ao lançar. Tente novamente.", ft.Colors.RED_800)
        finally:
            btn_lancar.opacity = 1.0
            btn_lancar.scale = 1.0
            page.update()

    btn_lancar.on_click = acao_lancar
    input_valor.on_submit = acao_lancar
    input_desc.on_submit  = acao_lancar

    # ══════════════════════════════════════════════════════════════[...]
    # RESUMO / FECHAR CAIXA
    # ══════════════════════════════════════════════════════════════[...]
    def montar_conteudo_resumo(totais, detalhe_cartoes, ao_abrir_detalhe=None, ao_registrar_inputs=None):
        ao_abrir_detalhe = ao_abrir_detalhe or abrir_detalhe_bandeira
        tamanho_fonte_itens = 17
        tamanho_fonte_titulo = 18

        linhas_bandeiras = []
        for bandeira, (valor, qtd) in detalhe_cartoes.items():
            cor   = cor_tipo(bandeira)
            icone = icone_tipo(bandeira)
            
            cor_valor = pal.text_pri if valor > 0 else pal.text_ter
            peso_valor = ft.FontWeight.W_600 if valor > 0 else ft.FontWeight.NORMAL

            row_controls = [
                ft.Icon(icone, color=cor, size=19),
                ft.Text(
                    bandeira, size=15, width=135, color=pal.text_sec,
                    max_lines=1, overflow=ft.TextOverflow.ELLIPSIS,
                ),
                ft.Text(f"({qtd} un)", size=14, width=65, color=pal.text_ter),
                ft.Text(formatar_moeda(valor), size=16, color=cor_valor, weight=peso_valor, expand=True, text_align=ft.TextAlign.RIGHT),
                ft.Icon(ft.Icons.CHEVRON_RIGHT, color=pal.text_ter, size=18),
            ]

            linhas_bandeiras.append(
                ft.Container(
                    content=ft.Row(row_controls, spacing=10),
                    border_radius=RADIUS_SM,
                    padding=ft.Padding(left=4, right=4, top=6, bottom=6),
                    ink=True,
                    tooltip="Toque para ver e editar os lançamentos desta bandeira",
                    on_click=lambda e, b=bandeira: ao_abrir_detalhe(b),
                )
            )

        # Pix agora faz parte da categoria de Cartões/Vouchers, exibido como "Pag Pix"
        cor_pix = cor_tipo(db.TIPO_PIX)
        icone_pix = icone_tipo(db.TIPO_PIX)
        cor_valor_pix = pal.text_pri if totais.pix > 0 else pal.text_ter
        peso_valor_pix = ft.FontWeight.W_600 if totais.pix > 0 else ft.FontWeight.NORMAL
        
        row_controls_pix = [
            ft.Icon(icone_pix, color=cor_pix, size=19),
            ft.Text(
                "Pag Pix", size=15, width=135, color=pal.text_sec,
                max_lines=1, overflow=ft.TextOverflow.ELLIPSIS,
            ),
            ft.Text(f"({totais.qtd_pix} un)", size=14, width=65, color=pal.text_ter),
            ft.Text(formatar_moeda(totais.pix), size=16, color=cor_valor_pix, weight=peso_valor_pix, expand=True, text_align=ft.TextAlign.RIGHT),
            ft.Icon(ft.Icons.CHEVRON_RIGHT, color=pal.text_ter, size=18),
        ]

        linhas_bandeiras.append(
            ft.Container(
                content=ft.Row(row_controls_pix, spacing=10),
                border_radius=RADIUS_SM,
                padding=ft.Padding(left=4, right=4, top=6, bottom=6),
                ink=True,
                tooltip="Toque para ver e editar os lançamentos de Pix",
                on_click=lambda e: ao_abrir_detalhe(db.TIPO_PIX, "Pag Pix"),
            )
        )

        caixa_cartoes = glass_container(
            content=ft.Column(linhas_bandeiras, spacing=10),
            padding=14,
        )

        v_sis_ini = turno_atual.vendas_sistema if (turno_atual and turno_atual.vendas_sistema) else 0.0
        obs_ini = turno_atual.observacao if (turno_atual and turno_atual.observacao) else ""

        input_vendas_sistema = ft.TextField(
            label="TOTAL DE VENDAS SISTEMA",
            value=f"{v_sis_ini:.2f}".replace(".", ",") if v_sis_ini > 0 else "",
            keyboard_type=_keyboard_valor,
            input_filter=FILTRO_VALOR_MONETARIO,
            hint_text="0,00",
            border_color=pal.border_strong,
            focused_border_color=C_BLUE,
            color=pal.text_pri,
            prefix=ft.Text("R$ ", color=pal.text_sec, size=15),
            height=50,
            text_size=15,
        )

        input_observacao = ft.TextField(
            label="OBSERVAÇÕES / JUSTIFICATIVA",
            value=obs_ini,
            multiline=True,
            min_lines=2,
            max_lines=3,
            hint_text="Descreva justificativas de sobras/faltas ou observações do turno...",
            border_color=pal.border_strong,
            focused_border_color=C_BLUE,
            color=pal.text_pri,
            text_size=14,
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
            size=14,
        )

        container_diferenca = ft.Container(
            border_radius=RADIUS_SM,
            padding=12,
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
                container_diferenca.border = ft.Border.all(1, C_GREEN)
                txt_dif_valor.color = C_GREEN
                txt_dif_label.color = C_GREEN
                txt_dif_label.value = "DIFERENÇA (SEM DIFERENÇA):"
            elif dif > 0:
                container_diferenca.bgcolor = ft.Colors.with_opacity(0.12, C_ORANGE)
                container_diferenca.border = ft.Border.all(1, C_ORANGE)
                txt_dif_valor.color = C_ORANGE
                txt_dif_label.color = C_ORANGE
                txt_dif_label.value = "DIFERENÇA (SOBRA PISTA):"
            else:
                container_diferenca.bgcolor = ft.Colors.with_opacity(0.12, C_RED)
                container_diferenca.border = ft.Border.all(1, C_RED)
                txt_dif_valor.color = C_RED
                txt_dif_label.color = C_RED
                txt_dif_label.value = "DIFERENÇA (FALTA PISTA):"
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

        return ft.Column(
            tight=True, spacing=14,
            scroll=ft.ScrollMode.AUTO, expand=True,
            controls=[
                ft.Column(spacing=3, controls=[
                    ft.Text(f"Turno #{turno_atual.numero_do_dia} · Operador(a): {turno_atual.operador}",
                            size=16, color=pal.text_pri, weight=ft.FontWeight.BOLD),
                    ft.Text(f"Aberto em: {turno_atual.aberto_em}",
                            size=15, color=pal.text_ter),
                ]),
                
                ft.Divider(height=1, color=pal.border),
                
                ft.Text("Detalhe de Cartões, Vouchers e Pix", size=tamanho_fonte_titulo, color=pal.text_pri, weight=ft.FontWeight.BOLD),
                caixa_cartoes,
                ft.Row([ft.Icon(ft.Icons.CREDIT_CARD, color=C_ORANGE, size=22),
                        ft.Text(f"Total Cartões ({totais.qtd_cartoes} un):", expand=True, size=tamanho_fonte_itens, color=pal.text_sec),
                        ft.Text(formatar_moeda(totais.cartoes), size=tamanho_fonte_itens, weight=ft.FontWeight.BOLD, color=pal.text_pri)]),
                
                ft.Divider(height=1, color=pal.border),
                
                ft.Row([ft.Icon(ft.Icons.MONEY, color=C_GREEN, size=22),
                        ft.Text("Sobra de Dinheiro:", size=tamanho_fonte_itens, expand=True, color=pal.text_sec),
                        ft.Text(formatar_moeda(totais.fisico), size=tamanho_fonte_itens, weight=ft.FontWeight.BOLD, color=pal.text_pri)]),
                ft.Row([ft.Icon(ft.Icons.RECEIPT_LONG, color=C_PURPLE, size=22),
                        ft.Text("Requisição:", size=tamanho_fonte_itens, expand=True, color=pal.text_sec),
                        ft.Text(formatar_moeda(totais.requisicao), size=tamanho_fonte_itens, weight=ft.FontWeight.BOLD, color=pal.text_pri)]),
                ft.Row([ft.Icon(ft.Icons.ACCOUNT_BALANCE, color=C_BROWN, size=22),
                        ft.Text("Depósito Global:", size=tamanho_fonte_itens, expand=True, color=pal.text_sec),
                        ft.Text(formatar_moeda(totais.deposito_global), size=tamanho_fonte_itens, weight=ft.FontWeight.BOLD, color=pal.text_pri)]),
                ft.Row([ft.Icon(ft.Icons.MONEY_OFF, color=C_RED, size=22),
                        ft.Text("Despesas:", size=tamanho_fonte_itens, expand=True, color=pal.text_sec),
                        ft.Text(formatar_moeda(totais.despesas), size=tamanho_fonte_itens, weight=ft.FontWeight.BOLD, color=pal.text_pri)]),
                
                ft.Divider(height=6, color=pal.border),
                
                # ── CONCILIAÇÃO DE VENDAS (PISTA vs. SISTEMA) ───────────────────
                ft.Text("Conciliação de Vendas do Caixa", size=tamanho_fonte_titulo, color=pal.text_pri, weight=ft.FontWeight.BOLD),
                
                # 1. TOTAL DE VENDAS PISTA (Calculado pelo App)
                ft.Container(
                    bgcolor=ft.Colors.with_opacity(0.12, C_BLUE),
                    border=ft.Border.all(1.2, C_BLUE),
                    border_radius=RADIUS_SM,
                    padding=12,
                    content=ft.Row([
                        ft.Icon(ft.Icons.POINT_OF_SALE, color=C_BLUE, size=22),
                        ft.Text("TOTAL DE VENDAS PISTA:", expand=True, weight=ft.FontWeight.BOLD, size=14, color=pal.text_pri),
                        ft.Text(formatar_moeda(totais.total_geral), weight=ft.FontWeight.BOLD, size=18, color=C_BLUE)
                    ])
                ),

                # 2. TOTAL DE VENDAS SISTEMA (Digitado pelo operador)
                input_vendas_sistema,

                # 3. DIFERENÇA (Pista - Sistema)
                container_diferenca,

                ft.Divider(height=4, color=pal.border),

                # 4. OBSERVAÇÕES / JUSTIFICATIVA
                input_observacao,
                
                ft.Container(height=10),
            ],
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
                if dlg_resumo: page.close(dlg_resumo)
                if sheet_resumo: page.close(sheet_resumo)
            except Exception:
                pass
            if dlg_resumo:
                dlg_resumo.open = False
            if sheet_resumo:
                sheet_resumo.open = False
            page.update()
            if dlg_resumo:
                _agendar_limpeza_overlay(dlg_resumo)
            if sheet_resumo:
                _agendar_limpeza_overlay(sheet_resumo)

        def abrir_detalhe_a_partir_do_resumo(tipo, rotulo=None):
            if mobile and not ios:
                fechar_resumo()
                async def _reabrir_detalhe():
                    import asyncio
                    await asyncio.sleep(0.15)
                    abrir_detalhe_bandeira(tipo, rotulo, ao_fechar=acao_fechar_caixa)
                page.run_task(_reabrir_detalhe)
            else:
                abrir_detalhe_bandeira(tipo, rotulo)

        def copiar_resumo(x):
            async def _copiar_async():
                try:
                    await ft.Clipboard().set(resumo)
                    mostrar_snackbar("Resumo copiado para a área de transferência")
                except Exception:
                    mostrar_snackbar("Não foi possível copiar o resumo")

            page.run_task(_copiar_async)

        def compartilhar_pdf(e=None):
            if turno_atual is None:
                mostrar_snackbar("Nenhum turno para exportar.")
                return
            try:
                garantir_conexao()
                v_val = validar_valor_monetario(ref_vendas_sis["control"].value or "0") if ref_vendas_sis["control"] else (turno_atual.vendas_sistema or 0.0)
                obs_val = (ref_obs["control"].value or "") if ref_obs["control"] else (turno_atual.observacao or "")
                turno_atual.vendas_sistema = v_val
                turno_atual.observacao = obs_val
                db.salvar_auditoria_turno(conn, turno_atual.id, v_val, obs_val)

                caminho_pdf = db.exportar_turno_pdf(conn, turno_atual.id)
            except Exception as ex:
                mostrar_snackbar(f"Erro ao gerar PDF: {ex}", ft.Colors.RED_800)
                return

            mostrar_snackbar("Gerando compartilhamento do PDF...")

            async def _share_async():
                try:
                    if compartilhar_servico is not None and hasattr(compartilhar_servico, "share_files"):
                        await compartilhar_servico.share_files([caminho_pdf])
                    elif compartilhar_servico is not None and hasattr(compartilhar_servico, "share_files_async"):
                        await compartilhar_servico.share_files_async([caminho_pdf])
                    else:
                        mostrar_snackbar(f"PDF gerado com sucesso em: {caminho_pdf}")
                except Exception as err:
                    mostrar_snackbar(f"PDF gerado e salvo em: {caminho_pdf}")

            page.run_task(_share_async)

        def encerrar_turno(x):
            nonlocal turno_atual
            if _em_andamento["valor"] or turno_atual is None:
                return
            _em_andamento["valor"] = True
            try:
                garantir_conexao()
                turno_id_encerrado = turno_atual.id
                operador_encerrado = turno_atual.operador

                v_val = validar_valor_monetario(ref_vendas_sis["control"].value or "0") if ref_vendas_sis["control"] else (turno_atual.vendas_sistema or 0.0)
                obs_val = (ref_obs["control"].value or "") if ref_obs["control"] else (turno_atual.observacao or "")
                turno_atual.vendas_sistema = v_val
                turno_atual.observacao = obs_val
                db.salvar_auditoria_turno(conn, turno_id_encerrado, v_val, obs_val)

                # Gera o PDF do fechamento
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

        conteudo_resumo = montar_conteudo_resumo(totais, detalhe_cart, abrir_detalhe_a_partir_do_resumo, ao_registrar_inputs=registrar_inputs)

        btn_copiar = ft.TextButton(
            content=ft.Row([ft.Icon(ft.Icons.CONTENT_COPY, size=16), ft.Text("Copiar resumo")],
                           tight=True),
            on_click=copiar_resumo,
        )

        btn_compartilhar_pdf = ft.TextButton(
            content=ft.Row([ft.Icon(ft.Icons.SHARE, size=16), ft.Text("Compartilhar PDF")], tight=True),
            on_click=compartilhar_pdf,
        )

        btn_encerrar = ft.TextButton("Encerrar turno", on_click=encerrar_turno)
        btn_fechar = ft.TextButton("Fechar", on_click=fechar_resumo)

        painel_resumo = ft.Container(
            expand=True,
            padding=ft.Padding(20, 12, 20, 30),
            bgcolor=pal.sheet_bg,
            content=ft.Column(
                expand=True,
                spacing=14,
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                controls=[
                    ft.Text("Resumo do Turno", size=18, weight=ft.FontWeight.BOLD, color=pal.text_pri),
                    conteudo_resumo,
                    ft.Divider(height=1),
                    ft.Row(
                        [btn_copiar, btn_encerrar, btn_fechar],
                        alignment=ft.MainAxisAlignment.CENTER,
                        wrap=True, spacing=6, run_spacing=4,
                    ),
                ],
            ),
        )

        if not mobile:
            dlg_resumo = ft.AlertDialog(
                title=ft.Text("Resumo do Turno"),
                content=ft.Container(
                    content=conteudo_resumo,
                    width=450,
                    height=600,
                ),
                actions=[btn_copiar, btn_encerrar, btn_fechar],
            )
            abrir_dialogo(dlg_resumo)
        else:
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
                    ft.Icons.ASSESSMENT_ROUNDED,
                    "Fechar Caixa & Resumo",
                    "Conferir totais, sangrias e conciliação do turno",
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
        controls=[icone_posto, txt_header_titulo, btn_tema, btn_menu],
        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
        vertical_alignment=ft.CrossAxisAlignment.CENTER,
        spacing=10,
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
            keyboard_type=ft.KeyboardType.NUMBER,
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

        lista_ctrl = ft.Column(spacing=8)
        txt_sub_info = ft.Text("", size=13, color=pal.text_sec)

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
            itens = db.listar_historico(conn, turno_atual.id, limite=100)
            lista_ctrl.controls.clear()
            txt_sub_info.value = f"{len(itens)} lançamento{'s' if len(itens) != 1 else ''} no turno atual"

            if not itens:
                lista_ctrl.controls.append(
                    ft.Container(
                        content=ft.Column(
                            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                            spacing=6,
                            controls=[
                                ft.Icon(ft.Icons.RECEIPT_ROUNDED, size=40, color=pal.text_ter),
                                ft.Text("Nenhum lançamento no turno atual", size=14, color=pal.text_sec),
                            ]
                        ),
                        padding=30,
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

        renderizar_itens()

        largura_modal = min(440, largura_conteudo)
        btn_fechar = ft.TextButton("Fechar", on_click=fechar_hist)

        if not mobile:
            dlg_hist = ft.AlertDialog(
                title=ft.Row(
                    [
                        ft.Icon(ft.Icons.RECEIPT_LONG_ROUNDED, color=C_ACCENT, size=22),
                        ft.Text("Histórico Recente", weight=ft.FontWeight.BOLD, color=pal.text_pri),
                    ],
                    spacing=8,
                ),
                content=ft.Container(
                    content=ft.Column(
                        tight=True,
                        spacing=10,
                        scroll=ft.ScrollMode.AUTO,
                        controls=[
                            txt_sub_info,
                            ft.Divider(height=1, color=pal.border),
                            lista_ctrl,
                        ],
                    ),
                    width=largura_modal,
                    height=460,
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
                    spacing=14,
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                    controls=[
                        ft.Container(
                            width=36, height=4, border_radius=2,
                            bgcolor=pal.border_strong,
                        ),
                        ft.Row(
                            [
                                ft.Icon(ft.Icons.RECEIPT_LONG_ROUNDED, color=C_ACCENT, size=22),
                                ft.Text("Histórico Recente", size=18, weight=ft.FontWeight.BOLD, color=pal.text_pri),
                            ],
                            spacing=8,
                            alignment=ft.MainAxisAlignment.CENTER,
                        ),
                        txt_sub_info,
                        ft.Divider(height=1, color=pal.border),
                        ft.Container(
                            content=ft.Column(
                                controls=[lista_ctrl],
                                scroll=ft.ScrollMode.AUTO,
                                expand=True,
                            ),
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
                ft.Container(height=30),
                ft.Container(
                    content=ft.Icon(ft.Icons.LOCAL_GAS_STATION, color=C_ACCENT_LIGHT, size=50),
                    bgcolor=ft.Colors.with_opacity(0.12, C_ACCENT),
                    border_radius=30,
                    padding=20,
                    border=borda_all(1, ft.Colors.with_opacity(0.20, C_ACCENT)),
                    shadow=_sombra(C_ACCENT, 20, 0.20, 4),
                ),
                ft.Container(height=8),
                ft.Text("Posto Janjão", size=28, weight=ft.FontWeight.BOLD, color=pal.text_pri),
                ft.Text("Pronto para começar o dia?", size=14, color=pal.text_sec),
                ft.Container(height=24),
                ft.Container(
                    content=ft.Row(
                        tight=True,
                        spacing=8,
                        alignment=ft.MainAxisAlignment.CENTER,
                        controls=[
                            ft.Icon(ft.Icons.PLAY_ARROW, color=ft.Colors.WHITE, size=20),
                            ft.Text("Abrir Novo Turno", color=ft.Colors.WHITE, size=15,
                                    weight=ft.FontWeight.W_600),
                        ],
                    ),
                    gradient=ft.LinearGradient(
                        begin=ft.Alignment(-1, 0),
                        end=ft.Alignment(1, 0),
                        colors=[C_ACCENT, C_ACCENT_DARK],
                    ),
                    border_radius=RADIUS_SM,
                    padding=ft.Padding(28, 16, 28, 16),
                    on_click=lambda e: solicitar_identificacao(novo_turno=True),
                    shadow=_sombra(C_ACCENT, 20, 0.30, 4),
                    scale=ft.Scale(scale=1),
                    animate_scale=_animacao(150, ft.AnimationCurve.EASE_OUT),
                    animate=_animacao(120, ft.AnimationCurve.EASE_OUT),
                ),
            ]
            if ultimo_fechado:
                controles_fechado.append(ft.Container(height=15))
                controles_fechado.append(
                    ft.TextButton(
                        content=ft.Row(
                            tight=True, spacing=4,
                            alignment=ft.MainAxisAlignment.CENTER,
                            controls=[
                                ft.Icon(ft.Icons.HISTORY, size=14, color=pal.text_ter),
                                ft.Text("Histórico de turnos / Reabrir anterior", size=12, color=pal.text_ter),
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

            def hover_btn_abrir(e):
                e.control.scale = 1.05 if e.data == "true" else 1.0
                e.control.update()
            tela_fechado.controls[7].on_hover = hover_btn_abrir

            if mobile:
                page.add(ft.SafeArea(tela_fechado))
            else:
                page.add(tela_fechado)

            rodape_lancar = None

            aplicar_largura()
            page.update()
            return

        btn_tema.content.icon = icone_tema_atual

        cor_accent_atual = C_ACCENT_LIGHT if tema_escuro() else C_ACCENT
        cor_despesa_atual = ft.Colors.RED_400 if tema_escuro() else ft.Colors.RED_700

        txt_turno_data.color = pal.text_sec
        txt_operador_nome.color = pal.text_pri
        txt_total_geral.color = pal.text_pri
        
        for card, txt_val, lbl, cor_badge in (
            (stat_din_card, txt_dinheiro, lbl_din, cor_accent_atual),
            (stat_pix_card, txt_pix, lbl_pix, cor_accent_atual),
            (stat_cart_card, txt_cartoes, lbl_cart, cor_accent_atual),
            (stat_req_card, txt_requisicao, lbl_req, cor_accent_atual),
            (stat_dep_card, txt_deposito_global, lbl_dep, cor_accent_atual),
            (stat_desp_card, txt_despesas, lbl_desp, cor_despesa_atual),
        ):
            card.bgcolor = pal.surface
            card.border = borda_all(1, pal.border)
            txt_val.color = pal.text_pri
            lbl.color = pal.text_sec
            badge_cnt = card.content.controls[0].controls[0]
            badge_cnt.content.color = cor_badge
            badge_cnt.bgcolor = ft.Colors.with_opacity(0.12, cor_badge)
            
        txt_total_geral_label.color = pal.text_sec
        txt_total_geral_sub.color = pal.text_ter
        total_geral_card.bgcolor = pal.surface
        total_geral_card.border = borda_all(1, pal.border)
        txt_header_titulo.color = pal.text_pri
        btn_tema.content.icon_color = pal.text_sec
        btn_tema.bgcolor = pal.surface
        btn_tema.border = borda_all(1, pal.border)
        btn_menu.content.icon_color = pal.text_sec
        btn_menu.bgcolor = pal.surface
        btn_menu.border = borda_all(1, pal.border)
        for div in (div_top, div_mid, div_bot):
            div.bgcolor = pal.border
        floating_bottom_bar.bgcolor = pal.sheet_bg
        floating_bottom_bar.border = borda_all(1, pal.border)

        controles_scroll = [
            header,
            info_turno_card,
            total_geral_card,
            stats_grid,
            div_top,
            seletor_col,
            input_valor,
            row_botoes_rapidos,
            input_desc,
            btn_lancar,
            ft.Container(height=85),
        ]

        area_scroll = ft.Column(
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            spacing=10,
            controls=controles_scroll,
            scroll=ft.ScrollMode.HIDDEN if mobile else ft.ScrollMode.AUTO,
            expand=True,
        )

        rodape_flutuante = ft.Container(
            content=floating_bottom_bar,
            bottom=16,
            left=0,
            right=0,
            alignment=ft.Alignment(0, 0),
        )

        conteudo_com_barra = ft.Stack(
            controls=[
                area_scroll,
                rodape_flutuante,
            ],
            expand=True,
            width=largura_conteudo,
        )

        if mobile:
            raiz = ft.SafeArea(conteudo_com_barra)
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
        texto_erro = ft.Text("", color=ft.Colors.RED_400, size=12, weight=ft.FontWeight.W_600)

        def validar_acesso(e=None):
            if not tem_pin or campo_pin.value == pin_configurado:
                nonlocal turno_atual, autenticado
                autenticado = True

                nome_digitado = (campo_nome.value or "").strip() or "Não informado"

                fechar_dialogo(dlg_acesso)

                if novo_turno:
                    turno_atual = db.abrir_novo_turno(conn, nome_digitado)
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
                        turno_atual = db.abrir_novo_turno(conn, nome_digitado)

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
        # No computador, definimos a porta e o view
        porta = int(os.environ.get("PORT", 5000))
        ft.run(main=main_seguro, port=porta, host="0.0.0.0")