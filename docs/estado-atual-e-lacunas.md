# Estado Atual e Lacunas Reais

Mapeamento consolidado do que ja existe no backend e no frontend do Evolua, comparado com a experiencia de produto esperada.

## Visao Geral

Hoje o projeto ja possui:

- backend em microsservicos com autenticacao, perfil, trilhas, check-ins, social, chat, assinatura e notificacoes
- frontend Flutter com autenticacao, dashboard e integracao real com todos os servicos principais
- navegacao principal alinhada com a IA de produto em `Home`, `Trilhas`, `Comunidade`, `Chat` e `Perfil`
- base visual dark consistente e arquitetura organizada por feature

Hoje o projeto ainda nao possui, de forma completa:

- experiencia de produto ponta a ponta em cada modulo
- fluxos secundarios importantes como onboarding, recuperacao de senha e configuracoes detalhadas
- entidades e interacoes sociais mais ricas, como comunidades reais, comentarios e reacoes
- jornadas de trilha com etapas, player, conclusao e retomada
- operacoes de edicao, exclusao, filtros e paginacao no backend
- camadas de descoberta, personalizacao e recomendacao

## Backend Disponivel Hoje

### Gateway

- Existe gateway central na porta `8080`.
- Faz roteamento da API.
- Nao aparece, neste momento, como camada de produto no frontend.

### Auth Service

Endpoints encontrados:

- `POST /v1/public/auth/register`
- `POST /v1/public/auth/login`
- `POST /v1/public/auth/refresh`
- `GET /v1/auth/me`

O que esta pronto:

- cadastro por email e senha
- login
- refresh token
- leitura da sessao atual

Lacunas reais:

- login social com Google e Apple
- recuperacao de senha
- verificacao de email
- onboarding acoplado ao primeiro acesso
- gerenciamento de sessao em multiplos dispositivos

### User Service

Endpoints encontrados:

- `POST /v1/profiles`
- `GET /v1/profiles`

O que esta pronto:

- criacao de perfil
- listagem de perfis do usuario autenticado

Lacunas reais:

- editar perfil
- avatar e foto
- interesses
- preferencias de notificacao
- configuracoes de privacidade
- configuracoes de conta
- um unico perfil canonical em vez de lista generica de perfis

### Content Service

Endpoints encontrados:

- `POST /v1/trails`
- `GET /v1/trails`

O que esta pronto:

- cadastro de trilhas
- listagem basica de trilhas

Lacunas reais:

- detalhe de trilha
- etapas sequenciais
- progresso por trilha
- iniciar, continuar e concluir trilha
- conteudo multimidia
- recomendacao personalizada
- categorias mais estruturadas
- paginacao, filtros e ordenacao no backend

### Emotional Service

Endpoints encontrados:

- `POST /v1/check-ins`
- `GET /v1/check-ins`

O que esta pronto:

- registro de check-in emocional
- listagem de historico

Lacunas reais:

- fluxo de check-in ultra rapido em 1 toque
- campos e escalas mais orientados ao produto
- agrupamento por periodo no backend
- serie temporal pronta para dashboard
- recomendacao automatica pos check-in
- conclusao de pratica conectada ao estado emocional

### Social Service

Endpoints encontrados:

- `POST /v1/posts`
- `GET /v1/posts`

O que esta pronto:

- criacao de post
- listagem de posts do usuario autenticado

Lacunas reais:

- feed por relevancia
- feed global ou por comunidade
- comentarios
- reacoes
- comunidades como entidade propria
- entrar e sair de comunidade
- criacao de grupo
- regras, moderacao e denuncia
- midia em posts
- paginacao, filtros e ordenacao no backend

### Chat Service

Endpoints encontrados:

- `POST /v1/messages`
- `GET /v1/messages`
- `STOMP /app/chat.send`
- `TOPIC /topic/chat/{recipientId}`

O que esta pronto:

- envio de mensagem via REST
- listagem basica de mensagens
- websocket com STOMP para entrega em tempo real

Lacunas reais:

- lista de conversas
- inbox por relacionamento
- grupos
- presenca e status online
- status de envio, entregue e lido no backend
- anexos e midia leve
- bloqueio e seguranca da conversa
- reconexao e retomada mais robustas
- paginacao e filtros no backend

### Subscription Service

Endpoints encontrados:

- `POST /v1/subscriptions`
- `GET /v1/subscriptions`

O que esta pronto:

- registro de assinatura
- listagem de assinaturas

Lacunas reais:

- paywall contextual
- comparacao de planos
- integracao real com pagamento
- renovacao, cancelamento e upgrade
- beneficios por plano no frontend

### Notification Service

Endpoints encontrados:

- `POST /v1/notifications`
- `GET /v1/notifications`

O que esta pronto:

- criacao manual de notificacoes
- listagem basica

Lacunas reais:

- centro de notificacoes do usuario
- marcacao de lido
- notificacoes disparadas por eventos reais
- preferencias granulares
- lembrete diario automatizado
- status de entrega por canal

## Frontend Disponivel Hoje

### Rotas e Estrutura de Navegacao

Rotas reais encontradas:

- `/auth`
- `/home`

Estrutura visivel dentro de `/home`:

- `Home`
- `Trilhas`
- `Comunidade`
- `Chat`
- `Perfil`

O que esta pronto:

- autenticacao e redirecionamento por sessao
- dashboard responsivo com IA coerente com o produto
- composicao de modulos dentro da area logada

Lacunas reais:

