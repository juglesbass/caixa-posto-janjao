"""Camada de acesso ao banco de dados do caixa."""

import csv
import os
import sqlite3
from dataclasses import dataclass
from datetime import datetime
from typing import Optional

LISTA_CARTOES = [
    "Master Crédito",
    "Master Débito",
    "Visa Crédito",
    "Visa Débito",
    "Elo Crédito",
    "Elo Débito",
    "Sodexo",
]

TIPOS_DROPDOWN = [
    "Dinheiro",
    "Pix",
    "Requisição",
    "Sodexo",
    *LISTA_CARTOES,
    "Sangria",
]


def caminho_banco() -> str:
    return os.environ.get("CAIXA_DB_PATH", "meu_caixa.db")


def caminho_backups() -> str:
    return os.environ.get("CAIXA_BACKUP_DIR", "backups")


@dataclass
class Totais:
    fisico: float
    pix: float
    cartoes: float
    requisicao: float
    sangria: float
    dinheiro: float

    @property
    def total_geral(self) -> float:
        return self.fisico + self.pix + self.cartoes + self.requisicao


@dataclass
class Turno:
    id: int
    aberto_em: str
    fechado_em: Optional[str] = None


def conectar() -> sqlite3.Connection:
    conn = sqlite3.connect(caminho_banco(), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn


def inicializar_banco(conn: sqlite3.Connection) -> None:
    cursor = conn.cursor()
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS lancamentos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            tipo TEXT,
            valor REAL,
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
            fisico REAL,
            pix REAL,
            cartoes REAL,
            requisicao REAL,
            total_geral REAL
        )
        """
    )

    colunas = {linha[1] for linha in cursor.execute("PRAGMA table_info(lancamentos)")}
    if "turno_id" not in colunas:
        cursor.execute("ALTER TABLE lancamentos ADD COLUMN turno_id INTEGER")

    turno = obter_ou_criar_turno_aberto(conn)
    cursor.execute(
        "UPDATE lancamentos SET turno_id = ? WHERE turno_id IS NULL",
        (turno.id,),
    )
    conn.commit()


def obter_ou_criar_turno_aberto(conn: sqlite3.Connection) -> Turno:
    cursor = conn.cursor()
    row = cursor.execute(
        "SELECT id, aberto_em, fechado_em FROM turnos WHERE fechado_em IS NULL ORDER BY id DESC LIMIT 1"
    ).fetchone()
    if row:
        return Turno(id=row["id"], aberto_em=row["aberto_em"], fechado_em=row["fechado_em"])

    agora = datetime.now().strftime("%d/%m/%Y %H:%M")
    cursor.execute("INSERT INTO turnos (aberto_em) VALUES (?)", (agora,))
    conn.commit()
    turno_id = cursor.lastrowid
    return Turno(id=turno_id, aberto_em=agora)


def obter_totais(conn: sqlite3.Connection, turno_id: int) -> Totais:
    cursor = conn.cursor()
    cursor.execute(
        "SELECT tipo, SUM(valor) FROM lancamentos WHERE turno_id = ? GROUP BY tipo",
        (turno_id,),
    )
    totais = {tipo: valor for tipo, valor in cursor.fetchall()}

    dinheiro = totais.get("Dinheiro", 0.0)
    pix = totais.get("Pix", 0.0)
    sangria = totais.get("Sangria", 0.0)
    requisicao = totais.get("Requisição", 0.0)
    total_cartoes = sum(totais.get(cartao, 0.0) for cartao in LISTA_CARTOES)
    fisico = dinheiro - sangria

    return Totais(
        fisico=fisico,
        pix=pix,
        cartoes=total_cartoes,
        requisicao=requisicao,
        sangria=sangria,
        dinheiro=dinheiro,
    )


def montar_resumo_texto(totais: Totais, turno: Turno) -> str:
    return (
        f"⛽ *Fechamento de Turno - Posto Janjão*\n"
        f"🕐 Turno aberto em: {turno.aberto_em}\n\n"
        f"💵 Dinheiro (físico): R$ {totais.fisico:.2f}\n"
        f"📱 PIX: R$ {totais.pix:.2f}\n"
        f"💳 Cartões (+ Sodexo): R$ {totais.cartoes:.2f}\n"
        f"📋 Requisição: R$ {totais.requisicao:.2f}\n"
        f"🔻 Sangria: R$ {totais.sangria:.2f}\n\n"
        f"✅ Total Geral: R$ {totais.total_geral:.2f}"
    )


def inserir_lancamento(
    conn: sqlite3.Connection,
    turno_id: int,
    tipo: str,
    valor: float,
    descricao: str,
) -> None:
    data_atual = datetime.now().strftime("%H:%M - %d/%m")
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO lancamentos (tipo, valor, descricao, data, turno_id) VALUES (?, ?, ?, ?, ?)",
        (tipo, valor, descricao, data_atual, turno_id),
    )
    conn.commit()


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


def fechar_turno(conn: sqlite3.Connection, turno_id: int, totais: Totais) -> Turno:
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
    return obter_ou_criar_turno_aberto(conn)


def listar_agrupado(conn: sqlite3.Connection, turno_id: int) -> list[tuple[str, float]]:
    cursor = conn.cursor()
    cursor.execute(
        "SELECT tipo, SUM(valor) FROM lancamentos WHERE turno_id = ? GROUP BY tipo",
        (turno_id,),
    )
    return [(tipo, valor) for tipo, valor in cursor.fetchall() if valor != 0]


def listar_historico(conn: sqlite3.Connection, turno_id: int, limite: int = 30) -> list[sqlite3.Row]:
    cursor = conn.cursor()
    return cursor.execute(
        """
        SELECT id, tipo, valor, descricao, data
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
        SELECT id, aberto_em, fechado_em, fisico, pix, cartoes, requisicao, total_geral
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
        SELECT id, tipo, valor, descricao, data
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
