import flet as ft
import sqlite3
from datetime import datetime
import os

def inicializar_banco():
    conn = sqlite3.connect("meu_caixa.db", check_same_thread=False)
    cursor = conn.cursor()
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS lancamentos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tipo TEXT,
            valor REAL,
            descricao TEXT,
            data TEXT
        )
    ''')
    conn.commit()
    return conn

def main(page: ft.Page):
    page.title = "Caixa - Posto Janjão"
    page.theme_mode = ft.ThemeMode.DARK
    page.window.width = 400
    page.vertical_alignment = ft.MainAxisAlignment.START
    page.scroll = ft.ScrollMode.AUTO
    page.horizontal_alignment = ft.CrossAxisAlignment.CENTER

    conn = inicializar_banco()

    lista_cartoes = [
        "Master Crédito", "Master Débito",
        "Visa Crédito", "Visa Débito",
        "Elo Crédito", "Elo Débito"
    ]

    def abrir_dialogo(dlg):
        if dlg not in page.overlay:
            page.overlay.append(dlg)
        dlg.open = True
        page.update()

    def fechar_dialogo(dlg):
        dlg.open = False
        page.update()

    def obter_totais():
        cursor = conn.cursor()
        cursor.execute("SELECT tipo, SUM(valor) FROM lancamentos GROUP BY tipo")
        totais = {tipo: valor for tipo, valor in cursor.fetchall()}

        dinheiro = totais.get("Dinheiro", 0.0)
        pix = totais.get("Pix", 0.0)
        sangria = totais.get("Sangria", 0.0)
        total_cartoes = sum(totais.get(c, 0.0) for c in lista_cartoes)

        fisico = dinheiro - sangria
        return fisico, pix, total_cartoes

    txt_fisico = ft.Text("R$ 0.00", size=40, weight=ft.FontWeight.BOLD, color=ft.Colors.GREEN_400)
    txt_pix = ft.Text("R$ 0.00", size=20, weight=ft.FontWeight.BOLD, color=ft.Colors.BLUE_400)
    txt_cartoes = ft.Text("R$ 0.00", size=20, weight=ft.FontWeight.BOLD, color=ft.Colors.ORANGE_400)

    def atualizar_painel():
        fisico, pix, cartoes = obter_totais()
        txt_fisico.value = f"R$ {fisico:.2f}"
        txt_pix.value = f"R$ {pix:.2f}"
        txt_cartoes.value = f"R$ {cartoes:.2f}"
        page.update()

    dropdown_tipo = ft.Dropdown(
        label="Forma de Pagamento",
        options=[
            ft.dropdown.Option("Dinheiro"),
            ft.dropdown.Option("Pix"),
            ft.dropdown.Option("Requisição"),
            ft.dropdown.Option("Sodexo"),
            ft.dropdown.Option("Master Crédito"),
            ft.dropdown.Option("Master Débito"),
            ft.dropdown.Option("Visa Crédito"),
            ft.dropdown.Option("Visa Débito"),
            ft.dropdown.Option("Elo Crédito"),
            ft.dropdown.Option("Elo Débito"),
            ft.dropdown.Option("Sangria"),
        ],
        value="Dinheiro",
        width=320
    )

    input_valor = ft.TextField(
        label="Valor (Ex: 50.00 ou 50,00)",
        width=320,
        prefix=ft.Text("R$ ")
    )

    input_desc = ft.TextField(
        label="Descrição / Placa (Opcional)",
        width=320
    )

    lista_agrupada = ft.ListView(expand=True, spacing=5, height=250, width=320)

    def carregar_lista_agrupada():
        lista_agrupada.controls.clear()
        cursor = conn.cursor()
        cursor.execute("SELECT tipo, SUM(valor) FROM lancamentos GROUP BY tipo")

        for tipo, valor_total in cursor.fetchall():
            if valor_total == 0:
                continue

            if tipo == "Dinheiro":
                cor = ft.Colors.GREEN
                icone = ft.Icons.MONEY
            elif tipo == "Sangria":
                cor = ft.Colors.RED_400
                icone = ft.Icons.REMOVE_CIRCLE
            elif tipo == "Pix":
                cor = ft.Colors.BLUE_400
                icone = ft.Icons.PIX
            elif tipo == "Requisição":
                cor = ft.Colors.PURPLE_400
                icone = ft.Icons.RECEIPT_LONG
            elif tipo == "Sodexo":
                cor = ft.Colors.TEAL_400
                icone = ft.Icons.LUNCH_DINING
            else:
                cor = ft.Colors.ORANGE_400
                icone = ft.Icons.CREDIT_CARD

            lista_agrupada.controls.append(
                ft.ListTile(
                    leading=ft.Icon(icone, color=cor),
                    title=ft.Text(f"{tipo} - R$ {valor_total:.2f}", color=cor, weight=ft.FontWeight.BOLD),
                )
            )
        page.update()

    def acao_lancar(e):
        if not input_valor.value:
            return
        try:
            valor_float = float(input_valor.value.replace(",", "."))
        except ValueError:
            input_valor.error_text = "Valor inválido"
            page.update()
            return

        data_atual = datetime.now().strftime("%H:%M - %d/%m")
        cursor = conn.cursor()
        cursor.execute("INSERT INTO lancamentos (tipo, valor, descricao, data) VALUES (?, ?, ?, ?)",
                       (dropdown_tipo.value, valor_float, input_desc.value, data_atual))
        conn.commit()

        input_valor.value = ""
        input_desc.value = ""
        input_valor.error_text = None

        atualizar_painel()
        carregar_lista_agrupada()
        input_valor.focus()

    def acao_fechar_caixa(e):
        fisico, pix, cartoes = obter_totais()
        total_geral = fisico + pix + cartoes

        dlg = ft.AlertDialog(
            title=ft.Text("Resumo do Turno"),
            content=ft.Text(
                f"Físico (Dinheiro): R$ {fisico:.2f}\n"
                f"Total PIX: R$ {pix:.2f}\n"
                f"Total Cartões: R$ {cartoes:.2f}\n\n"
                f"Total Geral: R$ {total_geral:.2f}"
            ),
        )
        dlg.actions = [
            ft.TextButton("Fechar", on_click=lambda x: fechar_dialogo(dlg)),
        ]
        abrir_dialogo(dlg)

    def acao_zerar_tudo(e):
        dlg_confirmar = ft.AlertDialog(
            title=ft.Text("Aviso Importante"),
            content=ft.Text("Tem certeza que deseja apagar todos os lançamentos do turno atual?"),
        )

        def confirmar_zerar(x):
            cursor = conn.cursor()
            cursor.execute("DELETE FROM lancamentos")
            conn.commit()
            fechar_dialogo(dlg_confirmar)
            atualizar_painel()
            carregar_lista_agrupada()

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
        width=320,
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
        width=320,
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
        width=320,
        height=50,
        bgcolor=ft.Colors.RED_700,
    )

    page.add(
        ft.Column(
            controls=[
                ft.Text("Físico na Carteira (Dinheiro):", size=14, color=ft.Colors.GREY_400),
                txt_fisico,
                ft.Row(
                    controls=[
                        ft.Column([ft.Text("Total PIX", size=12, color=ft.Colors.GREY_400), txt_pix], horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                        ft.Column([ft.Text("Total Cartões", size=12, color=ft.Colors.GREY_400), txt_cartoes], horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                    ],
                    alignment=ft.MainAxisAlignment.SPACE_AROUND,
                    width=320,
                ),
                ft.Divider(height=10, color=ft.Colors.TRANSPARENT),
                dropdown_tipo,
                input_valor,
                input_desc,
                ft.Divider(height=5, color=ft.Colors.TRANSPARENT),
                btn_lancar,
                btn_fechar,
                btn_limpar,
                ft.Divider(height=10),
                ft.Text("Totais por Bandeira:", size=16, weight=ft.FontWeight.BOLD, width=320, text_align=ft.TextAlign.LEFT),
                lista_agrupada,
            ],
            horizontal_alignment=ft.CrossAxisAlignment.CENTER,
            spacing=10,
        )
    )

    atualizar_painel()
    carregar_lista_agrupada()

if __name__ == "__main__":
    porta = int(os.environ.get("PORT", 5000))
    ft.run(main, view=ft.AppView.WEB_BROWSER, port=porta, host="0.0.0.0")
