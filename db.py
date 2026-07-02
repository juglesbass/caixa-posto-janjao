"""Camada de acesso ao banco de dados do caixa."""

import csv
import os
import sqlite3
from dataclasses import dataclass
from datetime import datetime
from typing import Optional

# ── Constantes de tipo (evita strings soltas espalhadas pelo código) ───────
TIPO_DINHEIRO = "Dinheiro"
TIPO_PIX = "Pix"
TIPO_REQUISICAO = "Requisição"
TIPO_SODEXO = "Sodexo"
TIPO_DEPOSITO_GLOBAL = "Depósito Global"
TIPO_DESPESA = "Despesas"

LISTA_CARTOES = [
    "Master Crédito",
    "Master Débito",
    "Visa Crédito",
    "Visa Débito",
    "Elo Crédito",
    "Elo Débito",
    TIPO_SODEXO,
    "Alelo Multibenefícios",
]

TIPOS_DROPDOWN = [
    TIPO_DINHEIRO,
    TIPO_PIX,
    TIPO_REQUISICAO,
    *LISTA_CARTOES,
    TIPO_DEPOSITO_GLOBAL,
    TIPO_DESPESA,
]


def _diretorio_dados_app() -> str | None:
    return os.environ.get("FLET_APP_STORAGE_DATA") or None


def caminho_banco() -> str:
    if custom := os.environ.get("CAIXA_DB_PATH"):
        return custom
    if data_dir := _diretorio_dados_app():
        return os.path.join(data_dir, "meu_caixa.db")
    return "meu_caixa.db"


def caminho_backups() -> str:
    if custom := os.environ.get("CAIXA_BACKUP_DIR"):
        return custom
    if data_dir := _diretorio_dados_app():
        return os.path.join(data_dir, "backups")
    return "backups"


def formatar_moeda(valor: float) -> str:
    texto = f"{valor:,.2f}"
    texto = texto.replace(",", "_").replace(".", ",").replace("_", ".")
    return f"R$ {texto}"


@dataclass
class Totais:
    fisico: float
    pix: float
    cartoes: float
    requisicao: float
    dinheiro: float
    deposito_global: float = 0.0
    despesas: float = 0.0

    @property
    def total_geral(self) -> float:
        return (
            self.fisico
            + self.pix
            + self.cartoes
            + self.requisicao
            + self.deposito_global
            + self.despesas
        )


@dataclass
class Turno:
    id: int
    aberto_em: str
    operador: str = "Não informado"
    fechado_em: Optional[str] = None


def conectar() -> sqlite3.Connection:
    conn = sqlite3.connect(caminho_banco(), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    try:
        conn.execute("PRAGMA journal_mode=WAL")
    except sqlite3.Error:
        pass
    return conn


def inicializar_banco(conn: sqlite3.Connection) -> None:
    cursor = conn.cursor()
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS lancamentos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tipo TEXT,
            valor_centavos INTEGER,
            descricao TEXT,
            data TEXT,
            turno_id INTEGER
        )
        """
    )
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS turnos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            aberto_em TEXT NOT NULL,
            fechado_em TEXT,
            operador TEXT,
            fisico REAL,
            pix REAL,
            cartoes REAL,
            requisicao REAL,
            total_geral REAL
        )
        """
    )

    colunas_lanc = {linha[1] for linha in cursor.execute("PRAGMA table_info(lancamentos)")}

    if "turno_id" not in colunas_lanc:
        cursor.execute("ALTER TABLE lancamentos ADD COLUMN turno_id INTEGER")
        colunas_lanc.add("turno_id")

    if "valor_centavos" not in colunas_lanc:
        cursor.execute("ALTER TABLE lancamentos ADD COLUMN valor_centavos INTEGER")
        if "valor" in colunas_lanc:
            cursor.execute(
                """
                UPDATE lancamentos
                SET valor_centavos = CAST(ROUND(valor * 100) AS INTEGER)
                WHERE valor_centavos IS NULL AND valor IS NOT NULL
                """
            )
        colunas_lanc.add("valor_centavos")

    colunas_turnos = {linha[1] for linha in cursor.execute("PRAGMA table_info(turnos)")}
    if "operador" not in colunas_turnos:
        cursor.execute("ALTER TABLE turnos ADD COLUMN operador TEXT")

    turno = obter_turno_aberto(conn)
    if turno:
        cursor.execute(
            "UPDATE lancamentos SET turno_id = ? WHERE turno_id IS NULL",
            (turno.id,),
        )
    conn.commit()


