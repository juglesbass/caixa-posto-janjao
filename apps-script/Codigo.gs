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
 * mesmo fechamento duas vezes substitui o arquivo em vez de criar outro. Com
 * isso o reenvio vira inofensivo e o problema todo desaparece.
 *
 * A CHAVE É O FECHAMENTO, NÃO O TURNO
 *
 * Usar turno_id como chave seria perigoso: se o operador reabrir um turno já
 * entregue só para mexer no app e fechar de novo — talvez com um lançamento
 * apagado sem querer — o relatório ruim sobrescreveria o bom, e o gerente
 * perderia o original sem nenhum aviso.
 *
 * Por isso a chave é o `auth_hash`, que o app gera a cada fechamento a partir de
 * operador|turno|total|horário. Reenvio do mesmo fechamento tem o mesmo hash e
 * substitui. Um fechamento NOVO do mesmo turno tem hash diferente: vira um
 * arquivo novo, e o anterior é PRESERVADO, apenas renomeado com a marca
 * "(fechamento anterior ...)". Em relatório financeiro, guardar demais é sempre
 * melhor que apagar de menos.
 * ─────────────────────────────────────────────────────────────────────────────
 *
 * ATENÇÃO: se o seu script atual já faz outras coisas (registrar em planilha,
 * mandar e-mail, etc.), NÃO cole este arquivo por cima. Aproveite só as partes
 * de idempotência: a chave em PropertiesService e o bloco que localiza e
 * substitui o arquivo anterior.
 *
 * Payload enviado pelo app (Content-Type: text/plain, corpo em JSON):
 *   nome_arquivo    "Agildo 05-09-2026 T1.pdf"
 *   turno_id        1
 *   auth_hash       "AUTH-1A2B-3C4D-5E6F"  <- chave de idempotência (por fechamento)
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
    var props = PropertiesService.getScriptProperties();

    // Chave do FECHAMENTO. Sem auth_hash (app antigo) cai para o turno, que é o
    // comportamento anterior: melhor deduplicar por turno do que não deduplicar.
    var authHash = String(dados.auth_hash || '').trim();
    var chaveEnvio = 'envio_' + pastaId + '_' + (authHash || ('turno' + turnoId));

    // Ponteiro para o último arquivo entregue deste turno, seja qual for o
    // fechamento. Serve para marcar o anterior quando chega um fechamento novo.
    var chaveTurno = 'turno_' + pastaId + '_' + turnoId;

    // 1. Este MESMO fechamento já foi entregue? Então é reenvio: substitui.
    var mesmoFechamento = abrirArquivo(props.getProperty(chaveEnvio));

    // 2. Senão, é um fechamento novo: o arquivo anterior do turno será mantido.
    var fechamentoAnterior = null;
    if (!mesmoFechamento) {
      fechamentoAnterior = abrirArquivo(props.getProperty(chaveTurno));
      if (!fechamentoAnterior) {
        // Registro perdido (script republicado do zero): tenta pelo nome, que
        // já inclui o número do turno e não colide entre turnos diferentes.
        fechamentoAnterior = localizarPeloNome(pasta, nome);
      }
    }

    var arquivo = pasta.createFile(blob);
    arquivo.setDescription(
      'Turno ' + turnoId +
      ' | Operador: ' + (dados.operador || '-') +
      (authHash ? ' | Autenticacao: ' + authHash : '')
    );

    // Só mexe no antigo DEPOIS que o novo existe: se algo falhar no meio, o
    // gerente fica com uma cópia a mais, nunca com nenhuma.
    var substituido = false;
    var preservado = null;

    if (mesmoFechamento) {
      // Reenvio do mesmo fechamento: o antigo é redundante, pode ir embora
      try {
        mesmoFechamento.setTrashed(true);
        substituido = true;
      } catch (err) {}
    } else if (fechamentoAnterior) {
      // Fechamento NOVO do mesmo turno: preserva o anterior renomeado, para que
      // ninguém perca o relatório bom por causa de um reabrir sem querer.
      try {
        fechamentoAnterior.setName(nomeDeArquivado(fechamentoAnterior));
        preservado = fechamentoAnterior.getId();
      } catch (err) {}
    }

    props.setProperty(chaveEnvio, arquivo.getId());
    props.setProperty(chaveTurno, arquivo.getId());

    return responder({
      status: 'success',
      message: substituido
        ? 'Reenvio do mesmo fechamento: arquivo substituido'
        : (preservado
            ? 'Novo fechamento do turno: anterior preservado e renomeado'
            : 'Arquivo criado'),
      turno_id: turnoId,
      auth_hash: authHash,
      file_id: arquivo.getId(),
      file_url: arquivo.getUrl(),
      substituido: substituido,
      preservado_id: preservado
    });

  } catch (err) {
    return responder({ status: 'error', message: String(err) });
  }
}

/**
 * Abre um arquivo pelo id guardado, ou null se ele nao existe mais.
 */
function abrirArquivo(id) {
  if (!id) return null;
  try {
    var f = DriveApp.getFileById(id);
    return f.isTrashed() ? null : f;
  } catch (err) {
    return null; // apagado de vez
  }
}

/**
 * Procura na pasta um arquivo com exatamente este nome. Rede de seguranca para
 * quando o registro em PropertiesService se perde.
 */
function localizarPeloNome(pasta, nome) {
  try {
    var iter = pasta.getFilesByName(nome);
    if (iter.hasNext()) {
      return iter.next();
    }
  } catch (err) {}
  return null;
}

/**
 * Nome do arquivo superado por um fechamento mais novo. Mantem o original
 * reconhecivel e deixa claro que ele nao e mais o relatorio valido.
 */
function nomeDeArquivado(arquivo) {
  var nome = arquivo.getName();
  // Se ja foi arquivado antes, nao empilha marcas
  if (nome.indexOf('(fechamento anterior') !== -1) {
    return nome;
  }
  var quando = Utilities.formatDate(
    arquivo.getDateCreated(),
    Session.getScriptTimeZone(),
    'dd-MM-yyyy HH:mm'
  );
  var marca = ' (fechamento anterior ' + quando + ')';
  var i = nome.lastIndexOf('.pdf');
  return i === -1 ? nome + marca : nome.substring(0, i) + marca + '.pdf';
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
