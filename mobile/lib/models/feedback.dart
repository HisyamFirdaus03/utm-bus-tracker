enum FeedbackStatus { newSubmission, inProgress, resolved }

FeedbackStatus _statusFromString(String? s) {
  switch (s) {
    case 'in_progress':
      return FeedbackStatus.inProgress;
    case 'resolved':
      return FeedbackStatus.resolved;
    case 'new':
    default:
      return FeedbackStatus.newSubmission;
  }
}

String _statusToString(FeedbackStatus s) {
  switch (s) {
    case FeedbackStatus.newSubmission:
      return 'new';
    case FeedbackStatus.inProgress:
      return 'in_progress';
    case FeedbackStatus.resolved:
      return 'resolved';
  }
}

class BusFeedback {
  final String id;
  final String studentId;
  final String busId;
  final String description;
  final String? screenshotUrl;
  final FeedbackStatus status;
  final String? adminResponse;
  final DateTime timestamp;

  const BusFeedback({
    required this.id,
    required this.studentId,
    required this.busId,
    required this.description,
    required this.status,
    required this.timestamp,
    this.screenshotUrl,
    this.adminResponse,
  });

  factory BusFeedback.fromJson(Map<String, dynamic> json) {
    return BusFeedback(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      busId: json['bus_id'] as String,
      description: json['description'] as String,
      screenshotUrl: json['screenshot_url'] as String?,
      status: _statusFromString(json['status'] as String?),
      adminResponse: json['admin_response'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'student_id': studentId,
        'bus_id': busId,
        'description': description,
        'screenshot_url': screenshotUrl,
        'status': _statusToString(status),
        'admin_response': adminResponse,
        'timestamp': timestamp.toIso8601String(),
      };
}
