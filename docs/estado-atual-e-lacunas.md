# Estado Atual e Lacunas Reais

## Estado atual consolidado

Hoje o projeto ja possui:

- autenticacao por email e Google
- home guiada por check-in
- trilhas com catalogo e jornada privada
- reflexoes e espacos com backend real
- chat HTTP e STOMP
- assinaturas com catalogo, assinatura atual e checkout
- notificacoes in-app com sino e console admin
- IA para insight de check-in, jornada e conversa

## Lacunas ainda reais antes de producao plena

### Externas

- Mercado Pago precisa de credencial valida e webhook publico
- Google Login precisa de validacao final em dominio/origem definitiva

### Produto

- rotina de observabilidade e alertas ainda pode crescer
- politicas de retry e reconciliação de pagamentos ainda podem amadurecer
- governanca de conteudo e moderacao social seguem simples

### UX

- falta validacao humana final em desktop e mobile
- checkout precisa ser exercitado com retorno real do provedor
- chat realtime ainda exige dupla sessao para QA completo

## Mudancas recentes relevantes

- `Feed` virou `Reflexoes`
- `Comunidades` virou `Espacos`
- notificacoes sairam do menu comum e foram para o sino
- assinatura nao usa mais criacao manual de registro
- gate premium passou a depender da assinatura confirmada
