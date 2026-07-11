# Contribuindo com o Caixa - Posto Janjão

Obrigado por contribuir! Este documento descreve como configurar o ambiente de desenvolvimento e contribuir com melhorias.

## 📋 Configuração do Ambiente

### Pré-requisitos
- Python 3.11 ou superior
- Git

### Setup Local

1. **Clone o repositório**
   ```bash
   git clone https://github.com/juglesbass/caixa-posto-janjao.git
   cd caixa-posto-janjao
   ```

2. **Crie um ambiente virtual**
   ```bash
   python -m venv .venv
   
   # No Windows:
   .venv\Scripts\activate
   
   # No macOS/Linux:
   source .venv/bin/activate
   ```

3. **Instale as dependências**
   ```bash
   pip install -r requirements.txt
   
   # Ou com uv:
   uv sync
   ```

4. **Execute a aplicação**
   ```bash
   python main.py
   ```

## 🏗️ Estrutura do Projeto

```
caixa-posto-janjao/
├── main.py                      # Entry point da aplicação
├── config.py                    # Configurações centralizadas
├── logger_config.py             # Sistema de logging
├── db.py                        # Camada de banco de dados
├── ui/                          # Módulo de interface
│   ├── __init__.py
│   ├── paleta.py               # Cores, temas e componentes UI comuns
│   └── (Em desenvolvimento: divisão de mais componentes)
├── tests/                       # Testes automatizados
├── pyproject.toml               # Configuração do projeto
├── requirements.txt             # Dependências Python
├── README.md                    # Documentação principal
└── .gitignore                   # Arquivos ignorados pelo git
```

## 🔧 Padrões de Código

### Convenções
- **Nomes de variáveis**: `snake_case` para variáveis/funções, `PascalCase` para classes
- **Comentários**: Use português para comentários em código
- **Docstrings**: Inclua docstrings em funções e classes
- **Imports**: Agrupe em: stdlib, terceiros, locais (com linhas em branco entre)

### Exemplo de Função Bem Estruturada
```python
def inserir_lancamento(conn: sqlite3.Connection, turno_id: int, 
                       tipo: str, valor: float, descricao: str) -> None:
    """
    Insere um novo lançamento no banco de dados.
    
    Args:
        conn: Conexão com o banco SQLite
        turno_id: ID do turno
        tipo: Tipo de pagamento (Dinheiro, PIX, etc)
        valor: Valor em reais
        descricao: Descrição opcional do lançamento
        
    Raises:
        ValueError: Se valor for negativo
        sqlite3.Error: Se houver erro no banco
    """
    if valor < 0:
        raise ValueError("Valor não pode ser negativo")
    
    # ... implementação
```

## ✅ Antes de Fazer Commit

1. **Verifique o código**
   ```bash
   pytest
   ```

2. **Atualize o .gitignore**
   - Não commite arquivos de banco de dados (*.db, *.db-shm, *.db-wal)
   - Não commite arquivos de configuração sensível (.env)

3. **Escreva mensagens descritivas**
   ```
   ❌ "Fix bug" (ruim)
   ✅ "Corrigir validação de valor monetário em lançamentos" (bom)
   ```

## 🐛 Reportando Issues

Ao reportar um bug, inclua:
- Versão do Python
- Sistema operacional
- Passos para reproduzir
- Comportamento esperado vs. observado
- Logs relevantes (se disponível em `backups/logs/`)

## 🚀 Propondo Novas Funcionalidades

1. Abra uma issue primeiro para discutir a ideia
2. Descreva o caso de uso
3. Mostre exemplos de como seria usado
4. Aguarde feedback antes de implementar

## 📚 Recursos Úteis

- [Flet Documentation](https://flet.dev/)
- [Python sqlite3](https://docs.python.org/3/library/sqlite3.html)
- [PEP 8 Style Guide](https://pep8.org/)

## ❓ Dúvidas?

- Abra uma issue com a tag `question`
- Descreva sua dúvida com clareza
- Inclua contexto se possível

---

Muito obrigado por contribuir com o projeto! 🙏
