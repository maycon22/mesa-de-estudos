-- Mesa de Estudos: auditoria de segurança (SÓ LEITURA: não altera nada)
-- Cole no SQL Editor do Supabase, clique em "Run" e confira a coluna "situacao". O ideal é tudo "OK".
with
tabelas as (
  select c.relname as tabela, c.relrowsecurity as rls
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relkind = 'r'
),
politicas as (
  select tablename, count(*) as n, bool_or('anon' = any(roles) or 'public' = any(roles)) as para_anon,
         bool_or(coalesce(qual, '') ~* '^\s*\(?\s*true\s*\)?\s*$' or coalesce(with_check, '') ~* '^\s*\(?\s*true\s*\)?\s*$') as liberada
  from pg_policies where schemaname = 'public' group by tablename
),
funcoes as (
  select p.proname, p.prosecdef, has_function_privilege('anon', p.oid, 'EXECUTE') as anon_exec, has_function_privilege('authenticated', p.oid, 'EXECUTE') as auth_exec
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prokind = 'f'
)
select 1 as ordem, 'RLS ligado na tabela ' || t.tabela as verificacao, case when t.rls then 'OK' else 'PROBLEMA' end as situacao,
       case when t.rls then 'cada linha só é vista pelas regras de acesso' else 'qualquer usuário logado veria tudo: rode supabase-setup.sql' end as detalhe
from tabelas t
union all
select 2, 'Regras de acesso da tabela ' || t.tabela,
       case when p.n is null then 'PROBLEMA' when p.para_anon or p.liberada then 'ATENÇÃO' else 'OK' end,
       case when p.n is null then 'nenhuma regra: com RLS ligado ninguém acessa; sem RLS, todos acessam'
            when p.para_anon then 'há regra para visitantes sem login' when p.liberada then 'há regra que libera tudo (true)' else p.n || ' regra(s), todas exigem login' end
from tabelas t left join politicas p on p.tablename = t.tabela
union all
select 3, 'Visitante sem login (anon) na tabela ' || g.table_name, 'PROBLEMA', 'permissão ' || string_agg(g.privilege_type, ', ')
from information_schema.role_table_grants g
where g.grantee = 'anon' and g.table_schema = 'public' group by g.table_name
union all
select 4, 'Função ' || f.proname,
       case when f.prosecdef and (f.anon_exec or f.auth_exec) then 'PROBLEMA' when f.anon_exec then 'ATENÇÃO' else 'OK' end,
       case when f.prosecdef and (f.anon_exec or f.auth_exec) then 'roda com privilégios de administrador e pode ser chamada pelo navegador'
            when f.anon_exec then 'pode ser chamada sem login' else case when f.prosecdef then 'privilegiada, só o servidor chama' else 'comum' end end
from funcoes f
union all
select 5, 'Versão dos documentos (gatilho)', case when exists (select 1 from pg_trigger where tgname = 'documentos_versao' and not tgisinternal) then 'OK' else 'ATENÇÃO' end,
       'sem o gatilho, o app ainda controla versões, mas pelo relógio do aparelho: rode supabase-seguranca.sql'
union all
select 6, 'Limite de tamanho dos documentos', case when exists (select 1 from pg_constraint where conname = 'documentos_tamanho') then 'OK' else 'ATENÇÃO' end, 'rode supabase-seguranca.sql'
union all
select 7, 'Pasta de arquivos ' || b.id, case when b.public then 'PROBLEMA' else 'OK' end, case when b.public then 'pasta pública: qualquer pessoa com o link vê os arquivos' else 'privada (links temporários)' end
from storage.buckets b
union all
select 8, 'Regras da pasta materiais', case when count(*) >= 4 then 'OK' else 'ATENÇÃO' end, count(*) || ' regra(s); esperado 4 (ler, enviar, alterar, apagar a própria pasta)'
from pg_policies where schemaname = 'storage' and tablename = 'objects' and policyname like 'materiais:%'
order by 1, 2;
