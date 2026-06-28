import os

import flet as ft

import db


def main(page: ft.Page):
    page.title = "Caixa - Posto Janjão"
    page.theme_mode = ft.ThemeMode.DARK
    page.vertical_alignment = ft.MainAxisAlignment.START
    page.scroll = ft.ScrollMode.AUTO
    page.horizontal_alignment = ft.CrossAxisAlignment.CENTER
    # Respiro extra no topo: quando o app é aberto como PWA em tela cheia no
    # iOS ("Adicionar à Tela de Início"), o conteúdo pode ficar por baixo da
    # barra de status (relógio/bateria/sinal). Esse padding maior no topo
    # garante que o cabeçalho (e o botão de menu "⋮") fiquem sempre visíveis
    # e clicáveis, abaixo dessa área.
    page.padding = ft.Padding.only(left=20, right=20, top=54, bottom=20)

    conn = db.conectar()
    db.inicializar_banco(conn)
    turno_atual = db.obter_ou_criar_turno_aberto(conn)

    pin_configurado = os.environ.get("CAIXA_PIN", "").strip()
    autenticado = not pin_configurado
    largura_conteudo = 380

    # ── Garantia de conexão viva ────────────────────────────────────────────
    # OBS: não fechamos a conexão no on_disconnect. Em apps móveis/PWA, a
    # sessão desconecta sozinha quando o app vai para segundo plano, mas o
    # Flet RECONECTA na mesma sessão quando o app volta — não cria uma nova.
    # Se a conexão fosse fechada ali, ficaria fechada para sempre nessa
    # mesma sessão, e só um restart completo do app resolveria (era
    # exatamente esse o bug). Em vez disso, verificamos e reabrimos a
    # conexão automaticamente sempre que algo for fazer uma operação no
    # banco, cobrindo esse caso e qualquer outro motivo de queda.
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
        largura = largura_conteudo
        seletor_tipo.width = largura
        input_valor.width = largura
        input_desc.width = largura
        botoes_rapidos.width = largura
        lista_agrupada.width = largura
        lista_historico.width = largura
        btn_lancar.width = largura
        linha_totais_secundarios.width = largura
        linha_totais_extras.width = largura
        txt_turno.width = largura
        page.update()

    def mostrar_snackbar(mensagem: str, cor=ft.Colors.GREEN_700):
        snack = ft.SnackBar(
            content=ft.Text(mensagem, color=ft.Colors.WHITE),
            bgcolor=cor,
            duration=2500,
        )
        # Nesta versão do Flet, AlertDialog/SnackBar/BottomSheet são todos
        # abertos com page.show_dialog() e fechados com page.pop_dialog().
        page.show_dialog(snack)

    def abrir_dialogo(dlg):
        page.show_dialog(dlg)

    def fechar_dialogo(dlg):
        page.pop_dialog()

    # Cada bandeira tem sua própria cor (mesmo tom para Crédito/Débito da
    # mesma bandeira, mas Crédito mais escuro/saturado e Débito mais claro),
    # pra dar pra identificar visualmente sem precisar ler o texto.
    # Visa usa a variante "accent" do índigo: o tom "normal" (700/300) fica
    # com pouco brilho sobre fundo escuro e parece apagado; o "accent" é
    # mais vibrante e legível, mesmo em opacidade reduzida.
    CORES_CARTOES = {
        "Master Crédito": ft.Colors.DEEP_ORANGE_700,
        "Master Débito": ft.Colors.DEEP_ORANGE_300,
        "Visa Crédito": ft.Colors.INDIGO_ACCENT_400,
        "Visa Débito": ft.Colors.INDIGO_ACCENT_100,
        "Elo Crédito": ft.Colors.AMBER_700,
        "Elo Débito": ft.Colors.AMBER_300,
    }

    def cor_icone_tipo(tipo):
        if tipo == db.TIPO_DINHEIRO:
            return ft.Colors.GREEN, ft.Icons.MONEY
        if tipo == db.TIPO_SANGRIA:
            return ft.Colors.RED_400, ft.Icons.REMOVE_CIRCLE
        if tipo == db.TIPO_PIX:
            return ft.Colors.BLUE_400, ft.Icons.PIX
        if tipo == db.TIPO_REQUISICAO:
            return ft.Colors.PURPLE_400, ft.Icons.RECEIPT_LONG
        if tipo == db.TIPO_SODEXO:
            return ft.Colors.TEAL_400, ft.Icons.LUNCH_DINING
        if tipo in CORES_CARTOES:
            return CORES_CARTOES[tipo], ft.Icons.CREDIT_CARD
        return ft.Colors.ORANGE_400, ft.Icons.CREDIT_CARD

    def formatar_moeda(valor: float) -> str:
        return db.formatar_moeda(valor)

    def criar_seletor_tipo(valor_inicial: str):
        """Cria um seletor de forma de pagamento em grade de 2 colunas,
        com chips coloridos agrupados por categoria (Operações / Cartões).
        Retorna (controle_coluna, estado, funcao_selecionar) — estado é um
        dict mutável com a chave 'valor' contendo o tipo selecionado atual.
        """
        estado = {"valor": valor_inicial}
        coluna = ft.Column(spacing=8, width=largura_conteudo)

        def construir_linha(tipos_da_linha):
            chips = []
            for tipo in tipos_da_linha:
                cor, icone = cor_icone_tipo(tipo)
                selecionado = tipo == estado["valor"]
                chips.append(
                    ft.Button(
                        content=ft.Row(
                            [
                                ft.Icon(
                                    icone,
                                    size=15,
                                    color=ft.Colors.WHITE if selecionado else cor,
                                ),
                                ft.Text(
                                    tipo,
                                    size=12,
                                    color=ft.Colors.WHITE if selecionado else cor,
                                    weight=ft.FontWeight.BOLD if selecionado else ft.FontWeight.NORMAL,
                                ),
                            ],
                            spacing=5,
                            tight=True,
                            alignment=ft.MainAxisAlignment.CENTER,
                        ),
                        style=ft.ButtonStyle(
                            bgcolor=cor if selecionado else ft.Colors.with_opacity(0.12, cor),
                            shape=ft.RoundedRectangleBorder(radius=8),
                            side=ft.BorderSide(
                                1.5 if selecionado else 1,
                                cor if selecionado else ft.Colors.with_opacity(0.45, cor),
                            ),
                        ),
                        height=42,
                        expand=1,
                        on_click=lambda e, t=tipo: selecionar(t),
                    )
                )
            return ft.Row(chips, spacing=8)

        def construir():
            coluna.controls.clear()
            principais = [db.TIPO_DINHEIRO, db.TIPO_PIX, db.TIPO_REQUISICAO, db.TIPO_SANGRIA]
            for i in range(0, len(principais), 2):
                coluna.controls.append(construir_linha(principais[i : i + 2]))

            coluna.controls.append(
                ft.Text("Cartões", size=12, color=ft.Colors.GREY_500, weight=ft.FontWeight.BOLD)
            )
            for i in range(0, len(db.LISTA_CARTOES), 2):
                coluna.controls.append(construir_linha(db.LISTA_CARTOES[i : i + 2]))

        def selecionar(tipo):
            estado["valor"] = tipo
            construir()
            page.update()

        construir()
        return coluna, estado, selecionar

    txt_fisico = ft.Text("R$ 0,00", size=52, weight=ft.FontWeight.BOLD, color=ft.Colors.GREEN_400)
    txt_pix = ft.Text("R$ 0,00", size=22, weight=ft.FontWeight.BOLD, color=ft.Colors.BLUE_400)
    txt_cartoes = ft.Text("R$ 0,00", size=22, weight=ft.FontWeight.BOLD, color=ft.Colors.ORANGE_400)
    txt_requisicao = ft.Text("R$ 0,00", size=20, weight=ft.FontWeight.BOLD, color=ft.Colors.PURPLE_400)
    txt_sangria = ft.Text("R$ 0,00", size=20, weight=ft.FontWeight.BOLD, color=ft.Colors.RED_400)
    txt_turno = ft.Text("", size=13, color=ft.Colors.GREY_500, text_align=ft.TextAlign.CENTER)

    def atualizar_painel():
        nonlocal turno_atual
        turno_atual = db.obter_ou_criar_turno_aberto(conn)
        totais = db.obter_totais(conn, turno_atual.id)
        txt_fisico.value = formatar_moeda(totais.fisico)
        txt_pix.value = formatar_moeda(totais.pix)
        txt_cartoes.value = formatar_moeda(totais.cartoes)
        txt_requisicao.value = formatar_moeda(totais.requisicao)
        txt_sangria.value = formatar_moeda(totais.sangria)
        txt_turno.value = f"Turno #{turno_atual.id} · aberto em {turno_atual.aberto_em}"
        page.update()

    rotulo_forma_pagamento = ft.Text("Forma de Pagamento", size=12, color=ft.Colors.GREY_400)
    seletor_tipo, estado_tipo, selecionar_tipo = criar_seletor_tipo(db.TIPO_DINHEIRO)

    input_valor = ft.TextField(
        label="Valor (Ex: 50.00 ou 50,00)",
        width=largura_conteudo,
        prefix=ft.Text("R$ "),
    )

    input_desc = ft.TextField(
        label="Descrição / Placa (Opcional)",
        width=largura_conteudo,
    )

    def set_valor(val, desc=""):
        input_valor.value = val
        if desc:
            input_desc.value = desc
        page.update()
        page.run_task(input_valor.focus)

    def validar_valor(texto: str) -> float | None:
        """Converte texto digitado em valor numérico, aceitando formatos
        comuns: '50.00', '50,00', '1.234,56' (BR) ou '1234.56'."""
        if not texto or not texto.strip():
            return None

        limpo = texto.strip().replace("R$", "").replace(" ", "")

        if "," in limpo and "." in limpo:
            # Formato BR com separador de milhar: 1.234,56 -> 1234.56
            limpo = limpo.replace(".", "").replace(",", ".")
        elif "," in limpo:
            # Apenas vírgula decimal: 50,00 -> 50.00
            limpo = limpo.replace(",", ".")
        # Se só tem ponto, assume que já é decimal (ex.: 50.00)

        try:
            valor = float(limpo)
        except ValueError:
            return None

        if valor <= 0:
            return None

        return round(valor, 2)

    def _estilo_btn(cor_bg):
        return ft.ButtonStyle(
            bgcolor=cor_bg,
            shape=ft.RoundedRectangleBorder(radius=8),
            color=ft.Colors.WHITE,
        )

    def make_btn_rapido(label, val, desc="", cor=ft.Colors.BLUE_GREY_700):
        def _click(e, v=val, d=desc):
            set_valor(v, d)

        return ft.Button(
            content=ft.Text(label, color=ft.Colors.WHITE, size=15),
            style=_estilo_btn(cor),
            on_click=_click,
            height=44,
        )

    def acao_completou(e):
        selecionar_tipo(db.TIPO_DINHEIRO)
        input_desc.value = "Completou"
        input_valor.value = ""
        input_valor.error_text = None
        page.update()
        page.run_task(input_valor.focus)

    botoes_rapidos = ft.Row(
        wrap=True,
        alignment=ft.MainAxisAlignment.CENTER,
        spacing=6,
        run_spacing=6,
        width=largura_conteudo,
        controls=[
            make_btn_rapido("R$ 50", "50.00"),
            make_btn_rapido("R$ 100", "100.00"),
            make_btn_rapido("R$ 200", "200.00"),
            make_btn_rapido("R$ 300", "300.00"),
            make_btn_rapido("R$ 500", "500.00"),
            ft.Button(
                content=ft.Text("Completou", color=ft.Colors.WHITE, size=15),
                style=_estilo_btn(ft.Colors.GREEN_800),
                on_click=acao_completou,
                height=44,
            ),
        ],
    )

    lista_agrupada = ft.ListView(expand=True, spacing=5, height=180, width=largura_conteudo)
    lista_historico = ft.ListView(expand=True, spacing=4, height=200, width=largura_conteudo)

    def carregar_lista_agrupada():
        lista_agrupada.controls.clear()
        for tipo, valor_total in db.listar_agrupado(conn, turno_atual.id):
            cor, icone = cor_icone_tipo(tipo)
            lista_agrupada.controls.append(
                ft.ListTile(
                    leading=ft.Icon(icone, color=cor),
                    title=ft.Text(f"{tipo} - {formatar_moeda(valor_total)}", color=cor, weight=ft.FontWeight.BOLD),
                )
            )
        page.update()

    def carregar_historico():
        lista_historico.controls.clear()
        for row in db.listar_historico(conn, turno_atual.id):
            cor, icone = cor_icone_tipo(row["tipo"])
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
                seletor_edit, estado_edit, _selecionar_edit = criar_seletor_tipo(tipo)
                campo_valor_edit = ft.TextField(
                    label="Valor",
                    value=f"{valor:.2f}".replace(".", ","),
                    prefix=ft.Text("R$ "),
                    width=min(300, largura_conteudo),
                )
                campo_desc_edit = ft.TextField(
                    label="Descrição / Placa (Opcional)",
                    value=descricao or "",
                    width=min(300, largura_conteudo),
                )
                seletor_edit.width = min(300, largura_conteudo)

                dlg_editar = ft.AlertDialog(
                    title=ft.Text("Editar lançamento"),
                    content=ft.Column(
                        [
                            ft.Text("Forma de Pagamento", size=12, color=ft.Colors.GREY_400),
                            seletor_edit,
                            campo_valor_edit,
                            campo_desc_edit,
                        ],
                        tight=True,
                        spacing=10,
                        scroll=ft.ScrollMode.AUTO,
                        height=420,
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
                            conn,
                            lancamento_id,
                            turno_atual.id,
                            estado_edit["valor"],
                            novo_valor,
                            campo_desc_edit.value or "",
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
                    ft.TextButton("Salvar", on_click=salvar_edicao),
                    ft.TextButton("Cancelar", on_click=lambda x: fechar_dialogo(dlg_editar)),
                ]
                abrir_dialogo(dlg_editar)

            lista_historico.controls.append(
                ft.ListTile(
                    leading=ft.Icon(icone, color=cor, size=18),
                    title=ft.Text(
                        f"{formatar_moeda(row['valor'])} · {row['tipo']}{desc_texto}",
                        color=cor,
                        size=13,
                    ),
                    subtitle=ft.Text(row["data"], color=ft.Colors.GREY_500, size=11),
                    trailing=ft.Row(
                        controls=[
                            ft.IconButton(
                                icon=ft.Icons.EDIT_OUTLINED,
                                icon_color=ft.Colors.BLUE_300,
                                icon_size=18,
                                tooltip="Editar",
                                on_click=abrir_edicao,
                            ),
                            ft.IconButton(
                                icon=ft.Icons.DELETE_OUTLINE,
                                icon_color=ft.Colors.RED_400,
                                icon_size=18,
                                tooltip="Apagar",
                                on_click=confirmar_exclusao,
                            ),
                        ],
                        tight=True,
                        spacing=0,
                    ),
                    dense=True,
                )
            )
        page.update()

    def recarregar_listas():
        garantir_conexao()
        atualizar_painel()
        carregar_lista_agrupada()
        carregar_historico()

    def acao_lancar(e=None):
        # Evita lançamento duplicado por duplo clique / Enter repetido
        if btn_lancar.disabled:
            return

        valor_float = validar_valor(input_valor.value or "")
        if valor_float is None:
            input_valor.error_text = "Informe um valor maior que zero"
            page.update()
            return

        btn_lancar.disabled = True
        page.update()

        try:
            garantir_conexao()
            db.inserir_lancamento(
                conn,
                turno_atual.id,
                estado_tipo["valor"],
                valor_float,
                input_desc.value or "",
            )

            input_valor.value = ""
            input_desc.value = ""
            input_valor.error_text = None

            mostrar_snackbar(f"{formatar_moeda(valor_float)} lançado em {estado_tipo['valor']}")
            recarregar_listas()
            page.run_task(input_valor.focus)
        except Exception:
            mostrar_snackbar("Erro ao lançar. Tente novamente.", ft.Colors.RED_800)
        finally:
            btn_lancar.disabled = False
            page.update()

    input_valor.on_submit = acao_lancar
    input_desc.on_submit = acao_lancar

    def montar_conteudo_resumo(totais: db.Totais):
        return ft.Column(
            width=min(300, largura_conteudo),
            tight=True,
            controls=[
                ft.Text(f"Turno #{turno_atual.id} · {turno_atual.aberto_em}", size=12, color=ft.Colors.GREY_500),
                ft.Row([
                    ft.Icon(ft.Icons.MONEY, color=ft.Colors.GREEN),
                    ft.Text("Dinheiro (físico):", expand=True),
                    ft.Text(formatar_moeda(totais.fisico), weight=ft.FontWeight.BOLD),
                ]),
                ft.Row([
                    ft.Icon(ft.Icons.PIX, color=ft.Colors.BLUE_400),
                    ft.Text("Total PIX:", expand=True),
                    ft.Text(formatar_moeda(totais.pix), weight=ft.FontWeight.BOLD),
                ]),
                ft.Row([
                    ft.Icon(ft.Icons.CREDIT_CARD, color=ft.Colors.ORANGE_400),
                    ft.Text("Cartões (+ Sodexo):", expand=True),
                    ft.Text(formatar_moeda(totais.cartoes), weight=ft.FontWeight.BOLD),
                ]),
                ft.Row([
                    ft.Icon(ft.Icons.RECEIPT_LONG, color=ft.Colors.PURPLE_400),
                    ft.Text("Requisição:", expand=True),
                    ft.Text(formatar_moeda(totais.requisicao), weight=ft.FontWeight.BOLD),
                ]),
                ft.Row([
                    ft.Icon(ft.Icons.REMOVE_CIRCLE, color=ft.Colors.RED_400),
                    ft.Text("Sangria:", expand=True),
                    ft.Text(formatar_moeda(totais.sangria), weight=ft.FontWeight.BOLD),
                ]),
                ft.Divider(height=20),
                ft.Row([
                    ft.Icon(ft.Icons.ACCOUNT_BALANCE_WALLET, color=ft.Colors.GREEN_ACCENT_400),
                    ft.Text("Total Geral:", expand=True, weight=ft.FontWeight.BOLD, size=18),
                    ft.Text(
                        formatar_moeda(totais.total_geral),
                        weight=ft.FontWeight.BOLD,
                        size=18,
                        color=ft.Colors.GREEN_ACCENT_400,
                    ),
                ]),
            ],
        )

    def acao_fechar_caixa(e=None):
        fechar_bottom_sheet()
        garantir_conexao()
        totais = db.obter_totais(conn, turno_atual.id)
        resumo = db.montar_resumo_texto(totais, turno_atual)
        dlg = ft.AlertDialog(
            title=ft.Text("Resumo do Turno"),
            content=montar_conteudo_resumo(totais),
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
                mostrar_snackbar("Erro ao encerrar o turno. Tente novamente.", ft.Colors.RED_800)

        dlg.actions = [
            ft.TextButton(
                content=ft.Row(
                    [ft.Icon(ft.Icons.CONTENT_COPY, size=18), ft.Text("Copiar resumo")],
                    tight=True,
                ),
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

        itens = []
        for turno in turnos:
            itens.append(
                ft.ListTile(
                    title=ft.Text(f"Turno #{turno['id']} · {formatar_moeda(turno['total_geral'])}"),
                    subtitle=ft.Text(f"{turno['aberto_em']} → {turno['fechado_em']}"),
                )
            )

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
                mostrar_snackbar("Erro ao zerar o turno. Nada foi apagado.", ft.Colors.RED_800)

        dlg_confirmar.actions = [
            ft.TextButton("Sim, Zerar", on_click=confirmar_zerar),
            ft.TextButton("Cancelar", on_click=lambda x: fechar_dialogo(dlg_confirmar)),
        ]
        abrir_dialogo(dlg_confirmar)

    # ── Bottom Sheet de Gerenciamento ──────────────────────────────────────
    bottom_sheet = ft.BottomSheet(
        open=False,
        content=ft.Container(
            padding=20,
            content=ft.Column(
                tight=True,
                spacing=12,
                controls=[
                    ft.Text(
                        "Gerenciar Turno",
                        size=18,
                        weight=ft.FontWeight.BOLD,
                    ),
                    ft.Divider(height=10),
                    ft.ListTile(
                        leading=ft.Icon(ft.Icons.ASSESSMENT, color=ft.Colors.BLUE_300),
                        title=ft.Text("Fechar Caixa / Resumo", size=16),
                        on_click=acao_fechar_caixa,
                    ),
                    ft.ListTile(
                        leading=ft.Icon(ft.Icons.HISTORY, color=ft.Colors.GREY_300),
                        title=ft.Text("Histórico de Turnos", size=16),
                        on_click=acao_historico_turnos,
                    ),
                    ft.Divider(height=10),
                    ft.ListTile(
                        leading=ft.Icon(ft.Icons.DELETE_FOREVER, color=ft.Colors.RED_400),
                        title=ft.Text("Limpar / Zerar Tudo", size=16, color=ft.Colors.RED_400),
                        on_click=acao_zerar_tudo,
                    ),
                ],
            ),
        ),
    )

    def abrir_bottom_sheet(e):
        page.show_dialog(bottom_sheet)

    def fechar_bottom_sheet():
        page.pop_dialog()

    # ── Botão principal ────────────────────────────────────────────────────
    btn_lancar = ft.Button(
        content=ft.Row(
            [
                ft.Icon(ft.Icons.ADD_SHOPPING_CART, color=ft.Colors.WHITE),
                ft.Text("Lançar Abastecimento", color=ft.Colors.WHITE, size=16),
            ],
            alignment=ft.MainAxisAlignment.CENTER,
            tight=True,
        ),
        style=_estilo_btn(ft.Colors.BLUE_700),
        on_click=acao_lancar,
        width=largura_conteudo,
        height=58,
    )

    # ── Totais ─────────────────────────────────────────────────────────────
    linha_totais_secundarios = ft.Row(
        controls=[
            ft.Column(
                [ft.Text("PIX", size=13, color=ft.Colors.GREY_400), txt_pix],
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                spacing=2,
            ),
            ft.Column(
                [ft.Text("Cartões", size=13, color=ft.Colors.GREY_400), txt_cartoes],
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                spacing=2,
            ),
        ],
        alignment=ft.MainAxisAlignment.SPACE_AROUND,
        width=largura_conteudo,
    )

    linha_totais_extras = ft.Row(
        controls=[
            ft.Column(
                [ft.Text("Requisição", size=13, color=ft.Colors.GREY_400), txt_requisicao],
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                spacing=2,
            ),
            ft.Column(
                [ft.Text("Sangria", size=13, color=ft.Colors.GREY_400), txt_sangria],
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                spacing=2,
            ),
        ],
        alignment=ft.MainAxisAlignment.SPACE_AROUND,
        width=largura_conteudo,
    )

    # ── Header com botão de tema e botão de menu ────────────────────────────
    def alternar_tema(e):
        # Sem cor fixa (WHITE70) no título/ícones do header, eles já seguem
        # o tema automaticamente — só precisamos trocar o theme_mode e
        # atualizar o ícone do próprio botão (sol/lua).
        page.theme_mode = (
            ft.ThemeMode.LIGHT if page.theme_mode == ft.ThemeMode.DARK else ft.ThemeMode.DARK
        )
        btn_tema.icon = (
            ft.Icons.LIGHT_MODE if page.theme_mode == ft.ThemeMode.DARK else ft.Icons.DARK_MODE
        )
        page.update()

    btn_tema = ft.IconButton(
        icon=ft.Icons.LIGHT_MODE,
        tooltip="Alternar tema claro/escuro",
        on_click=alternar_tema,
    )

    header = ft.Row(
        controls=[
            ft.Text(
                "Caixa · Posto Janjão",
                size=16,
                weight=ft.FontWeight.BOLD,
                expand=True,
            ),
            btn_tema,
            ft.IconButton(
                icon=ft.Icons.MORE_VERT,
                tooltip="Gerenciar turno",
                on_click=abrir_bottom_sheet,
            ),
        ],
        alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
        width=largura_conteudo,
    )

    # ── Layout principal ───────────────────────────────────────────────────
    conteudo_principal = ft.Column(
        controls=[
            header,
            txt_turno,
            ft.Text("Físico na Carteira (Dinheiro):", size=16, color=ft.Colors.GREY_400),
            txt_fisico,
            linha_totais_secundarios,
            linha_totais_extras,
            ft.Divider(height=10, color=ft.Colors.TRANSPARENT),
            rotulo_forma_pagamento,
            seletor_tipo,
            input_valor,
            botoes_rapidos,
            input_desc,
            ft.Divider(height=5, color=ft.Colors.TRANSPARENT),
            btn_lancar,
            ft.Divider(height=14),
            ft.Text(
                "Totais por Tipo:",
                size=18,
                weight=ft.FontWeight.BOLD,
                width=largura_conteudo,
                text_align=ft.TextAlign.LEFT,
            ),
            lista_agrupada,
            ft.Divider(height=5),
            ft.Text(
                "Histórico Recente:",
                size=18,
                weight=ft.FontWeight.BOLD,
                width=largura_conteudo,
                text_align=ft.TextAlign.LEFT,
            ),
            lista_historico,
        ],
        horizontal_alignment=ft.CrossAxisAlignment.CENTER,
        spacing=10,
    )

    def montar_interface():
        page.controls.clear()
        page.add(conteudo_principal)
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
    porta = int(os.environ.get("PORT", 5000))
    ft.run(main, view=ft.AppView.WEB_BROWSER, port=porta, host="0.0.0.0")
