// Genera las imágenes sintéticas de la semilla (comprobantes, facturas y QR de cobro).
// Uso: dart run tool/generar_imagenes_semilla.dart  → supabase/semilla/imagenes/
import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;

const salida = 'supabase/semilla/imagenes';

void tarjeta(String archivo, String titulo, List<String> lineas, img.Color fondo) {
  final im = img.Image(width: 600, height: 800);
  img.fill(im, color: img.ColorRgb8(250, 250, 250));
  img.fillRect(im, x1: 0, y1: 0, x2: 600, y2: 120, color: fondo);
  img.drawString(im, titulo, font: img.arial48, x: 30, y: 36, color: img.ColorRgb8(255, 255, 255));
  var y = 170;
  for (final l in lineas) {
    img.drawString(im, l, font: img.arial24, x: 30, y: y, color: img.ColorRgb8(30, 30, 30));
    y += 50;
  }
  img.drawString(im, 'DATOS DE DEMOSTRACION - CURSITO', font: img.arial14, x: 30, y: 760,
      color: img.ColorRgb8(150, 150, 150));
  File('$salida/$archivo').writeAsBytesSync(img.encodeJpg(im, quality: 80));
}

void qr(String archivo) {
  const n = 29, celda = 14, margen = 40;
  final im = img.Image(width: n * celda + 2 * margen, height: n * celda + 2 * margen + 60);
  img.fill(im, color: img.ColorRgb8(255, 255, 255));
  final r = Random(7);
  void cuadro(int cx, int cy) {
    for (var i = 0; i < 7; i++) {
      for (var j = 0; j < 7; j++) {
        final borde = i == 0 || j == 0 || i == 6 || j == 6;
        final centro = i >= 2 && i <= 4 && j >= 2 && j <= 4;
        if (borde || centro) {
          img.fillRect(im, x1: margen + (cx + i) * celda, y1: margen + (cy + j) * celda,
              x2: margen + (cx + i + 1) * celda - 1, y2: margen + (cy + j + 1) * celda - 1,
              color: img.ColorRgb8(0, 0, 0));
        }
      }
    }
  }
  for (var i = 0; i < n; i++) {
    for (var j = 0; j < n; j++) {
      final enCuadro = (i < 8 && j < 8) || (i > n - 9 && j < 8) || (i < 8 && j > n - 9);
      if (!enCuadro && r.nextBool()) {
        img.fillRect(im, x1: margen + i * celda, y1: margen + j * celda,
            x2: margen + (i + 1) * celda - 1, y2: margen + (j + 1) * celda - 1, color: img.ColorRgb8(0, 0, 0));
      }
    }
  }
  cuadro(0, 0);
  cuadro(n - 7, 0);
  cuadro(0, n - 7);
  img.drawString(im, 'QR de cobro (demo) - Javier Gutierrez', font: img.arial14, x: margen,
      y: n * celda + 2 * margen + 15, color: img.ColorRgb8(60, 60, 60));
  File('$salida/$archivo').writeAsBytesSync(img.encodePng(im));
}

void main() {
  Directory(salida).createSync(recursive: true);
  const pagos = {
    'javier.gutierrez': '778120935540', 'silvia.rojas': '552019384711', 'oscar.mamani': '903318275566',
    'lucia.torrez': '661204587390', 'rosa.huanca': '417760293851', 'marta.condori': '820193746602',
    'ana.vargas': '339581027764',
  };
  pagos.forEach((quien, nro) {
    tarjeta('comprobante-$quien.jpg', 'Transferencia QR', [
      'Banco de Demostracion',
      'Monto: Bs 60,00',
      'Nro. de transaccion:',
      nro,
      'Destino: Javier Gutierrez',
      'Concepto: Dia de la Madre',
    ], img.ColorRgb8(46, 125, 50));
  });
  tarjeta('factura-tarjetas-y-lazos.jpg', 'Libreria El Estudiante', [
    'Nota de venta', '8 tarjetas ......... Bs 30,00', 'Lazos ............. Bs 20,00', 'Total: Bs 50,00',
  ], img.ColorRgb8(21, 101, 192));
  tarjeta('factura-arreglos-florales.jpg', 'Floreria Primavera', [
    'Cotizacion', '8 arreglos florales', 'Total: Bs 180,00',
  ], img.ColorRgb8(173, 20, 87));
  qr('qr-cobro.png');
  stdout.writeln('Imagenes generadas en $salida');
}
