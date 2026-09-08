# Webhook do Google Drive — onde fica e como atualizar

O app manda o PDF de fechamento para um **Google Apps Script**, que grava o arquivo na pasta do gerente. O código de referência está em [`Codigo.gs`](Codigo.gs).

## Política de Imutabilidade Financeira (Modo Estritamente Aditivo)

Em relatório financeiro e fiscal, **apagar ou enviar arquivos para a lixeira é permanentemente proibido**.

O `Codigo.gs` opera exclusivamente no modo de **criação** (`drive.files.create`):
- **Nenhum arquivo é apagado ou enviado para a lixeira** sob nenhuma circunstância.
- **Nenhum arquivo anterior é renomeado ou alterado**.
- Se um arquivo com o mesmo nome já existir na pasta de destino (por exemplo, em caso de reabertura de turno, reenvio pela fila offline ou reprocessamento), o novo PDF é salvo com um sufixo sequencial de versão: `..._v2.pdf`, `..._v3.pdf`, etc.

| Situação | O que acontece na pasta do Google Drive |
|---|---|
| Envio inicial do turno | Arquivo novo criado com o nome original (ex: `Agildo 08-09-2026 T1.pdf`) |
| Turno reaberto e reenviado | Arquivo novo criado com versão sequencial (ex: `Agildo 08-09-2026 T1_v2.pdf`). O original permanece 100% intacto. |
| Reenvio posterior | Cria a próxima versão disponível (`_v3.pdf`), mantendo todo o histórico acessível para auditoria. |

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
- Se ele faz **mais coisas** (registra numa planilha, manda e-mail, etc.): **não cole por cima.** Aproveite a lógica de versionamento aditivo de [`Codigo.gs`](Codigo.gs) (`obterNomeDisponivel`) garantindo que NENHUMA linha execute `setTrashed` ou exclusão.

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
 3. **Reabra o mesmo turno pelo histórico e feche de novo.** Agora a pasta deve ter **dois** arquivos: o inicial (ex: `Agildo 08-09-2026 T1.pdf`) e o novo versionado (`Agildo 08-09-2026 T1_v2.pdf`). Todos os arquivos anteriores permanecem intactos.
 4. Desligue o Modo Teste.

## Como rotacionar o webhook

Se um dia precisar trocar a URL (ela é pública neste repositório), não é preciso mexer no código do app:

- pela tela de configurações do app, que grava em `google_drive_webhook_url`; ou
- no build: `flutter build web --release --dart-define=DRIVE_WEBHOOK_URL=https://.../exec`
