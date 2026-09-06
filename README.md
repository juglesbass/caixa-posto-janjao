# Caixa — Posto Janjão

Aplicativo de caixa para controle de turno no posto: lançamentos por forma de pagamento, totais em tempo real, histórico, fechamento de turno com assinatura digital e envio automático do PDF para o Google Drive do gerente.

Roda em **Android (APK)**, **iOS (IPA)** e como **PWA instalável** a partir do mesmo código.

> O app já foi um projeto Python/Flet. Hoje é **Flutter/Dart** — se você encontrar `main.py`, `requirements.txt` ou a pasta `venv/`, são resíduos da versão antiga e não fazem parte do build.

## Requisitos

- Flutter 3.44 ou superior (canal `stable`) — Dart 3.4 no mínimo, exigido pelo
  `dart:js_interop` usado nas notificações e na vibração do Web
- Para Android: JDK 17 + Android SDK
- Para iOS: macOS + Xcode

```bash
flutter pub get
```

## Executar

```bash
flutter run
```

## Build

### PWA / Web

```bash
flutter build web --release
```

> **Importante:** o banco local no Web depende de `web/sqlite3.wasm`, que está versionado no repositório. Se por algum motivo ele sumir, o app abre mas **nenhum dado é gravado** — o banco cai para memória e some ao recarregar a página (o app mostra um banner vermelho avisando). Para regerar:
>
> ```bash
> dart run sqflite_common_ffi_web:setup
> ```

Sirva o conteúdo de `build/web/` em HTTPS. Sem HTTPS o navegador não oferece a instalação do PWA nem libera notificações.

### Android

```bash
flutter build apk --release
```

#### Assinatura de release (obrigatória para distribuir)

O `build.gradle.kts` procura por `android/key.properties`. **Se o arquivo não
existir, o APK sai assinado com a chave de debug** — e a chave de debug muda de
máquina para máquina e a cada execução do CI. Um APK com chave diferente da
instalada não atualiza o app: o Android recusa com "app não instalado", e a
única saída passa a ser desinstalar — o que **apaga o banco local com os
turnos**.

Gere a chave uma única vez e guarde bem (perdê-la significa não conseguir mais
publicar atualizações):

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Coloque o `.jks` em `android/app/` e crie `android/key.properties`:

```properties
storePassword=SUA_SENHA
keyPassword=SUA_SENHA
keyAlias=upload
storeFile=upload-keystore.jks
```

Os dois arquivos estão no `.gitignore` e nunca devem ser versionados.

Para o CI assinar também, cadastre os secrets no repositório:

| Secret | Conteúdo |
|---|---|
| `ANDROID_KEYSTORE_BASE64` | saída de `base64 -w0 upload-keystore.jks` |
| `ANDROID_KEYSTORE_PASSWORD` | `storePassword` |
| `ANDROID_KEY_PASSWORD` | `keyPassword` |
| `ANDROID_KEY_ALIAS` | `upload` |

Sem os secrets o workflow continua gerando o APK, mas emite um aviso no log e o
arquivo sai com a chave de debug.

### iOS

```bash
flutter build ios --release
```

O workflow `.github/workflows/build-ios.yml` gera APK e IPA (não assinado) a cada push na `main`, e publica os dois como artefatos da execução.

> Não fixe `compileSdk`/`minSdk` na mão no `android/app/build.gradle.kts`. Os valores vêm do próprio Flutter (`flutter.compileSdkVersion` = 36, `flutter.minSdkVersion` = 24); travá-los em versões antigas quebra `share_plus`, `sqflite_android`, `printing` e `flutter_local_notifications`.
>
> O `isCoreLibraryDesugaringEnabled = true` e a dependência `desugar_jdk_libs` no `android/app/build.gradle.kts` são exigidos pelo `flutter_local_notifications` — não remova, o build do APK falha sem eles.

## Configuração

### Webhook do Google Drive

A URL do Apps Script que recebe os PDFs é resolvida nesta ordem:

1. Configuração `google_drive_webhook_url` salva no banco (tela de configurações)
2. `--dart-define=DRIVE_WEBHOOK_URL=...` no momento do build
3. O valor padrão em `lib/services/drive_service.dart`

```bash
flutter build web --release --dart-define=DRIVE_WEBHOOK_URL=https://script.google.com/macros/s/SEU_ID/exec
```

Como este repositório é público, a URL padrão é conhecida por qualquer um. Para rotacionar o webhook, publique um novo Apps Script e informe a URL nova por uma das duas primeiras opções — sem depender de alterar o código.

### Firestore (sincronização de operadores)

Os operadores e os hashes de PIN são sincronizados via API REST do Cloud Firestore, em modo *offline-first*: o app funciona 100% com o cache local e sincroniza quando há rede.

As regras de segurança recomendadas estão em [`firestore.rules`](firestore.rules):

```bash
firebase deploy --only firestore:rules
```

**Leia o cabeçalho do arquivo antes de publicar.** O app hoje acessa o Firestore sem autenticação, então a leitura da coleção `operadores` precisa estar liberada — e isso expõe os hashes de PIN a quem descobrir o ID do projeto. As regras do arquivo reduzem o dano, mas o fechamento definitivo exige **Firebase App Check** ou mover a validação de PIN para uma Cloud Function.

O que as regras garantem hoje:

