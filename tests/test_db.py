"""Testes para o módulo de banco de dados."""

import pytest
import sqlite3
import tempfile
import os
from datetime import datetime

# Importar os módulos a testar
import db


@pytest.fixture
def temp_db():
    """Cria um banco de dados temporário para testes."""
    with tempfile.NamedTemporaryFile(suffix='.db', delete=False) as f:
        db_path = f.name
    
    # Mockar o caminho do banco
    original_caminho = db.caminho_banco
    db.caminho_banco = lambda: db_path
    
    # Criar conexão
    conn = db.conectar()
    db.inicializar_banco(conn)
    
    yield conn
    
    # Cleanup
    conn.close()
    if os.path.exists(db_path):
        os.unlink(db_path)
    
    # Restaurar função original
    db.caminho_banco = original_caminho


class TestFormatarMoeda:
    """Testes para formatação de valores monetários."""
    
    def test_formatacao_simples(self):
        """Testa formatação de valor simples."""
        assert db.formatar_moeda(50.0) == "R$ 50,00"
    
    def test_formatacao_com_centavos(self):
        """Testa formatação com centavos."""
        assert db.formatar_moeda(50.99) == "R$ 50,99"
    
    def test_formatacao_grande(self):
        """Testa formatação de valor grande com separador de milhar."""
        assert db.formatar_moeda(1234.56) == "R$ 1.234,56"
    
    def test_formatacao_zero(self):
        """Testa formatação do zero."""
        assert db.formatar_moeda(0.0) == "R$ 0,00"
    
    def test_formatacao_negativa(self):
        """Testa formatação de valor negativo."""
        assert db.formatar_moeda(-50.0) == "R$ -50,00"


class TestTurno:
    """Testes para operações de turno."""
    
    def test_abrir_novo_turno(self, temp_db):
        """Testa abertura de novo turno."""
        turno = db.abrir_novo_turno(temp_db, "João")
        
        assert turno.id == 1
        assert turno.operador == "João"
        assert turno.aberto_em is not None
        assert turno.fechado_em is None
    
    def test_obter_turno_aberto(self, temp_db):
        """Testa recuperação de turno aberto."""
        db.abrir_novo_turno(temp_db, "Maria")
        turno = db.obter_turno_aberto(temp_db)
        
        assert turno is not None
        assert turno.operador == "Maria"
    
    def test_nao_ha_turno_aberto(self, temp_db):
        """Testa quando não há turno aberto."""
        turno = db.obter_turno_aberto(temp_db)
        assert turno is None


class TestLancamentos:
    """Testes para operações de lançamentos."""
    
    def test_inserir_lancamento(self, temp_db):
        """Testa inserção de lançamento."""
        turno = db.abrir_novo_turno(temp_db, "João")
        db.inserir_lancamento(
            temp_db, turno.id, 
            db.TIPO_DINHEIRO, 50.0, "Teste"
        )
        
        historico = db.listar_historico(temp_db, turno.id)
        assert len(historico) == 1
        assert historico[0]["tipo"] == db.TIPO_DINHEIRO
        assert historico[0]["valor"] == 50.0
    
    def test_deletar_lancamento(self, temp_db):
        """Testa exclusão de lançamento."""
        turno = db.abrir_novo_turno(temp_db, "João")
        db.inserir_lancamento(temp_db, turno.id, db.TIPO_DINHEIRO, 50.0, "")
        
        historico = db.listar_historico(temp_db, turno.id)
        lancamento_id = historico[0]["id"]
        
        # Deletar
        sucesso = db.deletar_lancamento(temp_db, lancamento_id, turno.id)
        assert sucesso is True
        
        # Verificar que foi deletado
        historico = db.listar_historico(temp_db, turno.id)
        assert len(historico) == 0
    
    def test_atualizar_lancamento(self, temp_db):
        """Testa atualização de lançamento."""
        turno = db.abrir_novo_turno(temp_db, "João")
        db.inserir_lancamento(temp_db, turno.id, db.TIPO_DINHEIRO, 50.0, "Original")
        
        historico = db.listar_historico(temp_db, turno.id)
        lancamento_id = historico[0]["id"]
        
        # Atualizar
        sucesso = db.atualizar_lancamento(
            temp_db, lancamento_id, turno.id,
            db.TIPO_PIX, 100.0, "Atualizado"
        )
        assert sucesso is True
        
        # Verificar atualização
        historico = db.listar_historico(temp_db, turno.id)
        assert historico[0]["tipo"] == db.TIPO_PIX
        assert historico[0]["valor"] == 100.0


class TestTotais:
    """Testes para cálculo de totais."""
    
    def test_obter_totais_vazio(self, temp_db):
        """Testa totais de turno sem lançamentos."""
        turno = db.abrir_novo_turno(temp_db, "João")
        totais = db.obter_totais(temp_db, turno.id)
        
        assert totais.fisico == 0.0
        assert totais.pix == 0.0
        assert totais.cartoes == 0.0
        assert totais.total_geral == 0.0
    
    def test_obter_totais_com_lancamentos(self, temp_db):
        """Testa totais com vários lançamentos."""
        turno = db.abrir_novo_turno(temp_db, "João")
        
        db.inserir_lancamento(temp_db, turno.id, db.TIPO_DINHEIRO, 100.0, "")
        db.inserir_lancamento(temp_db, turno.id, db.TIPO_PIX, 50.0, "")
        db.inserir_lancamento(temp_db, turno.id, "Visa Crédito", 30.0, "")
        
        totais = db.obter_totais(temp_db, turno.id)
        
        assert totais.fisico == 100.0
        assert totais.pix == 50.0
        assert totais.cartoes == 30.0
        assert totais.total_geral == 180.0
        assert totais.qtd_cartoes == 1


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
