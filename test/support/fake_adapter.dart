import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeHandler = Future<FakeResponse> Function(RequestOptions request);

class FakeResponse {
  const FakeResponse(this.status, [this.body, this.headers = const {}]);

  final int status;
  final Object? body;
  final Map<String, List<String>> headers;
}

/// Adaptador HTTP de Dio que responde con [handler] y registra las peticiones.
class FakeAdapter implements HttpClientAdapter {
  FakeAdapter(this.handler);

  final FakeHandler handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = await handler(options);
    final isProblem = response.status >= 400;
    return ResponseBody.fromString(
      response.body == null ? '' : jsonEncode(response.body),
      response.status,
      headers: {
        Headers.contentTypeHeader: [isProblem ? 'application/problem+json' : Headers.jsonContentType],
        ...response.headers,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> problem(String code, int status, {String detail = 'detalle', List<Map<String, String>>? errors}) =>
    {
      'type': 'https://hogar.app/problems/$code',
      'title': 'Error',
      'status': status,
      'detail': detail,
      'code': code,
      'requestId': 'req-1',
      'errors': ?errors,
    };
