import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/api_client.dart';
import 'auth/token_store.dart';

/// URL de la API: `--dart-define=API_BASE_URL=...` (por defecto, la API en local).
const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStore());

final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(baseUrl: apiBaseUrl, tokenStore: ref.watch(tokenStoreProvider)),
);