- Negam tudo por padrão; só `operadores` e `configuracoes/gerencia` são acessíveis.
- `allow delete: if false` nas duas coleções. **Ninguém apaga documento** — nem o
  app, nem um terceiro que descubra o ID do projeto.
- Todo `pin_hash` novo tem que estar no formato PBKDF2 com sal. Hashes SHA-256
  legados que já estão na base continuam validando, mas não é possível
  introduzir nem reintroduzir um hash fraco.

#### Exclusão de operador é reversível

A gerência não apaga o documento: marca `removido: true`. O operador some das
listas, para de autenticar em todos os aparelhos e tem as credenciais locais
revogadas na próxima sincronização — mas o registro continua na base,
preservando o rastro de quem assinou fechamentos antigos. Cadastrar de novo um
operador com o mesmo nome restaura o documento.

#### PIN Mestre sincronizado

O hash do PIN Mestre fica em `configuracoes/gerencia` e é replicado para todos os
aparelhos. Antes ele vivia só no armazenamento local de cada dispositivo: trocar
o PIN num celular não valia em nenhum outro, e qualquer instalação nova ou
navegador com os dados limpos voltava ao PIN de fábrica — com o painel da
gerência, e o "Limpar / Zerar Tudo" dentro dele, aberto para quem soubesse o
padrão.

### PIN mestre da gerência

O PIN mestre de fábrica é `9999` e abre qualquer turno e qualquer operação. **Troque no primeiro uso**, em Menu → Área da Gerência → Alterar PIN Mestre. Enquanto ele for o padrão, o painel da gerência exibe um alerta vermelho.

O PIN Mestre é sincronizado via Firestore, então trocá-lo em um aparelho vale em
todos os outros.

Os PINs são armazenados apenas como hash **PBKDF2-HMAC-SHA256 com sal aleatório por operador**. Hashes antigos (SHA-256 puro), ou derivados com menos iterações do que a versão atual usa, continuam validando e são regravados no formato mais forte no primeiro acesso correto. O PIN Mestre usa uma contagem de iterações bem maior que a dos operadores, porque é digitado poucas vezes e sempre atrás de um botão com indicador de carregamento.

## Funcionalidades

- Lançamento rápido por forma de pagamento, com atalhos de valor e calculadora de troco
- Seleção de maquininha (Rede/Cielo) e bandeiras de cartão em ordem operacional
- Totais em tempo real: dinheiro na gaveta, PIX, cartões, requisição, depósito, despesas, sangria e suprimento
- Histórico do turno com filtros e edição/exclusão de lançamentos
- Encerrantes de bico e consulta de produtos
- Fechamento de turno com PIN, assinatura digital SHA-256 e página pública de validação (`/validar?auth=...`)
- PDF de fechamento gerado no dispositivo e enviado ao Google Drive do gerente,
  com nome `Operador dd-MM-aaaa T<turno>.pdf` — o número do turno evita que o
  segundo fechamento do dia sobrescreva o primeiro dentro da pasta do gerente
- Fila offline: se faltar internet no fechamento, o PDF fica pendente e é
  reenviado automaticamente, com espera crescente entre as tentativas e uma nova
  tentativa sempre que o app volta do segundo plano
- Notificação do sistema quando o PDF fica pendente e quando é entregue (Android, iOS e Web)
- Exportação em CSV e compartilhamento por WhatsApp
- Gestão de operadores e PINs sincronizada via Firestore
- Tema claro/escuro e feedback tátil configurável

## Pasta do gerente no Google Drive

O app **nunca apaga nada** no Drive: a única operação é o `POST` do PDF para o
webhook do Apps Script. Ainda assim, dois pontos merecem atenção:

- **Publique o Apps Script com acesso "Qualquer pessoa".** Se estiver como
  "Qualquer pessoa com conta Google", o Google responde `HTTP 200` com a página
  de login em vez de executar o script. O app detecta essa resposta e trata como
  falha (o PDF vai para a fila); antes ela era lida como sucesso e o fechamento
  era dado como entregue sem nunca chegar ao Drive.
- **Não sobrescreva por nome.** O Apps Script deve sempre criar um arquivo novo,
  nunca procurar por nome e substituir.

O "Limpar / Zerar Tudo" do painel da gerência é recusado enquanto houver PDF na
fila de envio: zerar nessa hora apagaria fechamentos que ainda não chegaram à
pasta do gerente, sem deixar como reenviá-los. O diálogo oferece o envio antes.

## Testes

```bash
flutter analyze
flutter test
```

## Estrutura

```
lib/
├── main.dart              # Bootstrap, rotas e shell de navegação
├── models/                # Turno, Lançamento, Totais, Operador
├── services/              # Banco (SQLite), Drive, PDF, CSV, Auth, sync Firestore
├── screens/               # Início, Histórico, Resumo, Menu, Validação, Gerência
├── dialogs/               # Fechamento, PIN, sangria, encerrantes, lançamento rápido
├── widgets/               # Grade de pagamentos, HUD, navegação, banners
├── utils/                 # Moeda, tipos de pagamento, haptics, validação
└── theme/                 # Cores e tema
```

## Persistência

| Plataforma | Onde ficam os dados |
|---|---|
| Android / iOS | SQLite no diretório de bancos do app |
| Web / PWA | SQLite sobre IndexedDB (via `sqlite3.wasm`) |

Preferências (tema, maquininha ativa, haptics, hashes de PIN) ficam em `SharedPreferences` — `localStorage` no Web.
