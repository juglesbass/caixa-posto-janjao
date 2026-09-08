/**
 * Webhook do Caixa Posto Janjão — recebe o PDF de fechamento e grava no Drive.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * POLÍTICA DE SEGURANÇA E IMUTABILIDADE FINANCEIRA
 *
 * 1. MODO ESTRITAMENTE ADITIVO (APENAS CRIAÇÃO):
 *    O script opera única e exclusivamente no modo de criação (`createFile`).
 *    É expressamente PROIBIDA qualquer chamada de exclusão (`delete`,
 *    `setTrashed`, `trash`). Nenhum arquivo existente é apagado, sobrescrito
 *    ou enviado à lixeira.
 *
 * 2. TODO ENVIO VIRA ARQUIVO:
 *    Nenhuma verificação deste script pode impedir a gravação do PDF. As
 *    conferências abaixo só escolhem o NOME do arquivo; se qualquer uma delas
 *    falhar, o erro é engolido e o arquivo é criado assim mesmo. Falhar
 *    criando um arquivo a mais é aceitável. Falhar sem criar, não.
 *
 * 3. O NOME DIZ O QUE ACONTECEU:
 *    O app gera um `auth_hash` por FECHAMENTO, a partir de
 *    operador|turno|total|horário do fechamento. Isso separa dois casos que
 *    antes se confundiam:
 *
 *      Agildo 08-09-2026.pdf             entrega normal
 *      Agildo 08-09-2026 (reenvio).pdf   MESMO fechamento que chegou de novo
 *                                        (a fila offline reenviou após timeout).
 *                                        Nada foi corrigido.
 *      Agildo 08-09-2026_v2.pdf          turno REABERTO e fechado de novo.
 *                                        Aqui sim houve correção — o gerente
 *                                        usa o _v2 e descarta o anterior.
 *
 *    Assim "_vN" volta a significar uma coisa só: alguém corrigiu o turno.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * Payload enviado pelo app (Content-Type: text/plain, corpo em JSON):
 *   nome_arquivo    "Agildo 08-09-2026.pdf"
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

// Teto de tentativas ao procurar nome livre. Existe só para que um caso
// absurdo não trave a execução até o timeout do Apps Script sem gravar nada.
var LIMITE_TENTATIVAS_NOME = 200;

function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      return responder({ status: 'error', message: 'Requisicao sem corpo' });
    }

    var dados = JSON.parse(e.postData.contents);

    var turnoId = String(dados.turno_id || '').trim();
    var nomeOriginal = String(dados.nome_arquivo || '').trim();
    var base64 = dados.arquivo_base64;

    if (!turnoId || !nomeOriginal || !base64) {
      return responder({ status: 'error', message: 'Payload incompleto' });
    }

    // O app manda o id da pasta em quatro nomes diferentes por compatibilidade
    var pastaId = dados.folderId || dados.folder_id || dados.pasta_id || dados.pastaId;
    if (!pastaId) {
      pastaId = dados.modo_teste ? PASTA_TESTES : PASTA_OFICIAL;
    }

    var pasta = DriveApp.getFolderById(pastaId);
    var authHash = String(dados.auth_hash || '').trim();

    // ── Escolha do nome ──────────────────────────────────────────────────────
    // NUNCA exclui, NUNCA sobrescreve e NUNCA deixa de criar.
    var ehReenvio = false;
    if (authHash) {
      // Falha fechada é proibida: se esta conferência der qualquer problema,
      // ehReenvio continua false e o arquivo é criado pelo caminho normal.
      ehReenvio = jaRecebeuEsteFechamento(pastaId, authHash);
    }

    var nomeFinal = ehReenvio
      ? obterNomeReenvio(pasta, nomeOriginal)
      : obterNomeDisponivel(pasta, nomeOriginal);

    var bytes = Utilities.base64Decode(base64);
    var blob = Utilities.newBlob(bytes, MimeType.PDF, nomeFinal);

    // Criação do novo arquivo no Drive
    var arquivo = pasta.createFile(blob);

    var descricao = 'Turno ' + turnoId +
      ' | Operador: ' + (dados.operador || '-') +
      (authHash ? ' | Autenticacao: ' + authHash : '') +
      (ehReenvio ? ' | REENVIO do mesmo fechamento' : '') +
      ' | Recebido em: ' + Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'dd/MM/yyyy HH:mm:ss');
    arquivo.setDescription(descricao);

    // Auditoria. O ponteiro por auth_hash é gravado apenas na PRIMEIRA entrega
    // do fechamento: se um reenvio o sobrescrevesse, ele passaria a apontar
    // para a cópia em vez do original.
    try {
      var props = PropertiesService.getScriptProperties();
      props.setProperty('ultimo_envio_' + pastaId + '_' + turnoId, arquivo.getId());
      if (authHash && !ehReenvio) {
        props.setProperty('auth_' + pastaId + '_' + authHash, arquivo.getId());
      }
    } catch (eProps) {}

    var versaoAplicada = (!ehReenvio && nomeFinal !== nomeOriginal);

    return responder({
      status: 'success',
      message: ehReenvio
        ? 'Reenvio do mesmo fechamento gravado como ' + nomeFinal + ' (nada foi corrigido)'
        : (versaoAplicada
            ? 'Arquivo criado com versionamento (' + nomeFinal + ') preservando anteriores'
            : 'Arquivo criado com sucesso no Google Drive'),
      turno_id: turnoId,
      auth_hash: authHash,
      file_id: arquivo.getId(),
      file_url: arquivo.getUrl(),
      nome_arquivo: nomeFinal,
      reenvio: ehReenvio,
      versao_aplicada: versaoAplicada,
      substituido: false,
      preservado: true
    });

  } catch (err) {
    return responder({ status: 'error', message: String(err) });
  }
}

/**
 * Este MESMO fechamento já chegou antes e o arquivo ainda está lá?
 *
 * Só serve para escolher o nome. Devolve false diante de qualquer dúvida —
 * registro ausente, arquivo apagado de vez, arquivo na lixeira, ou erro de
 * leitura. Um "false" errado cria um arquivo a mais, o que é inofensivo; um
 * "true" errado marcaria como reenvio algo que não é, então na dúvida é false.
 *
 * Se o gerente mandou o original para a lixeira, o reenvio volta com o nome
 * limpo — é o comportamento desejado, e não uma exclusão feita pelo script.
 */
