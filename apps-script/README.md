# Webhook do Google Drive — onde fica e como atualizar

O app manda o PDF de fechamento para um **Google Apps Script**, que grava o arquivo na pasta do gerente. O código de referência está em [`Codigo.gs`](Codigo.gs).

## Por que mexer nisso

O app não consegue distinguir "o envio não chegou" de "o envio chegou e a resposta se perdeu". Quando o servidor demora e o cliente desiste por timeout, o PDF vai para a fila e é reenviado depois — e o gerente fica com **dois arquivos do mesmo turno**.

Isso não tem conserto do lado do app. O `Codigo.gs` resolve tornando o `doPost` **idempotente**: receber o mesmo turno duas vezes substitui o arquivo em vez de criar outro.

## Passo 1 — Achar o script

A URL do webhook é:

```
https://script.google.com/macros/s/AKfycbzes0dAFXK3_Us145YsnfKXAI_UzVjMHlVG4uK2-cYkxHy2f5M_VCaLEVEJhWOIvcVITQ/exec
```

O trecho `AKfycbze…` é o **ID da implantação**, não o do projeto — por isso essa URL não abre o editor. Para chegar ao script:

1. Entre em **https://script.google.com/home** com a conta Google que criou o script (a mesma dona da pasta do Drive).
2. A lista mostra todos os seus projetos. Abra o que parecer ser o do posto.
3. Confirme que é o certo: **Implantar → Gerenciar implantações**. O ID que aparece ali tem que bater com o `AKfycbze…` da URL acima.

Se não achar na lista, o script pode estar **vinculado a uma planilha**. Nesse caso abra a planilha e vá em **Extensões → Apps Script**.

## Passo 2 — Comparar antes de colar

Abra o `Codigo.gs` que já está lá e veja o que ele faz.

- Se ele **só** recebe o PDF e salva no Drive: pode substituir pelo conteúdo de [`Codigo.gs`](Codigo.gs).
- Se ele faz **mais coisas** (registra numa planilha, manda e-mail, renomeia, etc.): **não cole por cima.** Aproveite só as duas partes que dão a idempotência:
  - a chave em `PropertiesService` (`var chave = 'turno_' + pastaId + '_' + turnoId;`)
  - a função `localizarArquivoAnterior()` e o bloco que cria o novo arquivo e só depois manda o antigo para a lixeira

## Passo 3 — Conferir os IDs das pastas

No topo do `Codigo.gs`:

```javascript
var PASTA_OFICIAL = '1lW3RYNyOzPz1R8A-vT9t9QWoLNvkADsC';
var PASTA_TESTES  = '1uvJ6r3ZVzfw5Qv0X471hM11jYMSdbqhM';
```

Precisam ser os mesmos de `lib/services/drive_service.dart`. Se você trocou a pasta em algum momento, ajuste nos dois lugares.

## Passo 4 — Salvar e republicar (sem trocar a URL)

Esta é a parte onde é fácil errar:

1. Salve o código (💾 ou `Ctrl+S`).
2. **Implantar → Gerenciar implantações**.
3. Clique no **lápis** (Editar) da implantação que já existe.
4. Em **Versão**, escolha **Nova versão**.
5. **Implantar**.

> ⚠️ Não use **"Nova implantação"**. Isso cria uma URL `/exec` diferente e o app para de enviar — ele continuaria apontando para a URL antiga.

## Passo 5 — Conferir quem tem acesso

Ainda na tela de edição da implantação:

- **Executar como:** Eu (sua conta)
- **Quem pode acessar:** **Qualquer pessoa**

Tem que ser "Qualquer pessoa", **não** "Qualquer pessoa com conta Google". Com a segunda opção o Google devolve a tela de login em vez de rodar o script — e responde HTTP 200, o que já fez o app anunciar entrega sem nada ter chegado. O app hoje detecta isso e avisa "O Google pediu login em vez de executar o script", mas o certo é não cair nessa configuração.

## Passo 6 — Testar

Teste rápido, sem app: abra a URL `/exec` no navegador. Deve aparecer

```json
{"status":"ok","servico":"Caixa Posto Janjao"}
```

Se aparecer tela de login, volte ao passo 5.

Teste de verdade, com o app:

1. No app, ligue o **Modo Teste** (Menu → Gerência) — assim tudo vai para a pasta de Testes.
2. Feche um turno e confirme que o PDF chegou.
3. **Feche o mesmo turno de novo** (reabra pelo histórico e feche outra vez). Com a idempotência funcionando, a pasta continua com **um único arquivo**, atualizado — não dois.
4. Desligue o Modo Teste.

## Como rotacionar o webhook

Se um dia precisar trocar a URL (ela é pública neste repositório), não é preciso mexer no código do app:

- pela tela de configurações do app, que grava em `google_drive_webhook_url`; ou
- no build: `flutter build web --release --dart-define=DRIVE_WEBHOOK_URL=https://.../exec`
