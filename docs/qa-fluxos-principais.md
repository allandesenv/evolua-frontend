# QA Ponta a Ponta

## Escopo
Este roteiro valida os fluxos principais do Evolua com frontend e backend reais:

- login
- feed
- comunidades
- criacao de grupo
- trilhas
- check-in emocional
- chat em tempo real

Tambem inclui um sanity check rapido para `profile`, `subscription` e `notification`, para evitar telas com layout desacoplado do backend.

## Credenciais seed
- Admin: `clara@evolua.local / 123456`
- Usuario gratuito: `leo@evolua.local / 123456`

## Ambientes padrao
- Auth: `http://localhost:8081`
- User: `http://localhost:8082`
- Content: `http://localhost:8083`
- Emotional: `http://localhost:8084`
- Social: `http://localhost:8085`
- Chat: `http://localhost:8086`
- Subscription: `http://localhost:8087`
- Notification: `http://localhost:8088`
- Frontend web-server: `http://localhost:7359`

## Matriz pagina -> acao -> endpoint
| Pagina | Acao | Endpoint |
| --- | --- | --- |
| Auth | Login | `POST /v1/public/auth/login` |
| Auth | Registro | `POST /v1/public/auth/register` |
| Social > Feed | Listar posts | `GET /v1/posts` |
| Social > Feed | Criar post | `POST /v1/posts` |
| Social > Comunidades | Listar comunidades | `GET /v1/communities` |
| Social > Comunidades | Criar comunidade | `POST /v1/communities` |
| Social > Comunidades | Entrar em comunidade | `POST /v1/communities/{id}/join` |
| Social > Comunidades | Sair de comunidade | `POST /v1/communities/{id}/leave` |
| Trilhas | Listar trilhas | `GET /v1/trails` |
| Trilhas | Criar trilha admin | `POST /v1/trails` |
| Emocional | Listar check-ins | `GET /v1/check-ins` |
| Emocional | Criar check-in | `POST /v1/check-ins` |
| Chat | Listar mensagens | `GET /v1/messages` |
| Chat | Enviar mensagem | `POST /v1/messages` |
| Chat | Tempo real | `ws://localhost:8086/ws/chat` + `/app/chat.send` + `/topic/chat/{userId}` |
| Perfil | Listar perfis | `GET /v1/profiles` |
| Assinatura | Listar assinaturas | `GET /v1/subscriptions` |
| Notificacoes | Listar notificacoes | `GET /v1/notifications` |

## Pre-condicoes
1. Subir o backend:

```powershell
docker compose up -d
```

2. Subir o frontend:

```powershell
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 7359
```

3. Abrir o frontend em `http://localhost:7359`.

## Roteiro manual recomendado

### 1. Login
1. Abrir `http://localhost:7359`.
2. Confirmar que o primeiro acesso cai em `/auth`.
3. Entrar com `clara@evolua.local / 123456`.
4. Recarregar a pagina e confirmar persistencia da sessao.
5. Fazer logout e confirmar retorno para `/auth`.
6. Entrar com `leo@evolua.local / 123456`.

Resultado esperado:
- sessao persiste quando valida
- logout limpa a sessao
- usuario sem sessao nao cai direto na home

### 2. Feed
1. Entrar no modulo `Comunidade`.
2. Acessar a aba `Feed`.
3. Confirmar carregamento dos posts seed.
4. Aplicar filtro por comunidade.
5. Aplicar paginacao.
6. Criar um novo post em uma comunidade existente.

Resultado esperado:
- feed carrega dados reais
- filtros e pagina trocam sem quebrar estado
- post novo aparece apos refresh do estado

### 3. Comunidades
1. Ir para a aba `Comunidades`.
2. Confirmar listagem inicial.
3. Usar busca por nome/categoria.
4. Entrar em uma comunidade.
5. Sair da mesma comunidade.

Resultado esperado:
- estado `joined` muda imediatamente
- busca funciona com backend real
- lista continua consistente apos join/leave

### 4. Criacao de grupo
1. Ainda em `Comunidades`, abrir o fluxo de criacao.
2. Preencher nome, descricao, visibilidade e categoria.
3. Salvar.
4. Confirmar que a comunidade aparece na lista.
5. Confirmar que ela aparece no seletor de comunidade do composer de post.

Resultado esperado:
- validacao do formulario funciona
- grupo criado reaparece sem depender de novo login
- grupo novo pode receber post logo em seguida

### 5. Trilhas
1. Logar como admin `clara@evolua.local`.
2. Acessar `Trilhas`.
3. Criar uma trilha premium com resumo, conteudo markdown e link de video.
4. Confirmar que a trilha aparece na listagem do admin.
5. Fazer logout e entrar com `leo@evolua.local`.
6. Abrir `Trilhas` e localizar a trilha premium criada.

Resultado esperado:
- admin consegue criar
- usuario gratuito ve a trilha, mas com `accessible = false`
- conteudo completo e links ficam bloqueados para usuario gratuito

### 6. Check-in emocional
1. Acessar `Home` ou `Emocional`.
2. Criar um novo check-in.
3. Confirmar que ele aparece no historico.
4. Aplicar filtros por humor, energia e periodo.
5. Trocar de pagina e confirmar persistencia dos filtros.

Resultado esperado:
- novo check-in entra na timeline
- filtros batem com o backend
- paginacao permanece funcional

### 7. Chat em tempo real
1. Abrir o modulo `Chat`.
2. Confirmar carregamento do historico.
3. Selecionar uma conversa seed.
4. Enviar uma nova mensagem.
5. Em uma segunda sessao do frontend, entrar com o destinatario e abrir o chat correspondente.
6. Confirmar recebimento em tempo real.
7. Desconectar/reconectar e validar o indicador visual de conexao.

Resultado esperado:
- historico carrega do backend
- envio REST funciona
- mensagem chega em tempo real via STOMP/WebSocket
- estado de reconexao fica visivel quando a conexao oscila

## Sanity check complementar
Executar rapidamente apos os fluxos principais:

- Perfil: listagem/carregamento real
- Assinatura: listagem/carregamento real
- Notificacoes: listagem/carregamento real

Resultado esperado:
- nenhuma dessas telas depende apenas de layout

## Resultado do smoke tecnico de 2026-03-30
Fluxos validados com chamadas reais no backend local:

- `POST /v1/public/auth/login`
- `POST /v1/communities`
- `GET /v1/communities`
- `POST /v1/communities/{id}/join`
- `POST /v1/communities/{id}/leave`
- `POST /v1/posts`
- `GET /v1/posts`
- `POST /v1/trails`
- `GET /v1/trails`
- `POST /v1/check-ins`
- `GET /v1/check-ins`
- `POST /v1/messages`
- `GET /v1/messages`
- `GET /v1/profiles`
- `GET /v1/subscriptions`
- `GET /v1/notifications`

Observacoes confirmadas no smoke:
- criacao admin de trilha estava quebrando por compatibilidade com a coluna legada `description`; corrigido no `content-service`
- trilha premium criada por admin ficou `accessible = false` para o usuario gratuito, com `content = null`
- fluxo HTTP do chat esta funcional
- o smoke automatizado do WebSocket puro a partir do terminal local nao foi conclusivo nesta rodada; a validacao final do tempo real deve ser feita pelo roteiro manual em duas sessoes do frontend

## Checklist de encerramento
- `flutter analyze`
- `flutter test`
- `docker compose ps`
- executar o roteiro manual completo acima
