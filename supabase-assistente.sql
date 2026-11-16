-- Mesa de Estudos: controle de uso do assistente de IA (limites por pessoa e teto do mês)
-- Cole tudo no SQL Editor do seu projeto Supabase e clique em "Run". Pode rodar mais de uma vez.
-- Guarda só CONTAGENS (pedidos e tokens por dia). Perguntas, respostas e documentos não são guardados.

create table if not exists public.ia_uso (
  user_id uuid not null references auth.users (id) on delete cascade,
  dia date not null,
  requisicoes integer not null default 0,
  tokens_entrada bigint not null default 0,
  tokens_saida bigint not null default 0,
  minuto timestamptz,
  req_minuto integer not null default 0,
  primary key (user_id, dia)
);

alter table public.ia_uso enable row level security;

-- cada pessoa só LÊ o próprio uso; ninguém grava pelo navegador (só a função do servidor)
drop policy if exists "ia: ver o proprio uso" on public.ia_uso;
create policy "ia: ver o proprio uso" on public.ia_uso
  for select to authenticated using ((select auth.uid()) = user_id);
revoke all on public.ia_uso from anon, authenticated;
grant select on public.ia_uso to authenticated;

-- Reserva um pedido antes de chamar a IA. Trava a linha do dia para que pedidos simultâneos não passem do limite.
create or replace function public.ia_reservar(p_user uuid, p_limite_dia integer, p_limite_minuto integer,
                                              p_tokens_dia bigint, p_tokens_mes bigint, p_tokens_total bigint)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  hoje date := (now() at time zone 'America/Sao_Paulo')::date;
  inicio_mes date := date_trunc('month', (now() at time zone 'America/Sao_Paulo'))::date;
  r public.ia_uso%rowtype;
  usado_mes bigint;
  usado_total bigint;
begin
  insert into public.ia_uso (user_id, dia) values (p_user, hoje) on conflict (user_id, dia) do nothing;
  select * into r from public.ia_uso where user_id = p_user and dia = hoje for update;
  select coalesce(sum(tokens_entrada + tokens_saida), 0) into usado_mes from public.ia_uso where user_id = p_user and dia >= inicio_mes;
  select coalesce(sum(tokens_entrada + tokens_saida), 0) into usado_total from public.ia_uso where dia >= inicio_mes;
  if r.requisicoes >= p_limite_dia then return 'limite_dia'; end if;
  if r.tokens_entrada + r.tokens_saida >= p_tokens_dia then return 'limite_tokens_dia'; end if;
  if usado_mes >= p_tokens_mes then return 'limite_tokens_mes'; end if;
  if p_tokens_total > 0 and usado_total >= p_tokens_total then return 'limite_total'; end if;
  if r.minuto is not null and r.minuto > now() - interval '1 minute' then
    if r.req_minuto >= p_limite_minuto then return 'limite_minuto'; end if;
    update public.ia_uso set requisicoes = requisicoes + 1, req_minuto = req_minuto + 1 where user_id = p_user and dia = hoje;
  else
    update public.ia_uso set requisicoes = requisicoes + 1, req_minuto = 1, minuto = now() where user_id = p_user and dia = hoje;
  end if;
  return 'ok';
end;
$$;

-- Registra os tokens gastos depois da resposta.
create or replace function public.ia_registrar(p_user uuid, p_entrada bigint, p_saida bigint)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.ia_uso
     set tokens_entrada = tokens_entrada + greatest(p_entrada, 0), tokens_saida = tokens_saida + greatest(p_saida, 0)
   where user_id = p_user and dia = (now() at time zone 'America/Sao_Paulo')::date;
end;
$$;

-- Só a função do servidor (chave de serviço) pode usar estas duas funções.
revoke all on function public.ia_reservar(uuid, integer, integer, bigint, bigint, bigint) from public, anon, authenticated;
revoke all on function public.ia_registrar(uuid, bigint, bigint) from public, anon, authenticated;
grant execute on function public.ia_reservar(uuid, integer, integer, bigint, bigint, bigint) to service_role;
grant execute on function public.ia_registrar(uuid, bigint, bigint) to service_role;
