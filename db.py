import base64
import csv
import logging
import os
import sqlite3
import sys
from dataclasses import dataclass
from datetime import datetime
from typing import Optional

logger = logging.getLogger("caixa_app")


def _is_pyodide() -> bool:
    """Verifica se está executando dentro do navegador (Pyodide WebAssembly)."""
    if "pyodide" in sys.modules or (hasattr(sys, "platform") and sys.platform == "emscripten"):
        return True
    try:
        import js
        return True
    except Exception:
        return False


def restaurar_banco_web_storage() -> None:
    """Restaura o banco de dados do localStorage do navegador no Pyodide WebAssembly."""
    if not _is_pyodide():
        return
    try:
        import js
        b64_db = js.localStorage.getItem("caixa_db_backup")
        if b64_db:
            db_bytes = base64.b64decode(b64_db)
            if len(db_bytes) > 0:
                caminho = caminho_banco()
                pasta = os.path.dirname(caminho)
                if pasta:
                    os.makedirs(pasta, exist_ok=True)
                with open(caminho, "wb") as f:
                    f.write(db_bytes)
                logger.info(f"[DB WebStorage] Banco de dados restaurado do localStorage ({len(db_bytes)} bytes).")
    except Exception as e:
        logger.error(f"[DB WebStorage] Erro ao restaurar do localStorage: {e}")


def salvar_banco_web_sync(conn: Optional[sqlite3.Connection] = None) -> None:
    """Salva o estado atual do banco no localStorage do navegador para persistência PWA."""
    if not _is_pyodide():
        return
    try:
        if conn:
            try:
                conn.commit()
            except Exception:
                pass
        import js
        caminho = caminho_banco()
        if os.path.exists(caminho):
            with open(caminho, "rb") as f:
                db_bytes = f.read()
            if len(db_bytes) > 0:
                b64_db = base64.b64encode(db_bytes).decode("utf-8")
                js.localStorage.setItem("caixa_db_backup", b64_db)
                js.localStorage.setItem("caixa_db_last_sync", datetime.now().isoformat())
                logger.info(f"[DB WebStorage] Banco sincronizado no localStorage ({len(db_bytes)} bytes).")
    except Exception as e:
        logger.error(f"[DB WebStorage] Erro ao salvar no localStorage: {e}")


# ── Constantes de máquinas e tipos ─────────────────────────────────────────
MAQUINA_REDE = "Rede"
MAQUINA_CIELO = "Cielo"
MAQUINAS = [MAQUINA_REDE, MAQUINA_CIELO]

# ── Constantes de tipo (evita strings soltas espalhadas pelo código) ───────
TIPO_DINHEIRO = "Dinheiro"
TIPO_PIX = "Pag Pix"
TIPO_REQUISICAO = "Requisição"
TIPO_SODEXO = "Sodexo"
TIPO_DEPOSITO_GLOBAL = "Depósito Global"
TIPO_DESPESA = "Despesas"
TIPO_SANGRIA = "Sangria"
TIPO_SUPRIMENTO = "Suprimento"

BANDEIRAS_BASE = [
    "Fitcard",
    "Excard",
    "Amex",
    "Eucard",
    "Pix",
    "Avancard",
    "Master Crédito",
    "Master Débito",
    "Visa Crédito",
    "Visa Débito",
    "Elo Crédito",
    "Elo Débito",
    TIPO_SODEXO,
    "Alelo Multibenefícios",
]

LISTA_CARTOES_REDE = [f"Rede {b}" for b in BANDEIRAS_BASE]
LISTA_CARTOES_CIELO = [f"Cielo {b}" for b in BANDEIRAS_BASE]
LISTA_CARTOES = [*LISTA_CARTOES_REDE, *LISTA_CARTOES_CIELO, *BANDEIRAS_BASE]


def eh_cartao(tipo: str) -> bool:
    """Verifica se uma forma de pagamento é cartão/voucher."""
    if not tipo:
        return False
    if tipo in (
        TIPO_DINHEIRO,
        TIPO_PIX,
        TIPO_REQUISICAO,
        TIPO_DEPOSITO_GLOBAL,
        TIPO_DESPESA,
        TIPO_SANGRIA,
        TIPO_SUPRIMENTO,
    ):
        return False
    if tipo.startswith("Rede ") or tipo.startswith("Cielo "):
        return True
    return tipo in BANDEIRAS_BASE or tipo in LISTA_CARTOES


_vistos_td = set()
TIPOS_DROPDOWN = []
for _t in [TIPO_DINHEIRO, TIPO_PIX, TIPO_REQUISICAO, *LISTA_CARTOES, TIPO_DEPOSITO_GLOBAL, TIPO_DESPESA, TIPO_SANGRIA, TIPO_SUPRIMENTO]:
    if _t not in _vistos_td:
        _vistos_td.add(_t)
        TIPOS_DROPDOWN.append(_t)


def _diretorio_seguro() -> str:
    # 1. Tenta pegar a pasta oficial do Flet primeiro
    data_dir = os.environ.get("FLET_APP_STORAGE_DATA")
    if data_dir:
        try:
            os.makedirs(data_dir, exist_ok=True)
            return data_dir
        except Exception:
            pass

    # 2. Em iOS compilado: Procura a pasta Documents autorizada do container
    if os.environ.get("FLET_PLATFORM") == "ios":
        home = os.environ.get("HOME")
        if home:
            docs = os.path.join(home, "Documents")
            try:
                os.makedirs(docs, exist_ok=True)
                return docs
            except Exception:
                pass

    # 3. Fallback robusto: pasta do projeto ao lado do script
    local_dir = os.path.dirname(os.path.abspath(__file__))
    try:
        os.makedirs(local_dir, exist_ok=True)
        return local_dir
    except Exception:
        return os.getcwd()


def caminho_banco() -> str:
    if custom := os.environ.get("CAIXA_DB_PATH"):
        return custom
    pasta = _diretorio_seguro()
    os.makedirs(pasta, exist_ok=True)
    return os.path.join(pasta, "meu_caixa.db")


def caminho_backups() -> str:
    if custom := os.environ.get("CAIXA_BACKUP_DIR"):
        return custom
    pasta = os.path.join(_diretorio_seguro(), "backups")
    os.makedirs(pasta, exist_ok=True)
    return pasta


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
    sangrias: float = 0.0
    suprimento: float = 0.0
    fundo_caixa: float = 0.0
    qtd_cartoes: int = 0
    qtd_pix: int = 0
    qtd_sangrias: int = 0

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

    @property
    def dinheiro_gaveta(self) -> float:
        """Calcula o dinheiro físico real esperado na gaveta."""
        return max(0.0, self.fundo_caixa + self.fisico + self.suprimento - self.sangrias - self.despesas)


