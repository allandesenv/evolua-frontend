# EVP-01B — Inventário inicial e spike de segurança

Status: WIP; autoridade de desenvolvimento pública e0515de277fdc50168cf40da4a2f7a05f549b1a9, recuperação local PASS, Play upload hash não verificado. PR #167, issue #165. A auditoria da origem encerrou-se; a auditoria funcional e de privacidade ainda não está completa. Nenhuma alteração de runtime nesta etapa.

## Mapa observado na autoridade v43
| Feature/adaptador | Família de contrato atual | Destino pretendido |
|---|---|---|
| AuthRepositoryImpl / AuthController | /v1/public/auth, sessão e Google exchange | Identity; preservar Google, separar desbloqueio local da autenticação remota |
| ProfileRepositoryImpl | /v1/profiles/me, avatar | Private; alias/avatar social explicitamente escolhido |
| CheckInRepositoryImpl | /v1/check-ins, leitura, ritual | Private; persistência e inteligência local |
| TrailRepositoryImpl | /v1/trails, jornadas, respostas, vídeo | Catálogo público e progresso privado separados |
| JourneyChatRepositoryImpl | /v1/ai/journey-chat | Private; motor local, sem fallback remoto |
| DailyRitualRepositoryImpl | /v1/daily-rituals | Private |
| FutureMessageRepositoryImpl | /v1/future-messages | Private; entrega local |
| NotificationRepositoryImpl | /v1/notifications e admin | lembretes privados locais, social opcional |
| CommunityRepositoryImpl / SocialPostRepositoryImpl | /v1/communities, /v1/posts | Connect, conteúdo explicitamente publicado |
| ChatMessageRepositoryImpl | /v1/messages | Connect, transição a definir |
| CareRepositoryImpl / StompCareRealtimeService | /v1/care, /ws/care | Care seletivo, transporte explícito e destinatário verificado |
| SubscriptionRepositoryImpl | planos, checkout, Google verify, reward session, access | Comercial isolado; preservar direitos e verificação |
| AppVersionStatusController | /v1/app/version-status | Atualização independente do núcleo privado |

Observações verificadas: AppStartupController aquece check-ins e trilha corrente após primeiro frame de sessão; desacoplar warmup remoto antes de declarar funcionamento offline. authenticatedDioProvider é ponto relevante de instrumentação e sessão, não substitui análise de outros SDKs. Existem cache estável e armazenamento de sessão; revisar classificação, falhas e migração antes de reutilizar. Google OAuth hoje usa redirect e troca de código. Care usa STOMP e biblioteca cryptography existente. Ditado usa speech_to_text: disponibilidade de reconhecimento local não demonstrada; não ativar ditado privado na arquitetura nova sem prova de processamento local/consentimento separado. Vídeo externo, ads, updates e SDKs precisam inventário de tráfego e permissões independente; sem envio de conteúdo privado. Inventário estático das 13 implementações de repositório e pontos adicionais consultados; não é captura de rede nem confirmação do deploy API.

## Threat model inicial (a validar)
| Risco | Controle/gate |
|---|---|
| Perda/roubo do dispositivo | banco cifrado, proteção de chave pelo SO, bloqueio e credencial de recuperação independente |
| Troca de perfil ou sessão | chave e namespace por perfil, descarte de estado e operações antigas; testes de isolamento |
| Alteração/restauração incorreta | autenticação dos dados, schema versionado, transação, backup verificado, sem sobrescrita silenciosa |
| Vazamento em SDK, cache, log, backup SO, arquivo temporário | negar transferência privada por padrão, revisar cada fronteira, testes de rede e armazenamento |
| Conta Google revogada ou offline | acesso local independente; serviços sociais falham isoladamente |
| Publicação acidental ou abuso | cópia independente, prévia/consentimento, autorização e moderação |
| Dispositivo comprometido/desbloqueado | limites explícitos; não prometer proteção absoluta |
| Migração e compras | verificação de integridade, autorização, rollback e preservação de benefícios |

## Spike EVP-01B-S1
Prova pequena e exclusivamente em test/evp: usar AES-256-GCM da dependência cryptography já fixada, nova nonce por operação, AAD estruturado para vincular perfil/registro/versão, chave aleatória efêmera. Dados sintéticos. Verificar round trip, nonce, contexto diferente, chave errada e adulteração. Não implementar formato de backup, banco, autenticação ou integração; a prova não é criptografia de produção. Não adicionar dependências. Nenhum acesso HTTP, Firebase ou dado real. A seguir escolher spike de banco SQLCipher e gerenciamento de chaves com revisão de compatibilidade e benchmark em aparelho. A aprovação deste teste não substitui análise de segurança ou testes físicos.

## Baseline e gates pendentes
Medir v43 e futuro candidato em profile/release em aparelho físico com dados sintéticos; startup frio/quente, unlock, p50/p95 de gravação e consulta 10k registros, frames, memória e rede; não utilizar ambiente real para criar registros. Alvo inicial proposto conforme ADR. Planejar medição antes de otimizar. Confirmar dependências nativas e variantes Android/iOS/Web, contrato de exportação/migração, backend ativo, OAuth e fluxos comerciais. Nenhum novo teste foi executado nesta publicação; receipts do S1 são aguardados. RELEASE=NO_GO; BACKEND_SHUTDOWN=NO_GO.
