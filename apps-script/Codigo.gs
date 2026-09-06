/**
 * Webhook do Caixa Posto Janjão — recebe o PDF de fechamento e grava no Drive.
 *
 * ─────────────────────────────────────────────────────────────────────────────
 * POR QUE ESTE ARQUIVO EXISTE
 *
 * O app não tem como saber a diferença entre "o envio não chegou" e "o envio
 * chegou, foi processado, mas a resposta se perdeu no caminho". Quando o
 * servidor demora e o cliente desiste por timeout, o app enfileira o PDF e
 * reenvia depois — e o gerente acaba com dois arquivos do mesmo turno.
 *
 * A solução não está no app: está aqui. Este doPost é IDEMPOTENTE — receber o
 * mesmo turno duas vezes substitui o arquivo em vez de criar outro. Com isso o
 * reenvio vira inofensivo e o problema todo desaparece.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * ATENÇÃO: se o seu script atual já faz outras coisas (registrar em planilha,
 * mandar e-mail, etc.), NÃO cole este arquivo por cima. Aproveite só as partes
 * de idempotência: a chave em PropertiesService e o bloco que localiza e
 * substitui o arquivo anterior.
 *
 * Payload enviado pelo app (Content-Type: text/plain, corpo em JSON):
 *   nome_arquivo    "Agildo 05-09-2026 T1.pdf"
 *   turno_id        1                      <- chave de idempotência
 *   operador        "Agildo"
 *   arquivo_base64  "JVBERi0xLjQK..."
 *   folderId        id da pasta de destino (também vem como folder_id/pasta_id/pastaId)
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
    var nome    = String(dados.nome_arquivo || '').trim();
    var base64  = dados.arquivo_base64;

    if (!turnoId || !nome || !base64) {
      return responder({ status: 'error', message: 'Payload incompleto' });
    }

    // O app manda o id da pasta em quatro nomes diferentes por compatibilidade
    var pastaId = dados.folderId || dados.folder_id || dados.pasta_id || dados.pastaId;
    if (!pastaId) {
      pastaId = dados.modo_teste ? PASTA_TESTES : PASTA_OFICIAL;
    }

    var pasta = DriveApp.getFolderById(pastaId);
    var blob  = Utilities.newBlob(Utilities.base64Decode(base64), MimeType.PDF, nome);

    // ── Idempotência ────────────────────────────────────────────────────────
    // Procura um arquivo já gravado para este turno. Primeiro pelo id que
    // guardamos; se o registro tiver se perdido, cai para a busca pelo nome
    // (que já inclui o número do turno, então não colide entre turnos).
    var props = PropertiesService.getScriptProperties();
    var chave = 'turno_' + pastaId + '_' + turnoId;

    var anterior = localizarArquivoAnterior(props, chave, pasta, nome);

    var arquivo = pasta.createFile(blob);
    arquivo.setDescription('Turno ' + turnoId + ' | Operador: ' + (dados.operador || '-'));

    // Só descarta o antigo DEPOIS que o novo existe: se algo falhar no meio,
    // o gerente fica com uma cópia a mais, nunca com nenhuma.
    var substituido = false;
    if (anterior) {
      try {
        anterior.setTrashed(true);
        substituido = true;
      } catch (err) {
        // Sem permissão ou já removido: não é motivo para falhar o envio
      }
    }

    props.setProperty(chave, arquivo.getId());

    return responder({
      status: 'success',
      message: substituido ? 'Arquivo do turno substituido' : 'Arquivo criado',
      turno_id: turnoId,
      file_id: arquivo.getId(),
      file_url: arquivo.getUrl(),
      substituido: substituido
    });

  } catch (err) {
    return responder({ status: 'error', message: String(err) });
  }
}

/**
 * Devolve o arquivo já gravado para este turno, ou null se não houver.
 */
function localizarArquivoAnterior(props, chave, pasta, nome) {
  // 1. Pelo id guardado no envio anterior — caminho exato
  var idSalvo = props.getProperty(chave);
  if (idSalvo) {
    try {
      var f = DriveApp.getFileById(idSalvo);
      if (!f.isTrashed()) {
        return f;
      }
    } catch (err) {
      // Arquivo apagado de vez: segue para a busca por nome
    }
  }

  // 2. Pelo nome dentro da pasta — cobre o caso de o registro ter sido perdido
  //    (script republicado do zero, propriedades limpas). O nome traz o número
  //    do turno, então dois turnos diferentes nunca casam aqui.
  try {
    var iter = pasta.getFilesByName(nome);
    if (iter.hasNext()) {
      return iter.next();
    }
  } catch (err) {}

  return null;
}

function responder(obj) {
  return ContentService
    .createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

/**
 * Health check: abrir a URL /exec no navegador deve mostrar este JSON.
 * Se aparecer uma tela de login do Google, a implantação está com acesso
 * errado — veja o passo 5 do guia (apps-script/README.md).
 */
function doGet() {
  return responder({ status: 'ok', servico: 'Caixa Posto Janjao' });
}
