-- Mesa de Estudos: preparação do banco no Supabase
-- Cole tudo no SQL Editor do seu projeto e clique em "Run". Pode rodar mais de uma vez sem problema.

-- Cada usuário guarda alguns documentos: "config" (matérias, ciclo, ajustes)
-- e um por mês com as sessões de estudo ("m_2026-11", "m_2026-12"...).
create table if not exists public.documentos (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  chave text not null check (chave ~ '^(config|m_[0-9]{4}-[0-9]{2})$'),
  dados jsonb not null,
  atualizado_em timestamptz not null default now(),
  primary key (user_id, chave)
);

-- Cada pessoa só enxerga e altera os próprios dados.
alter table public.documentos enable row level security;

drop policy if exists "ler os proprios documentos" on public.documentos;
drop policy if exists "criar os proprios documentos" on public.documentos;
drop policy if exists "alterar os proprios documentos" on public.documentos;
drop policy if exists "apagar os proprios documentos" on public.documentos;

create policy "ler os proprios documentos" on public.documentos
  for select to authenticated using (auth.uid() = user_id);
create policy "criar os proprios documentos" on public.documentos
  for insert to authenticated with check (auth.uid() = user_id);
create policy "alterar os proprios documentos" on public.documentos
  for update to authenticated using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "apagar os proprios documentos" on public.documentos
  for delete to authenticated using (auth.uid() = user_id);

grant select, insert, update, delete on public.documentos to authenticated;
revoke all on public.documentos from anon;

-- Sincronização em tempo real entre aparelhos.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'documentos'
  ) then
    alter publication supabase_realtime add table public.documentos;
  end if;
end $$;
