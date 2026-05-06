import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/api_payload_parser.dart';
import 'package:evolua_frontend/core/network/authenticated_dio_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

class FeedbackSubmissionDraft {
  const FeedbackSubmissionDraft({
    this.workingWell,
    this.couldImprove,
    this.confusingOrHard,
    this.helpedHow,
    this.featureSuggestion,
    this.contentSuggestion,
    this.visualSuggestion,
    this.aiSuggestion,
    this.problemWhatHappened,
    this.problemWhere,
    this.problemCanRepeat,
    this.rating,
    this.ratingComment,
    this.screenshotBytes,
    this.screenshotFileName,
  });

  final String? workingWell;
  final String? couldImprove;
  final String? confusingOrHard;
  final String? helpedHow;
  final String? featureSuggestion;
  final String? contentSuggestion;
  final String? visualSuggestion;
  final String? aiSuggestion;
  final String? problemWhatHappened;
  final String? problemWhere;
  final String? problemCanRepeat;
  final String? rating;
  final String? ratingComment;
  final Uint8List? screenshotBytes;
  final String? screenshotFileName;

  Map<String, dynamic> toJson() {
    return {
      'workingWell': _trimmed(workingWell),
      'couldImprove': _trimmed(couldImprove),
      'confusingOrHard': _trimmed(confusingOrHard),
      'helpedHow': _trimmed(helpedHow),
      'featureSuggestion': _trimmed(featureSuggestion),
      'contentSuggestion': _trimmed(contentSuggestion),
      'visualSuggestion': _trimmed(visualSuggestion),
      'aiSuggestion': _trimmed(aiSuggestion),
      'problemWhatHappened': _trimmed(problemWhatHappened),
      'problemWhere': _trimmed(problemWhere),
      'problemCanRepeat': _trimmed(problemCanRepeat),
      'rating': _trimmed(rating),
      'ratingComment': _trimmed(ratingComment),
    };
  }

  bool get hasMeaningfulContent {
    return toJson().values.any((value) => value is String && value.isNotEmpty);
  }

  static String? _trimmed(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}

class FeedbackSubmissionResult {
  const FeedbackSubmissionResult({
    required this.id,
    required this.status,
    required this.createdAt,
    required this.screenshotAttached,
  });

  factory FeedbackSubmissionResult.fromJson(Map<String, dynamic> json) {
    return FeedbackSubmissionResult(
      id: (json['id'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'RECEIVED',
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.now(),
      screenshotAttached: json['screenshotAttached'] == true,
    );
  }

  final int id;
  final String status;
  final DateTime createdAt;
  final bool screenshotAttached;
}

class FeedbackRepository {
  const FeedbackRepository(this._dio);

  final Dio _dio;

  Future<FeedbackSubmissionResult> submit(FeedbackSubmissionDraft draft) async {
    final formData = FormData.fromMap({
      'payload': jsonEncode(draft.toJson()),
      if (draft.screenshotBytes != null && draft.screenshotFileName != null)
        'screenshot': MultipartFile.fromBytes(
          draft.screenshotBytes!,
          filename: draft.screenshotFileName,
          contentType: _imageContentType(draft.screenshotFileName!),
        ),
    });
    final response = await _dio.post<dynamic>(
      '/v1/feedback',
      data: formData,
      options: Options(headers: const {'Content-Type': 'multipart/form-data'}),
    );
    return FeedbackSubmissionResult.fromJson(
      ApiPayloadParser.dataMap(response.data),
    );
  }

  MediaType _imageContentType(String fileName) {
    final extension = path.extension(fileName).replaceFirst('.', '').toLowerCase();
    return MediaType('image', extension == 'jpg' ? 'jpeg' : extension);
  }
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  return FeedbackRepository(
    ref.watch(authenticatedDioProvider(AppConfig.userBaseUrl)),
  );
});
