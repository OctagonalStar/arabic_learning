// 同义词管理页：查看/删除已标记的同义对与不同对，并展示传递性同义组。

import 'package:arabic_learning/models/synonym.dart' show GlossPair;
import 'package:arabic_learning/services/global_state.dart';
import 'package:arabic_learning/services/synonyms.dart' show SynonymStore;
import 'package:arabic_learning/theme/tokens.dart' show AppSpacing;
import 'package:arabic_learning/widgets/kit.dart' show Button, TextContainer;
import 'package:arabic_learning/widgets/overlays.dart' show alart;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SynonymPage extends StatefulWidget {
  const SynonymPage({super.key});

  @override
  State<SynonymPage> createState() => _SynonymPage();
}

class _SynonymPage extends State<SynonymPage> {
  final SynonymStore store = SynonymStore();

  /// 删除一对标记（同义或不同）并刷新页面。
  void _removePair(GlossPair pair) {
    context.read<Global>().uiLogger.info("删除同义对标记: ${pair.display}");
    setState(() {
      store.removePair(pair.a, pair.b);
    });
  }

  /// 分区空状态。
  Widget _emptyHint(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Text(
          "暂无标记",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  /// 一个“同义对 / 不同对”列表分区。
  Widget _pairSection(BuildContext context, String title, IconData icon, List<GlossPair> pairs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextContainer(text: title),
        if (pairs.isEmpty)
          _emptyHint(context)
        else
          for (final GlossPair pair in pairs)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(icon),
                title: Text(pair.display),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  tooltip: "删除标记",
                  onPressed: () => _removePair(pair),
                ),
              ),
            ),
      ],
    );
  }

  /// “同义组”分区：展示并查集连通分量，便于查看传递关系。
  Widget _groupSection(BuildContext context, List<List<String>> groups) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextContainer(text: "同义组"),
        if (groups.isEmpty)
          _emptyHint(context)
        else
          for (final List<String> group in groups)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const Icon(Icons.hub),
                title: Text(group.join(" / ")),
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    context.read<Global>().uiLogger.fine("构建 SynonymPage");
    MediaQueryData mediaQuery = MediaQuery.of(context);
    final List<GlossPair> synonyms = store.synonymList;
    final List<GlossPair> distincts = store.distinctList;

    return Scaffold(
      appBar: AppBar(title: Text("同义词管理")),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
              child: Text(
                "同义对被标记后，出题时不会同时出现；\"不同\"对不会被提示为同义。",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            _pairSection(context, "已标记同义（出题时不会同时出现）", Icons.link, synonyms),
            _pairSection(context, "已标记不同（不再提示同义）", Icons.link_off, distincts),
            _groupSection(context, store.synonymGroups()),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Button(
                size: Size.fromHeight(mediaQuery.size.height * 0.08),
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                onPressed: () {
                  alart(context, "确定清空全部同义/不同标记吗？此操作不可撤销。", onConfirmed: () {
                    context.read<Global>().uiLogger.info("清空全部同义对标记");
                    setState(() {
                      store.clearAll();
                    });
                  });
                },
                child: Text("清空全部标记"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