@dataclass
class Turno:
    id: int
    aberto_em: str
    operador: str = "Não informado"
    fechado_em: Optional[str] = None
    vendas_sistema: float = 0.0
    observacao: str = ""
    numero_do_dia: int = 1
    fundo_caixa: float = 0.0


@dataclass
class Encerrante:
    id: int
    turno_id: int
    bico: str
    combustivel: str
    inicial: float
    final: float
    preco_litro: float
    litros: float
    total_reais: float


BICOS_PADRAO = [
    ("Bico 01", "Gasolina Comum", 5.89),
    ("Bico 02", "Gasolina Aditivada", 6.09),
    ("Bico 03", "Etanol", 3.99),
    ("Bico 04", "Diesel S10", 6.19),
]


def obter_numero_turno_do_dia(conn: sqlite3.Connection, turno_id: int) -> int:
    """Calcula o número sequencial do turno no seu respectivo dia (ex: 1º do dia, 2º do dia).
    Quando a data muda (novo dia), a contagem é automaticamente resetada para 1.
    """
    try:
        cursor = conn.cursor()
        row = cursor.execute("SELECT aberto_em FROM turnos WHERE id = ?", (turno_id,)).fetchone()
        if not row or not row["aberto_em"]:
            return 1
        data_str = row["aberto_em"][:10]
        count = cursor.execute(
            "SELECT COUNT(*) FROM turnos WHERE substr(aberto_em, 1, 10) = ? AND id <= ?",
            (data_str, turno_id),
        ).fetchone()[0]
        return max(1, count)
    except Exception:
        return 1


def conectar() -> sqlite3.Connection:
    restaurar_banco_web_storage()
    conn = sqlite3.connect(caminho_banco(), check_same_thread=False)
    conn.row_factory = sqlite3.Row
    try:
        if _is_pyodide():
            conn.execute("PRAGMA journal_mode=DELETE")
            conn.execute("PRAGMA synchronous=FULL")
        else:
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
            total_geral REAL,
            vendas_sistema REAL DEFAULT 0.0,
            observacao TEXT DEFAULT '',
            fundo_caixa REAL DEFAULT 0.0
        )
        """
    )
    cursor.execute(
        """
        CREATE TABLE IF NOT EXISTS encerrantes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            turno_id INTEGER NOT NULL,
            bico TEXT NOT NULL,
            combustivel TEXT NOT NULL,
            inicial REAL NOT NULL DEFAULT 0.0,
            final REAL NOT NULL DEFAULT 0.0,
            preco_litro REAL NOT NULL DEFAULT 0.0,
            litros REAL NOT NULL DEFAULT 0.0,
            total_reais REAL NOT NULL DEFAULT 0.0,
            FOREIGN KEY (turno_id) REFERENCES turnos(id)
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
    if "vendas_sistema" not in colunas_turnos:
        cursor.execute("ALTER TABLE turnos ADD COLUMN vendas_sistema REAL DEFAULT 0.0")
    if "observacao" not in colunas_turnos:
        cursor.execute("ALTER TABLE turnos ADD COLUMN observacao TEXT DEFAULT ''")
    if "fundo_caixa" not in colunas_turnos:
        cursor.execute("ALTER TABLE turnos ADD COLUMN fundo_caixa REAL DEFAULT 0.0")

    turno = obter_turno_aberto(conn)
    if turno:
        cursor.execute(
            "UPDATE lancamentos SET turno_id = ? WHERE turno_id IS NULL",
            (turno.id,),
        )
    conn.commit()
    salvar_banco_web_sync(conn)


def obter_turno_aberto(conn: sqlite3.Connection) -> Optional[Turno]:
    cursor = conn.cursor()
    row = cursor.execute(
        "SELECT id, aberto_em, fechado_em, operador, vendas_sistema, observacao, fundo_caixa FROM turnos WHERE fechado_em IS NULL ORDER BY id DESC LIMIT 1"
    ).fetchone()

    if row:
        cols = row.keys()
        v_sis = row["vendas_sistema"] if ("vendas_sistema" in cols and row["vendas_sistema"] is not None) else 0.0
        obs = row["observacao"] if ("observacao" in cols and row["observacao"] is not None) else ""
        f_cx = float(row["fundo_caixa"] or 0.0) if "fundo_caixa" in cols else 0.0
        num_dia = obter_numero_turno_do_dia(conn, row["id"])
        return Turno(
            id=row["id"],
            aberto_em=row["aberto_em"],
            operador=row["operador"] or "Não informado",
            fechado_em=row["fechado_em"],
            vendas_sistema=v_sis,
            observacao=obs,
            numero_do_dia=num_dia,
            fundo_caixa=f_cx,
        )
    return None


def obter_turno_por_id(conn: sqlite3.Connection, turno_id: int) -> Optional[Turno]:
    cursor = conn.cursor()
    row = cursor.execute(
        "SELECT id, aberto_em, fechado_em, operador, vendas_sistema, observacao, fundo_caixa FROM turnos WHERE id = ?",
        (turno_id,),
    ).fetchone()

    if row:
        cols = row.keys()
        v_sis = row["vendas_sistema"] if ("vendas_sistema" in cols and row["vendas_sistema"] is not None) else 0.0
        obs = row["observacao"] if ("observacao" in cols and row["observacao"] is not None) else ""
        f_cx = float(row["fundo_caixa"] or 0.0) if "fundo_caixa" in cols else 0.0
        num_dia = obter_numero_turno_do_dia(conn, row["id"])
        return Turno(
            id=row["id"],
            aberto_em=row["aberto_em"],
            operador=row["operador"] or "Não informado",
            fechado_em=row["fechado_em"],
            vendas_sistema=v_sis,
            observacao=obs,
            numero_do_dia=num_dia,
            fundo_caixa=f_cx,
        )
    return None


def salvar_auditoria_turno(conn: sqlite3.Connection, turno_id: int, vendas_sistema: float, observacao: str) -> None:
    cursor = conn.cursor()
    cursor.execute(
        "UPDATE turnos SET vendas_sistema = ?, observacao = ? WHERE id = ?",
        (vendas_sistema, observacao, turno_id),
    )
    conn.commit()
    salvar_banco_web_sync(conn)


