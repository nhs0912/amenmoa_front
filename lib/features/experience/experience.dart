import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const forest = Color(0xFF163F34);
const sage = Color(0xFFE8EEDC);

void openPage(BuildContext context, Widget child) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => child));
}

class PrayerEntry {
  PrayerEntry(
    this.id,
    this.title,
    this.seconds,
    this.date,
    this.note,
    this.kind,
  );
  final String id, title, note, kind;
  final int seconds;
  final DateTime date;
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'seconds': seconds,
    'date': date.toIso8601String(),
    'note': note,
    'kind': kind,
  };
  factory PrayerEntry.fromJson(Map<String, dynamic> v) => PrayerEntry(
    v['id'] as String,
    v['title'] as String,
    v['seconds'] as int,
    DateTime.parse(v['date'] as String),
    v['note'] as String,
    v['kind'] as String,
  );
}

class PrayerStore extends ChangeNotifier {
  List<PrayerEntry> entries = [];
  List<String> groups = ['새봄 셀', '가족 기도방', '우리 교회'];
  List<String> topics = ['하루를 시작하는 감사', '가족의 평안', '이웃의 회복을 위해'];
  List<String> schedules = [];
  String name = '서윤';
  double textScale = 1;
  bool reminders = true;
  bool loaded = false;
  String? error;
  Future<void> _writes = Future<void>.value();
  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      entries = (jsonDecode(p.getString('entries') ?? '[]') as List)
          .map((v) => PrayerEntry.fromJson(v as Map<String, dynamic>))
          .toList();
      groups = p.getStringList('groups') ?? groups;
      topics = p.getStringList('topics') ?? topics;
      schedules = p.getStringList('schedules') ?? schedules;
      name = p.getString('name') ?? name;
      textScale = p.getDouble('textScale') ?? 1;
      reminders = p.getBool('reminders') ?? true;
    } catch (_) {
      error = '저장한 정보를 불러오지 못했어요. 다시 실행해 주세요.';
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> save() {
    final snapshot = jsonEncode(entries.map((v) => v.toJson()).toList());
    final savedGroups = List<String>.of(groups);
    final savedTopics = List<String>.of(topics);
    final savedSchedules = List<String>.of(schedules);
    final savedName = name;
    final savedScale = textScale;
    final savedReminders = reminders;
    _writes = _writes.then((_) async {
      try {
        final p = await SharedPreferences.getInstance();
        final results = await Future.wait([
          p.setString('entries', snapshot),
          p.setStringList('groups', savedGroups),
          p.setStringList('topics', savedTopics),
          p.setStringList('schedules', savedSchedules),
          p.setString('name', savedName),
          p.setDouble('textScale', savedScale),
          p.setBool('reminders', savedReminders),
        ]);
        error = results.every((v) => v)
            ? null
            : '기기에 저장하지 못했어요. 저장 공간을 확인해 주세요.';
      } catch (_) {
        error = '기기에 저장하지 못했어요. 저장 공간을 확인해 주세요.';
      }
      notifyListeners();
    });
    notifyListeners();
    return _writes;
  }

  int get todaySeconds => entries
      .where((e) => sameDay(e.date, DateTime.now()))
      .fold(0, (a, e) => a + e.seconds);
  int get totalSeconds => entries.fold(0, (a, e) => a + e.seconds);
  Future<void> add(PrayerEntry entry) async {
    if (entries.any((e) => e.id == entry.id)) return;
    entries.insert(0, entry);
    await save();
  }
}

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String durationLabel(int seconds) => '${seconds ~/ 60}분 ${seconds % 60}초';
String clockLabel(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          height: 1.3,
        ),
      ),
      if (subtitle != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            subtitle!,
            style: const TextStyle(color: Color(0xFF6C7E74), height: 1.5),
          ),
        ),
      const SizedBox(height: 24),
      ...children.expand((w) => [w, const SizedBox(height: 16)]),
    ],
  );
}

class Paper extends StatelessWidget {
  const Paper({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.onTap,
  });
  final Widget child;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: const BorderSide(color: Color(0xFFE2E8E0)),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    ),
  );
}

Widget heading(String text) => Text(
  text,
  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
);
Widget primary(String label, VoidCallback action) => FilledButton(
  onPressed: action,
  style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
  child: Text(label),
);
Widget note(String text) =>
    Text(text, style: const TextStyle(color: Color(0xFF6C7E74), height: 1.6));
