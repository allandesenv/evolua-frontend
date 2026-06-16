# Instruções permanentes do projeto Evolua

Este é um repositório ativo de produção do Evolua.

Repositórios ativos:

* evolua-frontend: aplicativo Flutter usado em produção.
* evolua-api: backend Java/Spring Boot usado em produção.

Repositórios/pastas que devem ser ignorados:

* evolua/
* services/ai-service/
* qualquer backend antigo, legado ou experimental fora de evolua-api.

Regras obrigatórias:

* Nunca implementar alterações no backend antigo.
* Nunca editar arquivos fora de evolua-frontend ou evolua-api sem confirmação explícita.
* Antes de alterar qualquer coisa, identificar se a mudança pertence ao frontend ou ao backend atual.
* Preservar arquitetura, layout e regras atuais do Evolua.
* Não quebrar fluxos já funcionando.
* O backend oficial de produção é sempre evolua-api.
* O frontend oficial de produção é sempre evolua-frontend.
* Se encontrar código duplicado ou legado, apenas avisar; não modificar.
