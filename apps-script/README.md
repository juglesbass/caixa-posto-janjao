# Webhook do Google Drive — onde fica e como atualizar

O app manda o PDF de fechamento para um **Google Apps Script**, que grava o arquivo na pasta do gerente. O código de referência está em [`Codigo.gs`](Codigo.gs).

## Política de Imutabilidade Financeira (Modo Estritamente Aditivo)

Em relatório financeiro e fiscal, **apagar ou enviar arquivos para a lixeira é permanentemente proibido**.

O `Codigo.gs` opera exclusivamente no modo de **criação** (`createFile`):
- **Nenhum arquivo é apagado ou enviado para a lixeira** sob nenhuma circunstância.
- **Nenhum arquivo anterior é renomeado ou alterado**.
- **Nenhuma verificação do script pode impedir a gravação do PDF.** As conferências só escolhem o *nome*; se qualquer uma delas falhar, o erro é ignorado e o arquivo é criado assim mesmo. Gravar um arquivo a mais é aceitável — deixar de gravar, não.

### O nome do arquivo diz o que aconteceu

O app gera um `auth_hash` por **fechamento**, a partir de `operador|turno|total|horário do fechamento`. Isso separa duas situações que antes se confundiam na pasta:

| Situação | `auth_hash` | Nome na pasta do Drive |
|---|---|---|
| Envio inicial do turno | novo | `Agildo 08-09-2026.pdf` |
| **Turno reaberto e corrigido** | **muda** (horário novo) | `Agildo 08-09-2026_v2.pdf` — houve correção. O gerente usa o `_v2` e descarta o anterior. O original permanece 100% intacto. |
| **Mesmo fechamento reenviado** pela fila offline após timeout | **igual** | `Agildo 08-09-2026 (reenvio).pdf` — nada foi corrigido, o PDF só chegou duas vezes. Depois: `(reenvio 2)`, `(reenvio 3)`… |
| Reenvio de um fechamento já corrigido | igual ao do `_v2` | `Agildo 08-09-2026_v2 (reenvio).pdf` — diz as duas coisas |

Assim o `_vN` volta a significar **uma coisa só**: alguém reabriu o turno e corrigiu. O gerente sabe de bater o olho, sem precisar abrir os dois arquivos para comparar.

Se o gerente mandar o original para a lixeira por conta própria, um reenvio posterior volta com o nome limpo — quem apagou foi ele, não o script.

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
{"status":"ok","servico":"Caixa Posto Janjao","modo":"append_only","reenvio_rotulado":true}
```

O campo `reenvio_rotulado` confirma que a versão publicada é a que separa reenvio de correção. Se ele não aparecer, o script antigo ainda está no ar — refaça o passo 4.

Se aparecer tela de login, volte ao passo 5.

Teste de verdade, com o app:
 
 1. No app, ligue o **Modo Teste** (Menu → Gerência) — assim tudo vai para a pasta de Testes.
 2. Feche um turno e confirme que o PDF chegou.
 3. **Reabra o mesmo turno pelo histórico e feche de novo.** Agora a pasta deve ter **dois** arquivos: o inicial (`Agildo 08-09-2026.pdf`) e o corrigido (`Agildo 08-09-2026_v2.pdf`). Todos os arquivos anteriores permanecem intactos.
 4. Desligue o Modo Teste.

O caso do **reenvio** não dá para provocar à mão: ele acontece sozinho quando o servidor demora, o PDF cai na fila e é reenviado depois. Quando acontecer, o arquivo extra virá com `(reenvio)` no nome — é o sinal de que ninguém corrigiu nada e os dois PDFs têm o mesmo conteúdo.

## Como rotacionar o webhook

Se um dia precisar trocar a URL (ela é pública neste repositório), não é preciso mexer no código do app:

- pela tela de configurações do app, que grava em `google_drive_webhook_url`; ou
- no build: `flutter build web --release --dart-define=DRIVE_WEBHOOK_URL=https://.../exec`