def obter_ultimo_turno_fechado(conn: sqlite3.Connection) -> Optional[Turno]:
    """Retorna o último turno que foi encerrado."""
    cursor = conn.cursor()
    row = cursor.execute(
        "SELECT id, aberto_em, fechado_em, operador, vendas_sistema, observacao, fundo_caixa FROM turnos WHERE fechado_em IS NOT NULL ORDER BY id DESC LIMIT 1"
    ).fetchone()

    if row:
        cols = row.keys()
        v_sis = row["vendas_sistema"] if ("vendas_sistema" in cols and row["vendas_sistema"] is not None) else 0.0
        obs = row["observacao"] if ("observacao" in cols and row["observacao"] is not None) else ""
        f_cx = float(row["fundo_caixa"] or 0.0) if "fundo_caixa" in cols else 0.0
        num_dia = obter_numero_turno_do_dia(conn, row["id"])
        return Turno(
            id=row["id"],
            aberto_em=row["aberto_em"],
            operador=row["operador"] or "Não informado",
            fechado_em=row["fechado_em"],
            vendas_sistema=v_sis,
            observacao=obs,
            numero_do_dia=num_dia,
            fundo_caixa=f_cx,
        )
    return None


def reabrir_turno_por_id(conn: sqlite3.Connection, turno_id: int) -> Optional[Turno]:
    """Reabre um turno previamente encerrado, limpando a data de fechamento."""
    cursor = conn.cursor()
    cursor.execute("UPDATE turnos SET fechado_em = NULL WHERE id = ?", (turno_id,))
    conn.commit()
    salvar_banco_web_sync(conn)
    return obter_turno_por_id(conn, turno_id)


def abrir_novo_turno(conn: sqlite3.Connection, operador: str, fundo_caixa: float = 0.0) -> Turno:
    cursor = conn.cursor()
    agora = datetime.now().strftime("%d/%m/%Y %H:%M")
    cursor.execute(
        "INSERT INTO turnos (aberto_em, operador, fundo_caixa) VALUES (?, ?, ?)",
        (agora, operador, fundo_caixa),
    )
    conn.commit()
    salvar_banco_web_sync(conn)
    turno_id = cursor.lastrowid
    num_dia = obter_numero_turno_do_dia(conn, turno_id)
    return Turno(id=turno_id, aberto_em=agora, operador=operador, numero_do_dia=num_dia, fundo_caixa=fundo_caixa)


def obter_totais(conn: sqlite3.Connection, turno_id: int) -> Totais:
    cursor = conn.cursor()
    cursor.execute(
        "SELECT tipo, SUM(valor_centavos), COUNT(*) FROM lancamentos WHERE turno_id = ? GROUP BY tipo",
        (turno_id,),
    )
    resultados = cursor.fetchall()

    totais_centavos = {linha[0]: (linha[1] or 0) for linha in resultados}
    totais_qtd = {linha[0]: linha[2] for linha in resultados}

    dinheiro = totais_centavos.get(TIPO_DINHEIRO, 0) / 100.0
    pix = totais_centavos.get(TIPO_PIX, 0) / 100.0
    requisicao = totais_centavos.get(TIPO_REQUISICAO, 0) / 100.0
    deposito_global = totais_centavos.get(TIPO_DEPOSITO_GLOBAL, 0) / 100.0
    despesas = totais_centavos.get(TIPO_DESPESA, 0) / 100.0
    sangrias = totais_centavos.get(TIPO_SANGRIA, 0) / 100.0
    suprimento = totais_centavos.get(TIPO_SUPRIMENTO, 0) / 100.0

    total_cartoes = sum(
        val for k, val in totais_centavos.items()
        if k not in (TIPO_DINHEIRO, TIPO_PIX, TIPO_REQUISICAO, TIPO_DEPOSITO_GLOBAL, TIPO_DESPESA, TIPO_SANGRIA, TIPO_SUPRIMENTO)
    ) / 100.0
    qtd_cartoes = sum(
        qtd for k, qtd in totais_qtd.items()
        if k not in (TIPO_DINHEIRO, TIPO_PIX, TIPO_REQUISICAO, TIPO_DEPOSITO_GLOBAL, TIPO_DESPESA, TIPO_SANGRIA, TIPO_SUPRIMENTO)
    )
    qtd_pix = totais_qtd.get(TIPO_PIX, 0)
    qtd_sangrias = totais_qtd.get(TIPO_SANGRIA, 0)

    fundo_caixa = 0.0
    try:
        row_t = cursor.execute("SELECT fundo_caixa FROM turnos WHERE id = ?", (turno_id,)).fetchone()
        if row_t and "fundo_caixa" in row_t.keys() and row_t["fundo_caixa"] is not None:
            fundo_caixa = float(row_t["fundo_caixa"] or 0.0)
    except Exception:
        pass

    fisico = dinheiro

    return Totais(
        fisico=fisico,
        pix=pix,
        cartoes=total_cartoes,
        requisicao=requisicao,
        dinheiro=dinheiro,
        deposito_global=deposito_global,
        despesas=despesas,
        sangrias=sangrias,
        suprimento=suprimento,
        fundo_caixa=fundo_caixa,
        qtd_cartoes=qtd_cartoes,
        qtd_pix=qtd_pix,
        qtd_sangrias=qtd_sangrias,
    )


def obter_detalhe_cartoes(conn: sqlite3.Connection, turno_id: int) -> dict[str, tuple[float, int]]:
    cursor = conn.cursor()
    cursor.execute(
        "SELECT tipo, SUM(valor_centavos), COUNT(*) FROM lancamentos WHERE turno_id = ? GROUP BY tipo",
        (turno_id,),
    )
    resultados = cursor.fetchall()

    totais_centavos = {linha[0]: (linha[1] or 0) for linha in resultados}
    totais_qtd = {linha[0]: linha[2] for linha in resultados}

    detalhe = {}
    for c in LISTA_CARTOES_REDE + LISTA_CARTOES_CIELO:
        detalhe[c] = (totais_centavos.get(c, 0) / 100.0, totais_qtd.get(c, 0))
    for c in BANDEIRAS_BASE:
        if c in totais_centavos:
            detalhe[c] = (totais_centavos.get(c, 0) / 100.0, totais_qtd.get(c, 0))
    return detalhe


