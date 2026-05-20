import 'dart:io';

import '../../models/feedback.dart';

abstract class FeedbackRepository {
  /// Submit a new feedback row. If [screenshot] is provided, it's uploaded to
  /// Firebase Storage first and the resulting download URL is attached.
  Future<BusFeedback> submit({
    required String busId,
    required String description,
    File? screenshot,
  });

  /// All feedback rows submitted by the currently authenticated student,
  /// newest first.
  Future<List<BusFeedback>> getMyFeedback();
}
