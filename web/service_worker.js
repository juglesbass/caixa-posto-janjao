'use strict';

// Service worker de cache offline do Caixa Posto Janjão.
//
// Por que existe: o Flutter descontinuou o dele. No 3.47 o template virou um
// worker que se desregistra sozinho, e `--pwa-strategy=offline-first` entrega
// justamente esse — a flag ficou, a implementação foi esvaziada. Sem isto o PWA
// publicado não guarda nada: cada abertura pode rebaixar 1,4 MB de main.dart.js
// mais 2,3 MB de CanvasKit, com Cache-Control de 10 minutos no GitHub Pages. Era
// isso a demora de abertura no iPhone mais fraco, e voltava toda vez que o
// Safari limpava o cache. Pior: um caixa offline-first por dentro não abria sem
// internet.
//
// O CI substitui `build/web/flutter_service_worker.js` por este arquivo e troca
// __VERSAO_BUILD__ pelo SHA do commit. É o Flutter que registra esse caminho, o
// que mantém um único worker no escopo — dois registros brigando pelo mesmo
// escopo seria pior que não ter nenhum.
//
// SAÍDA DE EMERGÊNCIA: se este worker causar problema, basta remover do
// workflow o passo que sobrescreve o arquivo. O Flutter volta a gerar o worker
// que se desregistra, e todo cliente instalado se limpa sozinho na abertura
// seguinte. Não é preciso mexer em nada no aparelho de ninguém.

const VERSAO = '__VERSAO_BUILD__';
const CACHE = 'caixa-janjao-' + VERSAO;

// Só o suficiente para a tela aparecer. O resto entra sozinho conforme o app
// pede — o que cobre CanvasKit, sqlite3.wasm e os pedaços diferidos do PDF sem
// manter lista de arquivos em lugar nenhum, que é exatamente o tipo de lista que
// sai de sincronia e publica um app quebrado.
const NUCLEO = ['./', 'index.html', 'flutter_bootstrap.js', 'manifest.json'];

// Toda navegação é guardada e lida sob esta chave. O endereço de abertura do
// PWA nem sempre é idêntico ao da aba do navegador, e usar a própria requisição
// como chave fazia uma não encontrar o que a outra tinha guardado.
const CHAVE_PAGINA = 'index.html';

self.addEventListener('install', (event) => {
  event.waitUntil((async () => {
    try {
      const cache = await caches.open(CACHE);
      await cache.addAll(NUCLEO);
    } catch (e) {
      // Rede ruim durante a instalação não pode abortar o worker: o que faltou
      // entra no cache na primeira vez que o app pedir.
      console.warn('[SW] núcleo não pré-carregado:', e);
    }
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    // Apagar as versões anteriores é o que faz um deploy novo valer de fato:
    // main.dart.js não tem hash no nome, então sem esta limpeza o pacote velho
    // seria servido para sempre.
    const nomes = await caches.keys();
    await Promise.all(
      nomes.filter((n) => n !== CACHE).map((n) => caches.delete(n)),
    );
    await self.clients.claim();
  })());
});

// Guarda no cache só o que é seguro guardar. `resp.ok` aceita 206 (resposta
// parcial), e gravar 206 no Cache API lança exceção — por isso a comparação é
// com 200 exato. `type === 'basic'` descarta resposta opaca de outra origem.
async function guardar(req, resp) {
  if (!resp || resp.status !== 200 || resp.type !== 'basic') return;
  try {
    const cache = await caches.open(CACHE);
    await cache.put(req, resp.clone());
  } catch (e) {
    console.warn('[SW] não guardou', req.url, e);
  }
}

self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  let url;
  try {
    url = new URL(req.url);
  } catch (e) {
    return;
  }
  // Outra origem passa direto. O webhook do Drive e o Firestore nunca podem ser
  // servidos de cache: resposta velha de sincronização é pior que erro de rede.
  if (url.origin !== self.location.origin) return;

  // Navegação: responde do cache na hora e busca a versão nova por trás.
  //
  // Antes ia na rede primeiro. O efeito era que toda abertura do app esperava
  // uma ida à rede antes de desenhar qualquer coisa — e num iPhone que acabou de
  // acordar isso inclui DNS e handshake, com o app parado. Ficava lento mesmo
  // com tudo em cache. Confirmado no teste: em modo avião, que pula a rede
  // inteira, o app abre na hora.
  //
  // A troca custa uma coisa: um deploy novo passa a aparecer na abertura
  // SEGUINTE, não na primeira. Isso é aceitável porque o app é aberto muitas
  // vezes por dia e publicado de vez em quando — e porque a atualização não
  // depende disto para chegar. Quem manda é o próprio arquivo do worker: o
  // navegador o reverifica a cada navegação, e como o SHA do commit está dentro
  // dele, versão nova instala, o activate apaga o cache antigo e a abertura
  // seguinte pega tudo novo.
  if (req.mode === 'navigate') {
    event.respondWith((async () => {
      const cache = await caches.open(CACHE);
      const guardado = await cache.match(CHAVE_PAGINA);

      // A busca de atualização roda em paralelo e nunca segura a resposta.
      const rede = fetch(req)
        .then(async (resp) => {
          if (resp && resp.status === 200 && resp.type === 'basic') {
            try {
              await cache.put(CHAVE_PAGINA, resp.clone());
            } catch (e) {
              console.warn('[SW] não atualizou a página:', e);
            }
          }
          return resp;
        })
        .catch(() => null);

      if (guardado) {
        // waitUntil mantém o worker vivo até a atualização terminar.
        event.waitUntil(rede);
        return guardado;
      }

      const resp = await rede;
      return resp || Response.error();
    })());
    return;
  }

  // Demais recursos: cache primeiro. "Primeiro" não significa "velho", porque o
  // cache é versionado por build e o activate apaga os anteriores.
  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    const guardado = await cache.match(req);
    if (guardado) return guardado;
    const resp = await fetch(req);
    await guardar(req, resp);
    return resp;
  })());
});
