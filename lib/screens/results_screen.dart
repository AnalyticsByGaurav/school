import 'package:flutter/material.dart';
import '../api/client.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key});
  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool _loading = true;
  String _error = '';
  List<dynamic> _exams = [];
  int? _selExamId;
  String _selExamName = '';
  bool _resultLoading = false;
  Map<String, dynamic>? _result;

  @override
  void initState() { super.initState(); _loadExams(); }

  Future<void> _loadExams() async {
    setState(() { _loading = true; _error = ''; });
    final res = await Api.get('api/results.php', params: {'exams': 1});
    if (!mounted) return;
    if (res['success'] == true) {
      final d = res['data'] as Map<String, dynamic>?;
      final exams = d?['exams'] as List<dynamic>? ?? [];
      setState(() { _exams = exams; _loading = false; });
      if (exams.isNotEmpty) {
        final first = exams[0] as Map<String, dynamic>;
        _selectExam(first['id'] as int, first['name'] as String? ?? '');
      }
    } else {
      setState(() { _error = res['message'] as String? ?? 'Failed'; _loading = false; });
    }
  }

  Future<void> _selectExam(int id, String name) async {
    setState(() { _selExamId = id; _selExamName = name; _resultLoading = true; _result = null; });
    final res = await Api.get('api/results.php', params: {'exam_id': id});
    if (!mounted) return;
    if (res['success'] == true) {
      setState(() { _result = res['data'] as Map<String, dynamic>?; _resultLoading = false; });
    } else {
      setState(() { _resultLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Results'), backgroundColor: const Color(0xFF1A56DB), foregroundColor: Colors.white),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.grey),
                  Text(_error), const SizedBox(height: 12),
                  FilledButton(onPressed: _loadExams, child: const Text('Retry')),
                ]))
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_exams.isEmpty) return const Center(child: Text('No exams found'));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<int>(
            value: _selExamId,
            decoration: const InputDecoration(labelText: 'Select Exam', border: OutlineInputBorder()),
            items: _exams.map((e) {
              final ex = e as Map<String, dynamic>;
              return DropdownMenuItem<int>(
                value: ex['id'] as int,
                child: Text(ex['name'] as String? ?? ''),
              );
            }).toList(),
            onChanged: (id) {
              if (id == null) return;
              final ex = _exams.firstWhere((e) => (e as Map)['id'] == id) as Map<String, dynamic>;
              _selectExam(id, ex['name'] as String? ?? '');
            },
          ),
        ),
        Expanded(
          child: _resultLoading
              ? const Center(child: CircularProgressIndicator())
              : _result == null
                  ? const Center(child: Text('No result data'))
                  : _buildResult(),
        ),
      ],
    );
  }

  Widget _buildResult() {
    final results = _result?['results'] as List<dynamic>? ?? [];
    final pct     = (_result?['percentage'] as num?)?.toDouble() ?? 0;
    final obtained= (_result?['total_obtained'] as num?)?.toInt() ?? 0;
    final max     = (_result?['total_max']      as num?)?.toInt() ?? 0;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        Card(
          color: const Color(0xFF1A56DB),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              Column(children: [
                Text('$obtained/$max', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                const Text('Marks', style: TextStyle(color: Colors.white70)),
              ]),
              Column(children: [
                Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
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
                  ? const Chip(label: Text('Absent'), backgroundColor: Color(0xFFFFE0E0))
                  : Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('${row['obtained_marks']}/${row['max_marks']}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      if (row['grade'] != null)
                        Text('Grade: ${row['grade']}', style: const TextStyle(fontSize: 12, color: Colors.green)),
                    ]),
            ),
          );
        }),
      ],
    );
  }
}