def obter_encerrantes(conn: sqlite3.Connection, turno_id: int) -> list[Encerrante]:
    """Retorna todos os encerrantes de bicos lançados no turno."""
    cursor = conn.cursor()
    rows = cursor.execute(
        "SELECT id, turno_id, bico, combustivel, inicial, final, preco_litro, litros, total_reais FROM encerrantes WHERE turno_id = ? ORDER BY id ASC",
        (turno_id,)
    ).fetchall()
    return [
        Encerrante(
            id=r["id"],
            turno_id=r["turno_id"],
            bico=r["bico"],
            combustivel=r["combustivel"],
            inicial=float(r["inicial"] or 0.0),
            final=float(r["final"] or 0.0),
            preco_litro=float(r["preco_litro"] or 0.0),
            litros=float(r["litros"] or 0.0),
            total_reais=float(r["total_reais"] or 0.0),
        )
        for r in rows
    ]


def salvar_encerrante(
    conn: sqlite3.Connection,
    turno_id: int,
    bico: str,
    combustivel: str,
    inicial: float,
    final: float,
    preco_litro: float,
    encerrante_id: Optional[int] = None
) -> Encerrante:
    """Salva ou atualiza uma medição de encerrante com cálculo automático de litros e total."""
    cursor = conn.cursor()
    litros = max(0.0, round(final - inicial, 2)) if final >= inicial else 0.0
    total_reais = round(litros * preco_litro, 2)
    if encerrante_id:
        cursor.execute(
            """
            UPDATE encerrantes
            SET bico = ?, combustivel = ?, inicial = ?, final = ?, preco_litro = ?, litros = ?, total_reais = ?
            WHERE id = ? AND turno_id = ?
            """,
            (bico, combustivel, inicial, final, preco_litro, litros, total_reais, encerrante_id, turno_id)
        )
        enc_id = encerrante_id
    else:
        cursor.execute(
            """
            INSERT INTO encerrantes (turno_id, bico, combustivel, inicial, final, preco_litro, litros, total_reais)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (turno_id, bico, combustivel, inicial, final, preco_litro, litros, total_reais)
        )
        enc_id = cursor.lastrowid
    conn.commit()
    salvar_banco_web_sync(conn)
    return Encerrante(
        id=enc_id,
        turno_id=turno_id,
        bico=bico,
        combustivel=combustivel,
        inicial=inicial,
        final=final,
        preco_litro=preco_litro,
        litros=litros,
        total_reais=total_reais,
    )


def excluir_encerrante(conn: sqlite3.Connection, encerrante_id: int) -> None:
    """Remove uma medição de bico."""
    cursor = conn.cursor()
    cursor.execute("DELETE FROM encerrantes WHERE id = ?", (encerrante_id,))
    conn.commit()
    salvar_banco_web_sync(conn)


def obter_totais_encerrantes(conn: sqlite3.Connection, turno_id: int) -> tuple[float, float]:
    """Retorna (total_litros, total_reais) das medições de bicos do turno."""
    cursor = conn.cursor()
    row = cursor.execute(
        "SELECT SUM(litros), SUM(total_reais) FROM encerrantes WHERE turno_id = ?",
        (turno_id,)
    ).fetchone()
    if row:
        return float(row[0] or 0.0), float(row[1] or 0.0)
    return 0.0, 0.0


def obter_distribuicao_pagamentos(conn: sqlite3.Connection, turno_id: int) -> dict[str, float]:
    """Retorna a distribuição de valores por categoria para gráficos."""
    totais = obter_totais(conn, turno_id)
    dist = {}
    if totais.fisico > 0: dist["Dinheiro"] = totais.fisico
    if totais.pix > 0: dist["Pag Pix"] = totais.pix
    if totais.cartoes > 0: dist["Cartões"] = totais.cartoes
    if totais.requisicao > 0: dist["Requisição"] = totais.requisicao
    if totais.deposito_global > 0: dist["Depósito Global"] = totais.deposito_global
    if totais.despesas > 0: dist["Despesas"] = totais.despesas
    if totais.sangrias > 0: dist["Sangria"] = totais.sangrias
    return dist


def obter_movimento_por_hora(conn: sqlite3.Connection, turno_id: int) -> list[tuple[str, int, float]]:
    """Retorna o movimento agrupado por hora: [(hora_str, quantidade_vendas, total_reais), ...]."""
    cursor = conn.cursor()
    rows = cursor.execute(
        """
        SELECT substr(data, 12, 2) as hora, COUNT(*), SUM(valor_centavos)
        FROM lancamentos
        WHERE turno_id = ? AND data IS NOT NULL AND length(data) >= 13
        GROUP BY hora
        ORDER BY hora ASC
        """,
        (turno_id,)
    ).fetchall()
    resultado = []
    for r in rows:
        h = f"{r[0]}:00" if r[0] else "--:00"
        qtd = int(r[1] or 0)
        tot = float(r[2] or 0) / 100.0
        resultado.append((h, qtd, tot))
    return resultado


def exportar_turno_excel_csv(conn: sqlite3.Connection, turno_id: int) -> str:
    """Gera um arquivo CSV formatado com BOM UTF-8 (100% compatível com Microsoft Excel)."""
    turno = obter_turno_por_id(conn, turno_id)
    totais = obter_totais(conn, turno_id)
    cursor = conn.cursor()
    lancamentos = cursor.execute(
        "SELECT id, tipo, valor_centavos, descricao, data FROM lancamentos WHERE turno_id = ? ORDER BY id ASC",
        (turno_id,)
    ).fetchall()

    pasta = caminho_backups()
    os.makedirs(pasta, exist_ok=True)
    nome_op = (turno.operador or "Operador").replace(" ", "_")
    data_limpa = (turno.aberto_em or "data").replace("/", "-").replace(":", "-").replace(" ", "_")
    caminho = os.path.join(pasta, f"Fechamento_Turno_{turno.numero_do_dia}_{nome_op}_{data_limpa}.csv")

    with open(caminho, "w", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f, delimiter=";")
        writer.writerow(["FECHAMENTO DE TURNO - POSTO JANJAO"])
        writer.writerow(["Turno:", f"#{turno.numero_do_dia}"])
        writer.writerow(["Operador:", turno.operador])
        writer.writerow(["Aberto em:", turno.aberto_em])
        writer.writerow(["Fechado em:", turno.fechado_em or "Em Aberto"])
        writer.writerow([])
        writer.writerow(["RESUMO FINANCEIRO"])
        writer.writerow(["Categoria", "Valor"])
        writer.writerow(["Dinheiro em Vendas", formatar_moeda(totais.fisico)])
        writer.writerow(["Fundo de Caixa (Troco Inicial)", formatar_moeda(totais.fundo_caixa)])
        if totais.sangrias > 0:
            writer.writerow(["Sangrias (Retiradas Cofre)", formatar_moeda(totais.sangrias)])
        writer.writerow(["Dinheiro na Gaveta (Atual)", formatar_moeda(totais.dinheiro_gaveta)])
        writer.writerow(["Pag Pix", formatar_moeda(totais.pix)])
        writer.writerow(["Cartões e Vouchers", formatar_moeda(totais.cartoes)])
        writer.writerow(["Requisição", formatar_moeda(totais.requisicao)])
        writer.writerow(["Depósito Global", formatar_moeda(totais.deposito_global)])
        writer.writerow(["Despesas", formatar_moeda(totais.despesas)])
        writer.writerow(["TOTAL GERAL", formatar_moeda(totais.total_geral)])
        writer.writerow([])
        writer.writerow(["LANCAMENTOS DETALHADOS"])
        writer.writerow(["ID", "Data/Hora", "Forma de Pagamento", "Valor (R$)", "Descricao / Placa"])
        for l in lancamentos:
            v = float(l["valor_centavos"] or 0) / 100.0
            writer.writerow([l["id"], l["data"] or "", l["tipo"] or "", f"{v:.2f}".replace(".", ","), l["descricao"] or ""])

    return caminho


def montar_resumo_texto(totais: Totais, turno: Turno, detalhe_cartoes: dict[str, tuple[float, int]]) -> str:
    """Monta um resumo em texto limpo, elegante e direto para WhatsApp e clipboard."""
    cartoes_usados = [
        f"• {bandeira} ({qtd} un): *{formatar_moeda(val)}*"
        for bandeira, (val, qtd) in detalhe_cartoes.items()
        if qtd > 0 or val > 0
    ]
    if cartoes_usados:
        linhas_cartoes = "\n".join(cartoes_usados)
    else:
        linhas_cartoes = "• Nenhum cartão lançado"

    div = "━━━━━━━━━━━━━━━━━━━━━"

    linhas = [
        f"⛽ *FECHAMENTO DE TURNO #{turno.numero_do_dia} - POSTO JANJÃO*",
        f"👤 *Operador:* {turno.operador}",
        f"🕐 *Aberto em:* {turno.aberto_em}",
        div,
        "💳 *CARTÕES E VOUCHERS:*",
        linhas_cartoes,
        f"💳 *Total Cartões ({totais.qtd_cartoes} un):* *{formatar_moeda(totais.cartoes)}*",
        div,
        f"💵 *Sobra Dinheiro:* {formatar_moeda(totais.fisico)}",
    ]

    if totais.fundo_caixa > 0:
        linhas.append(f"💰 *Fundo de Caixa:* {formatar_moeda(totais.fundo_caixa)}")
    if totais.sangrias > 0:
        linhas.append(f"🔻 *Sangrias (Cofre):* {formatar_moeda(totais.sangrias)} ({totais.qtd_sangrias} un)")
    if totais.fundo_caixa > 0 or totais.sangrias > 0:
        linhas.append(f"📥 *Dinheiro na Gaveta:* {formatar_moeda(totais.dinheiro_gaveta)}")

    linhas.extend([
        f"⚡ *Pag Pix ({totais.qtd_pix} un):* {formatar_moeda(totais.pix)}",
        f"📋 *Requisição:* {formatar_moeda(totais.requisicao)}",
        f"🔒 *Depósito Global:* {formatar_moeda(totais.deposito_global)}",
        f"🛒 *Despesas:* {formatar_moeda(totais.despesas)}",
        div,
        f"✅ *TOTAL GERAL: {formatar_moeda(totais.total_geral)}*",
    ])

    v_sis = getattr(turno, "vendas_sistema", 0.0) or 0.0
    obs = getattr(turno, "observacao", "") or ""
    if v_sis > 0 or obs.strip():
        linhas.append(div)
        if v_sis > 0:
            diff = totais.total_geral - v_sis
            diff_str = f" (Dif: {formatar_moeda(diff)})" if abs(diff) > 0.01 else " (Bateu)"
            linhas.append(f"📊 *Vendas Sistema:* {formatar_moeda(v_sis)}{diff_str}")
        if obs.strip():
            linhas.append(f"📝 *Obs:* {obs.strip()}")

    return "\n".join(linhas)


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
    salvar_banco_web_sync(conn)


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
    salvar_banco_web_sync(conn)
    return cursor.rowcount > 0


def deletar_lancamento(conn: sqlite3.Connection, lancamento_id: int, turno_id: int) -> bool:
    cursor = conn.cursor()
    cursor.execute(
        "DELETE FROM lancamentos WHERE id = ? AND turno_id = ?",
        (lancamento_id, turno_id),
    )
    conn.commit()
    salvar_banco_web_sync(conn)
    return cursor.rowcount > 0


def zerar_turno(conn: sqlite3.Connection, turno_id: int) -> None:
    cursor = conn.cursor()
    cursor.execute("DELETE FROM lancamentos WHERE turno_id = ?", (turno_id,))
    conn.commit()
    salvar_banco_web_sync(conn)


def fechar_turno(
    conn: sqlite3.Connection,
    turno_id: int,
    totais: Totais,
    vendas_sistema: Optional[float] = None,
    observacao: Optional[str] = None,
) -> None:
    agora = datetime.now().strftime("%d/%m/%Y %H:%M")
    cursor = conn.cursor()
    if vendas_sistema is not None and observacao is not None:
        cursor.execute(
            """
            UPDATE turnos
            SET fechado_em = ?, fisico = ?, pix = ?, cartoes = ?, requisicao = ?, total_geral = ?, vendas_sistema = ?, observacao = ?
            WHERE id = ?
            """,
            (
                agora,
                totais.fisico,
                totais.pix,
                totais.cartoes,
                totais.requisicao,
                totais.total_geral,
                vendas_sistema,
                observacao,
                turno_id,
            ),
        )
    else:
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
    salvar_banco_web_sync(conn)


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


def listar_historico_por_tipo(
    conn: sqlite3.Connection, turno_id: int, tipo: str, limite: int = 500
) -> list[sqlite3.Row]:
    """Lista todos os lançamentos de um turno filtrados por uma bandeira/tipo específico.

    Usado pela tela de detalhe da bandeira no resumo do turno, para permitir
    localizar e editar lançamentos antigos que já saíram do histórico recente.
    """
    cursor = conn.cursor()
    return cursor.execute(
        """
        SELECT id, tipo, valor_centavos / 100.0 AS valor, descricao, data
        FROM lancamentos
        WHERE turno_id = ? AND tipo = ?
        ORDER BY id DESC
        LIMIT ?
        """,
        (turno_id, tipo, limite),
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


# --- Exportar resumo em PDF -------------------------------------------------
def exportar_turno_pdf(conn: sqlite3.Connection, turno_id: int) -> str:
    """Gera um PDF altamente profissional com o resumo do turno."""
    try:
        from reportlab.lib import colors
        from reportlab.lib.pagesizes import A4
        from reportlab.pdfgen import canvas
    except Exception as e:
        raise RuntimeError("reportlab não está instalado. Execute: pip install reportlab")

    # Obtém dados do turno
    cursor = conn.cursor()
    row = cursor.execute(
        "SELECT id, aberto_em, fechado_em, operador, vendas_sistema, observacao FROM turnos WHERE id = ?",
        (turno_id,),
    ).fetchone()

    if row:
        cols = row.keys()
        v_sis = row["vendas_sistema"] if ("vendas_sistema" in cols and row["vendas_sistema"] is not None) else 0.0
        obs = row["observacao"] if ("observacao" in cols and row["observacao"] is not None) else ""
        turno = Turno(
            id=row["id"],
            aberto_em=row["aberto_em"],
            operador=row["operador"] or "Não informado",
            fechado_em=row["fechado_em"],
            vendas_sistema=v_sis,
            observacao=obs,
        )
    else:
        turno = obter_turno_aberto(conn)
        if not turno:
            raise RuntimeError("Turno não encontrado para gerar PDF")

    totais = obter_totais(conn, turno_id)
    detalhe_cart = obter_detalhe_cartoes(conn, turno_id)

    os.makedirs(caminho_backups(), exist_ok=True)
    import re
    def _sanitizar_nome(nome: str) -> str:
        if not nome:
            return "Operador"
        nome_limpo = re.sub(r'[^\w\s-]', '', nome).strip()
        nome_limpo = re.sub(r'[\s_]+', ' ', nome_limpo).strip()
        return nome_limpo[:30] or "Operador"

    data_formatada = datetime.now().strftime("%d-%m-%Y")
    operador_nome = _sanitizar_nome(turno.operador)
    nome_base = f"{operador_nome} {data_formatada}"
    nome_arquivo_pdf = f"{nome_base}.pdf"
    caminho = os.path.join(caminho_backups(), nome_arquivo_pdf)

    contador = 2
    while os.path.exists(caminho):
        nome_arquivo_pdf = f"{nome_base} ({contador}).pdf"
        caminho = os.path.join(caminho_backups(), nome_arquivo_pdf)
        contador += 1

    data_geracao = datetime.now().strftime("%d/%m/%Y às %H:%M")

    w, h = A4
    margem_esq = 36
    margem_dir = w - 36
    largura_util = margem_dir - margem_esq
    y = h

    c = canvas.Canvas(caminho, pagesize=A4)

    def desenhar_marca_dagua_bomba(c, w, h):
        """Desenha a marca d'água colorida com bico de combustível e gotas de gasolina douradas."""
        cx = w / 2.0
        cy = (h / 2.0) - 75.0

        base_dir = os.path.dirname(os.path.abspath(__file__))
        caminho_img = os.path.join(base_dir, "assets", "bico_gold.jpg")
        if not os.path.exists(caminho_img):
            caminho_img = os.path.join(os.getcwd(), "assets", "bico_gold.jpg")

        if os.path.exists(caminho_img):
            try:
                c.saveState()

                # Corta qualquer parte da imagem abaixo de y = 125.0 (garante que nunca toque na assinatura)
                y_corte_assinatura = 125.0
                clip_p = c.beginPath()
                clip_p.rect(0, y_corte_assinatura, w, h - y_corte_assinatura)
                c.clipPath(clip_p, stroke=0, fill=0)

                c.setFillAlpha(0.28)
                largura_img = 310
                altura_img = 310
                c.drawImage(
                    caminho_img,
                    cx - (largura_img / 2.0),
                    cy - (altura_img / 2.0),
                    width=largura_img,
                    height=altura_img,
                    preserveAspectRatio=True,
                    mask="auto",
                )
                c.restoreState()
                return
            except Exception:
                pass

        # Fallback vetorial caso a imagem não esteja presente
        c.saveState()
        c.setStrokeColor(colors.HexColor("#F1F5F9"))
        c.setFillColor(colors.HexColor("#F8FAFC"))
        c.setLineWidth(1.2)
        c.roundRect(cx - 70, cy - 110, 140, 220, 12, fill=1, stroke=1)
        c.restoreState()

    # Desenha a marca d'água no fundo
    desenhar_marca_dagua_bomba(c, w, h)

    def checar_quebra_pagina(espaco_necessario=30):
        nonlocal y
        if y < 50 + espaco_necessario:
            c.showPage()
            desenhar_marca_dagua_bomba(c, w, h)
            y = h - 40

    # ── 1. CABEÇALHO COM BANNER SUPERIOR ──────────────────────────────────────────
    c.setFillColor(colors.HexColor("#0F172A"))
    c.rect(0, h - 60, w, 60, fill=1, stroke=0)

    c.setFillColor(colors.HexColor("#16A34A"))
    c.rect(0, h - 64, w, 4, fill=1, stroke=0)

    c.setFillColor(colors.HexColor("#FFFFFF"))
    c.setFont("Helvetica-Bold", 16)
    c.drawString(margem_esq, h - 34, "POSTO JANJÃO")
    c.setFont("Helvetica", 9)
    c.setFillColor(colors.HexColor("#94A3B8"))
    c.drawString(margem_esq, h - 48, "FECHAMENTO DE TURNO · RELATÓRIO FINANCEIRO")

    c.setFont("Helvetica", 8)
    c.setFillColor(colors.HexColor("#CBD5E1"))
    c.drawRightString(margem_dir, h - 34, f"Emitido em: {data_geracao}")
    c.drawRightString(margem_dir, h - 48, f"Documento #PDF-{turno.numero_do_dia:04d}")

    y = h - 82

    fechado_em_texto = turno.fechado_em if (turno.fechado_em and turno.fechado_em.strip()) else datetime.now().strftime("%d/%m/%Y %H:%M")

    # ── 2. CARD DE METADADOS DO TURNO (KPI BOX) ──────────────────────────────────
    c.setFillColor(colors.HexColor("#F8FAFC"))
    c.setStrokeColor(colors.HexColor("#E2E8F0"))
    c.setLineWidth(1)
    c.roundRect(margem_esq, y - 42, largura_util, 42, 6, fill=1, stroke=1)

    c.setFont("Helvetica-Bold", 7.5)
    c.setFillColor(colors.HexColor("#64748B"))
    c.drawString(margem_esq + 10, y - 15, "Nº TURNO")
    c.setFont("Helvetica-Bold", 11)
    c.setFillColor(colors.HexColor("#0F172A"))
    c.drawString(margem_esq + 10, y - 31, f"Turno #{turno.numero_do_dia}")

    c.setFont("Helvetica-Bold", 7.5)
    c.setFillColor(colors.HexColor("#64748B"))
    c.drawString(margem_esq + 95, y - 15, "OPERADOR CAIXA")
    c.setFont("Helvetica-Bold", 10)
    c.setFillColor(colors.HexColor("#0F172A"))
    c.drawString(margem_esq + 95, y - 31, turno.operador[:22])

    c.setFont("Helvetica-Bold", 7.5)
    c.setFillColor(colors.HexColor("#64748B"))
    c.drawString(margem_esq + 245, y - 15, "ABERTURA")
    c.setFont("Helvetica", 9.5)
    c.setFillColor(colors.HexColor("#1E293B"))
    c.drawString(margem_esq + 245, y - 31, turno.aberto_em)

    c.setFont("Helvetica-Bold", 7.5)
    c.setFillColor(colors.HexColor("#16A34A"))
    c.drawString(margem_esq + 380, y - 15, "FECHAMENTO")
    c.setFont("Helvetica-Bold", 9.5)
    c.setFillColor(colors.HexColor("#0F172A"))
    c.drawString(margem_esq + 380, y - 31, fechado_em_texto)

    y -= 62

    # ── 3. TABELA DE CARTÕES, VOUCHERS E PIX POR BANDEIRA ─────────────────────────
    checar_quebra_pagina(100)

    c.setFont("Helvetica-Bold", 11)
    c.setFillColor(colors.HexColor("#0F172A"))
    c.drawString(margem_esq, y, "DETALHAMENTO DE CARTÕES, VOUCHERS E PIX POR BANDEIRA")
    y -= 14

    c.setFillColor(colors.HexColor("#1E293B"))
    c.rect(margem_esq, y - 18, largura_util, 18, fill=1, stroke=0)

    c.setFont("Helvetica-Bold", 8.5)
    c.setFillColor(colors.HexColor("#FFFFFF"))
    c.drawString(margem_esq + 12, y - 12, "BANDEIRA / MEIO DE PAGAMENTO")
    c.drawCentredString(margem_esq + 300, y - 12, "QTD. COMPROVANTES")
    c.drawRightString(margem_dir - 12, y - 12, "SUBTOTAL (R$)")

    y -= 18

    col_qtd_x = margem_esq + 300
    par = False
    for bandeira, (valor, qtd) in detalhe_cart.items():
        checar_quebra_pagina(18)
        bg_cor = "#F8FAFC" if par else "#FFFFFF"
        par = not par

        c.setFillColor(colors.HexColor(bg_cor))
        c.rect(margem_esq, y - 16, largura_util, 16, fill=1, stroke=0)

        c.setStrokeColor(colors.HexColor("#F1F5F9"))
        c.setLineWidth(0.5)
        c.line(margem_esq, y - 16, margem_dir, y - 16)

        c.setFont("Helvetica", 9)
        c.setFillColor(colors.HexColor("#334155"))
        c.drawString(margem_esq + 12, y - 11, bandeira)

        c.setFont("Helvetica", 9)
        c.setFillColor(colors.HexColor("#64748B") if qtd == 0 else colors.HexColor("#0F172A"))
        c.drawCentredString(col_qtd_x, y - 11, f"{qtd} un")

        c.setFont("Helvetica-Bold" if valor > 0 else "Helvetica", 9)
        c.setFillColor(colors.HexColor("#0F172A") if valor > 0 else colors.HexColor("#94A3B8"))
        c.drawRightString(margem_dir - 12, y - 11, formatar_moeda(valor))

        y -= 16

    checar_quebra_pagina(22)
    y -= 2
    c.setFillColor(colors.HexColor("#EFF6FF"))
    c.setStrokeColor(colors.HexColor("#93C5FD"))
    c.setLineWidth(1)
    c.rect(margem_esq, y - 20, largura_util, 20, fill=1, stroke=1)

    c.setFont("Helvetica-Bold", 9.5)
    c.setFillColor(colors.HexColor("#1E40AF"))
    c.drawString(margem_esq + 12, y - 13, "TOTAL DE CARTÕES E VOUCHERS")
    c.drawCentredString(col_qtd_x, y - 13, f"{totais.qtd_cartoes} comprovantes")
    c.setFont("Helvetica-Bold", 10.5)
    c.drawRightString(margem_dir - 12, y - 13, formatar_moeda(totais.cartoes))

    y -= 32

    # ── 4. RESUMO FINANCEIRO (OUTROS LANÇAMENTOS) ──────────────────────────────
    checar_quebra_pagina(120)

    c.setFont("Helvetica-Bold", 11)
    c.setFillColor(colors.HexColor("#0F172A"))
    c.drawString(margem_esq, y, "RESUMO DOS OUTROS LANÇAMENTOS DO TURNO")
    y -= 14

    itens_financeiros = [
        ("Pag Pix", totais.pix, totais.qtd_pix, "#2563EB", "#F0F9FF"),
        ("Sobra de Dinheiro", totais.fisico, None, "#16A34A", "#F0FDF4"),
        ("Requisição", totais.requisicao, None, "#7C3AED", "#F5F3FF"),
        ("Depósito Global", totais.deposito_global, None, "#D97706", "#FFFBEB"),
        ("Despesas", totais.despesas, None, "#DC2626", "#FEF2F2"),
    ]

    for rotulo, valor, qtd, cor_destaque, bg_item in itens_financeiros:
        checar_quebra_pagina(20)
        c.setFillColor(colors.HexColor(bg_item))
        c.setStrokeColor(colors.HexColor("#E2E8F0"))
        c.setLineWidth(0.5)
        c.rect(margem_esq, y - 18, largura_util, 18, fill=1, stroke=1)

        c.setFillColor(colors.HexColor(cor_destaque))
        c.rect(margem_esq, y - 18, 4, 18, fill=1, stroke=0)

        c.setFont("Helvetica-Bold", 9)
        c.setFillColor(colors.HexColor("#1E293B"))
        c.drawString(margem_esq + 14, y - 12, rotulo)

        if qtd is not None:
            c.setFont("Helvetica", 8.5)
            c.setFillColor(colors.HexColor("#64748B"))
            c.drawCentredString(col_qtd_x, y - 12, f"({qtd} un)")

        c.setFont("Helvetica-Bold", 9.5)
        c.setFillColor(colors.HexColor(cor_destaque if valor > 0 else "#64748B"))
        c.drawRightString(margem_dir - 12, y - 12, formatar_moeda(valor))

        y -= 22

    y -= 10

    # ── 5. TABELA DE CONCILIAÇÃO DE VENDAS (PISTA vs. SISTEMA) ────────────────
    checar_quebra_pagina(110)

    # 1. TOTAL DE VENDAS PISTA
    c.setFillColor(colors.HexColor("#3730A3"))
    c.setStrokeColor(colors.HexColor("#6366F1"))
    c.setLineWidth(1.2)
    c.roundRect(margem_esq, y - 26, largura_util, 26, 4, fill=1, stroke=1)

    c.setFont("Helvetica-Bold", 9)
    c.setFillColor(colors.HexColor("#E0E7FF"))
    c.drawString(margem_esq + 14, y - 17, "TOTAL DE VENDAS PISTA:")

    c.setFont("Helvetica-Bold", 12)
    c.setFillColor(colors.HexColor("#FFFFFF"))
    c.drawRightString(margem_dir - 14, y - 17, formatar_moeda(totais.total_geral))

    y -= 30

    # 2. TOTAL DE VENDAS SISTEMA
    c.setFillColor(colors.HexColor("#1E293B"))
    c.setStrokeColor(colors.HexColor("#475569"))
    c.setLineWidth(1)
    c.roundRect(margem_esq, y - 26, largura_util, 26, 4, fill=1, stroke=1)

    c.setFont("Helvetica-Bold", 9)
    c.setFillColor(colors.HexColor("#CBD5E1"))
    c.drawString(margem_esq + 14, y - 17, "TOTAL DE VENDAS SISTEMA:")

    c.setFont("Helvetica-Bold", 11.5)
    c.setFillColor(colors.HexColor("#F8FAFC"))
    c.drawRightString(margem_dir - 14, y - 17, formatar_moeda(turno.vendas_sistema))

    y -= 30

    # 3. DIFERENÇA (PISTA - SISTEMA)
    diferenca = totais.total_geral - turno.vendas_sistema
    cor_dif_bg = "#064E3B" if abs(diferenca) < 0.01 else ("#78350F" if diferenca > 0 else "#7F1D1D")
    cor_dif_border = "#10B981" if abs(diferenca) < 0.01 else ("#F59E0B" if diferenca > 0 else "#EF4444")
    cor_dif_texto = "#D1FAE5" if abs(diferenca) < 0.01 else ("#FEF3C7" if diferenca > 0 else "#FEE2E2")

    c.setFillColor(colors.HexColor(cor_dif_bg))
    c.setStrokeColor(colors.HexColor(cor_dif_border))
    c.setLineWidth(1.2)
    c.roundRect(margem_esq, y - 26, largura_util, 26, 4, fill=1, stroke=1)

    c.setFont("Helvetica-Bold", 9.5)
    c.setFillColor(colors.HexColor(cor_dif_texto))
    label_dif = "DIFERENÇA:"
    c.drawString(margem_esq + 14, y - 17, label_dif)

    c.setFont("Helvetica-Bold", 12)
    c.drawRightString(margem_dir - 14, y - 17, formatar_moeda(diferenca))

    y -= 36

    # ── 5.1 SEÇÃO DE OBSERVAÇÕES / JUSTIFICATIVA ─────────────────────────────────
    if turno.observacao and turno.observacao.strip():
        obs_linhas = [l.strip() for l in turno.observacao.strip().split("\n") if l.strip()]
        alt_obs = max(32, 18 + len(obs_linhas) * 12)
        checar_quebra_pagina(alt_obs + 15)

        c.setFillColor(colors.HexColor("#F8FAFC"))
        c.setStrokeColor(colors.HexColor("#CBD5E1"))
        c.setLineWidth(0.8)
        c.roundRect(margem_esq, y - alt_obs, largura_util, alt_obs, 4, fill=1, stroke=1)

        c.setFont("Helvetica-Bold", 8.5)
        c.setFillColor(colors.HexColor("#475569"))
        c.drawString(margem_esq + 12, y - 13, "OBSERVAÇÕES / JUSTIFICATIVA:")

        c.setFont("Helvetica", 8.5)
        c.setFillColor(colors.HexColor("#0F172A"))
        y_text = y - 25
        for lin in obs_linhas[:4]:
            c.drawString(margem_esq + 12, y_text, lin[:95])
            y_text -= 12

        y -= (alt_obs + 16)
    else:
        y -= 10

    # ── 6. CAMPOS DE ASSINATURA E AUDITORIA ────────────────────────────────────
    checar_quebra_pagina(50)
    c.setStrokeColor(colors.HexColor("#CBD5E1"))
    c.setLineWidth(0.8)

    largura_campo = (largura_util - 40) / 2
    x_ass1 = margem_esq + 10
    x_ass2 = x_ass1 + largura_campo + 20

    c.line(x_ass1, y - 20, x_ass1 + largura_campo, y - 20)
    c.line(x_ass2, y - 20, x_ass2 + largura_campo, y - 20)

    c.setFont("Helvetica", 8)
    c.setFillColor(colors.HexColor("#64748B"))
    c.drawCentredString(x_ass1 + (largura_campo / 2), y - 30, f"Assinatura: {turno.operador}")
    c.drawCentredString(x_ass2 + (largura_campo / 2), y - 30, "Assinatura: Gerência / Conferência")

    # ── 7. RODAPÉ FIXO ────────────────────────────────────────────────────────
    c.setFont("Helvetica", 7.5)
    c.setFillColor(colors.HexColor("#94A3B8"))
    c.drawString(margem_esq, 20, "Posto Janjão · Sistema de Gestão de Caixa")
    c.drawRightString(margem_dir, 20, "Página 1 de 1 · Documento Autenticado")

    c.showPage()
    c.save()

    return caminho