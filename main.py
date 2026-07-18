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

# ── Acentos (funcionam em ambos os temas) ──────────────────────────────────
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
                page.services.append(ctrl)
            elif hasattr(page, "overlay"):
                page.overlay.append(ctrl)
        except Exception:
            pass

    haptic_feedback = None
    compartilhar_servico = None
    if mobile:
        try:
            haptic_feedback = ft.HapticFeedback()
            _registrar_servico(haptic_feedback)
        except Exception:
            haptic_feedback = None

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
            seletor_col.width = w
            input_valor.width = w
            input_desc.width = w
            row_botoes_rapidos.width = w
            col_historico.width = w
            btn_lancar.width = w
            if mobile and rodape_lancar is not None:
                rodape_lancar.width = w
            info_turno_card.width = w
            total_geral_card.width = w
            stats_grid.width = w
        page.update()

    def abrir_dialogo(dlg):
        # page.show_dialog() só existe (e funciona) em versões mais novas do
        # Flet. Se ela não existir OU falhar por qualquer outro motivo — por
        # exemplo tentar abrir uma tela flutuante em cima de outra que já
        # está aberta, algo mais instável no Android — caímos pro esquema
        # antigo de overlay em vez de deixar o toque não fazer nada.
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
        try:
            page.pop_dialog()
        except AttributeError:
            dlg.open = False
            page.update()
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
        db.TIPO_REQUISICAO:      C_PURPLE,
        db.TIPO_SODEXO:          C_TEAL,
        db.TIPO_DEPOSITO_GLOBAL: C_BROWN,
        db.TIPO_DESPESA:         C_RED,
        "Master Crédito":        C_RED,
        "Master Débito":         C_ORANGE,
        "Visa Crédito":          C_INDIGO,
        "Visa Débito":           C_INDIGO2,
        "Elo Crédito":           C_AMBER,
        "Elo Débito":            C_AMBER2,
        "Alelo Multibenefícios": C_PURPLE,
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

    def glass_container(content, padding=16, radius=RADIUS_SM, border_color=pal.border, bgcolor=pal.surface):
        return ft.Container(
            content=content,
            bgcolor=bgcolor,
            border_radius=radius,
            border=borda_all(1, border_color),
            padding=padding,
            blur=_blur_vidro(),
        )

    # ══════════════════════════════════════════════════════════════════
    # INFORMAÇÕES DO TURNO
    # ══════════════════════════════════════════════════════════════════
    txt_operador_nome = ft.Text("", size=18, weight=ft.FontWeight.BOLD, color=C_BLUE)
    txt_turno_data = ft.Text("", size=13)

    info_turno_card = ft.Container(
        width=largura_conteudo,
        border_radius=RADIUS,
        bgcolor=ft.Colors.with_opacity(0.10, C_BLUE),
        border=borda_all(1, ft.Colors.with_opacity(0.20, C_BLUE)),
        blur=_blur_vidro(),
        shadow=_sombra(ft.Colors.BLACK, 15, 0.1, 4),
        padding=ft.Padding(left=20, right=20, top=16, bottom=16),
        content=ft.Row(
            spacing=15,
            controls=[
                ft.Container(
                    content=ft.Icon(ft.Icons.PERSON, color=C_BLUE, size=24),
                    bgcolor=ft.Colors.with_opacity(0.15, C_BLUE),
                    padding=12,
                    border_radius=50,
                ),
                ft.Column(
                    spacing=2,
                    controls=[
                        txt_operador_nome,
                        txt_turno_data,
                    ]
                )
            ]
        )
    )

    # ══════════════════════════════════════════════════════════════════
    # STATS GRID
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
            border=borda_all(1, ft.Colors.with_opacity(0.18, cor)),
            padding=ft.Padding(left=14, right=14, top=13, bottom=13),
            expand=True,
            blur=_blur_vidro(),
            shadow=_sombra(ft.Colors.BLACK, 10, 0.05, 2),
            scale=ft.Scale(scale=1),
            animate_scale=_animacao(150, ft.AnimationCurve.EASE_OUT),
        )
        def hover_card(e):
            e.control.scale = 1.02 if e.data == "true" else 1.0
            e.control.update()
        card.on_hover = hover_card
        
        return card, txt, lbl

    stat_din_card, txt_dinheiro, lbl_din = _stat_card("Dinheiro", C_GREEN)
    stat_pix_card, txt_pix, lbl_pix = _stat_card("PIX", C_BLUE)
    stat_cart_card, txt_cartoes, lbl_cart = _stat_card("Cartões", C_ORANGE)
    stat_req_card, txt_requisicao, lbl_req = _stat_card("Requisição", C_PURPLE)
    stat_dep_card, txt_deposito_global, lbl_dep = _stat_card("Depósito Global", C_BROWN)
    stat_desp_card, txt_despesas, lbl_desp = _stat_card("Despesas", C_RED)

    stats_grid = ft.Column(
        spacing=10,
        width=largura_conteudo,
        controls=[
            ft.Row(spacing=10, controls=[stat_din_card, stat_pix_card]),
            ft.Row(spacing=10, controls=[stat_cart_card, stat_req_card]),
            ft.Row(spacing=10, controls=[stat_dep_card, stat_desp_card]),
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
        border=borda_all(1, ft.Colors.with_opacity(0.30, C_GREEN)),
        blur=_blur_vidro(),
        shadow=_sombra(C_GREEN, 15, 0.15, 4),
        padding=ft.Padding(left=16, right=16, top=13, bottom=13),
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
        if turno_atual is None:
            return

        totais = db.obter_totais(conn, turno_atual.id)
        txt_dinheiro.value      = formatar_moeda(totais.fisico)
        txt_pix.value           = formatar_moeda(totais.pix)
        txt_cartoes.value       = formatar_moeda(totais.cartoes)
        lbl_cart.value          = f"CARTÕES ({totais.qtd_cartoes})"
        txt_requisicao.value    = formatar_moeda(totais.requisicao)
        txt_deposito_global.value = formatar_moeda(totais.deposito_global)
        txt_despesas.value        = formatar_moeda(totais.despesas)
        txt_total_geral.value   = formatar_moeda(totais.total_geral)
        
        txt_operador_nome.value = f"Operador(a): {turno_atual.operador}"
        txt_turno_data.value    = f"Turno #{turno_atual.id} · Aberto em: {turno_atual.aberto_em}"
        
        if mobile:
            txt_rodape_resumo.value = f"Total geral · {formatar_moeda(totais.total_geral)}"
        # Sem page.update() aqui de propósito: quem chama decide quando enviar
        # ao cliente, pra não disparar várias idas e voltas pra uma única ação.

    # ══════════════════════════════════════════════════════════════════
    # SELETOR DE TIPO
    # ══════════════════════════════════════════════════════════════════
    def criar_seletor_tipo(valor_inicial: str):
        estado = {
            "valor": valor_inicial,
            "mostrar_bandeiras": valor_inicial in db.LISTA_CARTOES,
        }
        seletor_col = ft.Column(spacing=8, width=largura_conteudo)
        registro_chips = {}

        def _estilo(chave: str, selecionado: bool):
            cor = cor_tipo(chave)
            return {
                "bgcolor": cor if selecionado else ft.Colors.with_opacity(0.12, cor),
                "border": borda_all(
                    1.5 if selecionado else 1,
                    cor if selecionado else ft.Colors.with_opacity(0.35, cor),
                ),
                "cor_conteudo": ft.Colors.WHITE if selecionado else cor,
                "peso_texto": ft.FontWeight.W_600 if selecionado else ft.FontWeight.W_500,
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
                border_radius=RADIUS_SM,
                border=estilo["border"],
                height=50,
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
            selecionado = estado["valor"] in db.LISTA_CARTOES
            return _montar_chip("__cartao__", "Cartão", selecionado, _alternar_cartao)

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
                for i in range(0, len(db.LISTA_CARTOES), 2):
                    seletor_col.controls.append(_linha(db.LISTA_CARTOES[i:i + 2]))

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

            anterior_e_cartao = anterior in db.LISTA_CARTOES
            novo_e_cartao = tipo in db.LISTA_CARTOES

            if anterior_e_cartao != novo_e_cartao:
                estado["mostrar_bandeiras"] = novo_e_cartao
                construir()
                page.update()
                return

            _repintar_chip(anterior, False)
            _repintar_chip(tipo, True)
            page.update()

        def _alternar_cartao(e=None):
            if estado["valor"] in db.LISTA_CARTOES:
                estado["mostrar_bandeiras"] = not estado["mostrar_bandeiras"]
                construir()
                page.update()
            else:
                selecionar(db.LISTA_CARTOES[0])

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

    # ══════════════════════════════════════════════════════════════════
    # LISTA HISTÓRICO
    # ══════════════════════════════════════════════════════════════════
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
                    border=borda_all(1, ft.Colors.with_opacity(0.14, cor)),
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

    # ══════════════════════════════════════════════════════════════════
    # DETALHE DE BANDEIRA (lista completa de lançamentos por tipo/bandeira)
    # ══════════════════════════════════════════════════════════════════
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
            sheet_detalhe = ft.CupertinoBottomSheet(painel_detalhe)
            abrir_dialogo(sheet_detalhe)

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
        shadow=_sombra("#3b82f6", 20, 0.35, 4),
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

    # ══════════════════════════════════════════════════════════════════
    # RESUMO / FECHAR CAIXA
    # ══════════════════════════════════════════════════════════════════
    def montar_conteudo_resumo(totais, detalhe_cartoes, ao_abrir_detalhe=None):
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
                    bandeira, size=16, expand=True, color=pal.text_sec,
                    max_lines=1, overflow=ft.TextOverflow.ELLIPSIS,
                ),
            ]
            if qtd > 0:
                row_controls.append(ft.Text(f"({qtd} un)", size=16, color=pal.text_sec))
            
            row_controls.extend([
                ft.Text(formatar_moeda(valor), size=16, color=cor_valor, weight=peso_valor),
                ft.Icon(ft.Icons.CHEVRON_RIGHT, color=pal.text_ter, size=18),
            ])

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
                "Pag Pix", size=16, expand=True, color=pal.text_sec,
                max_lines=1, overflow=ft.TextOverflow.ELLIPSIS,
            ),
        ]
        if totais.qtd_pix > 0:
            row_controls_pix.append(ft.Text(f"({totais.qtd_pix} un)", size=16, color=pal.text_sec))
            
        row_controls_pix.extend([
            ft.Text(formatar_moeda(totais.pix), size=16, color=cor_valor_pix, weight=peso_valor_pix),
            ft.Icon(ft.Icons.CHEVRON_RIGHT, color=pal.text_ter, size=18),
        ])

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

        return ft.Column(
            tight=True, spacing=14,
            scroll=ft.ScrollMode.AUTO, expand=True,
            controls=[
                ft.Column(spacing=3, controls=[
                    ft.Text(f"Turno #{turno_atual.id} · Operador(a): {turno_atual.operador}",
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
                
                ft.Row([ft.Icon(ft.Icons.RECEIPT_LONG, color=C_PURPLE, size=22),
                        ft.Text("Requisição:", size=tamanho_fonte_itens, expand=True, color=pal.text_sec),
                        ft.Text(formatar_moeda(totais.requisicao), size=tamanho_fonte_itens, weight=ft.FontWeight.BOLD, color=pal.text_pri)]),
                ft.Row([ft.Icon(ft.Icons.ACCOUNT_BALANCE, color=C_BROWN, size=22),
                        ft.Text("Depósito Global:", size=tamanho_fonte_itens, expand=True, color=pal.text_sec),
                        ft.Text(formatar_moeda(totais.deposito_global), size=tamanho_fonte_itens, weight=ft.FontWeight.BOLD, color=pal.text_pri)]),
                ft.Row([ft.Icon(ft.Icons.MONEY_OFF, color=C_RED, size=22),
                        ft.Text("Despesas:", size=tamanho_fonte_itens, expand=True, color=pal.text_sec),
                        ft.Text(formatar_moeda(totais.despesas), size=tamanho_fonte_itens, weight=ft.FontWeight.BOLD, color=pal.text_pri)]),

                ft.Row([ft.Icon(ft.Icons.MONEY, color=C_GREEN, size=22),
                        ft.Text("Sobra de Dinheiro:", size=tamanho_fonte_itens, expand=True, color=pal.text_sec),
                        ft.Text(formatar_moeda(totais.fisico), size=tamanho_fonte_itens, weight=ft.FontWeight.BOLD, color=pal.text_pri)]),
                
                ft.Divider(height=6, color=pal.border),
                
                ft.Container(
                    bgcolor=ft.Colors.with_opacity(0.10, C_GREEN),
                    border_radius=RADIUS_SM,
                    padding=12,
                    content=ft.Row([
                        ft.Icon(ft.Icons.ACCOUNT_BALANCE_WALLET, color=C_GREEN, size=24),
                        ft.Text("TOTAL GERAL:", expand=True, weight=ft.FontWeight.BOLD, size=16, color=pal.text_pri),
                        ft.Text(formatar_moeda(totais.total_geral), weight=ft.FontWeight.BOLD, size=20, color=C_GREEN)
                    ])
                ),
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

        def fechar_resumo(x=None):
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
            # No Android, abrir uma tela flutuante (o detalhe da bandeira) em
            # cima de outra que já está aberta (o resumo) é instável e às
            # vezes simplesmente não faz nada. Por isso fechamos o resumo
            # primeiro, damos um tempinho pra animação terminar, e só então
            # abrimos o detalhe.
            fechar_resumo()

            async def _abrir_depois():
                import asyncio
                await asyncio.sleep(0.3)
                abrir_detalhe_bandeira(tipo, rotulo, ao_fechar=acao_fechar_caixa)

            page.run_task(_abrir_depois)

        def copiar_resumo(x):
            async def _copiar_async():
                try:
                    await ft.Clipboard().set(resumo)
                    mostrar_snackbar("Resumo copiado para a área de transferência")
                except Exception:
                    mostrar_snackbar("Não foi possível copiar o resumo")

            page.run_task(_copiar_async)

        def encerrar_turno(x):
            nonlocal turno_atual
            if _em_andamento["valor"] or turno_atual is None:
                return
            _em_andamento["valor"] = True
            try:
                garantir_conexao()
                db.fechar_turno(conn, turno_atual.id, totais)
                turno_atual = None
                fechar_resumo()

                async def _finalizar_encerramento():
                    import asyncio
                    # Espera a animação de fechar a tela do resumo terminar
                    # antes de reconstruir a interface inteira — fazer as duas
                    # coisas juntas de forma imediata é o que mais trava no
                    # Android.
                    await asyncio.sleep(0.35)
                    mostrar_snackbar("Turno encerrado com sucesso. Caixa Fechado.")
                    vibrar("medium")
                    montar_interface()

                page.run_task(_finalizar_encerramento)
            except Exception as ex:
                _em_andamento["valor"] = False
                mostrar_snackbar(f"Erro: {ex}", ft.Colors.RED_800)

        conteudo_resumo = montar_conteudo_resumo(totais, detalhe_cart, abrir_detalhe_a_partir_do_resumo)

        btn_copiar = ft.TextButton(
            content=ft.Row([ft.Icon(ft.Icons.CONTENT_COPY, size=16), ft.Text("Copiar resumo")],
                           tight=True),
            on_click=copiar_resumo,
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
                    ft.Container(
                        width=36, height=4, border_radius=2,
                        bgcolor=pal.border_strong,
                    ),
                    ft.Text("Resumo do Turno", size=18, weight=ft.FontWeight.BOLD, color=pal.text_pri),
                    conteudo_resumo,
                    ft.Divider(height=1),
                    ft.Row(
                        [btn_copiar, btn_encerrar, btn_fechar],
                        alignment=ft.MainAxisAlignment.CENTER,
                        wrap=True, spacing=4, run_spacing=4,
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
            sheet_resumo = ft.CupertinoBottomSheet(painel_resumo)
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
                title=ft.Text(f"Turno #{t['id']} · {t['operador']} · {formatar_moeda(t['total_geral'])}"),
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

    # ══════════════════════════════════════════════════════════════════
    # BOTTOM SHEET
    # ══════════════════════════════════════════════════════════════════
    txt_bottom_titulo = ft.Text(
        "Gerenciar Turno", size=17, weight=ft.FontWeight.BOLD, color=pal.text_pri
    )
    bottom_div_1 = ft.Divider(height=8, color=pal.border)
    bottom_div_2 = ft.Divider(height=8, color=pal.border)
    def acao_sair_operador(e=None):
        fechar_bottom_sheet()
        dlg_sair = ft.AlertDialog(
            title=ft.Text("Sair do Operador?"),
            content=ft.Text(
                "O turno continuará aberto.\n"
                "Na próxima vez que abrir o app será pedido o nome do operador."
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
                turno_atual.operador = "Não informado"
            except Exception:
                pass
            mostrar_snackbar("Operador desconectado. Até logo!")
            turno_atual = None
            solicitar_identificacao(novo_turno=False)

        dlg_sair.actions = [
            ft.TextButton("Sair", on_click=confirmar_sair),
            ft.TextButton("Cancelar", on_click=lambda x: fechar_dialogo(dlg_sair)),
        ]
        abrir_dialogo(dlg_sair)

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
                ft.Divider(height=4),
                ft.ListTile(
                    leading=ft.Icon(ft.Icons.LOGOUT, color=pal.text_ter),
                    title=ft.Text("Sair do Operador", size=15, color=pal.text_ter),
                    on_click=acao_sair_operador,
                ),
            ],
        ),
    )

    bottom_sheet = ft.BottomSheet(
        open=False,
        content=bottom_sheet_content,
    )

    _menu_aberto = None

    def fechar_menu():
        nonlocal _menu_aberto
        try:
            page.pop_dialog()
        except AttributeError:
            if _menu_aberto is not None:
                _menu_aberto.open = False
                page.update()
                _agendar_limpeza_overlay(_menu_aberto)
        _menu_aberto = None

    def _menu_handler(callback):
        def handler(e):
            fechar_menu()
            callback()
        return handler

    def abrir_bottom_sheet(e):
        nonlocal _menu_aberto
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
                    ft.CupertinoActionSheetAction(
                        content=ft.Text("Sair do Operador"),
                        on_click=_menu_handler(acao_sair_operador),
                    ),
                ],
            )
            _menu_aberto = ft.CupertinoBottomSheet(sheet)
            abrir_dialogo(_menu_aberto)
        else:
            _menu_aberto = bottom_sheet
            abrir_dialogo(_menu_aberto)

    def fechar_bottom_sheet():
        fechar_menu()

    # ══════════════════════════════════════════════════════════════════
    # HEADER / TEMA
    # ══════════════════════════════════════════════════════════════════
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

    # ══════════════════════════════════════════════════════════════════
    # LAYOUT PRINCIPAL E TELA DE CAIXA FECHADO
    # ══════════════════════════════════════════════════════════════════

    def montar_interface():
        nonlocal rodape_lancar
        page.controls.clear()

        icone_tema_atual = ft.Icons.LIGHT_MODE if tema_escuro() else ft.Icons.DARK_MODE

        if turno_atual is None:
            btn_tema_fechado = ft.IconButton(
                icon=icone_tema_atual,
                icon_color=pal.text_sec,
                on_click=alternar_tema,
            )

            topo = ft.Row([btn_tema_fechado], alignment=ft.MainAxisAlignment.END, width=largura_conteudo)

            tela_fechado = ft.Column(
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                alignment=ft.MainAxisAlignment.CENTER,
                spacing=20,
                expand=True,
                controls=[
                    topo,
                    ft.Container(height=40),
                    ft.Icon(ft.Icons.LOCK_OUTLINE, size=80, color=pal.text_ter),
                    ft.Text("Caixa Fechado", size=26, weight=ft.FontWeight.BOLD, color=pal.text_pri),
                    ft.Text("Nenhum turno em andamento no momento.", size=14, color=pal.text_sec),
                    ft.Container(height=20),
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
                        bgcolor=C_GREEN,
                        border_radius=12,
                        padding=ft.Padding(24, 16, 24, 16),
                        on_click=lambda e: solicitar_identificacao(novo_turno=True),
                        scale=ft.Scale(scale=1),
                        animate_scale=_animacao(150, ft.AnimationCurve.EASE_OUT),
                        animate=_animacao(120, ft.AnimationCurve.EASE_OUT),
                    ),
                    ft.Container(expand=True)
                ]
            )

            def hover_btn_abrir(e):
                e.control.scale = 1.05 if e.data == "true" else 1.0
                e.control.update()
            tela_fechado.controls[6].on_hover = hover_btn_abrir

            if mobile:
                page.add(ft.SafeArea(tela_fechado))
            else:
                page.add(tela_fechado)

            rodape_lancar = None

            aplicar_largura()
            page.update()
            return

        btn_tema.icon = icone_tema_atual

        txt_turno_data.color = pal.text_sec
        txt_operador_nome.color = pal.text_pri
        
        for card, lbl in (
            (stat_din_card, lbl_din),
            (stat_pix_card, lbl_pix),
            (stat_cart_card, lbl_cart),
            (stat_req_card, lbl_req),
            (stat_dep_card, lbl_dep),
            (stat_desp_card, lbl_desp),
        ):
            card.bgcolor = pal.surface
            lbl.color = pal.text_ter
            
        txt_total_geral_label.color = pal.text_pri
        txt_header_titulo.color = pal.text_pri
        btn_tema.icon_color = pal.text_sec
        btn_menu.icon_color = pal.text_sec
        txt_sec_historico.color = pal.text_pri
        for div in (div_top, div_mid, div_bot):
            div.bgcolor = pal.border
        txt_bottom_titulo.color = pal.text_pri
        bottom_div_1.color = pal.border
        bottom_div_2.color = pal.border
        bottom_sheet_content.bgcolor = pal.sheet_bg
        if mobile and rodape_lancar is not None:
            rodape_lancar.bgcolor = pal.bg
            rodape_lancar.border = ft.Border(top=ft.BorderSide(1, pal.border))
            txt_rodape_resumo.color = pal.text_sec

        controles_scroll = [
            header,
            info_turno_card,
            stats_grid,
            total_geral_card,
            div_top,
            seletor_col,
            input_valor,
            row_botoes_rapidos,
            input_desc,
            btn_lancar,
            div_mid,
            txt_sec_historico,
            col_historico,
        ]

        area_scroll = ft.Column(
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            spacing=10,
            controls=controles_scroll,
            scroll=ft.ScrollMode.HIDDEN if mobile else ft.ScrollMode.AUTO,
            expand=mobile,
        )

        rodape_lancar = None

        conteudo_principal = area_scroll

        if mobile:
            raiz = ft.SafeArea(ft.Column(controls=[conteudo_principal], expand=True))
        else:
            raiz = conteudo_principal

        page.add(raiz)
        aplicar_largura()
        reconstruir_seletor()
        montar_botoes_rapidos()
        recarregar_listas()

    # ══════════════════════════════════════════════════════════════════
    # FLUXO DE IDENTIFICAÇÃO (LOGIN / ABRIR TURNO)
    # ══════════════════════════════════════════════════════════════════

    def solicitar_identificacao(novo_turno=False):
        icone_topo = ft.Container(
            content=ft.Icon(
                ft.Icons.PLAY_ARROW_ROUNDED if novo_turno else ft.Icons.WAVING_HAND_ROUNDED,
                color=C_GREEN,
                size=30,
            ),
            width=60,
            height=60,
            bgcolor=ft.Colors.with_opacity(0.14, C_GREEN),
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
            focused_border_color=C_GREEN,
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
            focused_border_color=C_GREEN,
            on_submit=lambda e: page.run_task(validar_acesso_async),
        )
        texto_erro = ft.Text("", color=ft.Colors.RED_400, size=12, weight=ft.FontWeight.W_600)

        async def validar_acesso_async():
            import asyncio
            await asyncio.sleep(0.05)
            validar_acesso()

        def validar_acesso():
            if not tem_pin or campo_pin.value == pin_configurado:
                nonlocal turno_atual, autenticado
                autenticado = True

                nome_digitado = (campo_nome.value or "").strip() or "Não informado"

                fechar_dialogo(dlg_acesso)

                async def montagem_segura():
                    nonlocal turno_atual
                    import asyncio
                    await asyncio.sleep(0.2)

                    if novo_turno:
                        turno_atual = db.abrir_novo_turno(conn, nome_digitado)
                    else:
                        turno_existente = db.obter_turno_aberto(conn)
                        if turno_existente:
                            if turno_existente.operador == "Não informado" and nome_digitado != "Não informado":
                                conn.execute("UPDATE turnos SET operador = ? WHERE id = ?", (nome_digitado, turno_existente.id))
                                conn.commit()
                                turno_existente.operador = nome_digitado
                            turno_atual = turno_existente
                        else:
                            turno_atual = None

                    montar_interface()

                page.run_task(montagem_segura)
            else:
                texto_erro.value = "PIN incorreto"
                page.update()

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

        btn_confirmar = ft.Container(
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
            bgcolor=C_GREEN,
            border_radius=RADIUS_SM,
            padding=ft.Padding(24, 14, 24, 14),
            alignment=ft.Alignment(0, 0),
            width=240,
            on_click=lambda x: page.run_task(validar_acesso_async),
            scale=ft.Scale(scale=1),
            animate_scale=_animacao(150, ft.AnimationCurve.EASE_OUT),
            animate=_animacao(120, ft.AnimationCurve.EASE_OUT),
        )
        def hover_confirmar(e):
            e.control.scale = 1.05 if e.data == "true" else 1.0
            e.control.update()
        btn_confirmar.on_hover = hover_confirmar

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
        solicitar_identificacao(novo_turno=False)

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
