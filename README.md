# Mesa de Estudos

Planner de estudos para concursos, faculdade e desenvolvimento pessoal. O app tem:

- painel;
- cronômetro;
- ciclo de estudos;
- edital verticalizado;
- revisões e flashcards;
- gestão acadêmica;
- central de desempenho;
- organização pessoal;
- assistente de IA.

O menu lateral tem três módulos, cada um com as suas abas:

- **01. Faculdade**: visão geral, disciplinas, calendário, materiais, relatórios e configuração;
- **02. Concursos**: painel, ciclo, edital e revisões;
- **03. Desenvolvimento pessoal**: agenda, calendário, tarefas, metas, projetos, leituras, biblioteca, anotações, lembretes, atividades e categorias.

Cronômetro, registro, desempenho, histórico e assistente aparecem em todos os módulos, já filtrados pelo módulo. O endereço segue o formato `#modulo/aba` (ex.: `#concursos/edital`); endereços antigos continuam funcionando.

O app inteiro é o `index.html` (HTML, CSS e JavaScript, sem etapa de build), publicado no GitHub Pages. Os dados ficam no Supabase, com login e regras de acesso por usuário (RLS).

## Arquivos

| Arquivo | Para que serve |
| --- | --- |
| `index.html` | O aplicativo. A URL e a chave **pública** do Supabase ficam no bloco `CONFIG`. |
| `sw.js`, `manifest.webmanifest`, `icon-*.png` | Instalação no celular e funcionamento sem internet. |
| `.nojekyll` | Faz o GitHub Pages publicar os arquivos como estão. |
| `supabase-setup.sql` | Cria a tabela `documentos` com RLS. **Obrigatório.** |
| `supabase-seguranca.sql` | Versão por documento, limite de 5 MB e regras RLS revisadas. **Recomendado.** |
| `supabase-materiais.sql` | Pasta privada de arquivos (materiais e biblioteca). |
| `supabase-assistente.sql` | Controle de uso da IA (só se usar o assistente com IA). |
| `supabase-auditoria.sql` | Auditoria de segurança, **só leitura**. |
| `supabase/functions/assistente/index.ts` | Função do servidor do assistente de IA (opcional). |
| `ARQUITETURA-IA.md` | Arquitetura e regras do assistente. |

## Publicar uma nova versão

1. No app, abra **Ajustes → Exportar backup**.
2. No GitHub, abra **Add file → Upload files**, arraste os arquivos e clique em **Commit changes**.
3. Em **Settings → Pages**, confira se está publicado a partir de `main`, pasta `/ (root)`.
4. Recarregue o app em todos os aparelhos.

## Supabase: ordem dos SQLs

No **SQL Editor**, rode os arquivos nesta ordem; cada um pode ser rodado de novo sem problema:

1. `supabase-setup.sql`
2. `supabase-seguranca.sql`
3. `supabase-materiais.sql`
4. `supabase-assistente.sql`, só se for usar a IA.

Depois rode `supabase-auditoria.sql`: a coluna `situacao` deve mostrar OK em todas as linhas.

Em **Authentication**:

- deixe a confirmação de e-mail ligada;
- defina a senha mínima em 8 caracteres;
- em **URL Configuration**, use o endereço do site (ex.: `https://maycon22.github.io/mesa-de-estudos/`) em Site URL e em Redirect URLs.

## Segredos

O navegador só conhece a chave **publishable**, que é pública por definição. A chave `service_role` e a chave da API da IA (`ANTHROPIC_API_KEY`) **nunca** vão para este repositório: ficam em **Supabase → Edge Functions → Secrets**.
