import flet as ft
import sqlite3
from datetime import datetime

# Cria o banco de dados e a tabela se não existirem
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
        label="Valor em R$ (Ex: 50.00)",
        keyboard_type=ft.KeyboardType.NUMBER,
        width=300,
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

    page.add(
        ft.Column([
            ft.Text("Físico na Carteira:", size=16, color=ft.Colors.GREY_400),
            texto_saldo,
            ft.Divider(height=20, color=ft.Colors.WHITE24),
            dropdown_tipo,
            input_valor,
            input_desc,
            btn_lancar,
            ft.Divider(height=20, color=ft.Colors.WHITE24),
            ft.Text("Últimos Lançamentos:", size=16, weight=ft.FontWeight.BOLD),
            lista_historico
        ], horizontal_alignment=ft.CrossAxisAlignment.CENTER)
    )

    carregar_historico()

ft.run(main, view=ft.AppView.WEB_BROWSER, port=5000, host="0.0.0.0")
