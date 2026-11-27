# EVP — Continuidade e execução GitHub-first
Status: instrução explícita do mantenedor, 27/11/2026. Issue #165; Draft #166. Complementa EVP-01_PRIVATE_CORE e AGENTS.md.

## Contrato de trabalho
- Todo código, testes, documentação, correções, scripts e decisões produzidos pelo assistente são editados diretamente no GitHub, na branch de trabalho autorizada. Não transferir edição manual de código ao mantenedor. Sem Codex.
- Usar o ambiente Windows do mantenedor somente para operações que dependem de arquivos locais ainda não publicados, sincronização, toolchain Flutter/Android, dispositivos físicos, credenciais locais ou ações exclusivamente humanas. Nunca pedir que compartilhe credenciais.
- Cada execução necessária deve ser entregue em uma única linha PowerShell que obtém o executor versionado diretamente do GitHub (fetch explícito e git show do SHA completo), verifica falhas de fetch/leitura e executa o conteúdo fixado. Não usar referência móvel como autoridade de execução. Não usar scripts improvisados de edição local quando a alteração pode ser feita no GitHub.
- Exceção de recuperação: arquivos históricos exclusivos da máquina do mantenedor devem ser preservados/validados por executor local. O relatório privado e seu commit exato não podem ser enviados ao remoto público, nem por ancestralidade. O executor já publicado em 11e0bb3af2af5f3fe2f41ff5fa9f25d88cb8ba11 realiza a recuperação pública sanitizada e cria as duas branches. Ainda aguarda execução. Não repetir etapas já comprovadas.
- Uma WIP principal; ler issue/PR/HEAD, AGENTS e evidência anterior antes de alterar. Publicar atomicamente quando possível; verificar o diff e o SHA remoto. Manter Draft PR sem merge automático. Nenhuma mudança de produção, custo, credencial, dados reais ou serviço sem GO específico.

## Kernel enxuto (contrato para futuros executores, ainda não implementado como módulo comum)
- Adaptar conceitos úteis do Grovewake/Ofensiva à toolchain Flutter, não transplantar harness Unity. Preferir comandos convencionais, flutter analyze/test/build e diagnósticos nativos.
- Preflight: identidade do repo e remoto, branch/HEAD, worktree limpa quando exigida, ferramentas, espaço e pré-condições da etapa. Verificar SHA/ancestralidade e allowlist, sincronizar por fast-forward somente quando seguro. Proibir reset/clean/stash/force-push, não sobrescrever mudanças locais.
- Planejar execução em uma passagem: agrupar verificações independentes e testes afetados, evitar builds se o escopo é documental, não executar operações de rede/ads/pagamentos reais indevidamente.
- Receipts: etapa, HEAD antes/depois, executor SHA, escopo, entradas, comando/toolchain, resultados, logs sanitizados, códigos de saída e VERDICT. Falha deve imprimir ETAPA, ERRO, LINHA quando aplicável, EXITCODE quando disponível e NEXT; preservar evidência. Não afirmar PASS sem execução. Não reexecutar cegamente.
- Reutilização GREEN exige mesma autoridade relevante, dependências/configuração e ambiente compatíveis e ausência de alteração que invalide o resultado. Testes históricos da recuperação v43 não são testes da nova arquitetura. Executar regressão integral quando o risco ou release exigir.
- Melhoria contínua: registrar falha operacional, causa comprovada, correção mínima, teste/guard permanente e impacto; separar falha de produto de falha de ambiente; não esconder falhas. Consolidar evidências sem dados pessoais/segredos em GitHub público.
- Cada entrega informa arquivos/commits, verificações reais, pendências, bloqueios e próximo comando quando necessário. Nenhum novo chat depende de memória implícita: manter handoff versionado/issue e PR atualizados.

## Estado inicial
EVP-01A: local recovery PASS, public content review complete. Remote release/production-v43-billing8-public and feat/evp-private-core not yet present at verification. Executor public baseline pending local execution; only after receipt and remote SHA verification start implementation Draft PR targeting recovered public authority. Production and backend unchanged.
