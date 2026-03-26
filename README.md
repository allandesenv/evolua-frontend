# Evolua Frontend

Frontend Flutter do projeto Evolua com foco em Android, iOS e Web, seguindo a organizacao `Feature-First + Clean Architecture`, Riverpod para gerenciamento de estado e uma base visual dark pronta para crescer junto com o backend.

## Stack

- Flutter 3.38+
- Dart 3.10+
- Riverpod
- GoRouter
- Dio
- Shared Preferences

## Estrutura inicial

```text
lib/
  app/
  core/
  features/
    auth/
    home/
  shared/
  main.dart
```

Esta primeira iteracao ja entrega:

- design system dark com identidade visual propria
- tela de autenticacao responsiva
- integracao real com `auth-service`
- dashboard responsivo para web e mobile
- persistencia local simples da sessao
- modulos funcionais para `user`, `content`, `emotional`, `social`, `chat`, `subscription` e `notification`

## Como rodar

Se o Flutter nao estiver no `PATH`, voce pode usar o caminho absoluto:

```powershell
C:\tools\flutter\bin\flutter.bat pub get
C:\tools\flutter\bin\flutter.bat run -d chrome
```

Se o `PATH` ja estiver configurado:

```powershell
flutter pub get
flutter run -d chrome
```

## Configuracao de backend

Por padrao, o app usa:

- `http://localhost:8081` para autenticacao
- `http://localhost:8082` para user
- `http://localhost:8083` para content
- `http://localhost:8084` para emotional
- `http://localhost:8085` para social
- `http://localhost:8086` para chat
- `http://localhost:8087` para subscription
- `http://localhost:8088` para notification
- `http://localhost:8080` como base geral de API

Voce pode sobrescrever com `dart-define`:

```powershell
flutter run -d chrome `
  --dart-define=EVOLUA_AUTH_BASE_URL=http://localhost:8081 `
  --dart-define=EVOLUA_USER_BASE_URL=http://localhost:8082 `
  --dart-define=EVOLUA_CONTENT_BASE_URL=http://localhost:8083 `
  --dart-define=EVOLUA_EMOTIONAL_BASE_URL=http://localhost:8084 `
  --dart-define=EVOLUA_SOCIAL_BASE_URL=http://localhost:8085 `
  --dart-define=EVOLUA_CHAT_BASE_URL=http://localhost:8086 `
  --dart-define=EVOLUA_SUBSCRIPTION_BASE_URL=http://localhost:8087 `
  --dart-define=EVOLUA_NOTIFICATION_BASE_URL=http://localhost:8088 `
  --dart-define=EVOLUA_API_BASE_URL=http://localhost:8080
```

Para Android Emulator, normalmente use `10.0.2.2` no lugar de `localhost`.

Exemplo:

```powershell
flutter run -d emulator-5554 `
  --dart-define=EVOLUA_AUTH_BASE_URL=http://10.0.2.2:8081 `
  --dart-define=EVOLUA_USER_BASE_URL=http://10.0.2.2:8082 `
  --dart-define=EVOLUA_CONTENT_BASE_URL=http://10.0.2.2:8083 `
  --dart-define=EVOLUA_EMOTIONAL_BASE_URL=http://10.0.2.2:8084 `
  --dart-define=EVOLUA_SOCIAL_BASE_URL=http://10.0.2.2:8085 `
  --dart-define=EVOLUA_CHAT_BASE_URL=http://10.0.2.2:8086 `
  --dart-define=EVOLUA_SUBSCRIPTION_BASE_URL=http://10.0.2.2:8087 `
  --dart-define=EVOLUA_NOTIFICATION_BASE_URL=http://10.0.2.2:8088 `
  --dart-define=EVOLUA_API_BASE_URL=http://10.0.2.2:8080
```

## Fluxo atual

1. Abra a tela de autenticacao.
2. Crie uma conta nova ou entre com um usuario existente.
3. Ao autenticar com sucesso, o app redireciona para o dashboard.
4. Use os modulos para criar perfil, trilhas, check-ins, posts, mensagens, assinaturas e notificacoes.
5. A sessao fica salva localmente.

## Qualidade

Comandos recomendados:

```powershell
flutter analyze
flutter test
```

Se o Flutter nao estiver no `PATH`:

```powershell
C:\tools\flutter\bin\flutter.bat analyze
C:\tools\flutter\bin\flutter.bat test
```

## Proximos passos sugeridos

- conectar `user-service` ao perfil e preferencias
- ligar `content-service` a experiencias multimidia e biblioteca
- implementar diario emocional mais rico com filtros e historico
- integrar chat em tempo real via WebSocket/STOMP
- adicionar cache offline e sincronizacao local
- preparar internacionalizacao e cache offline
