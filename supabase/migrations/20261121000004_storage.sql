-- Cursito · 0004 · Storage (§13.6, ADR-CU08, R-CU42)
-- Buckets privados; la app muestra las fotos con URLs firmadas de 1 hora.
--   comprobantes/{curso_id}/{usuario_id}/{uuid}.jpg  lee: quien lo subió y el tesorero · sube: el padre en su carpeta
--   facturas/{curso_id}/{uuid}.jpg                   lee: padres y asesor (Q-CU-REN-01) · sube: el tesorero
--   qr_cobro/{curso_id}/{uuid}.jpg                   lee: adultos del curso · sube: el tesorero

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
  ('comprobantes', 'comprobantes', false, 524288,  array['image/jpeg', 'image/png', 'image/webp']),
  ('facturas',     'facturas',     false, 524288,  array['image/jpeg', 'image/png', 'image/webp']),
  ('qr_cobro',     'qr_cobro',     false, 1048576, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

create policy subir_comprobante on storage.objects for insert to authenticated
  with check (bucket_id = 'comprobantes'
              and (storage.foldername(name))[2] = auth.uid()::text
              and privado.es_padre(privado.uuid_o_nulo((storage.foldername(name))[1])));
create policy ver_comprobante on storage.objects for select to authenticated
  using (bucket_id = 'comprobantes'
         and ((storage.foldername(name))[2] = auth.uid()::text
              or privado.es_tesorero(privado.uuid_o_nulo((storage.foldername(name))[1]))));

create policy subir_factura on storage.objects for insert to authenticated
  with check (bucket_id = 'facturas' and privado.es_tesorero(privado.uuid_o_nulo((storage.foldername(name))[1])));
create policy ver_factura on storage.objects for select to authenticated
  using (bucket_id = 'facturas' and privado.ve_cuentas(privado.uuid_o_nulo((storage.foldername(name))[1])));

create policy subir_qr_cobro on storage.objects for insert to authenticated
  with check (bucket_id = 'qr_cobro' and privado.es_tesorero(privado.uuid_o_nulo((storage.foldername(name))[1])));
create policy ver_qr_cobro on storage.objects for select to authenticated
  using (bucket_id = 'qr_cobro' and privado.es_adulto(privado.uuid_o_nulo((storage.foldername(name))[1])));