# MODIFICAÇÃO PRINCIPAL 1: Apenas verifica se há turno, sem forçar criação.
def obter_turno_aberto(conn: sqlite3.Connection) -> Optional[Turno]:
    cursor = conn.cursor()
    row = cursor.execute(
        "SELECT id, aberto_em, fechado_em, operador FROM turnos WHERE fechado_em IS NULL ORDER BY id DESC LIMIT 1"
    ).fetchone()

    if row:
        return Turno(
            id=row["id"],
            aberto_em=row["aberto_em"],
            operador=row["operador"] or "Não informado",
            fechado_em=row["fechado_em"]
        )
    return None


# MODIFICAÇÃO PRINCIPAL 2: Função dedicada para criar turno.
def abrir_novo_turno(conn: sqlite3.Connection, operador: str) -> Turno:
    cursor = conn.cursor()
    agora = datetime.now().strftime("%d/%m/%Y %H:%M")
    cursor.execute("INSERT INTO turnos (aberto_em, operador) VALUES (?, ?)", (agora, operador))
    conn.commit()
    turno_id = cursor.lastrowid
    return Turno(id=turno_id, aberto_em=agora, operador=operador)


def obter_totais(conn: sqlite3.Connection, turno_id: int) -> Totais:
    cursor = conn.cursor()
    cursor.execute(
        "SELECT tipo, SUM(valor_centavos) FROM lancamentos WHERE turno_id = ? GROUP BY tipo",
        (turno_id,),
    )
    totais_centavos = {tipo: (centavos or 0) for tipo, centavos in cursor.fetchall()}

    dinheiro = totais_centavos.get(TIPO_DINHEIRO, 0) / 100.0
    pix = totais_centavos.get(TIPO_PIX, 0) / 100.0
    requisicao = totais_centavos.get(TIPO_REQUISICAO, 0) / 100.0
    deposito_global = totais_centavos.get(TIPO_DEPOSITO_GLOBAL, 0) / 100.0
    despesas = totais_centavos.get(TIPO_DESPESA, 0) / 100.0
    total_cartoes = sum(totais_centavos.get(cartao, 0) for cartao in LISTA_CARTOES) / 100.0
    fisico = dinheiro

    return Totais(
        fisico=fisico,
        pix=pix,
        cartoes=total_cartoes,
        requisicao=requisicao,
        dinheiro=dinheiro,
        deposito_global=deposito_global,
        despesas=despesas,
    )


def obter_detalhe_cartoes(conn: sqlite3.Connection, turno_id: int) -> dict[str, float]:
    cursor = conn.cursor()
    cursor.execute(
        "SELECT tipo, SUM(valor_centavos) FROM lancamentos WHERE turno_id = ? GROUP BY tipo",
        (turno_id,),
    )
    totais_centavos = {tipo: (centavos or 0) for tipo, centavos in cursor.fetchall()}
    return {cartao: totais_centavos.get(cartao, 0) / 100.0 for cartao in LISTA_CARTOES}


def montar_resumo_texto(totais: Totais, turno: Turno, detalhe_cartoes: dict[str, float]) -> str:
    linhas_cartoes = "\n".join(
        f"   • {bandeira}: {formatar_moeda(valor)}" for bandeira, valor in detalhe_cartoes.items()
    )
    return (
        f"⛽ *Fechamento de Turno - Posto Janjão*\n"
        f"👤 Operador: {turno.operador}\n"
        f"🕐 Turno aberto em: {turno.aberto_em}\n\n"
        f"💵 Dinheiro (físico): {formatar_moeda(totais.fisico)}\n"
        f"📱 PIX: {formatar_moeda(totais.pix)}\n"
        f"📋 Requisição: {formatar_moeda(totais.requisicao)}\n"
        f"🔒 Depósito Global: {formatar_moeda(totais.deposito_global)}\n"
        f"🛒 Despesas: {formatar_moeda(totais.despesas)}\n\n"
        f"💳 Cartões e Sodexo por bandeira:\n"
        f"{linhas_cartoes}\n"
        f"   Total de Cartões (+ Sodexo): {formatar_moeda(totais.cartoes)}\n\n"
        f"✅ Total Geral: {formatar_moeda(totais.total_geral)}"
    )