Widget metric(String value, String label) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      value,
      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
    ),
    note(label),
  ],
);

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store});
  final PrayerStore store;
  @override
  Widget build(BuildContext context) => PageBody(
    title: '혼자 시작해도, 함께',
    subtitle: '${store.name}님 · 오늘도 같은 마음으로 기도해요',
    children: [
      if (!store.loaded) const LinearProgressIndicator(),
      if (store.error != null)
        Text(store.error!, style: const TextStyle(color: Colors.red)),
      Paper(
        color: sage,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            note('오늘 내가 모은 기도'),
            const SizedBox(height: 12),
            metric(durationLabel(store.todaySeconds), '각자의 자리에서, 같은 마음으로.'),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.spa_outlined),
                SizedBox(width: 8),
                Expanded(child: Text('작은 기도가 쌓여 하루를 채워요.')),
              ],
            ),
          ],
        ),
      ),
      Paper(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Chip(label: Text('오늘의 기도')),
            heading('이웃의 회복을 위해'),
            const SizedBox(height: 8),
            note('우리의 이웃이 평안을 되찾도록 기도해요.'),
            const SizedBox(height: 12),
            primary(
              '혼자 기도 시작',
              () => openPage(context, SetupPage(store: store)),
            ),
          ],
        ),
      ),
      OutlinedButton.icon(
        onPressed: () => openPage(context, RoomsPage(store: store)),
        icon: const Icon(Icons.groups_outlined),
        label: const Text('지금 함께 기도'),
      ),
      Paper(
        onTap: () => openPage(context, PromisePage(store: store)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading('우리의 매일 한 시간'),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (store.todaySeconds / 3600).clamp(0, 1),
              minHeight: 7,
              borderRadius: BorderRadius.circular(10),
            ),
            const SizedBox(height: 12),
            note('나 ${store.todaySeconds ~/ 60} / 60분'),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('약속 보기  ›'),
            ),
          ],
        ),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: heading('오늘의 모임'),
        subtitle: Text(
          store.schedules.isEmpty ? '아직 예약한 모임이 없어요.' : store.schedules.first,
        ),
        trailing: const Icon(Icons.add_circle_outline),
        onTap: () => openPage(context, SchedulePage(store: store)),
      ),
      note('기기 저장 모드 · 그룹과 기도방의 예시를 둘러볼 수 있어요. 실시간 참여자와 서버 통계는 연결 전이에요.'),
    ],
  );
}

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key, required this.store});
  final PrayerStore store;
  @override
  Widget build(BuildContext context) => PageBody(
    title: '내 그룹',
    subtitle: '함께 기도하는 나의 공동체',
    children: [
      ...store.groups.indexed.map(
        (v) => Paper(
          color: [
            sage,
            const Color(0xFFF3EBDD),
            const Color(0xFFE7EDF2),
          ][v.$1 % 3],
          onTap: () => openPage(context, GroupPage(store: store, name: v.$2)),
          child: Row(
            children: [
              const Icon(Icons.groups_outlined, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    heading(v.$2),
                    note('기도제목 ${store.topics.length} · 기기 저장 그룹'),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
      primary('+ 새 그룹 만들기', () async {
        final value = await textDialog(context, '새 그룹 만들기', '그룹 이름');
        if (value != null && !store.groups.contains(value)) {
          store.groups.add(value);
          await store.save();
        }
      }),
    ],
  );
}

class GroupPage extends StatelessWidget {
  const GroupPage({super.key, required this.store, required this.name});
  final PrayerStore store;
  final String name;
  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: name,
    child: ListenableBuilder(
      listenable: store,
      builder: (context, _) => PageBody(
        title: '함께 기도하는 공동체',
        subtitle: '$name · 기기 저장 그룹',
        children: [
          Paper(
            color: sage,
            onTap: () => openPage(
              context,
              GoalPage(store: store, title: '이번 주 600분 기도', target: 600),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading('이번 주 600분 기도'),
                const SizedBox(height: 12),
                note('나의 이번 주 기록으로 확인하는 목표'),
                const SizedBox(height: 8),
                const Text('목표 보기  ›'),
              ],
            ),
          ),
          heading('기도제목'),
          ...store.topics.map(
            (t) => Paper(
              onTap: () => openPage(context, TopicPage(store: store, title: t)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading(t),
                  const SizedBox(height: 8),
                  note('마음을 모아 함께 기도해 주세요.'),
                  const SizedBox(height: 12),
                  const Text('기도제목 보기  ›'),
                ],
              ),
            ),
          ),
          primary('기도제목 나누기', () => addTopic(context, store)),
          OutlinedButton(
            onPressed: () => openPage(context, SchedulePage(store: store)),
            child: const Text('기도모임 예약'),
          ),
          note('멤버 초대·QR 가입·공동 집계는 서버 연결 후 사용할 수 있어요.'),
        ],
      ),
    ),
  );
}

Future<String?> textDialog(
  BuildContext context,
  String title,
  String hint,
) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLength: 100,
        decoration: InputDecoration(labelText: hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () {
            if (controller.text.trim().isNotEmpty) {
              Navigator.pop(context, controller.text.trim());
            }
          },
          child: const Text('저장'),
        ),
      ],
    ),
  );
  // Dispose after the closing route finishes using its text field.
  await Future<void>.delayed(const Duration(milliseconds: 300));
  controller.dispose();
  return result;
}

