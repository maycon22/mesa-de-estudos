# Assistente de estudos: arquitetura da IA

## Visão geral

```
Navegador (index.html)                      Supabase                          Anthropic
┌──────────────────────────────┐   login   ┌──────────────────────────┐  chave   ┌───────────┐
│ 1. Motor local (sem IA)      │ ────────▶ │ Edge Function            │ ───────▶ │ API Claude│
│    horas, revisões, tópicos, │   (JWT)   │ "assistente"             │          └───────────┘
│    desempenho, prioridades   │           │ - confere o login        │
│ 2. Resumo autorizado         │           │ - valida a tarefa        │
│    (só categorias marcadas)  │           │ - monta as instruções    │
│ 3. Pedido de IA              │           │ - reserva uso (limites)  │
│    { tarefa, entrada }       │ ◀──────── │ - chama a IA, registra   │
│ 4. Validação da resposta     │   texto   │   tokens; não guarda     │
└──────────────────────────────┘           │   conteúdo               │
                                           │ Tabela ia_uso (RLS)      │
                                           └──────────────────────────┘
```

Na versão do Claude (artefato), o passo 3 usa o recurso `sample` da própria página: a IA roda pela conta do usuário, sem chave nenhuma no código.

## Camadas

| Camada | Onde | O que faz |
|---|---|---|
| Motor local | `index.html` (`responderLocal`, `negligenciadas`, `precisaAtencao`, `prioritarios`…) | Responde perguntas sobre os registros com os mesmos cálculos da aba Desempenho. Não envia nada, não custa nada e funciona sem internet. |
| Resumo autorizado | `contextoIA()` | Texto calculado com o que o usuário autorizou (Concursos, Faculdade, Desenvolvimento, Organização). Anotações nunca vão. A prévia fica em Assistente → Privacidade e uso. |
| Tarefas da IA | `IA_TAREFAS` (o mesmo código no app e na função) | `chat`, `analise`, `questoes`, `flashcards`, `resumo`, `pdf`, `cronograma`, cada uma com instruções fixas e um teto de tokens de resposta. |
| Provedor | `iaChamar()` | Escolhe entre Claude da página e função do servidor. Aplica o limite diário do app, o intervalo de 3 s entre pedidos e um pedido por vez. |
| Servidor | `supabase/functions/assistente/index.ts` | Faz login, CORS, validação, limites, chamada à Anthropic e registro de uso. |
| Banco | `supabase-assistente.sql` | Tabela `ia_uso` (só contagens) e as funções `ia_reservar`/`ia_registrar`, que só a chave de serviço executa. |

## Regras de segurança

- **Chave:** `ANTHROPIC_API_KEY` existe só nos Secrets do Supabase. O navegador não conhece o endereço nem a chave da API.
- **Proxy fechado:** o servidor aceita apenas as tarefas conhecidas e os campos `pergunta`, `dados`, `material`, `assunto`, `n` e `horas`, com tamanho máximo. As instruções da IA são montadas no servidor, então o navegador não consegue mandar instruções próprias.
- **Controle de custo:**
  - limite por pessoa: pedidos por dia, por minuto, tokens por dia e tokens por mês;
  - teto mensal somando todos os usuários;
  - teto de resposta por tarefa;
  - a reserva é atômica, então pedidos simultâneos não furam o limite.
- **Privacidade:**
  - a IA vem desativada e é ligada com um consentimento explícito;
  - cada categoria de dados tem sua própria permissão;
  - documentos e textos só saem depois de uma confirmação que mostra o que será enviado;
  - a conversa não é salva;
  - o servidor guarda só contagens.
- **Sem alterações automáticas:** a IA não tem ferramentas. Flashcards, registro de questões no edital e ciclos sugeridos só são salvos quando o usuário clica e confirma, e o ciclo entra como "planejado".
- **Sem dados inventados:**
  - perguntas sobre os registros são respondidas pelo motor local;
  - a IA recebe a instrução de usar só o bloco DADOS;
  - JSON gerado é validado: matérias inexistentes são descartadas e respostas fora do formato são recusadas.
- **Identificação:**
  - todo conteúdo gerado aparece com o selo "Gerado por IA";
  - flashcards salvos levam a marca `ia: true` e o selo "IA";
  - respostas calculadas aparecem como "Calculado dos seus registros".
- **Saída segura:** a resposta da IA passa por escape antes de ir para a tela. HTML vira texto e não executa.

## Variáveis da função (Supabase → Edge Functions → Secrets)

| Nome | Padrão | Uso |
|---|---|---|
| `ANTHROPIC_API_KEY` | — | Obrigatória. |
| `IA_ORIGENS` | (todas) | Endereço do site, ex.: `https://maycon22.github.io`. |
| `IA_MODELO` | `claude-haiku-5-5` | Modelo usado. |
| `IA_LIMITE_DIA` / `IA_LIMITE_MINUTO` | 30 / 5 | Pedidos por pessoa. |
| `IA_TOKENS_DIA` / `IA_TOKENS_MES` | 150.000 / 1.500.000 | Tokens por pessoa. |
| `IA_TOKENS_MES_TOTAL` | 3.000.000 | Teto mensal de todos os usuários (0 = sem teto). |

Defina também um limite de gasto mensal no painel da Anthropic (console.anthropic.com → Limits). É a última proteção.

## Como ativar a IA no site (opcional, pago à parte)

1. Em **console.anthropic.com**, crie uma chave de API e defina um limite de gasto mensal (em **Limits**).
2. No Supabase, abra o **SQL Editor**, cole `supabase-assistente.sql` e clique em **Run**.
3. No Supabase, abra **Edge Functions** e crie uma função pelo editor do navegador com o nome `assistente`. Cole o conteúdo de `supabase/functions/assistente/index.ts` e faça o deploy.
4. Em **Edge Functions → Secrets**, adicione:
   - `ANTHROPIC_API_KEY`, com a sua chave;
   - `IA_ORIGENS`, com o endereço do site (ex.: `https://maycon22.github.io`).
5. No app, abra **Assistente → Privacidade e uso**, clique em **Ativar** e depois em **Testar conexão**.
