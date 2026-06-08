# Controle De Atualização Android

Fluxo recomendado para usar atualização recomendada ou obrigatória no Evolua:

1. Publique primeiro um backend compatível com `GET /v1/app/version-status`.
2. Gere o AAB com um `versionCode` maior que o último publicado.
3. Envie o AAB para teste interno na Google Play.
4. Valide em aparelho real, instalado pela Play Store, pois In-App Updates não funciona de forma confiável em APK/debug local.
5. Use staged rollout quando a versão trouxer mudança grande.
6. Atualize `APP_VERSION_ANDROID_LATEST_CODE` para recomendar a versão nova.
7. Aumente `APP_VERSION_ANDROID_MINIMUM_SUPPORTED_CODE` apenas para segurança, bug crítico ou incompatibilidade real.
8. Use `APP_VERSION_ANDROID_UPDATE_MODE=immediate` com moderação; para rotina normal prefira `flexible`.

Defaults seguros:

- `APP_VERSION_ANDROID_MINIMUM_SUPPORTED_CODE=0`
- `APP_VERSION_ANDROID_LATEST_CODE=0`
- `APP_VERSION_ANDROID_UPDATE_MODE=none`

Fallback:

- Se In-App Update falhar, o app abre a página da Google Play.
- Se o endpoint falhar, o app continua, exceto quando houver cache obrigatório recente de até 24h para a mesma plataforma, versão e backend.
