# Caixa - Posto Janjão — Deploy & CI

Este branch (feat/compartilhar-resumo-pdf) adiciona recursos de exportação de PDF, compartilhamento robusto, um servidor opcional para servir backups e workflows para gerar builds Android/iOS automaticamente.

Resumo das mudanças principais
- exportar_turno_pdf em `db.py` — usa `CAIXA_FONT_PATH` quando definido, tenta fontes do sistema e faz fallback.
- Uso de `Decimal` para cálculos monetários em `db.py` (melhora precisão).
- `main.py` — fallback de compartilhamento (ft.Share) e tentativa de abrir URL pública assinada quando o share não está disponível.
- `backups_server.py` — pequeno servidor Flask para servir a pasta `backups/` com tokens HMAC assinados; inclui endpoint `/backups/generate/<file>` para obter URL com token.
- Workflows GitHub Actions:
  - `.github/workflows/android-build.yml` — empacota Android quando há push/PR em arquivos `.py` e publica artifacts (APK/AAB).
  - `.github/workflows/ios-build.yml` — empacota iOS e publica artifacts (xcarchive/IPA quando possível). IPA é exportado apenas se os secrets de assinatura estiverem definidos.

O que você precisa configurar no repositório (Secrets)
- Android (opcional, apenas para assinar o APK):
  - ANDROID_KEYSTORE_BASE64 — conteúdo do keystore (.keystore) em base64
  - ANDROID_KEYSTORE_PASSWORD
  - ANDROID_KEY_ALIAS
  - ANDROID_KEY_PASSWORD

- iOS (opcional — necessário apenas se quiser IPA assinado automaticamente; para sideload não é obrigatório):
  - IOS_CERT_P12_BASE64 — .p12 em base64
  - IOS_CERT_P12_PASSWORD
  - IOS_PROVISIONING_PROFILE_BASE64 — .mobileprovision em base64
  - IOS_DEVELOPMENT_TEAM — Team ID

- Proteção de downloads (recomendado):
  - CAIXA_BACKUP_SECRET — segredo HMAC para gerar/validar tokens de download (se não definido, o servidor servirá arquivos sem token)

- Outras variáveis úteis (ambiente do host):
  - CAIXA_FONT_PATH — caminho para a TTF usada nos PDFs (ex.: /app/assets/fonts/DejaVuSans.ttf)
  - CAIXA_PUBLIC_BASE_URL — URL pública base (ex.: https://seu-app.onrender.com) usada como fallback no app

Como gerar os base64 para os secrets
- Linux / macOS:
  - base64 -w 0 my-release.keystore > keystore.b64
  - base64 -w 0 cert.p12 > cert.p12.b64
  - base64 -w 0 profile.mobileprovision > profile.b64
- Windows (PowerShell):
  - [Convert]::ToBase64String([IO.File]::ReadAllBytes("my-release.keystore")) | Out-File -Encoding ascii keystore.b64

Cole o conteúdo do arquivo `.b64` no campo do secret correspondente no GitHub.

Como testar localmente
1) Puxe o branch:
   git fetch origin
   git checkout feat/compartilhar-resumo-pdf
2) Instale dependências:
   pip install -r requirements.txt
3) (Opcional) Rode o servidor de backups local:
   python backups_server.py
   — disponível em http://0.0.0.0:5001 por padrão
4) Rode a app:
   python main.py
5) Gere fechamento de turno e clique em "Compartilhar PDF":
   - Em desktop: o PDF será salvo em `backups/`.
   - Se o share nativo falhar, o app tentará abrir `CAIXA_PUBLIC_BASE_URL/backups/<file>?token=...` ou o servidor local se estiver rodando.

Sobre os workflows (CI)
- Os workflows disparam em push e pull_request que alterem arquivos `**/*.py`.
- Os artefatos gerados ficam disponíveis na página do run (Actions → selecionar run → Artifacts).
- Android: sem os secrets de assinatura você terá APK/AAB unsigned — útil para testes e sideload.
- iOS: sem secrets a Action ainda envia o Xcode project / xcarchive quando gerados; exportar um IPA assinado requer certificados e perfil.

Notas de segurança e recomendações
- Não commit o arquivo de fonte (TTF) nem arquivos de certificação. Use secrets e `CAIXA_FONT_PATH` no ambiente de deploy.
- Para produção, configure `CAIXA_BACKUP_SECRET` e rode `backups_server.py` ou use mecanismo do host para servir `backups/` com controle de acesso.
- SQLite é usado para simplicidade; se houver multiusuários simultâneos considere migrar para Postgres.

Se quiser que eu abra o Pull Request com estas mudanças e esta descrição, diga apenas: `Abrir PR`. Caso queira revisar antes, posso gerar o link direto para abrir o PR no GitHub.
