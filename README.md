# Caixa - Posto Janjão

Aplicativo de caixa para controle de turno no posto: lançamentos por forma de pagamento, totais em tempo real, histórico e fechamento de turno.

## Requisitos

- Python 3.11+
- [Flet](https://flet.dev/) 0.85.3 ou superior

## Instalação

```bash
pip install -r requirements.txt
```

Ou com `uv`:

```bash
uv sync
```

## Executar

```bash
python main.py
```

O app abre no navegador na porta `5000` (ou na porta definida pela variável `PORT`).

## Variáveis de ambiente

| Variável | Descrição | Padrão |
|---|---|---|
| `PORT` | Porta do servidor web | `5000` |
| `CAIXA_PIN` | PIN de acesso (se definido, exige login) | desativado |
| `CAIXA_DB_PATH` | Caminho do banco SQLite | `meu_caixa.db` |
| `CAIXA_BACKUP_DIR` | Pasta dos backups CSV ao zerar turno | `backups/` |

Exemplo com PIN e banco persistente:

```bash
CAIXA_PIN=4321 CAIXA_DB_PATH=/dados/meu_caixa.db python main.py
```

## Funcionalidades

- Lançamento rápido com botões de valor e atalho **Completou**
- Enter no teclado para lançar abastecimento
- Totais de dinheiro físico, PIX, cartões, requisição e sangria
- Histórico recente com confirmação antes de apagar
- Resumo do turno com **copiar para área de transferência**
- Encerramento de turno com histórico de turnos anteriores
- Backup automático em CSV antes de zerar o turno atual
- Layout responsivo para celular e desktop
- Proteção opcional por PIN

## Persistência do banco

O SQLite fica no caminho configurado em `CAIXA_DB_PATH`. Em ambientes como Replit ou containers efêmeros, use um volume ou caminho persistente para não perder os dados ao reiniciar.

## Estrutura

- `main.py` — interface Flet
- `db.py` — banco de dados, turnos e exportação CSV
