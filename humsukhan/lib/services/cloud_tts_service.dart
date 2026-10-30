import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class CloudTtsResult {
  final List<int> audioBytes;
  final String mimeType;
  final String provider;

  const CloudTtsResult({
    required this.audioBytes,
    required this.mimeType,
    required this.provider,
  });
}

class CloudTtsException implements Exception {
  final String message;
  final String? provider;
  final int? statusCode;

  const CloudTtsException(this.message, {this.provider, this.statusCode});

  @override
  String toString() => 'CloudTtsException($message, $provider, $statusCode)';
}

/// Calls a speech-synthesis Edge Function and returns its JSON body.
typedef TtsFunctionInvoker = Future<Object?> Function(String function, Map<String, dynamic> body);

/// Cloud voices, used when the device has no voice for the language.
///
/// `speech-synthesis` is the primary. `speech-synthesis-v2` is a second,
/// independently deployed function with the same contract, tried when the
/// first fails for a reason a second attempt could get past — a timeout, a
/// network error, or a provider outage. A request the server rejected as
/// such (no text, not signed in) is not retried: the backup would refuse it
/// the same way.
class CloudTtsService {
  static CloudTtsService? _instance;
  static CloudTtsService get instance => _instance ??= CloudTtsService._(_invokeSupabase);
  CloudTtsService._(this._invoke);

  @visibleForTesting
  CloudTtsService.withInvoker(TtsFunctionInvoker invoke) : _invoke = invoke;

  static const functions = ['speech-synthesis', 'speech-synthesis-v2'];

  final TtsFunctionInvoker _invoke;

  Future<CloudTtsResult> synthesize({
    required String text,
    required String language,
  }) async {
    CloudTtsException? failure;
    for (final function in functions) {
      try {
        return await _synthesizeWith(function, text: text, language: language);
      } on CloudTtsException catch (e) {
        failure = e;
        if (!_worthRetrying(e)) rethrow;
        if (function != functions.last) debugPrint('Cloud TTS $function failed ($e); trying the backup.');
      }
    }
    throw failure!;
  }

  // Both functions share one per-user quota, so a request over the limit
  // (429) or too large (413) would be refused by the backup too.
  static bool _worthRetrying(CloudTtsException e) {
    final status = e.statusCode;
    return !const {400, 401, 403, 413, 429}.contains(status) && e.message != _noSession;
  }

  static const _noSession = 'Authenticated Supabase session unavailable';

  Future<CloudTtsResult> _synthesizeWith(String function, {required String text, required String language}) async {
    try {
      final data = await _invoke(function, {'text': text, 'language': language});
      if (data is! Map) {
        throw const CloudTtsException('Speech service returned an invalid response');
      }

      final map = Map<String, dynamic>.from(data);
      final error = map['error']?.toString();
      if (error != null && error.isNotEmpty) {
        throw CloudTtsException(
          error,
          provider: map['provider']?.toString(),
          statusCode: int.tryParse(map['status']?.toString() ?? ''),
        );
      }

      final encoded = map['audioBase64']?.toString();
      if (encoded == null || encoded.isEmpty) {
        throw const CloudTtsException('Speech service returned no audio');
      }

      final audio = base64Decode(encoded);
      if (audio.isEmpty) {
        throw const CloudTtsException('Speech service returned empty audio');
      }

      return CloudTtsResult(
        audioBytes: audio,
        mimeType: map['mimeType']?.toString() ?? 'audio/mpeg',
        provider: map['provider']?.toString() ?? 'cloud',
      );
    } on FunctionException catch (e) {
      debugPrint('Cloud TTS function $function failed: ${e.details}');
      throw CloudTtsException(
        e.details?.toString() ?? e.reasonPhrase ?? 'Cloud speech synthesis failed',
        statusCode: e.status,
      );
    } catch (e) {
      if (e is CloudTtsException) rethrow;
      debugPrint('Cloud TTS request to $function failed: $e');
      throw CloudTtsException(e.toString());
    }
  }

  static Future<Object?> _invokeSupabase(String function, Map<String, dynamic> body) async {
    final client = SupabaseService.instance.client;
    if (client == null || client.auth.currentSession == null) {
      throw const CloudTtsException(_noSession);
    }
    // Provider selection and credentials stay server-side; the device must
    // not probe Deepgram or Soniox directly.
    final response = await client.functions.invoke(function, body: body).timeout(const Duration(seconds: 8));
    return response.data;
  }
}
