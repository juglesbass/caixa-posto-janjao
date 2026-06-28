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
- `assets/` — ícone e splash para build mobile
- `scripts/build-ios.sh` — script de build iOS (macOS)

## App iOS (iPhone/iPad)

O mesmo código Python vira app nativo com [Flet](https://flet.dev/docs/publish/ios/). O build **precisa ser feito em um Mac** com Xcode instalado.

### O que já está configurado

- Bundle ID: `br.com.postojanjao.caixa`
- Banco SQLite persistente em `FLET_APP_STORAGE_DATA` (sobrevive a atualizações do app)
- Ícone e splash em `assets/`
- `SafeArea` automática no iOS/Android

### 1. Testar no Simulador (Mac)

```bash
pip install "flet>=0.85.3"
chmod +x scripts/build-ios.sh
./scripts/build-ios.sh simulator
```

Depois abra o **Simulator** e arraste `build/ios-simulator/Runner.app` para a janela.

### 2. Instalar no iPhone/iPad

1. Crie um **App ID** no [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list) com o bundle `br.com.postojanjao.caixa`.
2. Gere certificado **Apple Development** e um **Provisioning Profile** de desenvolvimento.
3. Edite `pyproject.toml` e preencha em `[tool.flet.ios]`:

```toml
team_id = "SEU_TEAM_ID"
provisioning_profile = "Nome do Profile"
signing_certificate = "Apple Development"
export_method = "debugging"
```

4. No Mac:

```bash
./scripts/build-ios.sh ipa
```

5. Instale o `.ipa` com **Apple Configurator** (arrastar para o iPhone conectado) ou pelo Xcode.

Documentação completa: [Packaging app for iOS | Flet](https://flet.dev/docs/publish/ios/)

### 3. Publicar na App Store

Use `export_method = "app-store-connect"` e envie o `.ipa` pelo app **Transporter** da Apple.

### Desenvolvimento local (web)

Continua igual — `python main.py` abre no navegador. O modo app nativo só entra quando `FLET_PLATFORM=ios` (build empacotado).
