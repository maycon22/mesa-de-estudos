-- Mesa de Estudos: armazenamento privado dos materiais da faculdade (PDFs, slides, apostilas…)
-- Cole tudo no SQL Editor do seu projeto Supabase e clique em "Run". Pode rodar mais de uma vez sem problema.
-- Não altera nem apaga nenhum dado que você já tem.

-- 1. Pasta de arquivos PRIVADA (não pública), com limite de 20 MB por arquivo e só tipos de documento e imagem.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('materiais', 'materiais', false, 20971520, array[
  'application/pdf',
  'application/vnd.ms-powerpoint', 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.oasis.opendocument.text', 'application/vnd.oasis.opendocument.presentation', 'application/vnd.oasis.opendocument.spreadsheet',
  'text/plain', 'text/markdown', 'text/csv',
  'image/png', 'image/jpeg', 'image/webp', 'image/gif'
])
on conflict (id) do update set public = false, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- 2. Cada pessoa só enxerga, envia, altera e apaga arquivos dentro da própria pasta (o nome da pasta é o id da conta).
drop policy if exists "materiais: ler os proprios" on storage.objects;
drop policy if exists "materiais: enviar os proprios" on storage.objects;
drop policy if exists "materiais: alterar os proprios" on storage.objects;
drop policy if exists "materiais: apagar os proprios" on storage.objects;

create policy "materiais: ler os proprios" on storage.objects
  for select to authenticated
  using (bucket_id = 'materiais' and (storage.foldername(name))[1] = (select auth.uid()::text));
create policy "materiais: enviar os proprios" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'materiais' and (storage.foldername(name))[1] = (select auth.uid()::text));
create policy "materiais: alterar os proprios" on storage.objects
  for update to authenticated
  using (bucket_id = 'materiais' and (storage.foldername(name))[1] = (select auth.uid()::text))
  with check (bucket_id = 'materiais' and (storage.foldername(name))[1] = (select auth.uid()::text));
create policy "materiais: apagar os proprios" on storage.objects
  for delete to authenticated
  using (bucket_id = 'materiais' and (storage.foldername(name))[1] = (select auth.uid()::text));
