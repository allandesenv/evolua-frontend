# Instruções permanentes do frontend Evolua

Este é o frontend oficial e ativo de produção do Evolua.

## Escopo oficial

- Frontend oficial: `evolua-frontend`.
- Backend oficial consumido: `evolua-api`.
- Ignorar `evolua/`, `services/ai-service/` e qualquer código antigo, legado, duplicado ou experimental.
- Nunca implementar correção contra backend antigo.
- Ao encontrar código legado ou duplicado, apenas informar; não modificar sem autorização explícita.

## Processo obrigatório antes de qualquer alteração

Antes de modificar arquivos:

1. Ler a implementação real.
2. Mapear o fluxo completo da tela até o backend.
3. Localizar widgets, providers, controllers, repositories, DTOs e endpoints.
4. Confirmar a causa com evidência.
5. Separar fatos confirmados, hipóteses e pontos não verificados.
6. Verificar impacto em Android, iOS e Web.
7. Identificar contratos e regras afetados.
8. Propor a menor alteração possível.
9. Definir testes, riscos e rollback.
10. Aguardar aprovação quando a tarefa exigir planejamento prévio.

Nunca corrigir bug apenas escondendo mensagem, reduzindo timeout, adicionando atraso, retry ou invalidações extras.

## Arquitetura

Preservar o fluxo:

- `presentation`: páginas e widgets;
- `application`: controllers, notifiers e providers;
- `domain`: entidades e interfaces;
- `data`: DTOs e repositories;
- `core/network`: Dio, interceptors e parsing;
- backend real no `evolua-api`.

Regras:

- não colocar regra de negócio nova em widget;
- não chamar HTTP direto no widget quando existe repository;
- não duplicar parser;
- não criar provider sem necessidade;
- não criar arquitetura paralela;
- não realizar refatorações paralelas;
- não alterar áreas sem relação com a tarefa.

## Análise de impacto

Antes de modificar provider, controller ou widget, localizar:

- todos os consumidores;
- telas relacionadas;
- ações automáticas e explícitas;
- rebuilds e invalidações;
- retries, timers e listeners;
- lifecycle e navegação;
- deep links;
- cache;
- sessão e troca de usuário;
- endpoint correspondente;
- testes existentes.

Não modificar provider sem verificar quem observa, invalida e mantém sua instância.

## Contratos com o backend

Antes de alterar chamada ou DTO, confirmar no `evolua-api`:

- endpoint e método HTTP;
- autenticação;
- request e response;
- status;
- campos, tipos e valores nulos;
- paginação e ordenação;
- efeitos colaterais.

Regras:

- não inventar endpoint ou campo;
- não inferir contrato pelo nome;
- não consumir endpoint novo antes de ele existir;
- não criar fallback que reintroduza o bug;
- não assumir atualização simultânea de backend e frontend;
- preservar compatibilidade durante transições.

## Configuração e URLs

Antes de alterar chamada HTTP, verificar:

- base URL e serviço correto;
- variável de ambiente e valor padrão;
- ambiente realmente acessado;
- modo de build;
- endpoint final;
- Dio e autenticação utilizados.

Não inserir URL temporária em repository, não trocar base URL para fazer teste passar e não duplicar configuração do `AppConfig`.

## Autenticação e sessão

Antes de modificar autenticação ou sessão, analisar:

- `AuthController`;
- armazenamento seguro;
- `authenticatedDioProvider`;
- refresh e retry;
- proteção contra loop;
- reset e geração de sessão;
- logout e troca de usuário;
- lifecycle e deep link.

Regras:

- não criar timeout arbitrário de sessão no mobile;
- não remover refresh sem análise completa;
- não repetir request indefinidamente;
- callback antigo não pode alterar sessão nova;
- dados do usuário anterior não podem aparecer para o próximo;
- token não deve ir para SharedPreferences;
- não registrar Authorization;
- não transformar 401 ou 403 em acesso local.

Novo estado autenticado deve definir chave por usuário, invalidação no logout e descarte na troca de usuário.

## Riverpod e estado assíncrono

Antes de alterar provider ou notifier, verificar:

- estado inicial, loading, sucesso e erro;
- refresh e invalidação;
- `autoDispose` e `keepAlive`;
- dependências;
- concorrência e resposta fora de ordem;
- `mounted`, `dispose` e troca de sessão.

Regras:

- não executar escrita dentro de `build`;
- não criar loop de `watch`, `invalidate` e `refresh`;
- não invalidar vários providers sem necessidade;
- resposta antiga não pode sobrescrever estado novo;
- `dispose` não garante conclusão de request;
- não usar `Future.delayed` como correção principal;
- loading deve terminar em sucesso, erro, timeout ou cancelamento;
- impedir ações críticas simultâneas duplicadas.

## Cache e dados privados

Antes de adicionar cache, classificar o conteúdo como público, estável, autenticado, específico de usuário, emocional, pessoal ou temporário.

Não armazenar em cache genérico:

- token;
- reflexão ou conteúdo emocional;
- chat;
- dados do Care;
- respostas privadas;
- URL assinada;
- payload sensível.

Cache autenticado deve possuir:

