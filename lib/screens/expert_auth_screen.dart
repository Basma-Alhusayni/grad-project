import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/image_upload_service.dart';
import '../widgets/validated_field.dart';
import '../widgets/green_button.dart';
import 'expert_home_screen.dart';
import 'first_login_screen.dart';

class ExpertAuthScreen extends StatefulWidget {
  const ExpertAuthScreen({super.key});
  @override
  State<ExpertAuthScreen> createState() => _ExpertAuthScreenState();
}

class _ExpertAuthScreenState extends State<ExpertAuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _auth = AuthService();
  bool _loading = false;
  String? _error;
  bool _requestSent = false;
  bool _rememberMe = false;

  // Login controllers
  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();

  // Request controllers
  final _reqName = TextEditingController();
  final _reqEmail = TextEditingController();
  final _reqCerts = TextEditingController();
  final _reqExp = TextEditingController();

  final List<XFile> _certImages = [];

  // Real-time error variables
  String? _loginEmailError;
  String? _loginPassError;
  bool _loginPassVisible = false;

  String? _reqNameError;
  String? _reqEmailError;
  String? _reqCertsError;
  String? _reqExpError;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (!_tab.indexIsChanging) {
        setState(() => _error = null);
      }
    });

    _loginEmail.addListener(_validateLoginEmail);
    _loginPass.addListener(_validateLoginPass);
    _reqName.addListener(_validateReqName);
    _reqEmail.addListener(_validateReqEmail);
    _reqCerts.addListener(_validateReqCerts);
    _reqExp.addListener(_validateReqExp);
  }

  @override
  void dispose() {
    _tab.dispose();
    _loginEmail.dispose();
    _loginPass.dispose();
    _reqName.dispose();
    _reqEmail.dispose();
    _reqCerts.dispose();
    _reqExp.dispose();
    super.dispose();
  }

  // --- Real-time Validators ---
  void _validateLoginEmail() {
    final v = _loginEmail.text.trim();
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    setState(() => _loginEmailError = v.isEmpty ? null : (!regex.hasMatch(v) ? 'صيغة البريد غير صحيحة' : null));
  }

  void _validateLoginPass() {
    final v = _loginPass.text;
    setState(() => _loginPassError = (v.isNotEmpty && v.length < 6) ? 'يجب أن تكون 6 أحرف على الأقل' : null);
  }

  void _validateReqName() => setState(() => _reqNameError = _reqName.text.trim().isEmpty ? 'الاسم مطلوب' : null);

  void _validateReqEmail() {
    final v = _reqEmail.text.trim();
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    setState(() => _reqEmailError = v.isEmpty ? 'البريد مطلوب' : (!regex.hasMatch(v) ? 'صيغة غير صحيحة' : null));
  }

  void _validateReqCerts() => setState(() => _reqCertsError = _reqCerts.text.trim().isEmpty ? 'الشهادات مطلوبة' : null);

  void _validateReqExp() => setState(() => _reqExpError = _reqExp.text.trim().isEmpty ? 'الخبرة مطلوبة' : null);

  // --- Logic ---
  Future<void> _login() async {
    if (_loginEmail.text.trim().isEmpty || _loginPass.text.isEmpty) {
      setState(() => _error = 'يرجى ملء جميع الحقول');
      return;
    }
    if (_loginEmailError != null || _loginPassError != null) return;

    setState(() { _loading = true; _error = null; });

    final res = await _auth.specialistLogin(
        email: _loginEmail.text.trim(),
        password: _loginPass.text
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (res['error'] != null) {
      setState(() => _error = res['error']);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('remember_me', _rememberMe);

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          await FirebaseFirestore.instance.collection('specialists').doc(uid).update({
            'isOnline': true,
          });
        } catch (e) {
          debugPrint('Error updating online status: $e');
        }
      }

      if (res['isFirstLogin'] == true) {
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const FirstLoginScreen()),
                (_) => false
        );
      } else {
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const ExpertHomeScreen()),
                (_) => false
        );
      }
    }
  }

  Future<void> _submitRequest() async {
    _validateReqName(); _validateReqEmail(); _validateReqCerts(); _validateReqExp();
    if (_reqNameError != null || _reqEmailError != null || _reqCertsError != null || _reqExpError != null) return;

    if (_certImages.isEmpty) {
      setState(() => _error = 'يرجى إرفاق صورة واحدة على الأقل للشهادات');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      List<String> uploadedUrls = [];
      for (var xFile in _certImages) {
        String? url = await ImageUploadService.uploadImage(File(xFile.path));
        if (url != null) uploadedUrls.add(url);
      }

      final String? resultMessage = await _auth.submitSpecialistRequest(
        email: _reqEmail.text.trim(),
        fullName: _reqName.text.trim(),
        certificates: _reqCerts.text.trim(),
        experience: _reqExp.text.trim(),
        certificateImageUrls: uploadedUrls,
      );

      if (!mounted) return;
      setState(() {
        _loading = false;
        if (resultMessage == null) {
          _requestSent = true;
        } else {
          _error = resultMessage;
        }
      });
    } catch (e) {
      setState(() { _loading = false; _error = 'فشل الاتصال، يرجى المحاولة لاحقاً'; });
    }
  }

  void _showFullScreenImage(XFile image) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: InteractiveViewer(child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(File(image.path), fit: BoxFit.contain))),
              ),
              Positioned(
                top: 10, right: 10,
                child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle), padding: const EdgeInsets.all(8), child: const Icon(Icons.close, color: Colors.black, size: 24)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorBox(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB91C1C), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Align(
    alignment: Alignment.centerRight,
    child: Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF374151), fontWeight: FontWeight.w500)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: TextButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back, color: Color(0xFF16A34A)),
                            label: const Text('رجوع', style: TextStyle(color: Color(0xFF16A34A))),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                          child: const Icon(Icons.manage_accounts, size: 64, color: Color(0xFF16A34A)),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 4))]),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Container(
                              margin: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                              child: TabBar(
                                controller: _tab,
                                indicator: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(10)),
                                indicatorSize: TabBarIndicatorSize.tab,
                                labelColor: Colors.white,
                                unselectedLabelColor: Colors.grey[600],
                                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                                tabs: const [Tab(text: 'تسجيل الدخول'), Tab(text: 'إرسال طلب')],
                              ),
                            ),

                            if (_tab.index == 0) // --- LOGIN ---
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  _label('البريد الإلكتروني'),
                                  const SizedBox(height: 6),
                                  ValidatedField(controller: _loginEmail, hint: 'example@email.com', icon: Icons.email_outlined, errorText: _loginEmailError),
                                  const SizedBox(height: 12),
                                  _label('كلمة المرور'),
                                  const SizedBox(height: 6),
                                  PasswordField(
                                      controller: _loginPass,
                                      hint: '••••••••',
                                      visible: _loginPassVisible,
                                      errorText: _loginPassError,
                                      onToggle: () => setState(() => _loginPassVisible = !_loginPassVisible)
                                  ),
                                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    Row(children: [
                                      Checkbox(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v!), activeColor: const Color(0xFF16A34A)),
                                      const Text('تذكرني', style: TextStyle(fontSize: 12)),
                                    ]),
                                    TextButton(onPressed: () {}, child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: Color(0xFF16A34A), fontSize: 12))),
                                  ]),

                                  if (_error != null) _errorBox(_error!),

                                  const SizedBox(height: 10),
                                  // ICON REMOVED HERE
                                  GreenButton(label: 'تسجيل الدخول', onPressed: _login, isLoading: _loading),
                                  const SizedBox(height: 8),
                                ]),
                              ),

                            if (_tab.index == 1) // --- REQUEST ---
                              _requestSent
                                  ? Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(children: [
                                  const Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 48),
                                  const SizedBox(height: 12),
                                  const Text('تم إرسال طلبك بنجاح!', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF14532D))),
                                  const Text('سيتم مراجعة بياناتك وإبلاغك عبر البريد.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                                ]),
                              )
                                  : Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                  _label('الاسم الكامل'),
                                  ValidatedField(controller: _reqName, hint: 'أدخل اسمك الكامل', icon: Icons.person_outline, errorText: _reqNameError),
                                  const SizedBox(height: 12),
                                  _label('البريد الإلكتروني'),
                                  ValidatedField(controller: _reqEmail, hint: 'example@email.com', icon: Icons.email_outlined, errorText: _reqEmailError, keyboardType: TextInputType.emailAddress),
                                  const SizedBox(height: 12),
                                  _label('الشهادات والمؤهلات'),
                                  ValidatedField(controller: _reqCerts, hint: 'مثال: بكالوريوس في علوم الزراعة', icon: Icons.workspace_premium_outlined, errorText: _reqCertsError),
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed: () async {
                                      final picker = ImagePicker();
                                      final images = await picker.pickMultiImage();
                                      if (images.isNotEmpty) setState(() => _certImages.addAll(images));
                                    },
                                    icon: const Icon(Icons.add_photo_alternate, color: Color(0xFF16A34A)),
                                    label: const Text('إدراج صور الشهادات', style: TextStyle(color: Color(0xFF16A34A))),
                                    style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: Color(0xFF86EFAC)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        minimumSize: const Size(double.infinity, 44)
                                    ),
                                  ),

                                  if (_certImages.isNotEmpty) ...[
                                    const SizedBox(height: 16),
                                    const Align(
                                      alignment: Alignment.centerRight,
                                      child: Text('معاينة الملفات المختارة (اضغط للتكبير):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 100,
                                      child: ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _certImages.length,
                                        itemBuilder: (context, index) {
                                          return Stack(
                                            children: [
                                              GestureDetector(
                                                onTap: () => _showFullScreenImage(_certImages[index]),
                                                child: Container(
                                                  margin: const EdgeInsets.only(left: 8),
                                                  width: 100,
                                                  height: 100,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: Colors.grey.shade300),
                                                    image: DecorationImage(image: FileImage(File(_certImages[index].path)), fit: BoxFit.cover),
                                                  ),
                                                ),
                                              ),
                                              Positioned(
                                                top: 2, left: 10,
                                                child: GestureDetector(
                                                  onTap: () => setState(() => _certImages.removeAt(index)),
                                                  child: Container(decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle), child: const Icon(Icons.close, color: Colors.white, size: 16)),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 12),
                                  _label('الخبرات المهنية'),
                                  ValidatedField(controller: _reqExp, hint: 'اذكر سنوات الخبرة ومكان العمل', icon: Icons.description_outlined, errorText: _reqExpError),

                                  if (_error != null) _errorBox(_error!),

                                  const SizedBox(height: 20),
                                  // ICON REMOVED HERE
                                  GreenButton(label: 'إرسال طلب الانضمام', onPressed: _submitRequest, isLoading: _loading),
                                ]),
                              ),
                          ]),
                        ),

                        // --- SPACER PUSHES TEXT TO BOTTOM ---
                        const Spacer(),

                        const Text('جميع الحقوق محفوظة © 2026 BioShield', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 8),
                      ]),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}