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

class CloudTtsService {
  static CloudTtsService? _instance;
  static CloudTtsService get instance => _instance ??= CloudTtsService._();
  CloudTtsService._();

  Future<CloudTtsResult> synthesize({
    required String text,
    required String language,
  }) async {
    final client = SupabaseService.instance.client;
    if (client == null || client.auth.currentSession == null) {
      throw const CloudTtsException('Authenticated Supabase session unavailable');
    }

    try {
      final response = await client.functions
          .invoke(
            'speech-synthesis',
            body: {
              'text': text,
              'language': language,
            },
          )
          .timeout(const Duration(seconds: 8));

      final data = response.data;
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
      debugPrint('Cloud TTS function failed: ${e.details}');
      throw CloudTtsException(
        e.details?.toString() ?? e.reasonPhrase ?? 'Cloud speech synthesis failed',
        statusCode: e.status,
      );
    } catch (e) {
      if (e is CloudTtsException) rethrow;
      debugPrint('Cloud TTS request failed: $e');
      throw CloudTtsException(e.toString());
    }
  }
}
