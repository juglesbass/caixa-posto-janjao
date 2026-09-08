/**
 * Webhook do Caixa Posto Janjão — recebe o PDF de fechamento e grava no Drive.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * POLÍTICA DE SEGURANÇA E IMUTABILIDADE FINANCEIRA
 *
 * 1. MODO ESTRITAMENTE ADITIVO (APENAS CRIAÇÃO):
 *    O script opera única e exclusivamente no modo de criação (`drive.files.create` / `createFile`).
 *    É expressamente PROIBIDA qualquer chamada de exclusão (`delete`, `setTrashed`, `trash`).
 *    Nenhum arquivo existente no Google Drive é apagado, sobrescrito ou enviado à lixeira.
 *
 * 2. VERSIONAMENTO CUMULATIVO E PRESERVAÇÃO TOTAL:
 *    Se um arquivo com o mesmo nome já existir na pasta de destino (por exemplo,
 *    em caso de turno reaberto, reenvio ou reprocessamento), o novo arquivo recebe
 *    automaticamente um sufixo de versão sequencial (_v2, _v3, etc.).
 *    Todos os fechamentos anteriores permanecem 100% intactos na pasta para
 *    garantia de auditoria fiscal e financeira do posto.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Payload enviado pelo app (Content-Type: text/plain, corpo em JSON):
 *   nome_arquivo    "Agildo 05-09-2026 T1.pdf"
 *   turno_id        1
 *   auth_hash       "AUTH-1A2B-3C4D-5E6F"
 *   operador        "Agildo"
 *   arquivo_base64  "JVBERi0xLjQK..."
 *   folderId        id da pasta de destino (também aceito como folder_id/pasta_id/pastaId)
 *   modo_teste      true/false
 */

// Pastas de destino no Drive do gerente (mesmas constantes do app)
var PASTA_OFICIAL = '1lW3RYNyOzPz1R8A-vT9t9QWoLNvkADsC';
var PASTA_TESTES  = '1uvJ6r3ZVzfw5Qv0X471hM11jYMSdbqhM';

function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      return responder({ status: 'error', message: 'Requisicao sem corpo' });
    }

    var dados = JSON.parse(e.postData.contents);

    var turnoId = String(dados.turno_id || '').trim();
    var nomeOriginal = String(dados.nome_arquivo || '').trim();
    var base64  = dados.arquivo_base64;

    if (!turnoId || !nomeOriginal || !base64) {
      return responder({ status: 'error', message: 'Payload incompleto' });
    }

    // O app manda o id da pasta em quatro nomes diferentes por compatibilidade
    var pastaId = dados.folderId || dados.folder_id || dados.pasta_id || dados.pastaId;
    if (!pastaId) {
      pastaId = dados.modo_teste ? PASTA_TESTES : PASTA_OFICIAL;
    }

    var pasta = DriveApp.getFolderById(pastaId);

    // ── Auditoria de Listagem e Versionamento Automático ─────────────────────
    // NUNCA exclui nem move arquivos anteriores para a lixeira.
    // Se o nome já existir, calcula o próximo sufixo (_v2, _v3, ...)
    var nomeFinal = obterNomeDisponivel(pasta, nomeOriginal);

    var bytes = Utilities.base64Decode(base64);
    var blob  = Utilities.newBlob(bytes, MimeType.PDF, nomeFinal);

    // Criação do novo arquivo no Drive (drive.files.create)
    var arquivo = pasta.createFile(blob);

    var authHash = String(dados.auth_hash || '').trim();
    var descricao = 'Turno ' + turnoId +
      ' | Operador: ' + (dados.operador || '-') +
      (authHash ? ' | Autenticacao: ' + authHash : '') +
      ' | Recebido em: ' + Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'dd/MM/yyyy HH:mm:ss');
    arquivo.setDescription(descricao);

    // Registra auditoria histórica no ScriptProperties sem nenhuma exclusão
    try {
      var props = PropertiesService.getScriptProperties();
      props.setProperty('ultimo_envio_' + pastaId + '_' + turnoId, arquivo.getId());
      if (authHash) {
        props.setProperty('auth_' + pastaId + '_' + authHash, arquivo.getId());
      }
    } catch (eProps) {}

    var versaoAplicada = (nomeFinal !== nomeOriginal);

    return responder({
      status: 'success',
      message: versaoAplicada
        ? 'Arquivo criado com versionamento (' + nomeFinal + ') preservando anteriores'
        : 'Arquivo criado com sucesso no Google Drive',
      turno_id: turnoId,
      auth_hash: authHash,
      file_id: arquivo.getId(),
      file_url: arquivo.getUrl(),
      nome_arquivo: nomeFinal,
      versao_aplicada: versaoAplicada,
      substituido: false,
      preservado: true
    });

  } catch (err) {
    return responder({ status: 'error', message: String(err) });
  }
}

/**
 * Inspeciona a pasta e determina o nome disponível para o arquivo.
 * Se "Nome.pdf" já existir, procura "Nome_v2.pdf", "Nome_v3.pdf", etc.
 * NUNCA apaga, NUNCA renomeia e NUNCA manda arquivos existentes para a lixeira.
 */
function obterNomeDisponivel(pasta, nomeOriginal) {
  var ext = '';
  var base = nomeOriginal;
  var idxExt = nomeOriginal.lastIndexOf('.');
  if (idxExt !== -1) {
    base = nomeOriginal.substring(0, idxExt);
    ext = nomeOriginal.substring(idxExt);
  }

  // Se o arquivo original exato não existe na pasta, usa o próprio nome
  var arquivos = pasta.getFilesByName(nomeOriginal);
  if (!arquivos.hasNext()) {
    return nomeOriginal;
  }

  // Remove qualquer sufixo de versão pré-existente no nome para encontrar a base pura
  var baseSemVersao = base.replace(/_v\d+$/i, '');

  var versao = 2;
  while (true) {
    var candidato = baseSemVersao + '_v' + versao + ext;
    var teste = pasta.getFilesByName(candidato);
    if (!teste.hasNext()) {
      return candidato;
    }
    versao++;
  }
}

function responder(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

/**
 * Health check: abrir a URL /exec no navegador deve mostrar este JSON.
 */
function doGet() {
  return responder({ status: 'ok', servico: 'Caixa Posto Janjao', modo: 'append_only' });
}
