import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/green_button.dart';
import 'expert_home_screen.dart';

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

  final _loginEmail = TextEditingController();
  final _loginPass = TextEditingController();
  final _reqName = TextEditingController();
  final _reqEmail = TextEditingController();
  final _reqCerts = TextEditingController();
  final _reqExp = TextEditingController();
  final List<XFile> _certImages = [];

  final _loginKey = GlobalKey<FormState>();
  final _reqKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_loginKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final res = await _auth.specialistLogin(
        email: _loginEmail.text.trim(), password: _loginPass.text);
    if (!mounted) return;
    setState(() => _loading = false);
    if (res['error'] != null) {
      setState(() => _error = res['error']);
    } else {
      Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const ExpertHomeScreen()),
              (_) => false);
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    setState(() => _certImages.addAll(images));
  }

  Future<void> _submitRequest() async {
    if (!_reqKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    final err = await _auth.submitSpecialistRequest(
      email: _reqEmail.text.trim(),
      fullName: _reqName.text.trim(),
      certificates: _reqCerts.text.trim(),
      experience: _reqExp.text.trim(),
    );
    if (!mounted) return;
    setState(() { _loading = false; _requestSent = err == null; });
    if (err != null) setState(() => _error = err);
  }

  Widget _label(String text) => Align(
    alignment: Alignment.centerRight,
    child: Text(text,
        style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF374151),
            fontWeight: FontWeight.w500)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF4),
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(children: [
              Row(children: [
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF16A34A)),
                  label: const Text('رجوع', style: TextStyle(color: Color(0xFF16A34A))),
                ),
              ]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7), shape: BoxShape.circle),
                child: const Icon(Icons.manage_accounts, size: 40, color: Color(0xFF16A34A)),
              ),
              const SizedBox(height: 12),
              const Text('حساب الخبير',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF14532D))),
              const Text('سجل دخول أو أرسل طلب خبير',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 4))
                    ]),
                child: Column(children: [
                  Container(
                    margin: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12)),
                    child: TabBar(
                      controller: _tab,
                      indicator: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(10)),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.grey[600],
                      tabs: const [
                        Tab(text: 'تسجيل الدخول'),
                        Tab(text: 'إرسال طلب'),
                      ],
                    ),
                  ),
                  // Error banner
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFFECACA))),
                        child: Row(children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(_error!,
                              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13))),
                        ]),
                      ),
                    ),

                  // ── LOGIN TAB ──────────────────────────────────────────
                  if (_tab.index == 0)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _loginKey,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          _label('البريد الإلكتروني'),
                          const SizedBox(height: 6),
                          AuthTextField(
                            hint: 'example@email.com',
                            icon: Icons.email_outlined,
                            controller: _loginEmail,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: 12),
                          _label('كلمة المرور'),
                          const SizedBox(height: 6),
                          AuthTextField(
                            hint: '••••••••',
                            icon: Icons.lock_outline,
                            controller: _loginPass,
                            obscure: true,
                            validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: 16),
                          GreenButton(
                            label: 'الدخول كخبير',
                            icon: Icons.shield,
                            onPressed: _login,
                            isLoading: _loading,
                          ),
                          const SizedBox(height: 8),
                        ]),
                      ),
                    ),

                  // ── REQUEST TAB ────────────────────────────────────────
                  if (_tab.index == 1)
                    _requestSent
                        ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF86EFAC))),
                        child: const Column(children: [
                          Icon(Icons.check_circle, color: Color(0xFF16A34A), size: 48),
                          SizedBox(height: 8),
                          Text('تم إرسال طلبك بنجاح!',
                              style: TextStyle(fontWeight: FontWeight.bold,
                                  color: Color(0xFF14532D), fontSize: 16)),
                          SizedBox(height: 4),
                          Text(
                              'سيتم مراجعته من قبل الإدارة وسيتم إرسال كلمة المرور إلى بريدك الإلكتروني عند الموافقة.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ]),
                      ),
                    )
                        : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _reqKey,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          _label('الاسم الكامل'),
                          const SizedBox(height: 6),
                          AuthTextField(
                            hint: 'أدخل اسمك الكامل',
                            icon: Icons.person_outline,
                            controller: _reqName,
                            validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: 12),
                          _label('البريد الإلكتروني'),
                          const SizedBox(height: 6),
                          AuthTextField(
                            hint: 'example@email.com',
                            icon: Icons.email_outlined,
                            controller: _reqEmail,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: 12),
                          _label('الشهادات'),
                          const SizedBox(height: 6),
                          AuthTextField(
                            hint: 'اذكر شهاداتك العلمية والمهنية...',
                            icon: Icons.workspace_premium_outlined,
                            controller: _reqCerts,
                            validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _pickImages,
                            icon: const Icon(Icons.upload, color: Color(0xFF16A34A)),
                            label: const Text('إدراج صور الشهادات',
                                style: TextStyle(color: Color(0xFF16A34A))),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF86EFAC)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              minimumSize: const Size(double.infinity, 44),
                            ),
                          ),
                          if (_certImages.isNotEmpty)
                            SizedBox(
                              height: 80,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _certImages.length,
                                itemBuilder: (_, i) => Stack(children: [
                                  Container(
                                    margin: const EdgeInsets.only(right: 8, top: 4),
                                    width: 70, height: 70,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF86EFAC)),
                                      image: DecorationImage(
                                        image: FileImage(File(_certImages[i].path)),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 0, right: 4,
                                    child: GestureDetector(
                                      onTap: () => setState(() => _certImages.removeAt(i)),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                            color: Colors.red, shape: BoxShape.circle),
                                        child: const Icon(Icons.close,
                                            color: Colors.white, size: 12),
                                      ),
                                    ),
                                  ),
                                ]),
                              ),
                            ),
                          const SizedBox(height: 12),
                          _label('الخبرات'),
                          const SizedBox(height: 6),
                          AuthTextField(
                            hint: 'اذكر خبراتك في مجال النباتات...',
                            icon: Icons.description_outlined,
                            controller: _reqExp,
                            validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFBFDBFE))),
                            child: const Row(children: [
                              Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                    'سيتم إرسال كلمة المرور الخاصة بك إلى بريدك الإلكتروني بعد الموافقة على طلبك من قبل الإدارة',
                                    style: TextStyle(color: Color(0xFF1D4ED8), fontSize: 12)),
                              ),
                            ]),
                          ),
                          const SizedBox(height: 14),
                          GreenButton(
                            label: 'إرسال الطلب',
                            icon: Icons.shield,
                            onPressed: _submitRequest,
                            isLoading: _loading,
                          ),
                          const SizedBox(height: 8),
                        ]),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 16),
              const Text('جميع الحقوق محفوظة © 2025 BioShield',
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
            ]),
          ),
        ),
      ),
    );
  }
}