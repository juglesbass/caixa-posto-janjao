import flet as ft
import sqlite3
from datetime import datetime

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

    conn = inicializar_banco()

    def abrir_dialogo(dlg):
        if dlg not in page.overlay:
            page.overlay.append(dlg)
        dlg.open = True
        page.update()

    def fechar_dialogo(dlg):
        dlg.open = False
        page.update()

    def calcular_saldo():
        cursor = conn.cursor()
        cursor.execute("SELECT tipo, valor FROM lancamentos")
        saldo = 0.0
        for tipo, valor in cursor.fetchall():
            if tipo == "Dinheiro":
                saldo += valor
            elif tipo == "Sangria":
                saldo -= valor
        return saldo

    texto_saldo = ft.Text(
        f"R$ {calcular_saldo():.2f}",
        size=45,
        weight=ft.FontWeight.BOLD,
        color=ft.Colors.GREEN_400
    )

    dropdown_tipo = ft.Dropdown(
        label="Forma de Pagamento",
        options=[
            ft.dropdown.Option("Dinheiro"),
            ft.dropdown.Option("Cartão"),
            ft.dropdown.Option("Pix"),
            ft.dropdown.Option("Sangria"),
        ],
        value="Dinheiro",
        width=300
    )

    input_valor = ft.TextField(
        label="Valor (Ex: 50.00)",
        keyboard_type=ft.KeyboardType.NUMBER,
        width=300,
        prefix=ft.Text("R$ ")
    )

    input_desc = ft.TextField(
        label="Descrição / Placa (Opcional)",
        width=300
    )

    lista_historico = ft.ListView(expand=True, spacing=10, height=300)

    def carregar_historico():
        lista_historico.controls.clear()
        cursor = conn.cursor()
        cursor.execute("SELECT tipo, valor, descricao, data FROM lancamentos ORDER BY id DESC LIMIT 20")
        for tipo, valor, desc, data in cursor.fetchall():
            cor = ft.Colors.GREEN if tipo == "Dinheiro" else ft.Colors.RED_400 if tipo == "Sangria" else ft.Colors.BLUE_400
            icone = ft.Icons.MONEY if tipo == "Dinheiro" else ft.Icons.CREDIT_CARD if tipo == "Cartão" else ft.Icons.PIX
            lista_historico.controls.append(
                ft.ListTile(
                    leading=ft.Icon(icone, color=cor),
                    title=ft.Text(f"{tipo} - R$ {valor:.2f}", color=cor, weight=ft.FontWeight.BOLD),
                    subtitle=ft.Text(f"{desc} | {data}" if desc else data),
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
        texto_saldo.value = f"R$ {calcular_saldo():.2f}"
        carregar_historico()
        input_valor.focus()

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
        width=300,
        height=55,
        bgcolor=ft.Colors.BLUE_700,
    )

    # --- DIÁLOGO LIMPAR TUDO ---
    dlg_limpar = ft.AlertDialog(
        modal=True,
        title=ft.Text("⚠️ Zerar Tudo?"),
        content=ft.Text(
            "Isso vai apagar TODOS os lançamentos do caixa.\nEssa ação não pode ser desfeita.",
            color=ft.Colors.GREY_400
        ),
    )

    def confirmar_limpar(e):
        cursor = conn.cursor()
        cursor.execute("DELETE FROM lancamentos")
        conn.commit()
        fechar_dialogo(dlg_limpar)
        texto_saldo.value = "R$ 0.00"
        input_valor.value = ""
        input_desc.value = ""
        dropdown_tipo.value = "Dinheiro"
        carregar_historico()

    def cancelar_limpar(e):
        fechar_dialogo(dlg_limpar)

    dlg_limpar.actions = [
        ft.TextButton("Cancelar", on_click=cancelar_limpar),
        ft.ElevatedButton(
            content=ft.Row(
                [
                    ft.Icon(ft.Icons.DELETE_FOREVER, color=ft.Colors.WHITE),
                    ft.Text("Zerar Tudo", color=ft.Colors.WHITE),
                ],
                alignment=ft.MainAxisAlignment.CENTER,
                tight=True,
            ),
            bgcolor=ft.Colors.RED_700,
            on_click=confirmar_limpar,
        ),
    ]

    btn_limpar = ft.ElevatedButton(
        content=ft.Row(
            [
                ft.Icon(ft.Icons.DELETE_SWEEP, color=ft.Colors.WHITE),
                ft.Text("Limpar / Zerar Tudo", color=ft.Colors.WHITE),
            ],
            alignment=ft.MainAxisAlignment.CENTER,
            tight=True,
        ),
        on_click=lambda e: abrir_dialogo(dlg_limpar),
        width=300,
        height=45,
        bgcolor=ft.Colors.RED_900,
    )

    # --- DIÁLOGO RESUMO / FECHAR CAIXA ---
    dlg_resumo = ft.AlertDialog(modal=True, title=ft.Text("Resumo do Turno"))

    def fechar_turno(e):
        cursor = conn.cursor()
        cursor.execute("DELETE FROM lancamentos")
        conn.commit()
        fechar_dialogo(dlg_resumo)
        texto_saldo.value = f"R$ {calcular_saldo():.2f}"
        carregar_historico()

    def cancelar_fechamento(e):
        fechar_dialogo(dlg_resumo)

    def abrir_resumo(e):
        cursor = conn.cursor()
        cursor.execute("SELECT tipo, SUM(valor) FROM lancamentos GROUP BY tipo")
        totais = {tipo: valor for tipo, valor in cursor.fetchall()}

        dinheiro = totais.get("Dinheiro", 0.0)
        cartao = totais.get("Cartão", 0.0)
        pix = totais.get("Pix", 0.0)
        sangria = totais.get("Sangria", 0.0)

        fisico_esperado = dinheiro - sangria
        total_vendido = dinheiro + cartao + pix

        dlg_resumo.content = ft.Column([
            ft.Text(f"💰 Dinheiro: R$ {dinheiro:.2f}"),
            ft.Text(f"💳 Cartão: R$ {cartao:.2f}"),
            ft.Text(f"📱 Pix: R$ {pix:.2f}"),
            ft.Divider(),
            ft.Text(f"🩸 Sangrias (Retiradas): R$ {sangria:.2f}", color=ft.Colors.RED_400),
            ft.Divider(),
            ft.Text(f"💵 FÍSICO NA CARTEIRA: R$ {fisico_esperado:.2f}", weight=ft.FontWeight.BOLD, color=ft.Colors.GREEN_400),
            ft.Text(f"📊 TOTAL VENDIDO (Soma Geral): R$ {total_vendido:.2f}", weight=ft.FontWeight.BOLD, color=ft.Colors.BLUE_400),
            ft.Text("\nDeseja finalizar este turno e zerar o caixa para amanhã?", size=12, color=ft.Colors.GREY_400),
        ], tight=True)

        dlg_resumo.actions = [
            ft.TextButton("Cancelar", on_click=cancelar_fechamento),
            ft.ElevatedButton(
                content=ft.Row(
                    [ft.Text("Zerar Caixa", color=ft.Colors.WHITE)],
                    alignment=ft.MainAxisAlignment.CENTER,
                    tight=True,
                ),
                bgcolor=ft.Colors.RED_700,
                on_click=fechar_turno,
            ),
        ]

        abrir_dialogo(dlg_resumo)

    btn_resumo = ft.ElevatedButton(
        content=ft.Row(
            [
                ft.Icon(ft.Icons.ANALYTICS, color=ft.Colors.WHITE),
                ft.Text("Fechar Caixa / Resumo", color=ft.Colors.WHITE),
            ],
            alignment=ft.MainAxisAlignment.CENTER,
            tight=True,
        ),
        on_click=abrir_resumo,
        width=300,
        height=45,
        bgcolor=ft.Colors.GREY_800,
    )

    page.add(
        ft.Column([
            ft.Text("Físico na Carteira:", size=16, color=ft.Colors.GREY_400),
            texto_saldo,
            ft.Divider(height=20, color=ft.Colors.WHITE24),
            dropdown_tipo,
            input_valor,
            input_desc,
            btn_lancar,
            btn_resumo,
            btn_limpar,
            ft.Divider(height=20, color=ft.Colors.WHITE24),
            ft.Text("Últimos Lançamentos:", size=16, weight=ft.FontWeight.BOLD),
            lista_historico
        ], horizontal_alignment=ft.CrossAxisAlignment.CENTER)
    )

    carregar_historico()

ft.run(main, view=ft.AppView.WEB_BROWSER, port=5000, host="0.0.0.0")