Future<void> addTopic(BuildContext context, PrayerStore store) async {
  final title = await textDialog(context, '기도제목 나누기', '함께 기도할 제목');
  if (title != null) {
    store.topics.add(title);
    await store.save();
  }
}

class TopicPage extends StatelessWidget {
  const TopicPage({super.key, required this.store, required this.title});
  final PrayerStore store;
  final String title;
  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: '기도제목',
    child: PageBody(
      title: title,
      subtitle: '나의 기도제목',
      children: [
        const Paper(
          color: sage,
          child: Text('작은 마음도 편하게 나눠도 괜찮아요.\n오늘의 기도에 이 제목을 담아 보세요.'),
        ),
        primary(
          '이 제목으로 기도하기',
          () => openPage(
            context,
            TimerPage(store: store, title: title, kind: '개인 기도'),
          ),
        ),
      ],
    ),
  );
}

class PrayerScreen extends StatelessWidget {
  const PrayerScreen({super.key, required this.store});
  final PrayerStore store;
  @override
  Widget build(BuildContext context) => PageBody(
    title: '마음을 모으는 기도',
    subtitle: '오늘도 각자의 자리에서 함께해요',
    children: [
      Paper(
        color: forest,
        onTap: () => openPage(context, SetupPage(store: store)),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.volunteer_activism_outlined,
              color: Color(0xFFD9E8AF),
              size: 36,
            ),
            SizedBox(height: 24),
            Text(
              '오늘 기도 시작',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '미리 담은 기도제목으로 마음을 모아요.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
      actionTile(
        context,
        Icons.wifi_tethering,
        '라이브 기도방',
        '같은 시간에 함께',
        RoomsPage(store: store),
      ),
      actionTile(
        context,
        Icons.flag_outlined,
        '목표기도방',
        '시간을 모아 목표 달성',
        GoalPage(store: store, title: '건강을 위한 기도', target: 100),
      ),
      actionTile(
        context,
        Icons.schedule,
        '기도 예약하기',
        '기도할 시간을 미리 정해요.',
        SchedulePage(store: store),
      ),
      actionTile(
        context,
        Icons.favorite_outline,
        '친구와 매일 기도 약속',
        '각자의 자리에서 매일 한 시간',
        PromisePage(store: store),
      ),
      OutlinedButton(
        onPressed: () => addTopic(context, store),
        child: const Text('기도제목 나누기'),
      ),
    ],
  );
}

Widget actionTile(
  BuildContext context,
  IconData icon,
  String title,
  String subtitle,
  Widget page,
) => Paper(
  onTap: () => openPage(context, page),
  child: Row(
    children: [
      Icon(icon, size: 28),
      const SizedBox(width: 16),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [heading(title), const SizedBox(height: 5), note(subtitle)],
        ),
      ),
      const Icon(Icons.chevron_right),
    ],
  ),
);

