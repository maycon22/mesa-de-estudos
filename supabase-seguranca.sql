-- Mesa de Estudos: reforço de segurança e integridade (Implementação 10)
-- Cole tudo no SQL Editor do seu projeto Supabase e clique em "Run". Pode rodar mais de uma vez.
-- NÃO apaga tabelas nem registros e NÃO desativa o RLS. Só acrescenta proteções.
-- Antes de rodar, faça um backup pelo app (Ajustes → Exportar backup), por precaução.

-- 1. Versão de cada documento gravada pelo próprio servidor.
--    O app só grava se a versão no banco for a que ele conhece; se outro aparelho gravou antes, ele mescla e tenta de novo.
create or replace function public.documentos_versao()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.atualizado_em := clock_timestamp();
  return new;
end;
$$;
revoke all on function public.documentos_versao() from public, anon, authenticated;
drop trigger if exists documentos_versao on public.documentos;
create trigger documentos_versao before insert or update on public.documentos
  for each row execute function public.documentos_versao();

-- 2. Limite de tamanho por documento (5 MB). Protege contra gravações anormais. Não confere os dados que já existem.
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'documentos_tamanho' and conrelid = 'public.documentos'::regclass) then
    alter table public.documentos add constraint documentos_tamanho check (pg_column_size(dados) <= 5242880) not valid;
  end if;
end $$;

-- 3. Regras de acesso (RLS) recriadas na forma recomendada pelo Supabase: cada pessoa só lê e grava as próprias linhas.
alter table public.documentos enable row level security;
drop policy if exists "ler os proprios documentos" on public.documentos;
drop policy if exists "criar os proprios documentos" on public.documentos;
drop policy if exists "alterar os proprios documentos" on public.documentos;
drop policy if exists "apagar os proprios documentos" on public.documentos;
create policy "ler os proprios documentos" on public.documentos
  for select to authenticated using ((select auth.uid()) = user_id);
create policy "criar os proprios documentos" on public.documentos
  for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "alterar os proprios documentos" on public.documentos
  for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "apagar os proprios documentos" on public.documentos
  for delete to authenticated using ((select auth.uid()) = user_id);

-- 4. Visitantes sem login não têm nenhum acesso; usuários logados só pelas regras acima.
revoke all on public.documentos from anon;
grant select, insert, update, delete on public.documentos to authenticated;
