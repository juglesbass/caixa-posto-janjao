"""Testes para o módulo de banco de dados."""

import unittest
import sqlite3
from unittest.mock import patch
from datetime import datetime

# Importar os módulos a testar
import db


class TestFormatarMoeda(unittest.TestCase):
    """Testes para formatação de valores monetários."""

    def test_formatacao_simples(self):
        """Testa formatação de valor simples."""
        self.assertEqual(db.formatar_moeda(50.0), "R$ 50,00")

    def test_formatacao_com_centavos(self):
        """Testa formatação com centavos."""
        self.assertEqual(db.formatar_moeda(50.99), "R$ 50,99")

    def test_formatacao_grande(self):
        """Testa formatação de valor grande com separador de milhar."""
        self.assertEqual(db.formatar_moeda(1234.56), "R$ 1.234,56")

    def test_formatacao_zero(self):
        """Testa formatação do zero."""
        self.assertEqual(db.formatar_moeda(0.0), "R$ 0,00")

    def test_formatacao_negativa(self):
        """Testa formatação de valor negativo."""
        self.assertEqual(db.formatar_moeda(-50.0), "R$ -50,00")


class TestParseMoedaFloat(unittest.TestCase):
    """Testes para conversão de strings monetárias em float."""

    def test_parse_vazio(self):
        self.assertEqual(db.parse_moeda_float(""), 0.0)
        self.assertEqual(db.parse_moeda_float(None), 0.0)

    def test_parse_formatado_reais(self):
        self.assertEqual(db.parse_moeda_float("R$ 50,00"), 50.0)
        self.assertEqual(db.parse_moeda_float("R$ 10,00"), 10.0)
        self.assertEqual(db.parse_moeda_float("R$ 500,00"), 500.0)

    def test_parse_com_centavos(self):
        self.assertEqual(db.parse_moeda_float("R$ 47,75"), 47.75)
        self.assertEqual(db.parse_moeda_float("4775"), 47.75)
        self.assertEqual(db.parse_moeda_float("5"), 0.05)
        self.assertEqual(db.parse_moeda_float("50"), 0.50)

    def test_parse_milhar(self):
        self.assertEqual(db.parse_moeda_float("R$ 1.234,56"), 1234.56)


class BaseDBTestCase(unittest.TestCase):
    """Base para testes que necessitam de banco de dados SQLite temporário."""

    def setUp(self):
        self.conn = sqlite3.connect(":memory:")
        self.conn.row_factory = sqlite3.Row
        # Mocka salvar_banco_web_sync para evitar leitura do disco em testes
        self._patcher = patch("db.salvar_banco_web_sync")
        self._patcher.start()
        db.inicializar_banco(self.conn)

    def tearDown(self):
        self._patcher.stop()
        self.conn.close()


class TestTurno(BaseDBTestCase):
    """Testes para operações de turno."""

    def test_abrir_novo_turno(self):
        """Testa abertura de novo turno."""
        turno = db.abrir_novo_turno(self.conn, "João")

        self.assertEqual(turno.id, 1)
        self.assertEqual(turno.operador, "João")
        self.assertIsNotNone(turno.aberto_em)
        self.assertIsNone(turno.fechado_em)

    def test_obter_turno_aberto(self):
        """Testa recuperação de turno aberto."""
        db.abrir_novo_turno(self.conn, "Maria")
        turno = db.obter_turno_aberto(self.conn)

        self.assertIsNotNone(turno)
        self.assertEqual(turno.operador, "Maria")

    def test_nao_ha_turno_aberto(self):
        """Testa quando não há turno aberto."""
        turno = db.obter_turno_aberto(self.conn)
        self.assertIsNone(turno)


