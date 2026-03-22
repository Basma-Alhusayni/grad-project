import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailService {
  static const String _serviceId          = 'service_nnf4cbq';
  static const String _approvalTemplateId = 'template_x799etq';
  static const String _rejectionTemplateId= 'template_fg12fni';
  static const String _publicKey          = 'uvYNI_E7RB_e_-vMf';

  static const String _apiUrl =
      'https://api.emailjs.com/api/v1.0/email/send';

  /// Sends the approval email containing the temporary password.
  static Future<EmailResult> sendApprovalEmail({
    required String toEmail,
    required String toName,
    required String tempPassword,
  }) async {
    return _send(
      templateId: _approvalTemplateId,
      templateParams: {
        'to_name': toName,
        'to_email': toEmail,
        'temp_password': tempPassword,
        'app_name': 'BioShield',
      },
    );
  }

  /// Sends the rejection email with the admin-supplied reason.
  static Future<EmailResult> sendRejectionEmail({
    required String toEmail,
    required String toName,
    required String rejectionReason,
  }) async {
    return _send(
      templateId: _rejectionTemplateId,
      templateParams: {
        'to_name': toName,
        'to_email': toEmail,
        'rejection_reason': rejectionReason,
        'app_name': 'BioShield',
      },
    );
  }

  static Future<EmailResult> _send({
    required String templateId,
    required Map<String, String> templateParams,
  }) async {
    // Skip real HTTP call if credentials are still placeholders
    if (_serviceId.startsWith('YOUR_') ||
        _publicKey.startsWith('YOUR_')) {
      // ignore: avoid_print
      print('[EmailService] ⚠️ Credentials not set — '
          'would have emailed: ${templateParams['to_email']}');
      return EmailResult.success();
    }

    try {
      final response = await http
          .post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: jsonEncode({
          'service_id': _serviceId,
          'template_id': templateId,
          'user_id': _publicKey,
          'template_params': templateParams,
        }),
      )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) return EmailResult.success();
      return EmailResult.failure(
          'EmailJS ${response.statusCode}: ${response.body}');
    } catch (e) {
      return EmailResult.failure('فشل إرسال البريد: $e');
    }
  }
}

class EmailResult {
  final bool success;
  final String? error;

  EmailResult._({required this.success, this.error});

  factory EmailResult.success() => EmailResult._(success: true);
  factory EmailResult.failure(String error) =>
      EmailResult._(success: false, error: error);
}