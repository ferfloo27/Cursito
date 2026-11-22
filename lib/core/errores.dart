import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Traduce las claves de error de la base y de Supabase a mensajes en español boliviano.
/// Ningún código técnico llega a la pantalla sin traducir (Idiomas y nomenclatura).
const _mensajes = <String, String>{
  // Cuentas
  'invalid_credentials': 'El correo o la contraseña no son correctos.',
  'weak_password': 'La contraseña debe tener al menos 8 caracteres.',
  'user_already_exists': 'Ya hay una cuenta con ese correo. Entra con tu contraseña.',
  'email_exists': 'Ya hay una cuenta con ese correo. Entra con tu contraseña.',
  'email_address_invalid': 'Revisa el correo: no parece válido.',
  'validation_failed': 'Revisa los datos e intenta de nuevo.',
  'over_request_rate_limit': 'Demasiados intentos. Espera un momento.',
  'sin_sesion': 'Tu sesión terminó. Vuelve a entrar.',
  // Curso y miembros
  'rol_invalido': 'Solo el asesor o el padre delegado pueden crear un curso.',
  'ya_es_asesor': 'Esa persona ya es asesora de otro curso. Solo se puede ser asesor de un curso.',
  'codigo_invalido': 'No encontramos un curso con ese código. Revísalo con el asesor.',
  'alumno_invalido': 'Ese alumno no está en la nómina del curso.',
  'alumno_ya_tiene_padre': 'Ese alumno ya tiene un padre vinculado.',
  'ya_tiene_hijo_en_curso': 'Ya tienes un hijo o hija en este curso.',
  'ya_es_miembro': 'Ya eres parte de este curso.',
  'materia_invalida': 'Esa materia no es de este curso.',
  'materia_ocupada': 'Esa materia ya tiene profesor en este curso.',
  'debe_ser_profesor': 'Solo se puede dar el rol de asesor a un profesor del curso.',
  'curso_ya_tiene_asesor': 'El curso ya tiene asesor.',
  'rol_no_puede_ser_tesorero': 'El tesorero tiene que ser el asesor o un padre.',
  'alumno_no_se_puede_quitar': 'No se puede quitar: el alumno ya tiene padre, cuenta o pagos.',
  // Vinculación
  'qr_invalido': 'Este código ya se usó o venció. Pídele a tu mamá o papá uno nuevo.',
  'no_se_pudo_vincular': 'No pudimos crear tu acceso. Intenta de nuevo.',
  // Plata
  'comprobante_usado': 'Este comprobante ya fue usado.',
  'deuda_saldada': 'Esta cuota ya está pagada.',
  'deuda_invalida': 'No encontramos esa cuota.',
  'cuota_anulada': 'Esta cuota fue anulada.',
  'monto_invalido': 'Escribe un monto mayor que cero.',
  'nro_invalido': 'Escribe el número de transacción del comprobante.',
  'comprobante_invalido': 'Sube la foto del comprobante.',
  'pago_ya_revisado': 'Este pago ya fue revisado.',
  'motivo_obligatorio': 'Escribe el motivo.',
  'cuota_con_pagos': 'No se puede anular: alguien ya pagó esta cuota.',
  'votacion_cerrada': 'La votación ya cerró.',
  'solo_padres_votan': 'Solo los padres votan los gastos.',
  'libro_inalterable': 'Los movimientos del libro no se editan ni se borran. Registra un ajuste.',
  'ajuste_sin_movimiento': 'El ajuste tiene que ser sobre un pago confirmado o un gasto aprobado.',
  // Actividades e informes
  'actividad_no_editable': 'Solo se cambian la fecha, el lugar y la descripción.',
  'asistencia_no_aplica': 'Esta actividad no pide asistencia.',
  'asistencia_cerrada': 'Ya pasó la fecha: no se puede cambiar la asistencia.',
  'informe_ya_leido': 'La familia ya leyó el informe: no se puede corregir.',
  'informe_no_editable': 'Este informe no se puede cambiar.',
  // Genéricos
  'sin_permiso': 'No tienes permiso para hacer esto.',
  'no_encontrado': 'No encontramos lo que buscas.',
  'ruta_invalida': 'No se pudo guardar la imagen.',
  'parametro_invalido': 'Algo salió mal. Intenta de nuevo.',
};

const sinConexion = 'No hay conexión. Revisa tu internet e intenta de nuevo.';
const errorGenerico = 'Algo salió mal. Intenta de nuevo.';

String mensajeDeError(Object e) {
  if (e is PostgrestException) {
    final clave = e.message.trim();
    if (_mensajes.containsKey(clave)) return _mensajes[clave]!;
    if (e.code == '23505') return _mensajes['comprobante_usado']!;
    if (e.code == '42501') return _mensajes['sin_permiso']!;
    return errorGenerico;
  }
  if (e is AuthException) {
    final clave = e.code ?? '';
    if (_mensajes.containsKey(clave)) return _mensajes[clave]!;
    if (e is AuthRetryableFetchException) return sinConexion;
    return errorGenerico;
  }
  if (e is FunctionException) {
    final d = e.details;
    final clave = d is Map ? '${d['error']}' : '';
    return _mensajes[clave] ?? errorGenerico;
  }
  if (e is StorageException) return 'No se pudo subir la foto. Intenta de nuevo.';
  if (e is SocketException || e is TimeoutException) return sinConexion;
  final txt = '$e';
  if (txt.contains('SocketException') || txt.contains('Failed host lookup') || txt.contains('ClientException')) {
    return sinConexion;
  }
  return _mensajes[txt] ?? errorGenerico;
}
