# Evolua Frontend

Frontend Flutter Web/Mobile do Evolua com Riverpod, GoRouter, Dio e interface focada em Home, Trilhas, Reflexoes, Espacos, Perfil, notificacoes no sino e jornada guiada por IA.

## Stack

- Flutter 3.38+
- Dart 3.10+
- Riverpod
- GoRouter
- Dio
- Shared Preferences
- url_launcher
- image_picker

## Como rodar

```powershell
flutter pub get
flutter run -d chrome
```

Alternativa mais estavel para web local:

```powershell
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 7359
```

## Backends padrao

- `EVOLUA_API_BASE_URL=http://localhost:8080`
- `EVOLUA_AUTH_BASE_URL=http://localhost:8081`
- `EVOLUA_USER_BASE_URL=http://localhost:8082`
- `EVOLUA_CONTENT_BASE_URL=http://localhost:8083`
- `EVOLUA_EMOTIONAL_BASE_URL=http://localhost:8084`
- `EVOLUA_SOCIAL_BASE_URL=http://localhost:8085`
- `EVOLUA_CHAT_BASE_URL=http://localhost:8086`
- `EVOLUA_SUBSCRIPTION_BASE_URL=http://localhost:8087`
- `EVOLUA_NOTIFICATION_BASE_URL=http://localhost:8088`
- `EVOLUA_AI_BASE_URL=http://localhost:8089`

Exemplo com `dart-define`:

```powershell
flutter run -d chrome `
  --dart-define=EVOLUA_API_BASE_URL=http://localhost:8080 `
  --dart-define=EVOLUA_AUTH_BASE_URL=http://localhost:8081 `
  --dart-define=EVOLUA_USER_BASE_URL=http://localhost:8082 `
  --dart-define=EVOLUA_CONTENT_BASE_URL=http://localhost:8083 `
  --dart-define=EVOLUA_EMOTIONAL_BASE_URL=http://localhost:8084 `
  --dart-define=EVOLUA_SOCIAL_BASE_URL=http://localhost:8085 `
  --dart-define=EVOLUA_CHAT_BASE_URL=http://localhost:8086 `
  --dart-define=EVOLUA_SUBSCRIPTION_BASE_URL=http://localhost:8087 `
  --dart-define=EVOLUA_NOTIFICATION_BASE_URL=http://localhost:8088 `
  --dart-define=EVOLUA_AI_BASE_URL=http://localhost:8089
```

## Fluxos principais

- autenticacao por email e Google
- cadastro local com nome, data de nascimento e genero
- Home com check-in e jornada
- Trilhas com `Minha jornada` e catalogo
- Reflexoes com composer e listagem real
- Espacos com explorar, meus espacos, entrar, sair e criar quando permitido
- Perfil com dados pessoais, avatar, assinatura e console admin de notificacoes
- Sino de notificacoes com inbox in-app

## Cadastro e perfil

Fluxo atual:

1. `Criar conta` coleta `Nome`, `Data de nascimento`, `Genero`, `Email` e `Senha`
2. o `auth-service` cria a conta com `displayName`
3. o app autentica o usuario
4. o frontend faz bootstrap automatico do perfil em `PUT /v1/profiles/me`
5. o cabecalho usa avatar e nome do perfil, com fallback para a sessao

O menu do avatar abre:

- `Ver perfil`
- `Configuracoes e privacidade`
- `Ajuda e suporte`
- `Tela e acessibilidade`
- `Dar feedback`
- `Sair`

## Assinaturas

O frontend nao ativa mais premium por formulario manual.

Fluxo atual:

1. listar planos
2. consultar assinatura atual
3. iniciar checkout com `POST /v1/billing/checkout`
4. voltar para `/home` com `billingCheckoutId`
5. acompanhar status ate confirmacao

## Qualidade

```powershell
flutter analyze
flutter test
```

## Documentos complementares

- [qa-fluxos-principais.md](./docs/qa-fluxos-principais.md)
- [estado-atual-e-lacunas.md](./docs/estado-atual-e-lacunas.md)
- [ux-ui-checklist.md](./docs/ux-ui-checklist.md)
