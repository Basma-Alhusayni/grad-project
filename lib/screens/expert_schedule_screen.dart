import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ExpertScheduleScreen extends StatefulWidget {
  const ExpertScheduleScreen({super.key});

  @override
  State<ExpertScheduleScreen> createState() =>
      _ExpertScheduleScreenState();
}

class _ExpertScheduleScreenState extends State<ExpertScheduleScreen> {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  DateTime _currentDate = DateTime.now();
  DateTime? _selectedDate;
  String _editStart = '09:00';
  String _editEnd = '17:00';

  // scheduleData: key = 'yyyy-MM-dd', value = {isAvailable, startTime, endTime}
  Map<String, Map<String, dynamic>> _scheduleData = {};

  final List<String> _monthNames = [
    'يناير', 'فبراير', 'مارس', 'إبريل', 'مايو', 'يونيو',
    'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];

  final List<String> _dayNames = [
    'الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء',
    'الخميس', 'الجمعة', 'السبت',
  ];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  // ── تحميل الجدول من Firestore ──────────────────────────────
  Future<void> _loadSchedule() async {
    final doc =
    await _db.collection('expertSchedules').doc(_uid).get();
    if (doc.exists) {
      final data = doc.data() ?? {};
      setState(() {
        _scheduleData = data.map((k, v) =>
            MapEntry(k, Map<String, dynamic>.from(v)));
      });
    }
  }

  // ── حفظ الجدول في Firestore ────────────────────────────────
  Future<void> _saveToFirestore() async {
    await _db
        .collection('expertSchedules')
        .doc(_uid)
        .set(_scheduleData);
  }

  String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isPast(DateTime date) {
    final today = DateTime.now();
    return date
        .isBefore(DateTime(today.year, today.month, today.day));
  }

  List<DateTime?> _getDaysInMonth(DateTime date) {
    final first = DateTime(date.year, date.month, 1);
    final last = DateTime(date.year, date.month + 1, 0);
    final List<DateTime?> days = [];

    // خلايا فارغة قبل بداية الشهر
    for (int i = 0; i < first.weekday % 7; i++) {
      days.add(null);
    }
    for (int d = 1; d <= last.day; d++) {
      days.add(DateTime(date.year, date.month, d));
    }
    return days;
  }

  // ── حفظ/تحديث يوم ──────────────────────────────────────────
  void _saveDay(bool isAvailable) {
    if (_selectedDate == null) return;
    final key = _dateKey(_selectedDate!);
    setState(() {
      _scheduleData[key] = {
        'isAvailable': isAvailable,
        'startTime': _editStart,
        'endTime': _editEnd,
      };
      _selectedDate = null;
    });
    _saveToFirestore();
    _showSnack(isAvailable ? 'تم تفعيل اليوم' : 'تم إغلاق اليوم');
  }

  // ── حذف يوم ────────────────────────────────────────────────
  void _deleteDay() {
    if (_selectedDate == null) return;
    final key = _dateKey(_selectedDate!);
    setState(() {
      _scheduleData.remove(key);
      _selectedDate = null;
    });
    _saveToFirestore();
    _showSnack('تم إزالة الجدول');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
      Text(msg, textDirection: TextDirection.rtl),
      backgroundColor: Colors.green[700],
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── ديالوج تعديل اليوم ─────────────────────────────────────
  void _showEditDialog(DateTime date) {
    final key = _dateKey(date);
    final existing = _scheduleData[key];
    setState(() {
      _selectedDate = date;
      _editStart = existing?['startTime'] ?? '09:00';
      _editEnd = existing?['endTime'] ?? '17:00';
    });

    showDialog(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(
              'تعديل ${_dayNames[date.weekday % 7]} - ${date.day} ${_monthNames[date.month - 1]}',
              style: const TextStyle(fontSize: 15),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // الحالة الحالية
                if (existing != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: existing['isAvailable'] == true
                          ? Colors.green
                          : Colors.red,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'الحالة الحالية: ${existing['isAvailable'] == true ? 'متاح' : 'مغلق'}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 14),

                // وقت البداية
                const Text('وقت البداية',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final parts = _editStart.split(':');
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay(
                          hour: int.parse(parts[0]),
                          minute: int.parse(parts[1])),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        _editStart =
                        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border:
                      Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_editStart,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const Icon(Icons.access_time,
                            color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // وقت النهاية
                const Text('وقت النهاية',
                    style: TextStyle(fontSize: 13)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final parts = _editEnd.split(':');
                    final picked = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay(
                          hour: int.parse(parts[0]),
                          minute: int.parse(parts[1])),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        _editEnd =
                        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border:
                      Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_editEnd,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold)),
                        const Icon(Icons.access_time,
                            color: Colors.grey),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              if (existing != null)
                TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.red),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _deleteDay();
                  },
                  child: const Text('إزالة'),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.close, size: 16),
                label: const Text('مغلق'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _saveDay(false);
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16a34a)),
                icon: const Icon(Icons.check, size: 16),
                label: const Text('متاح'),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _saveDay(true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth(_currentDate);
    final availableDays = _scheduleData.values
        .where((s) => s['isAvailable'] == true)
        .length;
    final closedDays = _scheduleData.values
        .where((s) => s['isAvailable'] == false)
        .length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── العنوان ─────────────────────────────────────
            const Text('جدول الأوقات',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF166534))),
            const SizedBox(height: 4),
            const Text('حدد أوقات توفرك لاستقبال الطلبات',
                style:
                TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 14),

            // ── إحصائيات ────────────────────────────────────
            Row(
              children: [
                _statBox('$availableDays', 'أيام متاحة',
                    Colors.green),
                const SizedBox(width: 10),
                _statBox(
                    '$closedDays', 'أيام مغلقة', Colors.blue),
              ],
            ),
            const SizedBox(height: 14),

            // ── التقويم ──────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8)
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  // التنقل بين الأشهر
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                            Icons.chevron_right,
                            color: Color(0xFF16a34a)),
                        onPressed: () => setState(() {
                          _currentDate = DateTime(
                              _currentDate.year,
                              _currentDate.month - 1);
                        }),
                      ),
                      Text(
                        '${_monthNames[_currentDate.month - 1]} ${_currentDate.year}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      IconButton(
                        icon: const Icon(
                            Icons.chevron_left,
                            color: Color(0xFF16a34a)),
                        onPressed: () => setState(() {
                          _currentDate = DateTime(
                              _currentDate.year,
                              _currentDate.month + 1);
                        }),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // أسماء الأيام
                  Row(
                    children: _dayNames
                        .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d.substring(0, 3),
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600]),
                        ),
                      ),
                    ))
                        .toList(),
                  ),
                  const SizedBox(height: 6),

                  // شبكة الأيام
                  GridView.builder(
                    shrinkWrap: true,
                    physics:
                    const NeverScrollableScrollPhysics(),
                    gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 7,
                      mainAxisSpacing: 4,
                      crossAxisSpacing: 4,
                    ),
                    itemCount: days.length,
                    itemBuilder: (context, index) {
                      final date = days[index];
                      if (date == null) {
                        return const SizedBox();
                      }

                      final key = _dateKey(date);
                      final schedule = _scheduleData[key];
                      final isAvailable =
                          schedule?['isAvailable'] == true;
                      final isClosed = schedule != null &&
                          schedule['isAvailable'] == false;
                      final past = _isPast(date);
                      final today = _isToday(date);

                      return GestureDetector(
                        onTap: past
                            ? null
                            : () => _showEditDialog(date),
                        child: Container(
                          decoration: BoxDecoration(
                            color: past
                                ? Colors.grey[100]
                                : isAvailable
                                ? const Color(0xFFdcfce7)
                                : isClosed
                                ? const Color(
                                0xFFFEF2F2)
                                : Colors.white,
                            borderRadius:
                            BorderRadius.circular(8),
                            border: Border.all(
                              color: today
                                  ? Colors.blue
                                  : isAvailable
                                  ? const Color(
                                  0xFF16a34a)
                                  : isClosed
                                  ? Colors.red
                                  .shade300
                                  : Colors.grey[200]!,
                              width: today ? 2 : 1,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: today
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: past
                                      ? Colors.grey[400]
                                      : isAvailable
                                      ? const Color(
                                      0xFF15803d)
                                      : isClosed
                                      ? Colors.red
                                      .shade600
                                      : Colors
                                      .grey[700],
                                ),
                              ),
                              if (isAvailable)
                                Positioned(
                                  bottom: 2,
                                  child: Icon(Icons.check,
                                      size: 8,
                                      color: const Color(
                                          0xFF16a34a)),
                                ),
                              if (isClosed)
                                Positioned(
                                  bottom: 2,
                                  child: Icon(Icons.close,
                                      size: 8,
                                      color:
                                      Colors.red.shade600),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // مفتاح الألوان
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _legendItem(const Color(0xFFdcfce7),
                          const Color(0xFF16a34a), 'متاح'),
                      _legendItem(const Color(0xFFFEF2F2),
                          Colors.red.shade300, 'مغلق'),
                      _legendItem(
                          Colors.white, Colors.grey, 'لم يُحدد'),
                      _legendItem(
                          Colors.white, Colors.blue, 'اليوم',
                          isToday: true),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── تلميح ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                border:
                Border.all(color: const Color(0xFFBFDBFE)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline,
                      color: Color(0xFF3B82F6), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'اضغط على أي يوم لتحديد أوقات العمل أو تعطيله',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1D4ED8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(
      String value, String label, MaterialColor color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.shade50,
          border: Border.all(color: color.shade200),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color.shade700)),
            Text(label,
                style: TextStyle(
                    fontSize: 11, color: color.shade600)),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(Color bg, Color border, String label,
      {bool isToday = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(
                color: border, width: isToday ? 2 : 1),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: Colors.grey[600])),
      ],
    );
  }
}