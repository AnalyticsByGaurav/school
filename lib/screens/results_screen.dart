import 'package:flutter/material.dart';
import '../api/client.dart';
import '../utils/session.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  static bool get _isTeacher =>
      !['student', 'parent'].contains(Session.userRole);

  bool _loading = true;
  String _error = '';
  List<dynamic> _exams = [];

  // Teacher: class picker loaded from timetable
  List<Map<String, dynamic>> _classes = [];
  int? _selClassId;
  int? _selSectionId;

  int? _selExamId;
  bool _resultLoading = false;
  Map<String, dynamic>? _result;

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    setState(() { _loading = true; _error = ''; _exams = []; _classes = []; });
    try {
    // Load exams
    final res = await Api.get('api/results.php', params: {'exams': 1});
    if (!mounted) return;
    if (res['success'] != true) {
      setState(() {
        _error = res['message'] as String? ?? 'Failed to load exams';
      });
      return;
    }
    final d = res['data'] as Map<String, dynamic>?;
    final exams = d?['exams'] as List<dynamic>? ?? [];
    setState(() { _exams = exams; });

    // For teacher: load class list from timetable, fallback to all school classes
    if (_isTeacher) {
      final ttRes = await Api.get('api/timetable.php');
      if (!mounted) return;
      final days = (ttRes['data']?['days'] as List<dynamic>?) ?? [];
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
      setState(() { _classes = classMap.values.toList(); });
    }

    // Auto-select first exam for student
    if (!_isTeacher && exams.isNotEmpty) {
      final first = exams[0] as Map<String, dynamic>;
      _fetchResult(first['id'] as int, null, null);
    }
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Failed to load. Please retry.'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _fetchResult(int examId, int? classId, int? sectionId) async {
    setState(() {
      _selExamId = examId;
      _resultLoading = true;
      _result = null;
    });
    final params = <String, dynamic>{'exam_id': examId};
    if (classId  != null) params['class_id']   = classId;
    if (sectionId != null) params['section_id'] = sectionId;

    final res = await Api.get('api/results.php', params: params);
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() { _result = res['data'] as Map<String, dynamic>?; _resultLoading = false; });
    } else {
      setState(() { _result = null; _resultLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        backgroundColor: const Color(0xFF1A56DB),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  const SizedBox(height: 8),
                  Text(_error, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _init, child: const Text('Retry')),
                ]))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_exams.isEmpty) return const Center(child: Text('No exams found'));

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(children: [
          // Exam selector
          DropdownButtonFormField<int>(
            value: _selExamId,
            decoration: const InputDecoration(
                labelText: 'Select Exam', border: OutlineInputBorder()),
            items: _exams.map((e) {
              final ex = e as Map<String, dynamic>;
              return DropdownMenuItem<int>(
                value: ex['id'] as int,
                child: Text(ex['name'] as String? ?? ''),
              );
            }).toList(),
            onChanged: (id) {
              if (id == null) return;
              if (_isTeacher && _selClassId != null) {
                _fetchResult(id, _selClassId, _selSectionId);
              } else if (!_isTeacher) {
                _fetchResult(id, null, null);
              } else {
                setState(() { _selExamId = id; _result = null; });
              }
            },
          ),

          // Teacher: class selector
          if (_isTeacher) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _selSectionId ?? _selClassId,
                  decoration: const InputDecoration(
                      labelText: 'Class', border: OutlineInputBorder()),
                  items: _classes.map((c) {
                    final uid = (c['section_id'] as int?) ?? (c['id'] as int);
                    final sec = c['section_name'] as String? ?? '';
                    return DropdownMenuItem<int>(
                      value: uid,
                      child: Text(sec.isNotEmpty
                          ? '${c['name']} — $sec'
                          : c['name'] as String),
                    );
                  }).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    final cls = _classes.firstWhere(
                        (c) => ((c['section_id'] as int?) ?? (c['id'] as int)) == v);
                    setState(() {
                      _selClassId   = cls['id'] as int;
                      _selSectionId = cls['section_id'] as int?;
                      _result = null;
                    });
                    if (_selExamId != null) {
                      _fetchResult(_selExamId!, cls['id'] as int, cls['section_id'] as int?);
                    }
                  },
                ),
              ),
            ]),
          ],
        ]),
      ),

      const SizedBox(height: 8),
      Expanded(
        child: _resultLoading
            ? const Center(child: CircularProgressIndicator())
            : _result == null
                ? Center(child: Text(
                    _isTeacher
                        ? 'Select exam and class to view results'
                        : 'No result data',
                    style: const TextStyle(color: Colors.grey)))
                : _result?['type'] == 'class'
                    ? _buildClassResults()
                    : _buildStudentResult(),
      ),
    ]);
  }

  // ── Student individual result ───────────────────────────────────────────────
  Widget _buildStudentResult() {
    final results = _result?['results'] as List<dynamic>? ?? [];
    final pct     = (_result?['percentage'] as num?)?.toDouble() ?? 0;
    final obtained = (_result?['total_obtained'] as num?)?.toInt() ?? 0;
    final max      = (_result?['total_max']      as num?)?.toInt() ?? 0;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Card(
          color: const Color(0xFF1A56DB),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              Column(children: [
                Text('$obtained/$max',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const Text('Marks', style: TextStyle(color: Colors.white70)),
              ]),
              Column(children: [
                Text('${pct.toStringAsFixed(1)}%',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const Text('Percentage', style: TextStyle(color: Colors.white70)),
              ]),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        ...results.map((r) {
          final row = r as Map<String, dynamic>;
          final isAbsent = (row['is_absent'] as int?) == 1;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(row['subject_name'] as String? ?? ''),
              subtitle: Text(row['code'] as String? ?? ''),
              trailing: isAbsent
                  ? const Chip(
                      label: Text('Absent'),
                      backgroundColor: Color(0xFFFFE0E0))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${row['obtained_marks']}/${row['max_marks']}',
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (row['grade'] != null)
                          Text('Grade: ${row['grade']}',
                              style: const TextStyle(fontSize: 12, color: Colors.green)),
                      ]),
            ),
          );
        }),
      ],
    );
  }

  // ── Teacher class-level results ─────────────────────────────────────────────
  Widget _buildClassResults() {
    final students = _result?['students'] as List<dynamic>? ?? [];
    if (students.isEmpty) return const Center(child: Text('No results found for this class'));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: students.length,
      itemBuilder: (_, i) {
        final stu = students[i] as Map<String, dynamic>;
        final pct     = (stu['percentage'] as num?)?.toDouble() ?? 0;
        final obtained = (stu['total_obtained'] as num?)?.toInt() ?? 0;
        final max      = (stu['total_max']      as num?)?.toInt() ?? 0;
        final subjects = (stu['subjects'] as List<dynamic>?) ?? [];

        Color pctColor = Colors.red;
        if (pct >= 75) pctColor = Colors.green;
        else if (pct >= 50) pctColor = Colors.orange;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: pctColor.withOpacity(0.1),
              child: Text('${pct.toInt()}%',
                  style: TextStyle(color: pctColor, fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
            title: Text(stu['student_name'] as String? ?? '',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
                'Roll: ${stu['roll_number'] ?? ''}   $obtained/$max marks'),
            children: subjects.map((sub) {
              final s = sub as Map<String, dynamic>;
              final isAbsent = (s['is_absent'] as int?) == 1;
              return ListTile(
                dense: true,
                title: Text(s['subject_name'] as String? ?? ''),
                trailing: isAbsent
                    ? const Text('Absent',
                        style: TextStyle(color: Colors.red, fontSize: 12))
                    : Text(
                        '${s['obtained_marks']}/${s['max_marks']}'
                        '${s['grade'] != null ? '  (${s['grade']})' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
