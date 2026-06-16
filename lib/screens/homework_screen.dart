import 'package:flutter/material.dart';
import '../api/client.dart';
import '../utils/session.dart';

class HomeworkScreen extends StatefulWidget {
  const HomeworkScreen({super.key});
  @override
  State<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends State<HomeworkScreen>
    with SingleTickerProviderStateMixin {
  static bool get _isTeacher =>
      !['student', 'parent'].contains(Session.userRole);

  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _isTeacher ? 2 : 1, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isTeacher) return const _HomeworkList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Homework'),
        backgroundColor: const Color(0xFF1A56DB),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [Tab(text: 'Assigned'), Tab(text: 'Assign New')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          const _HomeworkList(),
          _AssignHomeworkForm(onSaved: () => _tabs.animateTo(0)),
        ],
      ),
    );
  }
}

// ── Homework list (student + teacher view) ────────────────────────────────────
class _HomeworkList extends StatefulWidget {
  const _HomeworkList();
  @override
  State<_HomeworkList> createState() => _HomeworkListState();
}

class _HomeworkListState extends State<_HomeworkList> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _items = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    final res = await Api.get('api/homework.php');
    if (!mounted) return;
    if (res['success'] == true) {
      final d = res['data'] as Map<String, dynamic>?;
      setState(() {
        _items = d?['homework'] as List<dynamic>? ?? [];
        _loading = false;
      });
    } else {
      setState(() {
        _error = res['message'] as String? ?? 'Failed to load homework';
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
    if (_items.isEmpty) return const Center(child: Text('No homework assigned'));

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (_, i) {
          final h = _items[i] as Map<String, dynamic>;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(h['title'] as String? ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Wrap(spacing: 6, children: [
                  if (h['subject_name'] != null)
                    _chip(h['subject_name'] as String, Colors.blue),
                  if (h['class_name'] != null)
                    _chip(
                      '${h['class_name']}${h['section_name'] != null ? ' - ${h['section_name']}' : ''}',
                      Colors.purple,
                    ),
                ]),
                if ((h['description'] as String?)?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(h['description'] as String,
                      style: const TextStyle(fontSize: 13, color: Colors.black87)),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.red),
                  const SizedBox(width: 4),
                  Text('Due: ${h['due_date'] ?? ''}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.red, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
    margin: const EdgeInsets.only(top: 4),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
    child: Text(label,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}

// ── Assign homework form (teacher / admin) ────────────────────────────────────
class _AssignHomeworkForm extends StatefulWidget {
  final VoidCallback onSaved;
  const _AssignHomeworkForm({required this.onSaved});
  @override
  State<_AssignHomeworkForm> createState() => _AssignHomeworkFormState();
}

class _AssignHomeworkFormState extends State<_AssignHomeworkForm> {
  bool _metaLoading = true;

  // class entries: {id, name, section_id, section_name}
  List<Map<String, dynamic>> _classes = [];
  // subject entries per class: key = class_id → [{id, name}]
  final Map<int, List<Map<String, dynamic>>> _subjectsByClass = {};

  int? _selClassId;
  int? _selSectionId;
  int? _selSubjectId;
  List<Map<String, dynamic>> _subjects = [];

  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _dateCtrl  = TextEditingController();

  bool _submitting = false;
  String _msg = '';

  @override
  void initState() { super.initState(); _loadMeta(); }

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose(); _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMeta() async {
    setState(() { _metaLoading = true; });
    try {
      final res = await Api.get('api/timetable.php');
      if (!mounted) return;

      final days = (res['data']?['days'] as List<dynamic>?) ?? [];
      // Key by section_id so multiple sections of the same class all appear
      final Map<int, Map<String, dynamic>> classMap = {};
      final Map<int, Map<int, Map<String, dynamic>>> subjectMap = {};

      for (final day in days) {
        for (final p in ((day as Map)['periods'] as List<dynamic>? ?? [])) {
          final period = p as Map<String, dynamic>;
          if (period['is_break'] == 1) continue;
          final cid = period['class_id'];
          final sid = period['section_id'];
          final subId = period['subject_id'];
          if (cid == null || subId == null) continue;

          final key = (sid as int?) ?? (cid as int);
          classMap[key] = {
            'id': cid as int,
            'name': period['class_name'] ?? 'Class $cid',
            'section_id': sid as int?,
            'section_name': period['section_name'] ?? '',
          };

          subjectMap[cid as int] ??= {};
          subjectMap[cid]![subId as int] = {
            'id': subId as int,
            'name': period['subject_name'] ?? 'Subject $subId',
          };
        }
      }

      // Fallback: if no timetable entries, load all school classes + subjects
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

        // Load all school subjects as fallback
        final subRes = await Api.get('api/classes.php', params: {'subjects': '1'});
        if (!mounted) return;
        final subList = (subRes['data']?['subjects'] as List<dynamic>?) ?? [];
        final allSubs = <int, Map<String, dynamic>>{};
        for (final sub in subList) {
          final s = sub as Map<String, dynamic>;
          final subId = (s['id'] as num).toInt();
          allSubs[subId] = {'id': subId, 'name': s['name'] as String? ?? ''};
        }
        // Assign all subjects to every class in fallback mode
        for (final cid in classMap.values.map((c) => c['id'] as int).toSet()) {
          subjectMap[cid] = Map<int, Map<String, dynamic>>.from(allSubs);
        }
      }

      final Map<int, List<Map<String, dynamic>>> subsByClass = {};
      subjectMap.forEach((cid, subs) {
        subsByClass[cid] = subs.values.toList();
      });
      subsByClass.forEach((k, v) => _subjectsByClass[k] = v);

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

  void _onClassChanged(int? uid) {
    if (uid == null) return;
    // uid is section_id when set, else class_id
    final cls = _classes.firstWhere(
        (c) => ((c['section_id'] as int?) ?? (c['id'] as int)) == uid);
    final cid = cls['id'] as int;
    setState(() {
      _selClassId   = cid;
      _selSectionId = cls['section_id'] as int?;
      _subjects     = _subjectsByClass[cid] ?? [];
      _selSubjectId = null;
    });
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (_selClassId == null || _selSectionId == null || _selSubjectId == null ||
        title.isEmpty || _dateCtrl.text.isEmpty) {
      setState(() => _msg = 'All required fields must be filled');
      return;
    }
    setState(() { _submitting = true; _msg = ''; });
    final res = await Api.post('api/homework.php', {
      'class_id':    _selClassId,
      'section_id':  _selSectionId,
      'subject_id':  _selSubjectId,
      'title':       title,
      'description': _descCtrl.text.trim(),
      'due_date':    _dateCtrl.text,
    });
    if (!mounted) return;
    if (res['success'] == true) {
      _titleCtrl.clear(); _descCtrl.clear(); _dateCtrl.clear();
      setState(() { _submitting = false; _msg = ''; _selSubjectId = null; });
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Homework assigned successfully!')));
      widget.onSaved();
    } else {
      setState(() {
        _submitting = false;
        _msg = res['message'] as String? ?? 'Failed to assign homework';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_metaLoading) return const Center(child: CircularProgressIndicator());
    if (_classes.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(24),
        child: Text('No classes found. Contact admin to set up the timetable.',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_msg.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8)),
            child: Text(_msg, style: const TextStyle(color: Colors.red)),
          ),

        DropdownButtonFormField<int>(
          value: _selSectionId ?? _selClassId,
          decoration: const InputDecoration(labelText: 'Class *', border: OutlineInputBorder()),
          items: _classes.map((c) {
            final uid = (c['section_id'] as int?) ?? (c['id'] as int);
            final sec = c['section_name'] as String? ?? '';
            return DropdownMenuItem<int>(
              value: uid,
              child: Text(sec.isNotEmpty ? '${c['name']} — $sec' : c['name'] as String),
            );
          }).toList(),
          onChanged: _onClassChanged,
        ),
        const SizedBox(height: 16),

        DropdownButtonFormField<int>(
          value: _selSubjectId,
          decoration: const InputDecoration(labelText: 'Subject *', border: OutlineInputBorder()),
          items: _subjects.map((s) => DropdownMenuItem<int>(
            value: s['id'] as int,
            child: Text(s['name'] as String),
          )).toList(),
          onChanged: (v) => setState(() => _selSubjectId = v),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _titleCtrl,
          decoration: const InputDecoration(labelText: 'Title *', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _descCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Description', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _dateCtrl,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Due Date *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.calendar_today),
          ),
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 1)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 90)),
            );
            if (picked != null) {
              _dateCtrl.text = picked.toIso8601String().substring(0, 10);
            }
          },
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Assign Homework'),
          ),
        ),
      ]),
    );
  }
}
