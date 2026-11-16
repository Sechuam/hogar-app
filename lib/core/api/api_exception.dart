import 'dart:convert';

import 'package:dio/dio.dart';

/// Error de la API convertido desde su `ProblemDetail` (RFC 7807), o de red.
///
/// [code] es el código estable de la API (`validation-error`, `plan-member-limit`…); la UI decide con
/// él y muestra [message], que es el `detail` del servidor (ya en español).
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.status,
    this.fieldErrors = const {},
    this.requestId,
    this.retryAfterSeconds,
  });

  /// Sin conexión, timeout o respuesta que no es un ProblemDetail.
  static const network = 'network-error';

  /// El refresh token ya no vale: hay que volver a iniciar sesión.
  static const sessionExpired = 'session-expired';

  final String code;
  final String message;
  final int? status;

  /// `errors[]` de un `validation-error`: campo → mensaje.
  final Map<String, String> fieldErrors;
  final String? requestId;

  /// Cabecera `Retry-After` de un 429.
  final int? retryAfterSeconds;

  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    if (response == null) {
      return const ApiException(
        code: network,
        message: 'No se pudo conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.',
      );
    }
    final data = _decode(response.data);
    final retryAfter = int.tryParse(response.headers.value('retry-after') ?? '');
    if (data is Map && data['code'] is String) {
      final errors = <String, String>{};
      final raw = data['errors'];
      if (raw is List) {
        for (final error in raw) {
          if (error is Map && error['field'] is String) {
            errors.putIfAbsent(error['field'] as String, () => '${error['message'] ?? 'no es válido'}');
          }
        }
      }
      return ApiException(
        code: data['code'] as String,
        message: (data['detail'] as String?) ?? (data['title'] as String?) ?? 'Error inesperado.',
        status: response.statusCode,
        fieldErrors: errors,
        requestId: data['requestId'] as String?,
        retryAfterSeconds: retryAfter,
      );
    }
    return ApiException(
      code: network,
      message: 'El servidor respondió con un error inesperado (${response.statusCode}).',
      status: response.statusCode,
      retryAfterSeconds: retryAfter,
    );
  }

  /// Las descargas binarias reciben también el ProblemDetail como bytes.
  static Object? _decode(Object? data) {
    if (data is! List<int>) {
      return data;
    }
    try {
      return jsonDecode(utf8.decode(data));
    } on FormatException {
      return null;
    }
  }

  @override
  String toString() => 'ApiException($code, $status): $message';
}