class TestLancamentos(BaseDBTestCase):
    """Testes para operações de lançamentos."""

    def test_inserir_lancamento(self):
        """Testa inserção de lançamento."""
        turno = db.abrir_novo_turno(self.conn, "João")
        db.inserir_lancamento(
            self.conn, turno.id,
            db.TIPO_DINHEIRO, 50.0, "Teste"
        )

        historico = db.listar_historico(self.conn, turno.id)
        self.assertEqual(len(historico), 1)
        self.assertEqual(historico[0]["tipo"], db.TIPO_DINHEIRO)
        self.assertEqual(historico[0]["valor"], 50.0)

    def test_deletar_lancamento(self):
        """Testa exclusão de lançamento."""
        turno = db.abrir_novo_turno(self.conn, "João")
        db.inserir_lancamento(self.conn, turno.id, db.TIPO_DINHEIRO, 50.0, "")

        historico = db.listar_historico(self.conn, turno.id)
        lancamento_id = historico[0]["id"]

        # Deletar
        sucesso = db.deletar_lancamento(self.conn, lancamento_id, turno.id)
        self.assertTrue(sucesso)

        # Verificar que foi deletado
        historico = db.listar_historico(self.conn, turno.id)
        self.assertEqual(len(historico), 0)

    def test_atualizar_lancamento(self):
        """Testa atualização de lançamento."""
        turno = db.abrir_novo_turno(self.conn, "João")
        db.inserir_lancamento(self.conn, turno.id, db.TIPO_DINHEIRO, 50.0, "Original")

        historico = db.listar_historico(self.conn, turno.id)
        lancamento_id = historico[0]["id"]

        # Atualizar
        sucesso = db.atualizar_lancamento(
            self.conn, lancamento_id, turno.id,
            db.TIPO_PIX, 100.0, "Atualizado"
        )
        self.assertTrue(sucesso)

        # Verificar atualização
        historico = db.listar_historico(self.conn, turno.id)
        self.assertEqual(historico[0]["tipo"], db.TIPO_PIX)
        self.assertEqual(historico[0]["valor"], 100.0)


class TestTotais(BaseDBTestCase):
    """Testes para cálculo de totais."""

    def test_obter_totais_vazio(self):
        """Testa totais de turno sem lançamentos."""
        turno = db.abrir_novo_turno(self.conn, "João")
        totais = db.obter_totais(self.conn, turno.id)

        self.assertEqual(totais.fisico, 0.0)
        self.assertEqual(totais.pix, 0.0)
        self.assertEqual(totais.cartoes, 0.0)
        self.assertEqual(totais.total_geral, 0.0)

    def test_obter_totais_com_lancamentos(self):
        """Testa totais com vários lançamentos."""
        turno = db.abrir_novo_turno(self.conn, "João")

        db.inserir_lancamento(self.conn, turno.id, db.TIPO_DINHEIRO, 100.0, "")
        db.inserir_lancamento(self.conn, turno.id, db.TIPO_PIX, 50.0, "")
        db.inserir_lancamento(self.conn, turno.id, "Visa Crédito", 30.0, "")
        db.inserir_lancamento(self.conn, turno.id, "VR Multibenefícios", 45.0, "")

        totais = db.obter_totais(self.conn, turno.id)

        self.assertEqual(totais.fisico, 100.0)
        self.assertEqual(totais.pix, 50.0)
        self.assertEqual(totais.cartoes, 75.0)
        self.assertEqual(totais.total_geral, 225.0)
        self.assertEqual(totais.qtd_cartoes, 2)


class TestAuditoriaConciliacao(BaseDBTestCase):
    """Testes para conciliação de caixa e observações."""

    def test_salvar_e_recuperar_auditoria(self):
        """Testa salvação e recuperação de vendas_sistema e observações."""
        turno = db.abrir_novo_turno(self.conn, "Operador Teste")
        db.salvar_auditoria_turno(self.conn, turno.id, 4354.68, "Turno sem alterações e com sobras da pista.")

        turno_rec = db.obter_turno_por_id(self.conn, turno.id)
        self.assertIsNotNone(turno_rec)
        self.assertEqual(turno_rec.vendas_sistema, 4354.68)
        self.assertEqual(turno_rec.observacao, "Turno sem alterações e com sobras da pista.")

    def test_numero_turno_do_dia_reset_diario(self):
        """Testa se a numeração do turno reseta para 1 a cada nova data."""
        t1 = db.abrir_novo_turno(self.conn, "Agildo")
        self.assertEqual(t1.numero_do_dia, 1)

    def test_reabrir_ultimo_turno(self):
        """Testa o fechamento e posterior reabertura do turno."""
        t1 = db.abrir_novo_turno(self.conn, "Agildo")
        totais = db.obter_totais(self.conn, t1.id)
        db.fechar_turno(self.conn, t1.id, totais)
        self.assertIsNone(db.obter_turno_aberto(self.conn))

        t_reaberto = db.reabrir_turno_por_id(self.conn, t1.id)
        self.assertIsNotNone(t_reaberto)
        self.assertEqual(t_reaberto.id, t1.id)
        self.assertIsNone(t_reaberto.fechado_em)
        self.assertIsNotNone(db.obter_turno_aberto(self.conn))


if __name__ == "__main__":
    unittest.main()
