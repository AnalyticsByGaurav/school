import 'package:flutter/material.dart';
import '../api/client.dart';
import '../utils/session.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});
  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  static bool get _isTeacher =>
      !['student', 'parent'].contains(Session.userRole);

  @override
  Widget build(BuildContext context) {
    if (!_isTeacher) return const _StudentAttendanceView();

    return const Scaffold(
      body: _TeacherMarkView(),
    );
  }
}

// ── Student / parent monthly view ─────────────────────────────────────────────
class _StudentAttendanceView extends StatefulWidget {
  const _StudentAttendanceView();
  @override
  State<_StudentAttendanceView> createState() => _StudentAttendanceViewState();
}

class _StudentAttendanceViewState extends State<_StudentAttendanceView> {
  bool _loading = true;
  String _error = '';
  Map<String, dynamic>? _data;
  final _now = DateTime.now();

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    final month = '${_now.year}-${_now.month.toString().padLeft(2, '0')}';
    final res = await Api.get('api/attendance.php', params: {'month': month});
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() { _data = res['data'] as Map<String, dynamic>?; _loading = false; });
    } else {
      setState(() {
        _error = res['message'] as String? ?? 'Failed to load attendance';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.grey),
        const SizedBox(height: 8),
        Text(_error, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _load, child: const Text('Retry')),
      ]));
    }

    final records = _data?['records'] as List<dynamic>? ?? [];
    final summary = _data?['summary'] as Map<String, dynamic>? ?? {};
    final present = (summary['present'] as num?)?.toInt() ?? 0;
    final absent  = (summary['absent']  as num?)?.toInt() ?? 0;
    final late    = (summary['late']    as num?)?.toInt() ?? 0;
    final total   = present + absent + late;
    final pct     = total > 0 ? (present / total * 100).toStringAsFixed(1) : '0';

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: const Color(0xFF1A56DB),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Text('$pct%',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
                const Text('Attendance This Month',
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _stat('Present', present, Colors.green),
                  _stat('Absent',  absent,  Colors.red),
                  _stat('Late',    late,    Colors.orange),
                ]),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Daily Records',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ...records.map((r) {
            final rec = r as Map<String, dynamic>;
            final s = rec['status'] as String? ?? '';
            Color c = Colors.grey;
            if (s == 'present')  c = Colors.green;
            else if (s == 'absent')   c = Colors.red;
            else if (s == 'late')     c = Colors.orange;
            else if (s == 'half_day') c = Colors.amber;
            return ListTile(
              dense: true,
              title: Text(rec['date'] as String? ?? ''),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                    color: c.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(s.toUpperCase(),
                    style: TextStyle(
                        color: c, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _stat(String label, int val, Color c) => Column(children: [
    Text('$val', style: TextStyle(color: c, fontSize: 22, fontWeight: FontWeight.bold)),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
  ]);
}

// ── Teacher class marking view ────────────────────────────────────────────────
class _TeacherMarkView extends StatefulWidget {
  const _TeacherMarkView();
  @override
  State<_TeacherMarkView> createState() => _TeacherMarkViewState();
}

class _TeacherMarkViewState extends State<_TeacherMarkView> {
  // Meta (from timetable)
  bool _metaLoading = true;
  List<Map<String, dynamic>> _classes = [];

  // Selections
  int?   _selClassId;
  int?   _selSectionId;
  String _date = DateTime.now().toIso8601String().substring(0, 10);
  final  _dateCtrl = TextEditingController();

  // Roster
  bool _rosterLoading = false;
  List<Map<String, dynamic>> _students = [];
  final Map<int, String> _statuses = {}; // student_id → status

  bool _submitting = false;
  String _msg = '';

  static const _statusOptions = ['present', 'absent', 'late', 'half_day', 'leave'];
  static const _statusColors  = {
    'present':  Colors.green,
    'absent':   Colors.red,
    'late':     Colors.orange,
    'half_day': Colors.amber,
    'leave':    Colors.blue,
  };

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = _date;
    _loadMeta();
  }

  @override
  void dispose() { _dateCtrl.dispose(); super.dispose(); }

  Future<void> _loadMeta() async {
    setState(() { _metaLoading = true; });
    try {
      final res = await Api.get('api/timetable.php');
      if (!mounted) return;

      final days = (res['data']?['days'] as List<dynamic>?) ?? [];
      // Key by section_id so multiple sections of the same class all appear
      final Map<int, Map<String, dynamic>> classMap = {};
      for (final day in days) {
        for (final p in ((day as Map)['periods'] as List<dynamic>? ?? [])) {
          final period = p as Map<String, dynamic>;
          if (period['is_break'] == 1) continue;
          final cid = period['class_id'];
          final sid = period['section_id'];
          if (cid == null) continue;
          final key = (sid as int?) ?? (cid as int);
          classMap[key] = {
            'id': cid as int,
            'name': period['class_name'] ?? 'Class $cid',
            'section_id': sid as int?,
            'section_name': period['section_name'] ?? '',
          };
        }
      }

      // Fallback: if no timetable entries, load all school classes
      if (classMap.isEmpty) {
        final clsRes = await Api.get('api/classes.php');
        if (!mounted) return;
        final clsList = (clsRes['data']?['classes'] as List<dynamic>?) ?? [];
        for (final cls in clsList) {
          final c = cls as Map<String, dynamic>;
          final cid = (c['class_id'] as num).toInt();
          final secId = (c['section_id'] as num?)?.toInt();
          final key = secId ?? cid;
          classMap[key] = {
            'id': cid,
            'name': c['class_name'] as String? ?? '',
            'section_id': secId,
            'section_name': c['section_name'] as String? ?? '',
          };
        }
      }

      if (!mounted) return;
      setState(() {
        _classes = classMap.values.toList();
        _metaLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() { _classes = []; _metaLoading = false; });
    }
  }

  Future<void> _loadRoster() async {
    if (_selClassId == null) return;
    setState(() { _rosterLoading = true; _students = []; _statuses.clear(); });
    final res = await Api.get('api/attendance.php', params: {
      'class_id':   _selClassId,
      'section_id': _selSectionId,
      'date':       _date,
    });
    if (!mounted) return;
    if (res['success'] == true) {
      final list = (res['data']?['students'] as List<dynamic>?) ?? [];
      final students = list.cast<Map<String, dynamic>>();
      final Map<int, String> statuses = {};
      for (final s in students) {
        final stuId = (s['id'] as num).toInt();
        statuses[stuId] = s['status'] as String? ?? 'present';
      }
      setState(() {
        _students = students;
        _statuses.addAll(statuses);
        _rosterLoading = false;
      });
    } else {
      setState(() {
        _msg = res['message'] as String? ?? 'Failed to load students';
        _rosterLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_students.isEmpty) return;
    setState(() { _submitting = true; _msg = ''; });
    final records = _students.map((s) {
      final stuId = (s['id'] as num).toInt();
      return {'student_id': stuId, 'status': _statuses[stuId] ?? 'present'};
    }).toList();

    final res = await Api.post('api/attendance.php', {
      'class_id':   _selClassId,
      'section_id': _selSectionId,
      'date':       _date,
      'records':    records,
    });
    if (!mounted) return;
    if (res['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] as String? ?? 'Attendance saved!')));
      setState(() { _submitting = false; });
    } else {
      setState(() {
        _submitting = false;
        _msg = res['message'] as String? ?? 'Failed to save attendance';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_metaLoading) return const Center(child: CircularProgressIndicator());
    if (_classes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No classes assigned to you.',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return Column(children: [
      // Filters
      Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          if (_msg.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(_msg, style: const TextStyle(color: Colors.red)),
            ),

          Row(children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _selSectionId ?? _selClassId,
                decoration: const InputDecoration(
                    labelText: 'Class', border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                items: _classes.map((c) {
                  final uid = (c['section_id'] as int?) ?? (c['id'] as int);
                  final sec = c['section_name'] as String? ?? '';
                  return DropdownMenuItem<int>(
                    value: uid,
                    child: Text(
                      sec.isNotEmpty ? '${c['name']} — $sec' : c['name'] as String,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v == null) return;
                  final cls = _classes.firstWhere(
                      (c) => ((c['section_id'] as int?) ?? (c['id'] as int)) == v);
                  setState(() {
                    _selClassId   = cls['id'] as int;
                    _selSectionId = cls['section_id'] as int?;
                    _students = [];
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: _dateCtrl,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today, size: 18),
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    _date = picked.toIso8601String().substring(0, 10);
                    _dateCtrl.text = _date;
                    if (_selClassId != null || _selSectionId != null) _loadRoster();
                  }
                },
              ),
            ),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.search),
              label: const Text('Load Students'),
              onPressed: (_selClassId != null || _selSectionId != null) ? _loadRoster : null,
            ),
          ),
        ]),
      ),

      // Roster
      Expanded(
        child: _rosterLoading
            ? const Center(child: CircularProgressIndicator())
            : _students.isEmpty
                ? const Center(child: Text('Select a class and tap Load Students'))
                : Column(children: [
                    // Quick-set all buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(children: [
                        const Text('Mark all:', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        ..._statusOptions.take(3).map((s) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ActionChip(
                            label: Text(s[0].toUpperCase(),
                                style: TextStyle(color: _statusColors[s], fontSize: 12)),
                            padding: EdgeInsets.zero,
                            onPressed: () => setState(() {
                              for (final st in _students) {
                                _statuses[(st['id'] as num).toInt()] = s;
                              }
                            }),
                          ),
                        )),
                      ]),
                    ),
                    const Divider(height: 8),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        itemCount: _students.length,
                        itemBuilder: (_, i) {
                          final s = _students[i];
                          final stuId = (s['id'] as num).toInt();
                          final current = _statuses[stuId] ?? 'present';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              child: Row(children: [
                                CircleAvatar(
                                  radius: 18,
                                  backgroundColor:
                                      const Color(0xFF1A56DB).withOpacity(0.1),
                                  child: Text(
                                    (s['roll_number'] as String? ?? '?')
                                        .substring(0, 1),
                                    style: const TextStyle(
                                        color: Color(0xFF1A56DB),
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s['name'] as String? ?? '',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      Text('Roll: ${s['roll_number'] ?? ''}',
                                          style: const TextStyle(
                                              fontSize: 12, color: Colors.grey)),
                                    ])),
                                // Status selector
                                DropdownButton<String>(
                                  value: current,
                                  underline: const SizedBox(),
                                  style: TextStyle(
                                      color: _statusColors[current] ?? Colors.grey,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                  items: _statusOptions
                                      .map((opt) => DropdownMenuItem(
                                            value: opt,
                                            child: Text(
                                              opt[0].toUpperCase() +
                                                  opt.substring(1).replaceAll('_', ' '),
                                              style: TextStyle(
                                                  color: _statusColors[opt] ??
                                                      Colors.grey,
                                                  fontWeight: FontWeight.bold),
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (v) => setState(
                                      () => _statuses[stuId] = v ?? 'present'),
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.check),
                          label: _submitting
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Save Attendance'),
                          onPressed: _submitting ? null : _submit,
                        ),
                      ),
                    ),
                  ]),
      ),
    ]);
  }
}
