// Sube las imágenes de la semilla a Storage (después de cargar seed.sql).
// Uso (PowerShell):
//   $env:SUPABASE_URL = "http://127.0.0.1:56321"; $env:SUPABASE_SECRET_KEY = "<clave secreta o service_role>"
//   node supabase/semilla/subir_imagenes.mjs
// La clave secreta nunca se guarda en el repositorio.
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const url = process.env.SUPABASE_URL;
const clave = process.env.SUPABASE_SECRET_KEY;
if (!url || !clave) {
  console.error("Faltan SUPABASE_URL y SUPABASE_SECRET_KEY");
  process.exit(1);
}

const curso = "22222222-0000-4000-8000-000000000001";
const padres = {
  "javier.gutierrez": "11111111-0000-4000-8000-000000000011",
  "marta.condori": "11111111-0000-4000-8000-000000000012",
  "silvia.rojas": "11111111-0000-4000-8000-000000000013",
  "oscar.mamani": "11111111-0000-4000-8000-000000000014",
  "lucia.torrez": "11111111-0000-4000-8000-000000000015",
  "rosa.huanca": "11111111-0000-4000-8000-000000000016",
  "ana.vargas": "11111111-0000-4000-8000-000000000017",
};

const archivos = [
  ...Object.entries(padres).map(([quien, id]) => [`comprobante-${quien}.jpg`, "comprobantes", `${curso}/${id}/semilla.jpg`]),
  ["factura-tarjetas-y-lazos.jpg", "facturas", `${curso}/tarjetas-y-lazos.jpg`],
  ["factura-arreglos-florales.jpg", "facturas", `${curso}/arreglos-florales.jpg`],
  ["qr-cobro.png", "qr_cobro", `${curso}/semilla.png`],
];

const carpeta = join(dirname(fileURLToPath(import.meta.url)), "imagenes");
let fallos = 0;
for (const [archivo, bucket, ruta] of archivos) {
  const r = await fetch(`${url}/storage/v1/object/${bucket}/${ruta}`, {
    method: "POST",
    headers: {
      apikey: clave,
      Authorization: `Bearer ${clave}`,
      "Content-Type": archivo.endsWith(".png") ? "image/png" : "image/jpeg",
      "x-upsert": "true",
    },
    body: readFileSync(join(carpeta, archivo)),
  });
  console.log(r.ok ? "ok  " : "FALLA", `${bucket}/${ruta}`, r.ok ? "" : await r.text());
  if (!r.ok) fallos++;
}
process.exit(fallos ? 1 : 0);
