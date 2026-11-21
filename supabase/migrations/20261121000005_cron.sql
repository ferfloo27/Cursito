-- Cursito · 0005 · Cierre de votaciones vencidas cada 5 minutos (RN-CU08, DEC-CU07).
-- Además, rendicion() y actualizar_votaciones() cierran las vencidas al consultar.
create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule('cerrar-votaciones-vencidas', '*/5 * * * *',
                     $$select privado.cerrar_votaciones_vencidas()$$);
