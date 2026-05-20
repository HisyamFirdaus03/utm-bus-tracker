import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/api_client.dart';
import '../../models/feedback.dart';
import '../repositories/feedback_repository.dart';

class ApiFeedbackRepository implements FeedbackRepository {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  Future<BusFeedback> submit({
    required String busId,
    required String description,
    File? screenshot,
  }) async {
    String? screenshotUrl;
    if (screenshot != null) {
      screenshotUrl = await _uploadScreenshot(screenshot);
    }

    final response = await ApiClient.instance.dio.post(
      '/api/feedbacks/',
      data: {
        'bus_id': busId,
        'description': description,
        'screenshot_url': ?screenshotUrl,
      },
    );
    return BusFeedback.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<List<BusFeedback>> getMyFeedback() async {
    final response = await ApiClient.instance.dio.get('/api/feedbacks/');
    final list = response.data as List;
    return list
        .map((e) => BusFeedback.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<String> _uploadScreenshot(File file) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw ApiException('Must be signed in to attach a screenshot');
    }
    final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref('feedback_screenshots/$uid/$filename');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }
}