- chave por usuário e contexto;
- TTL e invalidação;
- limpeza no logout;
- versão de schema;
- tamanho máximo;
- tratamento de corrupção.

Não usar cache para esconder requisições duplicadas.

## Monetização e anúncios

Antes de alterar anúncios ou planos, mapear:

1. ação do usuário;
2. reward type;
3. bloco selecionado;
4. modo de teste ou real;
5. criação da reward session;
6. custom data;
7. callback SSV;
8. consulta de acesso;
9. entitlement ou crédito;
10. consumo;
11. Premium e Fundador;
12. loading, erro e timeout.

Regras:

- `onUserEarnedReward` não é autorização final;
- anúncio real depende da confirmação do backend;
- não conceder acesso permanente no cliente;
- não contornar SSV;
- não chamar test grant em modo real;
- não usar fluxo real em modo de teste;
- não alterar IDs de anúncio sem autorização;
- não alterar rewarded, interstitial e assinatura juntos;
- uma ação não pode criar várias reward sessions;
- um anúncio não pode abrir outro automaticamente;
- não duplicar polling;
- usar um único limite de espera;
- toda falha deve terminar em estado visual determinístico;
- não alterar Premium, Fundador, limites ou elegibilidade sem autorização.

Antes de corrigir anúncio, identificar exatamente a etapa que falhou: carregamento, abertura, recompensa local, callback SSV, validação, concessão, entitlement ou atualização da tela.

## Requisições HTTP

Antes de alterar o fluxo, medir:

- quantidade e origem das requests;
- retries e invalidações;
- chamadas no build, navegação e retorno do background;
- timeouts;
- respostas fora de ordem.

Não criar:

- polling ilimitado;
- retry imediato em loop;
- POST duplicado;
- escrita no preview ou rebuild;
- GET adicional desnecessário;
- sequência de invalidações sem medição.

Não esconder erro crítico retornando objeto vazio.

## Interface

Antes de alterar widget ou página, verificar:

- layout compacto e amplo;
- teclado e scroll;
- loading, vazio, erro e sucesso;
- navegação e acessibilidade;
- tema e textos atuais.

Regras:

- não alterar layout, textos, ícones, cores ou espaçamentos sem solicitação;
- não mudar texto para esconder erro técnico;
- ação explícita deve depender de toque;
- abrir tela não pode iniciar jornada, pagamento, anúncio ou criação de dados.

## Compatibilidade multiplataforma

Antes de alterar código compartilhado, verificar Android, iOS e Web.

Solução específica de plataforma deve:

- ficar isolada;
- preservar fallback;
- evitar imports incompatíveis;
- definir comportamento para plataforma não suportada.

## Privacidade e logs

Nunca registrar:

- token, Authorization ou senha;
- reflexão, conteúdo emocional, chat ou dados do Care;
- e-mail completo;
- userId bruto sem necessidade;
- session ID, transaction ID ou custom data completos;
- URL assinada;
- payload completo.

Logs devem conter somente operação, resultado, status HTTP, tipo de erro, plataforma, modo de teste ou real, duração e identificadores mascarados.

## Dependências e plugins

Não adicionar ou atualizar package sem:

- necessidade comprovada;
- análise Android, iOS e Web;
- impacto nativo;
- confirmação de que dependência existente não resolve;
- aprovação explícita.

Não atualizar Flutter, Dart, Riverpod, Dio, GoRouter, AdMob ou plugin nativo em tarefa não relacionada.

## Performance

Antes de otimizar, medir requests, rebuilds, payload, invalidações, timers, memória, controllers, listas e paginação.

Regras:

- não otimizar sem medição;
- não manter página inteira em loading por ação local;
- não reconstruir toda a tela por pequena atualização;
- não criar N requisições para N itens quando houver alternativa;
- não resolver performance apenas com cache.

## Testes definidos antes da implementação

O plano deve indicar:

- teste que reproduz o bug;
- sucesso, erro e loading;
- ação duplicada;
- resposta fora de ordem;
- troca de usuário e logout;
- rebuild, deep link e lifecycle;
- contrato;
- quantidade de requests;
- plataformas aplicáveis.

Usar fake clock ou fake service em vez de espera real longa.

## Plano obrigatório

Antes de implementar, apresentar:

- causa confirmada;
- fluxo atual;
- comportamento desejado;
- fora do escopo;
- arquivos a modificar e apenas analisar;
- estratégia mínima;
- contratos preservados;
- quantidade atual e esperada de requisições;
- tratamento de estado e sessão;
- testes;
- riscos;
- rollback.

Nunca afirmar risco zero.

## Interromper e pedir confirmação

Não implementar automaticamente quando houver:

- causa não confirmada;
- contrato desconhecido ou endpoint indisponível;
- alteração de autenticação ou sessão;
- mudança de monetização, SSV, pagamento ou plano;
- mudança de texto ou regra de produto;
- package novo ou alteração nativa;
- cache de dados privados;
- persistência nova;
- refatoração ampla;
- impacto multiplataforma desconhecido;
- risco de dados cruzarem usuários;
- ausência de testes para fluxo crítico.
