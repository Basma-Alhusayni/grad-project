import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'expert_home_screen.dart';

class FirstLoginScreen extends StatefulWidget {
  const FirstLoginScreen({super.key});

  @override
  State<FirstLoginScreen> createState() => _FirstLoginScreenState();
}

class _FirstLoginScreenState extends State<FirstLoginScreen> {
  final _newPassController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _newPassVisible = false;
  bool _confirmVisible = false;
  bool _saving = false;

  String? _newPassError;
  String? _confirmError;

  static const _green600 = Color(0xFF16A34A);
  static const _green900 = Color(0xFF14532D);
  static const _green50 = Color(0xFFF0FDF4);

  // Attach live validators to both password fields when the screen opens
  @override
  void initState() {
    super.initState();
    _newPassController.addListener(_validateNewPass);
    _confirmController.addListener(_validateConfirm);
  }

  // Remove listeners and clean up both controllers
  @override
  void dispose() {
    _newPassController.removeListener(_validateNewPass);
    _confirmController.removeListener(_validateConfirm);
    _newPassController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  // Checks that the new password is at least 6 characters, and re-validates the confirm field if filled
  void _validateNewPass() {
    final v = _newPassController.text;
    setState(() {
      if (v.isEmpty) {
        _newPassError = null;
      } else if (v.length < 6) {
        _newPassError = 'يجب أن تكون 6 أحرف على الأقل';
      } else {
        _newPassError = null;
      }
    });
    if (_confirmController.text.isNotEmpty) _validateConfirm();
  }

  // Checks that the confirm password matches the new password
  void _validateConfirm() {
    final v = _confirmController.text;
    setState(() {
      if (v.isEmpty) {
        _confirmError = null;
      } else if (v != _newPassController.text) {
        _confirmError = 'كلمة المرور غير متطابقة';
      } else {
        _confirmError = null;
      }
    });
  }

  // Returns true only if both fields pass validation and the passwords match
  bool get _formValid =>
      _newPassError == null &&
          _confirmError == null &&
          _newPassController.text.length >= 6 &&
          _confirmController.text == _newPassController.text;

  // Validates both fields then calls AuthService to save the new password and navigate to the home screen
  Future<void> _submit() async {
    setState(() {
      if (_newPassController.text.isEmpty) {
        _newPassError = 'كلمة المرور الجديدة مطلوبة';
      }
      if (_confirmController.text.isEmpty) {
        _confirmError = 'تأكيد كلمة المرور مطلوب';
      }
    });
    if (!_formValid) return;

    setState(() => _saving = true);

    final err = await AuthService().changePasswordFirstTime(
      newPassword: _newPassController.text,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err, textDirection: TextDirection.rtl),
        backgroundColor: Colors.red,
      ));
    } else {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const ExpertHomeScreen()),
            (_) => false,
      );
    }
  }

  // Builds the first login screen with a welcome message, password rules hint, and two password fields
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _green50,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const SizedBox(height: 32),
                Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_reset,
                      color: _green600, size: 48),
                ),
                const SizedBox(height: 24),
                const Text(
                  'مرحباً بك في BioShield! 🌿',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: _green900,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'لأمان حسابك، يرجى تعيين كلمة مرور\nجديدة قبل البدء',
                  style: TextStyle(
                      fontSize: 14, color: Colors.grey, height: 1.6),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 16,
                          offset: Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFBFDBFE)),
                        ),
                        child: const Row(children: [
                          Icon(Icons.info_outline,
                              color: Color(0xFF3B82F6), size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'يجب أن تكون كلمة المرور 6 أحرف على الأقل',
                              style: TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontSize: 12),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 20),

                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text('كلمة المرور الجديدة',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151))),
                      ),
                      const SizedBox(height: 6),
                      _PasswordField(
                        hint: '••••••••',
                        controller: _newPassController,
                        visible: _newPassVisible,
                        errorText: _newPassError,
                        onToggle: () => setState(
                                () => _newPassVisible = !_newPassVisible),
                      ),
                      const SizedBox(height: 16),

                      const Align(
                        alignment: Alignment.centerRight,
                        child: Text('تأكيد كلمة المرور',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151))),
                      ),
                      const SizedBox(height: 6),
                      _PasswordField(
                        hint: '••••••••',
                        controller: _confirmController,
                        visible: _confirmVisible,
                        errorText: _confirmError,
                        onToggle: () => setState(
                                () => _confirmVisible = !_confirmVisible),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _green600,
                            disabledBackgroundColor:
                            _green600.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          child: _saving
                              ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2))
                              : const Text(
                            'حفظ كلمة المرور والمتابعة',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final String hint;
  final TextEditingController controller;
  final bool visible;
  final String? errorText;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.hint,
    required this.controller,
    required this.visible,
    required this.onToggle,
    this.errorText,
  });

  // Builds a password input field with a show/hide toggle and an inline error message
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: controller,
          obscureText: !visible,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          decoration: InputDecoration(
            hintText: hint,
            suffixIcon: IconButton(
              icon: Icon(
                visible ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey[400],
                size: 20,
              ),
              onPressed: onToggle,
            ),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: errorText != null
                      ? Colors.red
                      : const Color(0xFFD1D5DB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: errorText != null
                      ? Colors.red
                      : const Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color: errorText != null
                      ? Colors.red
                      : const Color(0xFF16A34A),
                  width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 4),
            child: Text(errorText!,
                style:
                const TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }
}