def inserir_lancamento(
    conn: sqlite3.Connection,
    turno_id: int,
    tipo: str,
    valor: float,
    descricao: str,
) -> None:
    data_atual = datetime.now().strftime("%H:%M - %d/%m")
    valor_centavos = int(round(valor * 100))
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO lancamentos (tipo, valor_centavos, descricao, data, turno_id) VALUES (?, ?, ?, ?, ?)",
        (tipo, valor_centavos, descricao, data_atual, turno_id),
    )
    conn.commit()


def atualizar_lancamento(
    conn: sqlite3.Connection,
    lancamento_id: int,
    turno_id: int,
    tipo: str,
    valor: float,
    descricao: str,
) -> bool:
    valor_centavos = int(round(valor * 100))
    cursor = conn.cursor()
    cursor.execute(
        """
        UPDATE lancamentos
        SET tipo = ?, valor_centavos = ?, descricao = ?
        WHERE id = ? AND turno_id = ?
        """,
        (tipo, valor_centavos, descricao, lancamento_id, turno_id),
    )
    conn.commit()
    return cursor.rowcount > 0


def deletar_lancamento(conn: sqlite3.Connection, lancamento_id: int, turno_id: int) -> bool:
    cursor = conn.cursor()
    cursor.execute(
        "DELETE FROM lancamentos WHERE id = ? AND turno_id = ?",
        (lancamento_id, turno_id),
    )
    conn.commit()
    return cursor.rowcount > 0


def zerar_turno(conn: sqlite3.Connection, turno_id: int) -> None:
    cursor = conn.cursor()
    cursor.execute("DELETE FROM lancamentos WHERE turno_id = ?", (turno_id,))
    conn.commit()


# MODIFICAÇÃO PRINCIPAL 3: Apenas fecha, sem retornar um turno novo.
def fechar_turno(conn: sqlite3.Connection, turno_id: int, totais: Totais) -> None:
    agora = datetime.now().strftime("%d/%m/%Y %H:%M")
    cursor = conn.cursor()
    cursor.execute(
        """
        UPDATE turnos
        SET fechado_em = ?, fisico = ?, pix = ?, cartoes = ?, requisicao = ?, total_geral = ?
        WHERE id = ?
        """,
        (
            agora,
            totais.fisico,
            totais.pix,
            totais.cartoes,
            totais.requisicao,
            totais.total_geral,
            turno_id,
        ),
    )
    conn.commit()


def listar_agrupado(conn: sqlite3.Connection, turno_id: int) -> list[tuple[str, float]]:
    cursor = conn.cursor()
    cursor.execute(
        "SELECT tipo, SUM(valor_centavos) FROM lancamentos WHERE turno_id = ? GROUP BY tipo",
        (turno_id,),
    )
    return [
        (tipo, (centavos or 0) / 100.0)
        for tipo, centavos in cursor.fetchall()
        if centavos
    ]


def listar_historico(conn: sqlite3.Connection, turno_id: int, limite: int = 30) -> list[sqlite3.Row]:
    cursor = conn.cursor()
    return cursor.execute(
        """
        SELECT id, tipo, valor_centavos / 100.0 AS valor, descricao, data
        FROM lancamentos
        WHERE turno_id = ?
        ORDER BY id DESC
        LIMIT ?
        """,
        (turno_id, limite),
    ).fetchall()


def listar_turnos_fechados(conn: sqlite3.Connection, limite: int = 20) -> list[sqlite3.Row]:
    cursor = conn.cursor()
    return cursor.execute(
        """
        SELECT id, aberto_em, fechado_em, operador, fisico, pix, cartoes, requisicao, total_geral
        FROM turnos
        WHERE fechado_em IS NOT NULL
        ORDER BY id DESC
        LIMIT ?
        """,
        (limite,),
    ).fetchall()


def exportar_turno_csv(conn: sqlite3.Connection, turno_id: int) -> str:
    os.makedirs(caminho_backups(), exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    caminho = os.path.join(caminho_backups(), f"turno_{turno_id}_{timestamp}.csv")

    cursor = conn.cursor()
    linhas = cursor.execute(
        """
        SELECT id, tipo, valor_centavos / 100.0 AS valor, descricao, data
        FROM lancamentos
        WHERE turno_id = ?
        ORDER BY id
        """,
        (turno_id,),
    ).fetchall()

    with open(caminho, "w", newline="", encoding="utf-8") as arquivo:
        escritor = csv.writer(arquivo)
        escritor.writerow(["id", "tipo", "valor", "descricao", "data"])
        for linha in linhas:
            escritor.writerow([linha["id"], linha["tipo"], linha["valor"], linha["descricao"], linha["data"]])

    return caminho