function jaRecebeuEsteFechamento(pastaId, authHash) {
  try {
    var props = PropertiesService.getScriptProperties();
    var idAnterior = props.getProperty('auth_' + pastaId + '_' + authHash);
    if (!idAnterior) return false;

    var anterior = DriveApp.getFileById(idAnterior);
    if (!anterior) return false;
    if (anterior.isTrashed()) return false;

    return true;
  } catch (err) {
    // Arquivo removido definitivamente, sem permissão, cota, etc.
    return false;
  }
}

/**
 * Nome para um reenvio do mesmo fechamento: "Nome (reenvio).pdf" e, se já
 * houver, "(reenvio 2)", "(reenvio 3)"...
 *
 * O sufixo "_vN" do nome recebido é preservado de propósito: o reenvio de um
 * fechamento corrigido vira "Nome_v2 (reenvio).pdf", que continua dizendo as
 * duas coisas — foi corrigido E chegou duas vezes.
 */
function obterNomeReenvio(pasta, nomeOriginal) {
  var partes = separarExtensao(nomeOriginal);

  var candidato = partes.base + ' (reenvio)' + partes.ext;
  if (!pasta.getFilesByName(candidato).hasNext()) return candidato;

  for (var n = 2; n <= LIMITE_TENTATIVAS_NOME; n++) {
    candidato = partes.base + ' (reenvio ' + n + ')' + partes.ext;
    if (!pasta.getFilesByName(candidato).hasNext()) return candidato;
  }
  return partes.base + ' (reenvio ' + carimbo() + ')' + partes.ext;
}

/**
 * Inspeciona a pasta e determina o nome disponível para o arquivo.
 * Se "Nome.pdf" já existir, procura "Nome_v2.pdf", "Nome_v3.pdf", etc.
 * NUNCA apaga, NUNCA renomeia e NUNCA manda arquivos existentes para a lixeira.
 */
function obterNomeDisponivel(pasta, nomeOriginal) {
  var partes = separarExtensao(nomeOriginal);

  // Se o arquivo original exato não existe na pasta, usa o próprio nome
  if (!pasta.getFilesByName(nomeOriginal).hasNext()) {
    return nomeOriginal;
  }

  // Remove qualquer sufixo de versão pré-existente para achar a base pura
  var baseSemVersao = partes.base.replace(/_v\d+$/i, '');

  for (var versao = 2; versao <= LIMITE_TENTATIVAS_NOME; versao++) {
    var candidato = baseSemVersao + '_v' + versao + partes.ext;
    if (!pasta.getFilesByName(candidato).hasNext()) {
      return candidato;
    }
  }
  // Saída de emergência: nome único por carimbo de tempo, para que o PDF seja
  // gravado de qualquer jeito em vez de a execução morrer procurando nome.
  return baseSemVersao + '_v' + carimbo() + partes.ext;
}

function separarExtensao(nomeArquivo) {
  var idx = nomeArquivo.lastIndexOf('.');
  if (idx === -1) return { base: nomeArquivo, ext: '' };
  return { base: nomeArquivo.substring(0, idx), ext: nomeArquivo.substring(idx) };
}

function carimbo() {
  return Utilities.formatDate(new Date(), Session.getScriptTimeZone(), 'yyyyMMdd-HHmmss');
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
  return responder({
    status: 'ok',
    servico: 'Caixa Posto Janjao',
    modo: 'append_only',
    reenvio_rotulado: true
  });
}
