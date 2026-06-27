import os

import flet as ft

import db


def main(page: ft.Page):
    page.title = "Caixa - Posto Janjão"
    page.theme_mode = ft.ThemeMode.DARK
    page.window.width = 420
    page.vertical_alignment = ft.MainAxisAlignment.START
    page.scroll = ft.ScrollMode.AUTO
    page.horizontal_alignment = ft.CrossAxisAlignment.CENTER
    page.padding = 16

    conn = db.conectar()
    db.inicializar_banco(conn)
    turno_atual = db.obter_ou_criar_turno_aberto(conn)

    pin_configurado = os.environ.get("CAIXA_PIN", "").strip()
    autenticado = not pin_configurado
    largura_conteudo = 320

    def atualizar_largura():
        nonlocal largura_conteudo
        largura_conteudo = max(280, min(400, int(page.width) - 32))
        aplicar_largura()

    def aplicar_largura():
        largura = largura_conteudo
        dropdown_tipo.width = largura
        input_valor.width = largura
        input_desc.width = largura
        botoes_rapidos.width = largura
        lista_agrupada.width = largura
        lista_historico.width = largura
        btn_lancar.width = largura
        btn_fechar.width = largura
        btn_limpar.width = largura
        btn_historico_turnos.width = largura
        linha_totais_secundarios.width = largura
        linha_totais_extras.width = largura
        txt_turno.width = largura

    def mostrar_snackbar(mensagem: str, cor=ft.Colors.GREEN_700):
        page.open(
            ft.SnackBar(
                content=ft.Text(mensagem, color=ft.Colors.WHITE),
                bgcolor=cor,
                duration=2500,
            )
        )

    def abrir_dialogo(dlg):
        if dlg not in page.overlay:
            page.overlay.append(dlg)
        dlg.open = True
        page.update()

    def fechar_dialogo(dlg):
        dlg.open = False
        page.update()

    def cor_icone_tipo(tipo):
        if tipo == "Dinheiro":
            return ft.Colors.GREEN, ft.Icons.MONEY
        if tipo == "Sangria":
            return ft.Colors.RED_400, ft.Icons.REMOVE_CIRCLE
        if tipo == "Pix":
            return ft.Colors.BLUE_400, ft.Icons.PIX
        if tipo == "Requisição":
            return ft.Colors.PURPLE_400, ft.Icons.RECEIPT_LONG
        if tipo == "Sodexo":
            return ft.Colors.TEAL_400, ft.Icons.LUNCH_DINING
        return ft.Colors.ORANGE_400, ft.Icons.CREDIT_CARD

    txt_fisico = ft.Text("R$ 0.00", size=40, weight=ft.FontWeight.BOLD, color=ft.Colors.GREEN_400)
    txt_pix = ft.Text("R$ 0.00", size=18, weight=ft.FontWeight.BOLD, color=ft.Colors.BLUE_400)
    txt_cartoes = ft.Text("R$ 0.00", size=18, weight=ft.FontWeight.BOLD, color=ft.Colors.ORANGE_400)
    txt_requisicao = ft.Text("R$ 0.00", size=16, weight=ft.FontWeight.BOLD, color=ft.Colors.PURPLE_400)
    txt_sangria = ft.Text("R$ 0.00", size=16, weight=ft.FontWeight.BOLD, color=ft.Colors.RED_400)
    txt_turno = ft.Text("", size=12, color=ft.Colors.GREY_500, text_align=ft.TextAlign.CENTER)

    def atualizar_painel():
        nonlocal turno_atual
        turno_atual = db.obter_ou_criar_turno_aberto(conn)
        totais = db.obter_totais(conn, turno_atual.id)
        txt_fisico.value = f"R$ {totais.fisico:.2f}"
        txt_pix.value = f"R$ {totais.pix:.2f}"
        txt_cartoes.value = f"R$ {totais.cartoes:.2f}"
        txt_requisicao.value = f"R$ {totais.requisicao:.2f}"
        txt_sangria.value = f"R$ {totais.sangria:.2f}"
        txt_turno.value = f"Turno #{turno_atual.id} · aberto em {turno_atual.aberto_em}"
        page.update()

    dropdown_tipo = ft.Dropdown(
        label="Forma de Pagamento",
        options=[ft.dropdown.Option(tipo) for tipo in db.TIPOS_DROPDOWN],
        value="Dinheiro",
        width=largura_conteudo,
    )

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
        input_valor.focus()

    def validar_valor(texto: str) -> float | None:
        if not texto or not texto.strip():
            return None
        try:
            valor = float(texto.replace(",", "."))
        except ValueError:
            return None
        if valor <= 0:
            return None
        return valor

    def make_btn_rapido(label, val, desc="", cor=ft.Colors.BLUE_GREY_700):
        def _click(e, v=val, d=desc):
            set_valor(v, d)

        return ft.ElevatedButton(
            content=ft.Text(label, color=ft.Colors.WHITE, size=13),
            bgcolor=cor,
            on_click=_click,
            height=38,
        )

    def acao_completou(e):
        dropdown_tipo.value = "Dinheiro"
        input_desc.value = "Completou"
        input_valor.value = ""
        input_valor.error_text = None
        page.update()
        input_valor.focus()

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
            ft.ElevatedButton(
                content=ft.Text("Completou", color=ft.Colors.WHITE, size=13),
                bgcolor=ft.Colors.GREEN_800,
                on_click=acao_completou,
                height=38,
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
                    title=ft.Text(f"{tipo} - R$ {valor_total:.2f}", color=cor, weight=ft.FontWeight.BOLD),
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
                    content=ft.Text(f"Remover R$ {valor:.2f} · {tipo}?"),
                )

                def excluir_confirmado(x, lancamento_id=rid):
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

            lista_historico.controls.append(
                ft.ListTile(
                    leading=ft.Icon(icone, color=cor, size=18),
                    title=ft.Text(
                        f"R$ {row['valor']:.2f} · {row['tipo']}{desc_texto}",
                        color=cor,
                        size=13,
                    ),
                    subtitle=ft.Text(row["data"], color=ft.Colors.GREY_500, size=11),
                    trailing=ft.IconButton(
                        icon=ft.Icons.DELETE_OUTLINE,
                        icon_color=ft.Colors.RED_400,
                        icon_size=18,
                        tooltip="Apagar",
                        on_click=confirmar_exclusao,
                    ),
                    dense=True,
                )
            )
        page.update()

    def recarregar_listas():
        atualizar_painel()
        carregar_lista_agrupada()
        carregar_historico()

    def acao_lancar(e=None):
        valor_float = validar_valor(input_valor.value or "")
        if valor_float is None:
            input_valor.error_text = "Informe um valor maior que zero"
            page.update()
            return

        db.inserir_lancamento(
            conn,
            turno_atual.id,
            dropdown_tipo.value,
            valor_float,
            input_desc.value or "",
        )

        input_valor.value = ""
        input_desc.value = ""
        input_valor.error_text = None

        mostrar_snackbar(f"R$ {valor_float:.2f} lançado em {dropdown_tipo.value}")
        recarregar_listas()
        input_valor.focus()

    input_valor.on_submit = acao_lancar
    input_desc.on_submit = acao_lancar

    def montar_conteudo_resumo(totais: db.Totais):
        return ft.Column(
            width=min(300, largura_conteudo),
            tight=True,
            controls=[
                ft.Text(f"Turno #{turno_atual.id} · {turno_atual.aberto_em}", size=12, color=ft.Colors.GREY_500),
                ft.Row(
                    [
                        ft.Icon(ft.Icons.MONEY, color=ft.Colors.GREEN),
                        ft.Text("Dinheiro (físico):", expand=True),
                        ft.Text(f"R$ {totais.fisico:.2f}", weight=ft.FontWeight.BOLD),
                    ]
                ),
                ft.Row(
                    [
                        ft.Icon(ft.Icons.PIX, color=ft.Colors.BLUE_400),
                        ft.Text("Total PIX:", expand=True),
                        ft.Text(f"R$ {totais.pix:.2f}", weight=ft.FontWeight.BOLD),
                    ]
                ),
                ft.Row(
                    [
                        ft.Icon(ft.Icons.CREDIT_CARD, color=ft.Colors.ORANGE_400),
                        ft.Text("Cartões (+ Sodexo):", expand=True),
                        ft.Text(f"R$ {totais.cartoes:.2f}", weight=ft.FontWeight.BOLD),
                    ]
                ),
                ft.Row(
                    [
                        ft.Icon(ft.Icons.RECEIPT_LONG, color=ft.Colors.PURPLE_400),
                        ft.Text("Requisição:", expand=True),
                        ft.Text(f"R$ {totais.requisicao:.2f}", weight=ft.FontWeight.BOLD),
                    ]
                ),
                ft.Row(
                    [
                        ft.Icon(ft.Icons.REMOVE_CIRCLE, color=ft.Colors.RED_400),
                        ft.Text("Sangria:", expand=True),
                        ft.Text(f"R$ {totais.sangria:.2f}", weight=ft.FontWeight.BOLD),
                    ]
                ),
                ft.Divider(color=ft.Colors.WHITE24, height=20),
                ft.Row(
                    [
                        ft.Icon(ft.Icons.ACCOUNT_BALANCE_WALLET, color=ft.Colors.GREEN_ACCENT_400),
                        ft.Text("Total Geral:", expand=True, weight=ft.FontWeight.BOLD, size=18),
                        ft.Text(
                            f"R$ {totais.total_geral:.2f}",
                            weight=ft.FontWeight.BOLD,
                            size=18,
                            color=ft.Colors.GREEN_ACCENT_400,
                        ),
                    ]
                ),
            ],
        )

    def acao_fechar_caixa(e):
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
            db.fechar_turno(conn, turno_atual.id, totais)
            turno_atual = db.obter_ou_criar_turno_aberto(conn)
            fechar_dialogo(dlg)
            mostrar_snackbar("Turno encerrado. Novo turno iniciado.")
            recarregar_listas()

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

    def acao_historico_turnos(e):
        turnos = db.listar_turnos_fechados(conn)
        if not turnos:
            mostrar_snackbar("Nenhum turno encerrado ainda.", ft.Colors.BLUE_GREY_700)
            return

        itens = []
        for turno in turnos:
            itens.append(
                ft.ListTile(
                    title=ft.Text(f"Turno #{turno['id']} · R$ {turno['total_geral']:.2f}"),
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

    def acao_zerar_tudo(e):
        dlg_confirmar = ft.AlertDialog(
            title=ft.Text("Aviso Importante"),
            content=ft.Text(
                "Isso apaga todos os lançamentos do turno atual.\n"
                "Um backup em CSV será salvo antes da exclusão."
            ),
        )

        def confirmar_zerar(x):
            caminho_backup = db.exportar_turno_csv(conn, turno_atual.id)
            db.zerar_turno(conn, turno_atual.id)
            fechar_dialogo(dlg_confirmar)
            mostrar_snackbar(f"Turno zerado. Backup: {os.path.basename(caminho_backup)}")
            recarregar_listas()

        dlg_confirmar.actions = [
            ft.TextButton("Sim, Zerar", on_click=confirmar_zerar),
            ft.TextButton("Cancelar", on_click=lambda x: fechar_dialogo(dlg_confirmar)),
        ]
        abrir_dialogo(dlg_confirmar)

    btn_lancar = ft.ElevatedButton(
        content=ft.Row(
            [
                ft.Icon(ft.Icons.ADD_SHOPPING_CART, color=ft.Colors.WHITE),
                ft.Text("Lançar Abastecimento", color=ft.Colors.WHITE),
            ],
            alignment=ft.MainAxisAlignment.CENTER,
            tight=True,
        ),
        on_click=acao_lancar,
        width=largura_conteudo,
        height=50,
        bgcolor=ft.Colors.BLUE_700,
    )

    btn_fechar = ft.ElevatedButton(
        content=ft.Row(
            [
                ft.Icon(ft.Icons.ASSESSMENT, color=ft.Colors.WHITE),
                ft.Text("Fechar Caixa / Resumo", color=ft.Colors.WHITE),
            ],
            alignment=ft.MainAxisAlignment.CENTER,
            tight=True,
        ),
        on_click=acao_fechar_caixa,
        width=largura_conteudo,
        height=50,
        bgcolor=ft.Colors.GREY_700,
    )

    btn_limpar = ft.ElevatedButton(
        content=ft.Row(
            [
                ft.Icon(ft.Icons.DELETE_FOREVER, color=ft.Colors.WHITE),
                ft.Text("Limpar / Zerar Tudo", color=ft.Colors.WHITE),
            ],
            alignment=ft.MainAxisAlignment.CENTER,
            tight=True,
        ),
        on_click=acao_zerar_tudo,
        width=largura_conteudo,
        height=50,
        bgcolor=ft.Colors.RED_700,
    )

    btn_historico_turnos = ft.OutlinedButton(
        content=ft.Row(
            [
                ft.Icon(ft.Icons.HISTORY, size=18),
                ft.Text("Histórico de Turnos"),
            ],
            alignment=ft.MainAxisAlignment.CENTER,
            tight=True,
        ),
        on_click=acao_historico_turnos,
        width=largura_conteudo,
        height=42,
    )

    linha_totais_secundarios = ft.Row(
        controls=[
            ft.Column(
                [ft.Text("PIX", size=11, color=ft.Colors.GREY_400), txt_pix],
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                spacing=2,
            ),
            ft.Column(
                [ft.Text("Cartões", size=11, color=ft.Colors.GREY_400), txt_cartoes],
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
                [ft.Text("Requisição", size=11, color=ft.Colors.GREY_400), txt_requisicao],
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                spacing=2,
            ),
            ft.Column(
                [ft.Text("Sangria", size=11, color=ft.Colors.GREY_400), txt_sangria],
                horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                spacing=2,
            ),
        ],
        alignment=ft.MainAxisAlignment.SPACE_AROUND,
        width=largura_conteudo,
    )

    conteudo_principal = ft.Column(
        controls=[
            txt_turno,
            ft.Text("Físico na Carteira (Dinheiro):", size=14, color=ft.Colors.GREY_400),
            txt_fisico,
            linha_totais_secundarios,
            linha_totais_extras,
            ft.Divider(height=10, color=ft.Colors.TRANSPARENT),
            dropdown_tipo,
            input_valor,
            botoes_rapidos,
            input_desc,
            ft.Divider(height=5, color=ft.Colors.TRANSPARENT),
            btn_lancar,
            btn_fechar,
            btn_limpar,
            btn_historico_turnos,
            ft.Divider(height=10),
            ft.Text("Totais por Tipo:", size=16, weight=ft.FontWeight.BOLD, width=largura_conteudo, text_align=ft.TextAlign.LEFT),
            lista_agrupada,
            ft.Divider(height=5),
            ft.Text("Histórico Recente:", size=16, weight=ft.FontWeight.BOLD, width=largura_conteudo, text_align=ft.TextAlign.LEFT),
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
        campo_pin.focus()

    page.on_resized = lambda e: atualizar_largura()

    if autenticado:
        montar_interface()
    else:
        solicitar_pin()


if __name__ == "__main__":
    porta = int(os.environ.get("PORT", 5000))
    ft.run(main, view=ft.AppView.WEB_BROWSER, port=porta, host="0.0.0.0")