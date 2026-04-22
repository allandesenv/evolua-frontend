# QA Ponta a Ponta

## Escopo

Este roteiro cobre os fluxos principais do produto com backend real:

- login
- home
- reflexoes
- espacos
- trilhas
- check-in e jornada
- perfil
- notificacoes
- assinatura
- chat

## Credenciais seed

- Admin: `clara@evolua.local / 123456`
- Usuario comum: `leo@evolua.local / 123456`

## Ambientes locais

- Frontend: `http://localhost:7359` ou `flutter run -d chrome`
- Gateway: `http://localhost:8080`
- Auth: `http://localhost:8081`
- User: `http://localhost:8082`
- Content: `http://localhost:8083`
- Emotional: `http://localhost:8084`
- Social: `http://localhost:8085`
- Chat: `http://localhost:8086`
- Subscription: `http://localhost:8087`
- Notification: `http://localhost:8088`
- AI: `http://localhost:8089`

## Matriz pagina -> acao -> endpoint

| Pagina | Acao | Endpoint |
| --- | --- | --- |
| Auth | Login | `POST /v1/public/auth/login` |
| Auth | Registro | `POST /v1/public/auth/register` |
| Reflexoes | Listar reflexoes | `GET /v1/posts` |
| Reflexoes | Publicar reflexao | `POST /v1/posts` |
| Espacos | Listar espacos | `GET /v1/communities` |
| Espacos | Criar espaco | `POST /v1/communities` |
| Espacos | Entrar no espaco | `POST /v1/communities/{id}/join` |
| Espacos | Sair do espaco | `POST /v1/communities/{id}/leave` |
| Trilhas | Listar trilhas | `GET /v1/trails` |
| Trilhas | Jornada atual | `GET /v1/trails/journey/current` |
| Trilhas | Criar trilha admin | `POST /v1/trails` |
| Emocional | Listar check-ins | `GET /v1/check-ins` |
| Emocional | Criar check-in | `POST /v1/check-ins` |
| Chat | Listar mensagens | `GET /v1/messages` |
| Chat | Enviar mensagem | `POST /v1/messages` |
| Assinatura | Listar planos | `GET /v1/plans` |
| Assinatura | Assinatura atual | `GET /v1/subscription/current` |
| Assinatura | Iniciar checkout | `POST /v1/billing/checkout` |
| Notificacoes | Inbox | `GET /v1/notifications` |
| Notificacoes | Badge | `GET /v1/notifications/unread-count` |

## Pre-condicoes

1. Backend rodando:

```powershell
docker compose up -d
docker compose ps
```

2. Frontend rodando:

```powershell
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 7359
```

## Roteiro manual recomendado

### 1. Login

- entrar com admin
- validar persistencia de sessao
- logout
- entrar com usuario comum

### 2. Home

- validar header, menu lateral e navegação
- executar check-in curto
- confirmar retorno de insight/jornada

### 3. Reflexoes

- abrir `Reflexoes`
- confirmar ausencia do painel contextual antigo no topo
- publicar reflexao
- filtrar por espaco e visibilidade

### 4. Espacos

- abrir `Espacos`
- confirmar ausencia do painel contextual antigo no topo
- explorar, entrar e sair
- validar criacao apenas quando permitido

### 5. Trilhas

- abrir `Minha jornada`
- abrir `Catalogo`
- validar bloqueio premium para usuario comum
- criar trilha como admin

### 6. Assinatura

- abrir `Planos e assinaturas`
- validar plano atual
- iniciar checkout premium
- validar retorno para `/home` com status de confirmacao

### 7. Notificacoes

- validar badge no sino
- abrir inbox
- marcar notificacao como lida
- como admin, enviar notificacao manual pelo perfil

### 8. Chat

- listar historico
- enviar mensagem
- validar tempo real em segunda sessao se possivel

## Checklist final

- `flutter analyze`
- `flutter test`
- `docker compose ps`
- smoke tecnico dos endpoints principais
- validacao manual final por clique
