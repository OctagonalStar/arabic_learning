import 'package:arabic_learning/core/adaptive.dart' show AdaptiveTabBody;
import 'package:material_ui/material_ui.dart';

import 'package:arabic_learning/core/navigation.dart';
import 'package:arabic_learning/screens/test/dictation/dictation_list_page.dart'
    show DictationListPage;
import 'package:arabic_learning/screens/test/listening_test_page.dart'
    show ForeListeningSettingPage;
import 'package:arabic_learning/screens/test/local_pk_page.dart'
    show LocalPKSelectPage;
import 'package:arabic_learning/screens/test/reading_test_page.dart'
    show ReadingTestPage;
import 'package:arabic_learning/screens/test/recitation/recitation_list_page.dart'
    show RecitationListPage;
import 'package:arabic_learning/theme/tokens.dart' show AppSpacing;

/// 测试页：按能力分组的入口列表。
class TestPage extends StatelessWidget {
  const TestPage({super.key});

  static const double _wideBreakpoint = 900.0;
  static const double _maxContentWidth = 960.0;

  @override
  Widget build(BuildContext context) {
    final List<_TestGroup> groups = <_TestGroup>[
      _TestGroup(
        title: '综合练习',
        entries: <_TestEntry>[
          _TestEntry(
            icon: Icons.connect_without_contact,
            title: '联机对战',
            subtitle: '局域网双人答题对战',
            page: () => const LocalPKSelectPage(),
          ),
          _TestEntry(
            icon: Icons.auto_stories,
            title: '阅读理解',
            subtitle: '阅读短文后作答',
            page: () => const ReadingTestPage(),
          ),
        ],
      ),
      _TestGroup(
        title: '输入训练',
        entries: <_TestEntry>[
          _TestEntry(
            icon: Icons.headphones,
            title: '听抄训练',
            subtitle: '听音频，抄写原文',
            page: () => const DictationListPage(),
          ),
          _TestEntry(
            icon: Icons.multitrack_audio,
            title: '自主听写',
            subtitle: '选择词库听写单词',
            page: () => const ForeListeningSettingPage(),
          ),
        ],
      ),
      _TestGroup(
        title: '口语与记忆',
        entries: <_TestEntry>[
          _TestEntry(
            icon: Icons.record_voice_over,
            title: '课文背诵',
            subtitle: '跟读课文并评测',
            page: () => const RecitationListPage(),
          ),
        ],
      ),
    ];

    return AdaptiveTabBody(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= _wideBreakpoint;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: wide
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(child: _GroupCard(group: groups[0])),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(child: _GroupCard(group: groups[1])),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        _GroupCard(group: groups[2]),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (int i = 0; i < groups.length; i++) ...<Widget>[
                          if (i > 0) const SizedBox(height: AppSpacing.md),
                          _GroupCard(group: groups[i]),
                        ],
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _TestEntry {
  const _TestEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.page,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget Function() page;
}

class _TestGroup {
  const _TestGroup({required this.title, required this.entries});

  final String title;
  final List<_TestEntry> entries;
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.group});

  final _TestGroup group;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.xxs,
            ),
            child: Text(
              group.title,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (int i = 0; i < group.entries.length; i++) ...<Widget>[
            if (i > 0) const Divider(height: 1.0),
            _EntryTile(entry: group.entries[i]),
          ],
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final _TestEntry entry;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(entry.icon),
      title: Text(entry.title),
      subtitle: Text(entry.subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => pushPage(context, entry.page()),
    );
  }
}
