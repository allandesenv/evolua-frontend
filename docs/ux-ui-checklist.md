# Checklist Pratico de UX/UI

Baseado na documentacao oficial de UX/UI do Evolua.

## Objetivo do Produto

- Entregar uma experiencia diaria simples, acolhedora e eficaz.
- Ajudar o usuario a regular o estado emocional com poucos passos.
- Tornar o progresso visivel e facil de perceber.
- Estimular consistencia por meio de microvitorias.
- Oferecer suporte social seguro, com privacidade por padrao.

## Principios Norteadores

- `Clareza > complexidade`
- `Ação rápida`: cada fluxo importante deve caber em `1 a 3 toques`.
- `Personalizacao por estado emocional`
- `Progressao visivel`
- `Comunidade segura`
- `Privacidade por padrao`

## Checklist de Produto

- Cada tela deve ter um objetivo principal claro.
- O usuario deve entender o valor do app em menos de 1 minuto.
- O fluxo principal deve levar o usuario a uma pratica no primeiro dia.
- O core loop deve caber em `3 a 8 minutos`.
- Cada etapa do core loop deve ter no maximo 1 decisao principal.
- O produto deve transmitir acolhimento, nao julgamento.
- O app deve mostrar progresso perceptivel ao longo do uso.
- O usuario deve sentir controle sobre compartilhamento, privacidade e notificacoes.

## Checklist de Navegacao

- A IA global deve permanecer em `Home`, `Trilhas`, `Comunidade`, `Chat` e `Perfil`.
- A navegacao deve evitar nomes tecnicos de servicos.
- As acoes principais devem estar acessiveis em poucos toques.
- O estado da aba ativa deve estar sempre claro.
- O retorno entre lista, detalhe e acao deve ser simples.
- A navegacao deve funcionar bem em mobile first e desktop responsivo.
- A Home deve servir como ponto de retomada diario.

## Checklist do Core Loop

- `Home`: saudacao, CTA de check-in, sugestao do dia, acessos rapidos, mini progresso.
- `Check-in`: interacao rapida com escala, emoji ou tags.
- `Sugestao personalizada`: uma recomendacao clara por vez.
- `Pratica guiada`: experiencia objetiva com tempo e CTA de conclusao.
- `Conclusao`: feedback simples sobre como o usuario se sentiu.
- `Registro de progresso`: reforco visual da evolucao.
- `Reforco social opcional`: compartilhar ou consumir feed sem obrigatoriedade.

## Checklist por Area

### Home

- Exibir saudacao contextual.
- Destacar botao de check-in como CTA principal.
- Mostrar `Sugestao do dia`.
- Trazer acesso rapido a trilhas.
- Exibir mini progresso, streak ou resumo recente.
- Evitar sobrecarga de informacao.

### Trilhas

- Mostrar lista clara de trilhas.
- Exibir beneficios e duracao no detalhe.
- Permitir iniciar e continuar com clareza.
- Mostrar estado da jornada: nova, em andamento, concluida.
- Reforcar progresso e conquista ao concluir.

### Comunidade

- Separar exploracao de comunidades e feed.
- Mostrar busca, topicos, participantes e regras.
- Facilitar entrada em comunidades relevantes.
- Tornar postagem, comentarios e reacoes simples e seguras.
- Incluir moderacao e denuncia de forma acessivel.

### Chat

- Suportar conversas `1:1` e grupos.
- Exibir presenca ou conexao quando aplicavel.
- Tornar status de envio e reconexao compreensiveis.
- Dar acesso facil a seguranca, bloqueio e controle da conversa.

### Perfil

- Exibir foto, bio e configuracoes principais.
- Mostrar historico, nivel, conquistas e progresso.
- Centralizar privacidade, notificacoes e preferencias.

## Checklist de Componentes

- Usar paleta com `verde` como cor primaria e `azul` como secundaria.
- Manter neutros consistentes para fundos, cards e texto.
- Garantir estados de `sucesso`, `atencao` e `erro`.
- Seguir tipografia sans-serif moderna com hierarquia clara.
- Manter grid de `8pt` para espacos e alinhamentos.
- Padronizar `botoes`, `cards`, `inputs`, `chips` e `badges`.
- Garantir contraste adequado para modo escuro.
- Garantir area de toque minima de `48dp`.

## Checklist de Microcopy

- Usar frases curtas e diretas.
- Priorizar verbos de acao.
- Manter tom acolhedor e nao julgador.
- Evitar jargoes tecnicos ou espirituais.
- Reforcar microvitorias e progresso.
- Escrever mensagens de erro que orientem a proxima acao.
- Evitar textos que gerem culpa ou pressao.

## Checklist de Estados de Tela

- Toda tela deve ter `loading`, `vazio`, `erro` e `sucesso` bem definidos.
- `Loading` deve usar `skeleton` quando houver listas ou cards.
- Estados vazios devem orientar o que fazer em seguida.
- Estados de erro devem oferecer recuperacao clara.
- O status do sistema deve estar sempre visivel.
- Transicoes devem ser suaves, em torno de `200 a 300ms`.

## Checklist de Acessibilidade

- Garantir contraste seguindo WCAG.
- Garantir labels adequadas para leitores de tela.
- Nao comunicar estados apenas por cor.
- Manter leitura facil em tamanhos pequenos.
- Preservar usabilidade completa em modo escuro.

## Checklist de Conteudo e Confianca

- Privacidade deve ser padrao, nao opcional escondida.
- Controles de visibilidade devem ser claros.
- Moderacao e denuncia devem ser faceis de encontrar.
- Notificacoes devem ter controle granular.
- O usuario deve sentir seguranca ao compartilhar.

## Checklist de Performance e Mobile

- Priorizar mobile first.
- Otimizar fluxos de uso com uma mao.
- Manter performance leve.
- Preparar offline basico para diario quando possivel.

## Heuristicas para Revisao de Tela

- O usuario entende rapidamente o que fazer?
- A proxima acao principal esta evidente?
- Existe alguma decisao desnecessaria?
- O estado atual do sistema esta claro?
- A tela respeita consistencia com o restante do app?
- O texto ajuda sem soar tecnico?
- Ha risco de sobrecarga cognitiva?

## Criterios de Sucesso UX

- Usuario entende o app em menos de 1 minuto.
- Realiza a primeira pratica no primeiro dia.
- Retorna no dia seguinte.
- Percebe progresso ao longo do uso.
- Sente acolhimento, clareza e seguranca.

## Regra de Implementacao para Dev

- UX deve prevalecer sobre complexidade tecnica.
- Cada tela deve ter 1 objetivo principal.
- Sempre reduzir carga cognitiva antes de adicionar funcionalidade.
- Validar fluxos com testes e revisoes frequentes.
- Iterar rapido mantendo consistencia visual e textual.