- rotas profundas por feature
- detalhe de trilha, detalhe de comunidade e detalhe de conversa
- compartilhamento de links internos
- navegacao por estado e contexto mais refinada

### Auth

O que esta pronto:

- tela de autenticacao responsiva
- fluxo de cadastro e login
- persistencia local de sessao

Lacunas reais:

- login social
- recuperar senha
- onboarding
- primeira configuracao de interesses
- permissao de notificacao no primeiro acesso

### Home

O que esta pronto:

- home hub com CTA principal de check-in
- sugestao do dia em formato placeholder
- atalhos para trilhas, comunidade, chat e perfil
- cards de resumo com contadores
- embed do modulo emocional

Lacunas reais:

- sugestao personalizada de verdade
- resumo diario mais inteligente
- progresso e streak reais
- continuidade contextual da ultima pratica
- insights baseados em historico

### Perfil

O que esta pronto:

- formulario para criar perfil
- listagem de perfis
- composicao com assinatura

Lacunas reais:

- tela de perfil de usuario final
- edicao de dados
- foto, bio rica, interesses e preferencias
- configuracoes e privacidade
- historico consolidado
- conquistas e nivel em linguagem de produto

### Trilhas

O que esta pronto:

- formulario de criacao de trilha
- listagem de trilhas
- filtro e paginação no frontend
- estados vazios guiados

Lacunas reais:

- tela de descoberta orientada ao usuario final
- detalhe da trilha
- jornada sequencial
- player de pratica
- continuar de onde parou
- recomendacao por contexto emocional
- paginacao real no backend

### Emocional

O que esta pronto:

- formulario de check-in
- historico visual inicial
- filtros no frontend
- paginação no frontend
- estado vazio guiado

Lacunas reais:

- experiencia de check-in em 1 toque
- timeline agrupada por periodo
- recomendacao automatica pos check-in
- conclusao de pratica integrada
- dados agregados prontos no backend
- paginacao real no backend

### Comunidade

O que esta pronto:

- modulo social com criacao e listagem de posts
- filtros e paginação no frontend
- composicao do modulo com notificacoes

Lacunas reais:

- separacao clara entre `Feed` e `Comunidades`
- descoberta de comunidades
- criacao de grupo
- entrar em comunidade
- topicos e regras
- comentarios e reacoes
- feed com cara de produto, nao de painel tecnico
- paginacao real e ranking no backend

### Chat

O que esta pronto:

- criacao de mensagem
- listagem basica
- busca e paginação no frontend
- conexao STOMP em tempo real
- indicador de conexao ao vivo

Lacunas reais:

- lista de conversas
- conversa ativa separada da inbox
- status de entrega e leitura
- reconexao mais visivel
- grupos
- inbox mais familiar ao usuario
- paginacao real no backend

### Assinatura

O que esta pronto:

- formulario de criacao de assinatura
- listagem basica

Lacunas reais:

- experiencia de planos e beneficios
- paywall contextual
- CTA de upgrade
- fluxo de compra real

### Notificacoes

O que esta pronto:

- criacao manual de notificacao
- listagem basica

Lacunas reais:

- centro de notificacoes do usuario
- preferencias por tipo de alerta
- marcacao de lido
- automacoes ligadas a eventos do produto

## Integracoes Ja Feitas

- frontend integrado com `auth`, `user`, `content`, `emotional`, `social`, `chat`, `subscription` e `notification`
- uso de Riverpod e Dio por modulo
- sessao persistida no frontend
- chat com STOMP configurado
- CORS ajustado para Flutter Web

## Lacunas Transversais Entre Backend e Frontend

### Dados e API

- listagens ainda retornam listas simples em quase todos os servicos
- falta paginacao real no backend
- faltam filtros de API por busca, categoria, periodo e relevancia
- faltam ordenacoes e metadados de navegacao
- faltam dados iniciais para primeira experiencia mais viva

### Produto

- muitos modulos ainda estao em formato `formulario + lista`
- a experiencia ainda esta mais proxima de um console funcional do que de um app de produto maduro
- faltam jornadas completas para `onboarding`, `pratica`, `comunidade`, `paywall` e `perfil`

### Social e Comunidade

- o backend possui apenas posts
- o frontend exibe social, mas ainda nao ha comunidades reais como entidade
- ainda nao existe resposta funcional para perguntas como `como eu crio um novo grupo?`

### Navegacao

- a IA principal existe, mas as telas ainda nao se desdobram em subfluxos profundos
- o app nao possui paginas dedicadas para detalhe, descoberta, configuracao e conclusao

### UX/UI

- o tema e a IA ja estao alinhados com a documentacao
- ainda faltam skeletons em mais telas, loading mais refinado e estados de sucesso mais claros
- parte do microcopy ainda esta orientada a modulo tecnico e nao a jornada do usuario final

## Diagnostico Objetivo

O estado atual do projeto e:

- `backend funcional por servico`
- `frontend funcional por modulo`
- `produto parcialmente montado`

Em outras palavras:

- ja existe base tecnica suficiente para evoluir com velocidade
- ja existe autenticacao e integracao real entre frontend e backend
- ainda ha distancia importante entre os servicos disponiveis e a experiencia esperada no produto final

## Prioridades Naturais a Partir Deste Mapeamento

1. transformar `formulario + lista` em fluxos de produto por modulo
2. criar entidades e interacoes reais para comunidade e feed
3. implementar paginacao, filtros e ordenacao no backend
4. aprofundar trilhas, emocional e chat como experiencias completas
5. fechar onboarding, perfil e paywall com linguagem de produto