class SetupPage extends StatefulWidget {
  const SetupPage({super.key, required this.store});
  final PrayerStore store;
  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  String? selected;
  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: '지금 기도하기',
    child: PageBody(
      title: '오늘의 기도를 시작해 보세요',
      subtitle: '마음에 담을 기도제목을 골라 주세요.',
      children: [
        ...widget.store.topics.map(
          (t) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t),
            value: selected == t,
            onChanged: (_) => setState(() => selected = t),
          ),
        ),
        OutlinedButton(
          onPressed: () async {
            await addTopic(context, widget.store);
            if (mounted) setState(() {});
          },
          child: const Text('+ 기도제목 추가'),
        ),
        primary(
          '혼자 기도 시작',
          () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => TimerPage(
                store: widget.store,
                title: selected ?? '오늘의 감사',
                kind: '개인 기도',
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class TimerPage extends StatefulWidget {
  const TimerPage({
    super.key,
    required this.store,
    required this.title,
    required this.kind,
  });
  final PrayerStore store;
  final String title, kind;
  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  final Stopwatch watch = Stopwatch();
  late final Timer ticker;
  late final String id;
  bool paused = false;
  bool finishing = false;
  @override
  void initState() {
    super.initState();
    id = DateTime.now().microsecondsSinceEpoch.toString();
    watch.start();
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    ticker.cancel();
    watch.stop();
    super.dispose();
  }

  Future<void> finish() async {
    if (finishing) return;
    setState(() => finishing = true);
    watch.stop();
    final seconds = watch.elapsed.inSeconds;
    final memo = await textDialog(context, '기도를 마쳤어요', '오늘의 기도 메모 (선택)');
    if (!mounted) return;
    // Closing the memo still saves the measured prayer time.
    await widget.store.add(
      PrayerEntry(
        id,
        widget.title,
        seconds,
        DateTime.now(),
        memo ?? '',
        widget.kind,
      ),
    );
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.store.error ?? '${durationLabel(seconds)}의 기도를 기록했어요.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(finish());
    },
    child: Scaffold(
      backgroundColor: forest,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: ListView(
              padding: const EdgeInsets.all(28),
              children: [
                Text(
                  widget.kind,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 32),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),
                Center(
                  child: Container(
                    width: 270,
                    padding: const EdgeInsets.symmetric(
                      vertical: 50,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF839C72)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          '나의 기도 시간',
                          style: TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 20),
                        FittedBox(
                          child: Text(
                            clockLabel(watch.elapsed.inSeconds),
                            style: const TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          paused ? '잠시 쉬는 중' : '기도 중',
                          style: const TextStyle(color: Color(0xFFD9E8AF)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  '오늘의 기도에 마음을 모아요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 36),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                  ),
                  onPressed: finishing
                      ? null
                      : () => setState(() {
                          paused = !paused;
                          paused ? watch.stop() : watch.start();
                        }),
                  child: Text(paused ? '기도 이어가기' : '일시정지'),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD9E8AF),
                    foregroundColor: forest,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  onPressed: finishing ? null : finish,
                  child: Text(finishing ? '기록하는 중' : '기도 마치기'),
                ),
                const SizedBox(height: 16),
                const Text(
                  '화면을 벗어날 때 기도 기록을 저장해요.\n앱이 강제로 종료되면 진행 중인 시간은 복구되지 않아요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class RoomsPage extends StatelessWidget {
  const RoomsPage({super.key, required this.store});
  final PrayerStore store;
  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: '라이브 기도방',
    child: PageBody(
      title: '같은 마음으로, 함께',
      subtitle: '기도방 미리보기 · 실시간 서버 연결 전',
      children: [
        ...['오늘의 감사', '가정의 평안', '이웃의 회복'].map(
          (t) => Paper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Chip(label: Text('예시 기도방')),
                heading(t),
                const SizedBox(height: 8),
                note('이 제목을 담아 개인 기도를 시작할 수 있어요.'),
                const SizedBox(height: 12),
                primary(
                  '이 제목으로 혼자 기도',
                  () => openPage(
                    context,
                    TimerPage(store: store, title: t, kind: '개인 기도'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class GoalPage extends StatelessWidget {
  const GoalPage({
    super.key,
    required this.store,
    required this.title,
    required this.target,
  });
  final PrayerStore store;
  final String title;
  final int target;
  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: '기도 목표',
    child: ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final start = DateTime(
          now.year,
          now.month,
          now.day,
        ).subtract(Duration(days: now.weekday - 1));
        final seconds = store.entries
            .where(
              (e) =>
                  !e.date.isBefore(start) &&
                  e.date.isBefore(start.add(const Duration(days: 7))),
            )
            .fold<int>(0, (sum, e) => sum + e.seconds);
        return PageBody(
          title: title,
          subtitle: '이번 주 나의 기록 · 월요일부터 일요일까지',
          children: [
            Paper(
              color: sage,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  metric(
                    '${seconds ~/ 60} / $target분',
                    seconds >= target * 60
                        ? '목표를 채웠어요!'
                        : '${((target * 60 - seconds) / 60).ceil()}분 남음',
                  ),
                  const SizedBox(height: 20),
                  LinearProgressIndicator(
                    value: (seconds / (target * 60)).clamp(0, 1),
                    minHeight: 8,
                  ),
                  const SizedBox(height: 16),
                  note('개인 기도와 직접 저장한 기록을 한 번씩 합산해요.'),
                ],
              ),
            ),
            primary(
              '기도 시작',
              () => openPage(
                context,
                TimerPage(store: store, title: title, kind: '개인 기도'),
              ),
            ),
            note('그룹 멤버의 시간 합산과 목표기도방 참여는 서버 연결이 필요해요.'),
          ],
        );
      },
    ),
  );
}

class PromisePage extends StatelessWidget {
  const PromisePage({super.key, required this.store});
  final PrayerStore store;
  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: '매일 기도 약속',
    child: ListenableBuilder(
      listenable: store,
      builder: (context, _) => PageBody(
        title: '우리의 매일 한 시간',
        subtitle: '각자의 자리에서, 같은 마음으로',
        children: [
          Paper(
            color: sage,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading('오늘 · 하루 60분'),
                const SizedBox(height: 24),
                metric(
                  '${store.todaySeconds ~/ 60} / 60분',
                  store.todaySeconds >= 3600
                      ? '오늘의 목표를 채웠어요.'
                      : '조금 더 마음을 모아볼까요?',
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: (store.todaySeconds / 3600).clamp(0, 1),
                ),
              ],
            ),
          ),
          primary('기도 이어가기', () => openPage(context, SetupPage(store: store))),
          note('친구 초대·완료 알림·톡톡은 계정과 서버 연결 후 사용할 수 있어요.'),
        ],
      ),
    ),
  );
}

class SchedulePage extends StatefulWidget {
  const SchedulePage({super.key, required this.store});
  final PrayerStore store;
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final title = TextEditingController();
  DateTime date = DateTime.now().add(const Duration(hours: 1));
  String? error;
  @override
  void dispose() {
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: '내 기도 예약',
    child: PageBody(
      title: '기도할 시간을 정해요',
      subtitle: '이 기기에 일정을 저장해요.',
      children: [
        TextField(
          controller: title,
          maxLength: 100,
          decoration: const InputDecoration(labelText: '모임명 또는 기도제목'),
        ),
        ListTile(
          title: const Text('날짜와 시작 시간'),
          subtitle: Text(
            '${date.year}.${date.month}.${date.day}  ${clockLabel(date.hour * 60 + date.minute)}',
          ),
          trailing: const Icon(Icons.edit_calendar_outlined),
          onTap: () async {
            final day = await showDatePicker(
              context: context,
              initialDate: date,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 730)),
            );
            if (day == null || !context.mounted) return;
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(date),
            );
            if (time != null && mounted) {
              setState(
                () => date = DateTime(
                  day.year,
                  day.month,
                  day.day,
                  time.hour,
                  time.minute,
                ),
              );
            }
          },
        ),
        if (error != null)
          Text(error!, style: const TextStyle(color: Colors.red)),
        primary('예약 저장', () async {
          if (title.text.trim().isEmpty || !date.isAfter(DateTime.now())) {
            setState(() => error = '기도제목과 미래의 시작 시간을 입력해 주세요.');
            return;
          }
          widget.store.schedules.add(
            '${title.text.trim()} · ${date.month}/${date.day} ${TimeOfDay.fromDateTime(date).format(context)}',
          );
          await widget.store.save();
          if (context.mounted) Navigator.pop(context);
        }),
        note('푸시 알림과 그룹 초대 전송은 서버 연결 전이에요. 예약은 앱 안에서 확인할 수 있어요.'),
        ...widget.store.schedules.map((s) => ListTile(title: Text(s))),
      ],
    ),
  );
}

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key, required this.store});
  final PrayerStore store;
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? selected;
  @override
  Widget build(BuildContext context) {
    final count = DateUtils.getDaysInMonth(month.year, month.month);
    final offset = DateTime(month.year, month.month).weekday % 7;
    final entries = widget.store.entries
        .where(
          (e) => selected == null
              ? e.date.year == month.year && e.date.month == month.month
              : sameDay(e.date, selected!),
        )
        .toList();
    return PageBody(
      title: '기도의 발자취',
      subtitle: '마음을 모은 시간은 여기에 남아요.',
      children: [
        Paper(
          color: sage,
          child: metric(
            durationLabel(widget.store.totalSeconds),
            '지금까지 쌓인 나의 기도',
          ),
        ),
        Row(
          children: [
            IconButton(
              tooltip: '이전 달',
              onPressed: () => setState(() {
                month = DateTime(month.year, month.month - 1);
                selected = null;
              }),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(child: heading('${month.year}년 ${month.month}월')),
            ),
            IconButton(
              tooltip: '다음 달',
              onPressed: () => setState(() {
                month = DateTime(month.year, month.month + 1);
                selected = null;
              }),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        Row(
          children: [
            for (final d in ['일', '월', '화', '수', '목', '금', '토'])
              Expanded(child: Center(child: Text(d))),
          ],
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: count + offset,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 48,
          ),
          itemBuilder: (context, i) {
            if (i < offset) return const SizedBox.shrink();
            final day = DateTime(month.year, month.month, i - offset + 1);
            final hasEntry = widget.store.entries.any(
              (e) => sameDay(e.date, day),
            );
            return InkWell(
              onTap: () => setState(
                () => selected = selected != null && sameDay(selected!, day)
                    ? null
                    : day,
              ),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: selected != null && sameDay(selected!, day)
                      ? forest
                      : hasEntry
                      ? sage
                      : null,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    '${day.day}${hasEntry ? '·' : ''}',
                    style: TextStyle(
                      color: selected != null && sameDay(selected!, day)
                          ? Colors.white
                          : forest,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        OutlinedButton.icon(
          onPressed: () =>
              openPage(context, ManualEntryPage(store: widget.store)),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('직접 기도 기록'),
        ),
        heading(
          selected == null
              ? '이번 달의 기도'
              : '${selected!.month}월 ${selected!.day}일의 기도',
        ),
        if (entries.isEmpty)
          const Paper(child: Text('아직 기록이 없어요.\n오늘의 첫 기도를 남겨 보세요.')),
        ...entries.map(
          (e) => Paper(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading(e.title),
                note(
                  '${e.date.month}/${e.date.day} · ${e.kind} · ${durationLabel(e.seconds)}',
                ),
                if (e.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(e.note),
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () async {
                      final remove = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('이 기록을 삭제할까요?'),
                          content: const Text('삭제하면 누적 기도 시간에도 반영돼요.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('취소'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('삭제'),
                            ),
                          ],
                        ),
                      );
                      if (remove == true) {
                        widget.store.entries.removeWhere((v) => v.id == e.id);
                        await widget.store.save();
                      }
                    },
                    child: const Text('기록 삭제'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class ManualEntryPage extends StatefulWidget {
  const ManualEntryPage({super.key, required this.store});
  final PrayerStore store;
  @override
  State<ManualEntryPage> createState() => _ManualEntryPageState();
}

class _ManualEntryPageState extends State<ManualEntryPage> {
  final form = GlobalKey<FormState>();
  final title = TextEditingController(),
      minutes = TextEditingController(),
      memo = TextEditingController();
  DateTime date = DateTime.now();
  bool saving = false;
  @override
  void dispose() {
    title.dispose();
    minutes.dispose();
    memo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: '직접 기도 기록',
    child: Form(
      key: form,
      child: PageBody(
        title: '오늘의 기도를 남겨요',
        children: [
          TextFormField(
            controller: title,
            decoration: const InputDecoration(labelText: '기도제목'),
            validator: (v) =>
                v == null || v.trim().isEmpty ? '기도제목을 입력해 주세요.' : null,
          ),
          TextFormField(
            controller: minutes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '기도 시간 (분)'),
            validator: (v) {
              final n = int.tryParse(v ?? '');
              return n == null || n < 1 || n > 1440
                  ? '1~1440분 사이로 입력해 주세요.'
                  : null;
            },
          ),
          ListTile(
            title: const Text('기도한 날짜'),
            subtitle: Text('${date.year}.${date.month}.${date.day}'),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => date = d);
            },
          ),
          TextFormField(
            controller: memo,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(labelText: '기도 메모 (선택)'),
          ),
          FilledButton(
            onPressed: saving
                ? null
                : () async {
                    if (!form.currentState!.validate()) return;
                    setState(() => saving = true);
                    await widget.store.add(
                      PrayerEntry(
                        DateTime.now().microsecondsSinceEpoch.toString(),
                        title.text.trim(),
                        int.parse(minutes.text) * 60,
                        date,
                        memo.text.trim(),
                        '개인 기도',
                      ),
                    );
                    if (context.mounted) Navigator.pop(context);
                  },
            child: Text(saving ? '저장 중' : '기록 저장'),
          ),
        ],
      ),
    ),
  );
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.store, this.onExitToLogin});
  final PrayerStore store;
  final VoidCallback? onExitToLogin;
  @override
  Widget build(BuildContext context) => PageBody(
    title: '내 프로필',
    subtitle: '오늘도 평안한 하루 보내세요',
    children: [
      Paper(
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: sage,
              child: Text(
                store.name.isEmpty ? '나' : store.name.substring(0, 1),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [heading(store.name), note('기기 저장 프로필')],
              ),
            ),
            IconButton(
              tooltip: '프로필 편집',
              onPressed: () async {
                final value = await textDialog(context, '프로필 편집', '이름');
                if (value != null) {
                  store.name = value;
                  await store.save();
                }
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
      ListTile(
        title: const Text('내 그룹'),
        trailing: Text('${store.groups.length}개'),
        onTap: () => openPage(
          context,
          DetailScaffold(
            title: '내 그룹',
            child: GroupsScreen(store: store),
          ),
        ),
      ),
      heading('내 기도제목'),
      ...store.topics.map(
        (t) => ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(t),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => openPage(context, TopicPage(store: store, title: t)),
        ),
      ),
      OutlinedButton(
        onPressed: () => addTopic(context, store),
        child: const Text('기도제목 추가'),
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('모임 알림 수신 선호'),
        subtitle: const Text('기기에 선호만 저장 · 알림 전송 연결 전'),
        value: store.reminders,
        onChanged: (v) {
          store.reminders = v;
          unawaited(store.save());
        },
      ),
      heading('글씨 크기'),
      SegmentedButton<double>(
        segments: const [
          ButtonSegment(value: 1, label: Text('기본')),
          ButtonSegment(value: 1.2, label: Text('크게')),
          ButtonSegment(value: 1.4, label: Text('더 크게')),
        ],
        selected: {store.textScale},
        onSelectionChanged: (v) {
          store.textScale = v.first;
          unawaited(store.save());
        },
      ),
      if (onExitToLogin != null)
        OutlinedButton.icon(
          onPressed: onExitToLogin,
          icon: const Icon(Icons.login),
          label: const Text('로그인 화면으로'),
        ),
      const Paper(
        color: sage,
        child: Text(
          '아멘모아 · 기기 저장 모드\n\n기도 기록·기도제목·프로필·예약을 이 기기에 저장합니다. 계정 인증, 클라우드 동기화, 실시간 기도방과 푸시 알림은 서버 연결 전입니다. 앱 데이터 삭제 시 기록도 삭제됩니다.',
        ),
      ),
    ],
  );
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context) => const DetailScaffold(
    title: '알림',
    child: PageBody(
      title: '함께하는 기도의 소식',
      subtitle: '새로운 소식이 오면 여기에 모여요.',
      children: [
        Paper(
          child: Column(
            children: [
              Icon(Icons.notifications_none, size: 42),
              SizedBox(height: 20),
              Text('아직 도착한 알림이 없어요.'),
              SizedBox(height: 12),
              Text(
                '계정과 알림 서버 연결 후 초대와 시작 소식을 받을 수 있어요.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class DetailScaffold extends StatelessWidget {
  const DetailScaffold({super.key, required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: child,
        ),
      ),
    ),
  );
}
