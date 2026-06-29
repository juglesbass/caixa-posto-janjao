import os
from types import SimpleNamespace

import flet as ft

import db


def _app_mobile() -> bool:
    return os.environ.get("FLET_PLATFORM", "") in ("ios", "android")


def criar_paleta(escuro: bool) -> SimpleNamespace:
    if escuro:
        return SimpleNamespace(
            bg="#0a0a0f",
            surface=ft.Colors.with_opacity(0.06, ft.Colors.WHITE),
            border=ft.Colors.with_opacity(0.11, ft.Colors.WHITE),
            border_strong=ft.Colors.with_opacity(0.35, ft.Colors.WHITE),
            text_pri="#f2f2f7",
            text_sec=ft.Colors.with_opacity(0.80, "#f2f2f7"),
            text_ter=ft.Colors.with_opacity(0.65, "#f2f2f7"),
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


# ── Acentos (funcionam em ambos os temas) ──────────────────────────────────

# Acento por categoria
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

RADIUS    = 18
RADIUS_SM = 12

FILTRO_VALOR_MONETARIO = ft.InputFilter(
    allow=True,
    regex_string=r"^[\d.,]*$",
    replacement_string="",
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

    page.title = "Caixa - Posto Janjão"
    if adaptive_ui:
        page.adaptive = True
    page.theme = ft.Theme(color_scheme_seed=ft.Colors.BLUE_700, use_material3=True)
    page.dark_theme = ft.Theme(color_scheme_seed=ft.Colors.BLUE_400, use_material3=True)

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
        ft.Padding.only(left=16, right=16, top=8, bottom=0 if mobile else 16)
        if mobile
        else ft.Padding.only(left=20, right=20, top=54, bottom=20)
    )

    if mobile:
        async def fixar_retrato():
            try:
                await page.set_allowed_device_orientations([ft.DeviceOrientation.PORTRAIT_UP])
            except Exception:
                pass

        page.run_task(fixar_retrato)

    conn = db.conectar()
    db.inicializar_banco(conn)
    turno_atual = db.obter_ou_criar_turno_aberto(conn)

    pin_configurado = os.environ.get("CAIXA_PIN", "").strip()
    autenticado = not pin_configurado
    largura_conteudo = 380

    # ── Conexão viva ────────────────────────────────────────────────────────
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
        seletor_col.width = w
        input_valor.width = w
        input_desc.width = w
        row_botoes_rapidos.width = w
        col_agrupada.width = w
        col_historico.width = w
        btn_lancar.width = w
        if mobile:
            rodape_lancar.width = w
        hero_card.width = w
        total_geral_card.width = w
        stats_grid.width = w
        txt_turno.width = w
        page.update()

    def mostrar_snackbar(mensagem: str, cor=ft.Colors.GREEN_700):
        page.show_dialog(
            ft.SnackBar(
                content=ft.Text(mensagem, color=ft.Colors.WHITE),
                bgcolor=cor,
                duration=2500,
            )
        )

    def abrir_dialogo(dlg):
        page.show_dialog(dlg)

    def fechar_dialogo(dlg):
        page.pop_dialog()

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

    # ── Mapa de cores / ícones por tipo ────────────────────────────────────
    CORES = {
        db.TIPO_DINHEIRO:        C_GREEN,
        db.TIPO_PIX:             C_BLUE,
        db.TIPO_REQUISICAO:      C_PURPLE,
        db.TIPO_SODEXO:          C_TEAL,
        db.TIPO_DEPOSITO_GLOBAL: C_BROWN,
        "Master Crédito":        C_RED,
        "Master Débito":         C_ORANGE,
        "Visa Crédito":          C_INDIGO,
        "Visa Débito":           C_INDIGO2,
        "Elo Crédito":           C_AMBER,
        "Elo Débito":            C_AMBER2,
    }

    ICONES = {
        db.TIPO_DINHEIRO:        ft.Icons.MONEY,
        db.TIPO_PIX:             ft.Icons.PIX,
        db.TIPO_REQUISICAO:      ft.Icons.RECEIPT_LONG,
        db.TIPO_SODEXO:          ft.Icons.LUNCH_DINING,
        db.TIPO_DEPOSITO_GLOBAL: ft.Icons.ACCOUNT_BALANCE,
    }

    def cor_tipo(tipo: str) -> str:
        return CORES.get(tipo, C_ORANGE)

    def icone_tipo(tipo: str):
        return ICONES.get(tipo, ft.Icons.CREDIT_CARD)

    def formatar_moeda(valor: float) -> str:
        return db.formatar_moeda(valor)

    # ── Helper: container vidro ─────────────────────────────────────────────
    def glass_container(content, padding=16, radius=RADIUS_SM, border_color=pal.border, bgcolor=pal.surface):
        return ft.Container(
            content=content,
            bgcolor=bgcolor,
            border_radius=radius,
            border=ft.Border(
                left=ft.BorderSide(1, border_color),
                right=ft.BorderSide(1, border_color),
                top=ft.BorderSide(1, border_color),
                bottom=ft.BorderSide(1, border_color),
            ),
            padding=padding,
        )

    # ══════════════════════════════════════════════════════════════════
    # HERO — Dinheiro físico
    # ══════════════════════════════════════════════════════════════════
    txt_fisico_label = ft.Text(
        "💵  Físico na Carteira",
        size=13,
        color=pal.text_sec,
        weight=ft.FontWeight.W_500,
    )
    txt_fisico = ft.Text(
        "R$ 0,00",
        size=52,
        weight=ft.FontWeight.BOLD,
        color=C_GREEN,
        font_family="SF Pro Display",
    )
    txt_turno = ft.Text(
        "",
        size=13,
        color=pal.text_sec,
        width=largura_conteudo,
    )

    hero_card = ft.Container(
        width=largura_conteudo,
        border_radius=RADIUS,
        border=ft.Border(
            left=ft.BorderSide(1, ft.Colors.with_opacity(0.22, C_GREEN)),
            right=ft.BorderSide(1, ft.Colors.with_opacity(0.22, C_GREEN)),
            top=ft.BorderSide(1, ft.Colors.with_opacity(0.35, C_GREEN)),
            bottom=ft.BorderSide(1, ft.Colors.with_opacity(0.12, C_GREEN)),
        ),
        gradient=ft.LinearGradient(
            begin=ft.Alignment(-1, -1),
            end=ft.Alignment(1, 1),
            colors=[
                ft.Colors.with_opacity(0.16, C_GREEN),
                ft.Colors.with_opacity(0.06, C_GREEN),
                ft.Colors.with_opacity(0.08, C_BLUE),
            ],
        ),
        padding=ft.Padding.only(left=20, right=20, top=22, bottom=18),
        content=ft.Column(
            spacing=4,
            controls=[
                txt_fisico_label,
                txt_fisico,
                txt_turno,
            ],
        ),
    )

    # ══════════════════════════════════════════════════════════════════
    # STATS GRID — PIX / Cartões / Requisição / Depósito
    # ══════════════════════════════════════════════════════════════════
    def _stat_card(label: str, cor: str):
        lbl = ft.Text(label.upper(), size=12, color=pal.text_ter, weight=ft.FontWeight.W_600)
        txt = ft.Text("R$ 0,00", size=22, weight=ft.FontWeight.BOLD, color=cor)
        card = ft.Container(
            content=ft.Column(
                spacing=4,
                controls=[lbl, txt],
            ),
            bgcolor=pal.surface,
            border_radius=RADIUS_SM,
            border=ft.Border(
                left=ft.BorderSide(1, ft.Colors.with_opacity(0.18, cor)),
                right=ft.BorderSide(1, ft.Colors.with_opacity(0.18, cor)),
                top=ft.BorderSide(1, ft.Colors.with_opacity(0.18, cor)),
                bottom=ft.BorderSide(1, ft.Colors.with_opacity(0.18, cor)),
            ),
            padding=ft.Padding.only(left=14, right=14, top=13, bottom=13),
            expand=True,
        )
        return card, txt, lbl

    stat_pix_card, txt_pix, lbl_pix = _stat_card("PIX", C_BLUE)
    stat_cart_card, txt_cartoes, lbl_cart = _stat_card("Cartões", C_ORANGE)
    stat_req_card, txt_requisicao, lbl_req = _stat_card("Requisição", C_PURPLE)
    stat_dep_card, txt_deposito_global, lbl_dep = _stat_card("Depósito Global", C_BROWN)

    stats_grid = ft.Column(
        spacing=10,
        width=largura_conteudo,
        controls=[
            ft.Row(spacing=10, controls=[stat_pix_card, stat_cart_card]),
            ft.Row(spacing=10, controls=[stat_req_card, stat_dep_card]),
        ],
    )

    # ══════════════════════════════════════════════════════════════════
    # TOTAL GERAL
    # ══════════════════════════════════════════════════════════════════
    txt_total_geral = ft.Text(
        "R$ 0,00",
        size=22,
        weight=ft.FontWeight.BOLD,
        color=C_GREEN,
    )

    txt_total_geral_label = ft.Text(
        "Total Geral", size=15, weight=ft.FontWeight.W_600, color=pal.text_pri
    )

    total_geral_card = ft.Container(
        width=largura_conteudo,
        border_radius=RADIUS_SM,
        gradient=ft.LinearGradient(
            begin=ft.Alignment(-1, 0),
            end=ft.Alignment(1, 0),
            colors=[
                ft.Colors.with_opacity(0.20, C_GREEN),
                ft.Colors.with_opacity(0.08, C_GREEN),
            ],
        ),
        border=ft.Border(
            left=ft.BorderSide(1, ft.Colors.with_opacity(0.30, C_GREEN)),
            right=ft.BorderSide(1, ft.Colors.with_opacity(0.30, C_GREEN)),
            top=ft.BorderSide(1, ft.Colors.with_opacity(0.30, C_GREEN)),
            bottom=ft.BorderSide(1, ft.Colors.with_opacity(0.30, C_GREEN)),
        ),
        padding=ft.Padding.only(left=16, right=16, top=13, bottom=13),
        content=ft.Row(
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
            vertical_alignment=ft.CrossAxisAlignment.CENTER,
            controls=[
                ft.Row(
                    spacing=10,
                    controls=[
                        ft.Container(
                            content=ft.Icon(ft.Icons.ACCOUNT_BALANCE_WALLET, color=C_GREEN, size=20),
                            bgcolor=ft.Colors.with_opacity(0.20, C_GREEN),
                            border_radius=10,
                            padding=7,
                        ),
                        txt_total_geral_label,
                    ],
                ),
                txt_total_geral,
            ],
        ),
    )

    def atualizar_painel():
        nonlocal turno_atual
        turno_atual = db.obter_ou_criar_turno_aberto(conn)
        totais = db.obter_totais(conn, turno_atual.id)
        txt_fisico.value        = formatar_moeda(totais.fisico)
        txt_pix.value           = formatar_moeda(totais.pix)
        txt_cartoes.value       = formatar_moeda(totais.cartoes)
        txt_requisicao.value    = formatar_moeda(totais.requisicao)
        txt_deposito_global.value = formatar_moeda(totais.deposito_global)
        txt_total_geral.value   = formatar_moeda(totais.total_geral)
        txt_turno.value         = f"Turno #{turno_atual.id} · aberto em {turno_atual.aberto_em}"
        if mobile:
            txt_rodape_resumo.value = f"Total geral · {formatar_moeda(totais.total_geral)}"
        page.update()

    # ══════════════════════════════════════════════════════════════════
    # SELETOR DE TIPO — chips estilo iOS
    # ══════════════════════════════════════════════════════════════════
    def criar_seletor_tipo(valor_inicial: str):
        estado = {"valor": valor_inicial}
        seletor_col = ft.Column(spacing=8, width=largura_conteudo)

        def _chip(tipo: str):
            cor = cor_tipo(tipo)
            icone = icone_tipo(tipo)
            selecionado = tipo == estado["valor"]

            return ft.Container(
                content=ft.Row(
                    spacing=6,
                    tight=True,
                    alignment=ft.MainAxisAlignment.CENTER,
                    controls=[
                        ft.Icon(
                            icone,
                            size=14,
                            color=ft.Colors.WHITE if selecionado else cor,
                        ),
                        ft.Text(
                            tipo,
                            size=12,
                            color=ft.Colors.WHITE if selecionado else cor,
                            weight=ft.FontWeight.W_600 if selecionado else ft.FontWeight.W_500,
                        ),
                    ],
                ),
                bgcolor=cor if selecionado else ft.Colors.with_opacity(0.12, cor),
                border_radius=RADIUS_SM,
                border=ft.Border(
                    left=ft.BorderSide(1.5 if selecionado else 1,
                                       cor if selecionado else ft.Colors.with_opacity(0.35, cor)),
                    right=ft.BorderSide(1.5 if selecionado else 1,
                                        cor if selecionado else ft.Colors.with_opacity(0.35, cor)),
                    top=ft.BorderSide(1.5 if selecionado else 1,
                                      cor if selecionado else ft.Colors.with_opacity(0.35, cor)),
                    bottom=ft.BorderSide(1.5 if selecionado else 1,
                                         cor if selecionado else ft.Colors.with_opacity(0.35, cor)),
                ),
                height=46,
                expand=True,
                alignment=ft.Alignment(0, 0),
                on_click=lambda e, t=tipo: selecionar(t),
                animate=ft.Animation(150, ft.AnimationCurve.EASE_OUT),
            )

        def _linha(tipos):
            return ft.Row(spacing=8, controls=[_chip(t) for t in tipos])

        def construir():
            seletor_col.controls.clear()
            principais = [
                db.TIPO_DINHEIRO, db.TIPO_PIX,
                db.TIPO_REQUISICAO, db.TIPO_DEPOSITO_GLOBAL,
            ]
            for i in range(0, len(principais), 2):
                seletor_col.controls.append(_linha(principais[i:i+2]))

            seletor_col.controls.append(
                ft.Text("Cartões", size=13, color=pal.text_ter,
                        weight=ft.FontWeight.W_600)
            )
            for i in range(0, len(db.LISTA_CARTOES), 2):
                seletor_col.controls.append(_linha(db.LISTA_CARTOES[i:i+2]))

        def selecionar(tipo):
            estado["valor"] = tipo
            salvar_ultimo_tipo(tipo)
            construir()
            page.update()

        construir()
        return seletor_col, estado, selecionar, construir

    tipo_inicial = carregar_ultimo_tipo()
    seletor_col, estado_tipo, selecionar_tipo, reconstruir_seletor = criar_seletor_tipo(tipo_inicial)

    # ══════════════════════════════════════════════════════════════════
    # INPUTS
    # ══════════════════════════════════════════════════════════════════
    _keyboard_valor = (
        ft.KeyboardType.WEB_SEARCH
        if page.platform == ft.PagePlatform.IOS
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
        token = str(_blur_token)
        for campo in campos:
            campo.blur = token

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

    # ══════════════════════════════════════════════════════════════════
    # BOTÕES RÁPIDOS
    # ══════════════════════════════════════════════════════════════════
    def _pill_btn(label, on_click, is_completou=False):
        cor_borda = ft.Colors.with_opacity(0.35, C_GREEN) if is_completou else pal.border_strong
        cor_texto = C_GREEN if is_completou else pal.text_sec
        cor_bg    = ft.Colors.with_opacity(0.10, C_GREEN) if is_completou else pal.surface
        return ft.Container(
            content=ft.Text(label, size=14, color=cor_texto, weight=ft.FontWeight.W_500),
            bgcolor=cor_bg,
            border_radius=100,
            border=ft.Border(
                left=ft.BorderSide(1, cor_borda), right=ft.BorderSide(1, cor_borda),
                top=ft.BorderSide(1, cor_borda),  bottom=ft.BorderSide(1, cor_borda),
            ),
            padding=ft.Padding.only(left=16, right=16, top=9, bottom=9),
            on_click=on_click,
            animate=ft.Animation(120, ft.AnimationCurve.EASE_OUT),
        )

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

    # ══════════════════════════════════════════════════════════════════
    # LISTAS (Column — evita scroll duplo no iOS)
    # ══════════════════════════════════════════════════════════════════
    col_agrupada = ft.Column(spacing=6, width=largura_conteudo)
    col_historico = ft.Column(spacing=6, width=largura_conteudo)

    def _list_tile_agrupado(tipo, valor_total):
        cor   = cor_tipo(tipo)
        icone = icone_tipo(tipo)
        return ft.Container(
            content=ft.Row(
                alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
                vertical_alignment=ft.CrossAxisAlignment.CENTER,
                controls=[
                    ft.Row(
                        spacing=10,
                        controls=[
                            ft.Container(
                                content=ft.Icon(icone, color=cor, size=17),
                                bgcolor=ft.Colors.with_opacity(0.14, cor),
                                border_radius=9,
                                padding=7,
                            ),
                            ft.Text(tipo, size=14, color=cor, weight=ft.FontWeight.W_600),
                        ],
                    ),
                    ft.Text(formatar_moeda(valor_total), size=15, color=cor,
                            weight=ft.FontWeight.BOLD),
                ],
            ),
            bgcolor=pal.surface,
            border_radius=RADIUS_SM,
            border=ft.Border(
                left=ft.BorderSide(1, ft.Colors.with_opacity(0.16, cor)),
                right=ft.BorderSide(1, ft.Colors.with_opacity(0.16, cor)),
                top=ft.BorderSide(1, ft.Colors.with_opacity(0.16, cor)),
                bottom=ft.BorderSide(1, ft.Colors.with_opacity(0.16, cor)),
            ),
            padding=ft.Padding.only(left=14, right=14, top=11, bottom=11),
        )

    def carregar_lista_agrupada():
        col_agrupada.controls.clear()
        for tipo, valor_total in db.listar_agrupado(conn, turno_atual.id):
            col_agrupada.controls.append(_list_tile_agrupado(tipo, valor_total))
        page.update()

    def carregar_historico():
        col_historico.controls.clear()
        for row in db.listar_historico(conn, turno_atual.id):
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
                        atualizar_painel()
                        carregar_lista_agrupada()
                        carregar_historico()
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
                                        border_radius=8,
                                        padding=6,
                                    ),
                                    ft.Column(
                                        spacing=2,
                                        expand=True,
                                        controls=[
                                            ft.Text(
                                                f"{formatar_moeda(row['valor'])} · {row['tipo']}{desc_texto}",
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
                        left=ft.BorderSide(1, ft.Colors.with_opacity(0.14, cor)),
                        right=ft.BorderSide(1, ft.Colors.with_opacity(0.14, cor)),
                        top=ft.BorderSide(1, ft.Colors.with_opacity(0.14, cor)),
                        bottom=ft.BorderSide(1, ft.Colors.with_opacity(0.14, cor)),
                    ),
                    padding=ft.Padding.only(left=12, right=4, top=10, bottom=10),
                )
            )
        page.update()

    def recarregar_listas():
        garantir_conexao()
        atualizar_painel()
        carregar_lista_agrupada()
        carregar_historico()

    # ══════════════════════════════════════════════════════════════════
    # BOTÃO LANÇAR
    # ══════════════════════════════════════════════════════════════════
    btn_lancar = ft.Container(
        content=ft.Row(
            alignment=ft.MainAxisAlignment.CENTER,
            spacing=10,
            controls=[
                ft.Icon(ft.Icons.ADD_SHOPPING_CART, color=ft.Colors.WHITE, size=20),
                ft.Text("Lançar Abastecimento", color=ft.Colors.WHITE, size=16,
                        weight=ft.FontWeight.W_600),
            ],
        ),
        bgcolor=None,
        gradient=ft.LinearGradient(
            begin=ft.Alignment(-1, 0),
            end=ft.Alignment(1, 0),
            colors=["#3b82f6", "#2563eb"],
        ),
        border_radius=RADIUS,
        height=56,
        width=largura_conteudo,
        alignment=ft.Alignment(0, 0),
        shadow=ft.BoxShadow(
            blur_radius=20,
            spread_radius=0,
            color=ft.Colors.with_opacity(0.35, "#3b82f6"),
            offset=ft.Offset(0, 4),
        ),
        on_click=None,  # definido abaixo
        animate=ft.Animation(120, ft.AnimationCurve.EASE_OUT),
    )

    def acao_lancar(e=None):
        if btn_lancar.opacity == 0.5:
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
            salvar_ultimo_tipo(estado_tipo["valor"])
            recarregar_listas()
            desfocar_campos(input_valor, input_desc)
        except Exception:
            mostrar_snackbar("Erro ao lançar. Tente novamente.", ft.Colors.RED_800)
        finally:
            btn_lancar.opacity = 1.0
            page.update()

    btn_lancar.on_click = acao_lancar
    input_valor.on_submit = acao_lancar
    input_desc.on_submit  = acao_lancar

    # ══════════════════════════════════════════════════════════════════
    # RESUMO / FECHAR CAIXA
    # ══════════════════════════════════════════════════════════════════
    def montar_conteudo_resumo(totais, detalhe_cartoes):
        linhas_bandeiras = []
        for bandeira, valor in detalhe_cartoes.items():
            cor   = cor_tipo(bandeira)
            icone = icone_tipo(bandeira)
            linhas_bandeiras.append(
                ft.Row([
                    ft.Container(width=18),
                    ft.Icon(icone, color=cor, size=14),
                    ft.Text(bandeira, size=12, expand=True, color=cor),
                    ft.Text(formatar_moeda(valor), size=12, color=cor),
                ], spacing=4)
            )
        return ft.Column(
            width=min(300, largura_conteudo),
            tight=True, spacing=8,
            scroll=ft.ScrollMode.AUTO, height=480,
            controls=[
                ft.Text(f"Turno #{turno_atual.id} · {turno_atual.aberto_em}",
                        size=12, color=pal.text_ter),
                ft.Row([ft.Icon(ft.Icons.MONEY, color=C_GREEN),
                        ft.Text("Dinheiro (físico):", expand=True),
                        ft.Text(formatar_moeda(totais.fisico), weight=ft.FontWeight.BOLD)]),
                ft.Row([ft.Icon(ft.Icons.PIX, color=C_BLUE),
                        ft.Text("Total PIX:", expand=True),
                        ft.Text(formatar_moeda(totais.pix), weight=ft.FontWeight.BOLD)]),
                ft.Divider(height=1),
                ft.Text("Cartões por bandeira:", size=13, color=pal.text_sec, weight=ft.FontWeight.BOLD),
                *linhas_bandeiras,
                ft.Row([ft.Icon(ft.Icons.CREDIT_CARD, color=C_ORANGE),
                        ft.Text("Total Cartões (+ Sodexo):", expand=True, size=13),
                        ft.Text(formatar_moeda(totais.cartoes), weight=ft.FontWeight.BOLD)]),
                ft.Divider(height=1),
                ft.Row([ft.Icon(ft.Icons.RECEIPT_LONG, color=C_PURPLE),
                        ft.Text("Requisição:", expand=True),
                        ft.Text(formatar_moeda(totais.requisicao), weight=ft.FontWeight.BOLD)]),
                ft.Row([ft.Icon(ft.Icons.ACCOUNT_BALANCE, color=C_BROWN),
                        ft.Text("Depósito Global:", expand=True),
                        ft.Text(formatar_moeda(totais.deposito_global), weight=ft.FontWeight.BOLD)]),
                ft.Divider(height=20),
                ft.Row([ft.Icon(ft.Icons.ACCOUNT_BALANCE_WALLET, color=C_GREEN),
                        ft.Text("Total Geral:", expand=True, weight=ft.FontWeight.BOLD, size=18),
                        ft.Text(formatar_moeda(totais.total_geral),
                                weight=ft.FontWeight.BOLD, size=18, color=C_GREEN)]),
            ],
        )

    def acao_fechar_caixa(e=None):
        fechar_bottom_sheet()
        garantir_conexao()
        totais        = db.obter_totais(conn, turno_atual.id)
        detalhe_cart  = db.obter_detalhe_cartoes(conn, turno_atual.id)
        resumo        = db.montar_resumo_texto(totais, turno_atual, detalhe_cart)
        dlg = ft.AlertDialog(
            title=ft.Text("Resumo do Turno"),
            content=montar_conteudo_resumo(totais, detalhe_cart),
        )

        def copiar_resumo(x):
            page.set_clipboard(resumo)
            mostrar_snackbar("Resumo copiado para a área de transferência")

        def encerrar_turno(x):
            nonlocal turno_atual
            try:
                garantir_conexao()
                db.fechar_turno(conn, turno_atual.id, totais)
                turno_atual = db.obter_ou_criar_turno_aberto(conn)
                fechar_dialogo(dlg)
                mostrar_snackbar("Turno encerrado. Novo turno iniciado.")
                recarregar_listas()
            except Exception:
                mostrar_snackbar("Erro ao encerrar o turno.", ft.Colors.RED_800)

        dlg.actions = [
            ft.TextButton(
                content=ft.Row([ft.Icon(ft.Icons.CONTENT_COPY, size=16), ft.Text("Copiar resumo")],
                               tight=True),
                on_click=copiar_resumo,
            ),
            ft.TextButton("Encerrar turno", on_click=encerrar_turno),
            ft.TextButton("Fechar", on_click=lambda x: fechar_dialogo(dlg)),
        ]
        abrir_dialogo(dlg)

    def acao_historico_turnos(e=None):
        fechar_bottom_sheet()
        garantir_conexao()
        turnos = db.listar_turnos_fechados(conn)
        if not turnos:
            mostrar_snackbar("Nenhum turno encerrado ainda.", ft.Colors.BLUE_GREY_700)
            return
        itens = [
            ft.ListTile(
                title=ft.Text(f"Turno #{t['id']} · {formatar_moeda(t['total_geral'])}"),
                subtitle=ft.Text(f"{t['aberto_em']} → {t['fechado_em']}"),
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

    def acao_zerar_tudo(e=None):
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
                recarregar_listas()
            except Exception:
                mostrar_snackbar("Erro ao zerar. Nada foi apagado.", ft.Colors.RED_800)

        dlg_confirmar.actions = [
            ft.TextButton("Sim, Zerar", on_click=confirmar_zerar),
            ft.TextButton("Cancelar",   on_click=lambda x: fechar_dialogo(dlg_confirmar)),
        ]
        abrir_dialogo(dlg_confirmar)

    # ══════════════════════════════════════════════════════════════════
    # BOTTOM SHEET
    # ══════════════════════════════════════════════════════════════════
    txt_bottom_titulo = ft.Text(
        "Gerenciar Turno", size=17, weight=ft.FontWeight.BOLD, color=pal.text_pri
    )
    bottom_div_1 = ft.Divider(height=8, color=pal.border)
    bottom_div_2 = ft.Divider(height=8, color=pal.border)
    bottom_sheet_content = ft.Container(
        padding=20,
        bgcolor=pal.sheet_bg,
        content=ft.Column(
            tight=True,
            spacing=8,
            controls=[
                txt_bottom_titulo,
                bottom_div_1,
                ft.ListTile(
                    leading=ft.Icon(ft.Icons.ASSESSMENT, color=C_BLUE),
                    title=ft.Text("Fechar Caixa / Resumo", size=15),
                    on_click=acao_fechar_caixa,
                ),
                ft.ListTile(
                    leading=ft.Icon(ft.Icons.HISTORY, color=pal.text_sec),
                    title=ft.Text("Histórico de Turnos", size=15),
                    on_click=acao_historico_turnos,
                ),
                bottom_div_2,
                ft.ListTile(
                    leading=ft.Icon(ft.Icons.DELETE_FOREVER, color=C_RED),
                    title=ft.Text("Limpar / Zerar Tudo", size=15, color=C_RED),
                    on_click=acao_zerar_tudo,
                ),
            ],
        ),
    )

    bottom_sheet = ft.BottomSheet(
        open=False,
        content=bottom_sheet_content,
    )

    def fechar_menu():
        page.pop_dialog()

    def _menu_handler(callback):
        def handler(e):
            fechar_menu()
            callback()
        return handler

    def abrir_bottom_sheet(e):
        if ios:
            sheet = ft.CupertinoActionSheet(
                title=ft.Text("Gerenciar Turno"),
                cancel=ft.CupertinoActionSheetAction(
                    content=ft.Text("Cancelar"),
                    on_click=lambda ev: fechar_menu(),
                ),
                actions=[
                    ft.CupertinoActionSheetAction(
                        content=ft.Text("Fechar Caixa / Resumo"),
                        on_click=_menu_handler(acao_fechar_caixa),
                    ),
                    ft.CupertinoActionSheetAction(
                        content=ft.Text("Histórico de Turnos"),
                        on_click=_menu_handler(acao_historico_turnos),
                    ),
                    ft.CupertinoActionSheetAction(
                        content=ft.Text("Limpar / Zerar Tudo", color=C_RED),
                        on_click=_menu_handler(acao_zerar_tudo),
                    ),
                ],
            )
            page.show_dialog(ft.CupertinoBottomSheet(sheet))
        else:
            page.show_dialog(bottom_sheet)

    def fechar_bottom_sheet():
        fechar_menu()

    # ══════════════════════════════════════════════════════════════════
    # HEADER / TEMA
    # ══════════════════════════════════════════════════════════════════
    def aplicar_paleta_ui():
        nonlocal pal
        pal = criar_paleta(tema_escuro())
        page.bgcolor = pal.bg

        txt_fisico_label.color = pal.text_sec
        txt_turno.color = pal.text_sec

        for card, lbl in (
            (stat_pix_card, lbl_pix),
            (stat_cart_card, lbl_cart),
            (stat_req_card, lbl_req),
            (stat_dep_card, lbl_dep),
        ):
            card.bgcolor = pal.surface
            lbl.color = pal.text_ter

        txt_total_geral_label.color = pal.text_pri
        txt_header_titulo.color = pal.text_pri
        btn_tema.icon_color = pal.text_sec
        btn_menu.icon_color = pal.text_sec

        txt_sec_forma.color = pal.text_ter
        txt_sec_totais.color = pal.text_pri
        txt_sec_historico.color = pal.text_pri

        for div in (div_top, div_mid, div_bot):
            div.bgcolor = pal.border

        txt_bottom_titulo.color = pal.text_pri
        bottom_div_1.color = pal.border
        bottom_div_2.color = pal.border
        bottom_sheet_content.bgcolor = pal.sheet_bg
        if mobile:
            rodape_lancar.bgcolor = pal.bg
            rodape_lancar.border = ft.Border(
                top=ft.BorderSide(1, pal.border),
            )
            txt_rodape_resumo.color = pal.text_sec

        op = 0.16 if tema_escuro() else 0.11
        hero_card.gradient = ft.LinearGradient(
            begin=ft.Alignment(-1, -1),
            end=ft.Alignment(1, 1),
            colors=[
                ft.Colors.with_opacity(op, C_GREEN),
                ft.Colors.with_opacity(op * 0.4, C_GREEN),
                ft.Colors.with_opacity(op * 0.5, C_BLUE),
            ],
        )

        montar_botoes_rapidos()
        reconstruir_seletor()
        recarregar_listas()
        page.update()

    def alternar_tema(e):
        page.theme_mode = (
            ft.ThemeMode.LIGHT if page.theme_mode == ft.ThemeMode.DARK else ft.ThemeMode.DARK
        )
        btn_tema.icon = (
            ft.Icons.LIGHT_MODE if page.theme_mode == ft.ThemeMode.DARK else ft.Icons.DARK_MODE
        )
        try:
            page.client_storage.set(
                "caixa_tema",
                "dark" if page.theme_mode == ft.ThemeMode.DARK else "light",
            )
        except Exception:
            pass
        aplicar_paleta_ui()

    btn_tema = ft.IconButton(
        icon=ft.Icons.LIGHT_MODE if tema_escuro() else ft.Icons.DARK_MODE,
        tooltip="Alternar tema",
        icon_color=pal.text_sec,
        on_click=alternar_tema,
    )

    txt_header_titulo = ft.Text(
        "Caixa · Posto Janjão",
        size=17,
        weight=ft.FontWeight.W_600,
        color=pal.text_pri,
        expand=True,
    )
    btn_menu = ft.IconButton(
        icon=ft.Icons.MORE_VERT,
        tooltip="Gerenciar turno",
        icon_color=pal.text_sec,
        on_click=abrir_bottom_sheet,
    )

    header = ft.Row(
        controls=[txt_header_titulo, btn_tema, btn_menu],
        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
        width=largura_conteudo,
    )

    # ── Separador fino ──────────────────────────────────────────────────────
    def _divider():
        return ft.Container(height=1, bgcolor=pal.border, width=largura_conteudo)

    div_top = _divider()
    div_mid = _divider()
    div_bot = _divider()

    txt_sec_forma = ft.Text(
        "Forma de Pagamento", size=13, color=pal.text_ter, weight=ft.FontWeight.W_600
    )
    txt_sec_totais = ft.Text(
        "Totais por Tipo",
        size=18,
        weight=ft.FontWeight.BOLD,
        color=pal.text_pri,
        width=largura_conteudo,
    )
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

    # ══════════════════════════════════════════════════════════════════
    # LAYOUT PRINCIPAL
    # ══════════════════════════════════════════════════════════════════
    controles_scroll = [
        header,
        hero_card,
        stats_grid,
        total_geral_card,
        div_top,
        txt_sec_forma,
        seletor_col,
        input_valor,
        row_botoes_rapidos,
        input_desc,
        div_mid,
        txt_sec_totais,
        col_agrupada,
        div_bot,
        txt_sec_historico,
        col_historico,
    ]

    if not mobile:
        controles_scroll.insert(
            controles_scroll.index(input_desc) + 1,
            btn_lancar,
        )

    area_scroll = ft.Column(
        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
        spacing=10,
        controls=controles_scroll,
        scroll=ft.ScrollMode.AUTO if mobile else None,
        expand=mobile,
    )

    rodape_lancar = ft.Container(
        content=ft.Column(
            spacing=8,
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            controls=[txt_rodape_resumo, btn_lancar],
        ),
        width=largura_conteudo,
        padding=ft.Padding.only(left=0, right=0, top=8, bottom=8),
        bgcolor=pal.bg,
        border=ft.Border(top=ft.BorderSide(1, pal.border)),
        visible=mobile,
    )

    conteudo_principal = (
        ft.Column(
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            spacing=0,
            expand=True,
            controls=[area_scroll, rodape_lancar],
        )
        if mobile
        else area_scroll
    )

    def montar_interface():
        page.controls.clear()
        if mobile:
            raiz = ft.SafeArea(ft.Column(controls=[conteudo_principal], expand=True))
        else:
            raiz = conteudo_principal
        page.add(raiz)
        aplicar_largura()
        recarregar_listas()

    def solicitar_pin():
        campo_pin = ft.TextField(
            label="PIN de acesso",
            password=True,
            can_reveal_password=True,
            width=260,
            on_submit=lambda e: validar_pin(),
        )
        texto_erro = ft.Text("", color=ft.Colors.RED_400, size=12)

        def validar_pin():
            if campo_pin.value == pin_configurado:
                nonlocal autenticado
                autenticado = True
                fechar_dialogo(dlg_pin)
                montar_interface()
            else:
                texto_erro.value = "PIN incorreto"
                page.update()

        dlg_pin = ft.AlertDialog(
            title=ft.Text("Acesso ao Caixa"),
            content=ft.Column([campo_pin, texto_erro], tight=True, spacing=8),
            modal=True,
        )
        dlg_pin.actions = [ft.TextButton("Entrar", on_click=lambda x: validar_pin())]
        abrir_dialogo(dlg_pin)
        page.run_task(campo_pin.focus)

    page.on_resized = lambda e: atualizar_largura()

    if autenticado:
        montar_interface()
    else:
        solicitar_pin()


if __name__ == "__main__":
    if _app_mobile():
        ft.run(main)
    else:
        porta = int(os.environ.get("PORT", 5000))
        ft.run(main, view=ft.AppView.WEB_BROWSER, port=porta, host="0.0.0.0")
