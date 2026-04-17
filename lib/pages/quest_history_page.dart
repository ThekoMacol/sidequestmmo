import 'package:flutter/material.dart';
import '../models/quest.dart';
import '../models/app_lang.dart';


class QuestHistoryPage extends StatelessWidget {
  final List<Quest> completedQuests;
  final AppLang lang;

  const QuestHistoryPage({
    super.key,
    required this.completedQuests,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    final items = List<Quest>.from(completedQuests);

    return Scaffold(
      appBar: AppBar(
        title: Text(lang == AppLang.de ? 'History' : 'History'),
      ),
      body: items.isEmpty
          ? Center(child: Text(lang == AppLang.de ? 'Keine Einträge' : 'No entries'))
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final q = items[i];
          final status = q.failed
              ? (lang == AppLang.de ? 'Fehlgeschlagen' : 'Failed')
              : (lang == AppLang.de ? 'Abgeschlossen' : 'Completed');

          final ts = q.finishedAt ?? q.endAt ?? q.dayKey;

          return Card(
            child: ListTile(
              title: Text(q.name),
              subtitle: Text([
                status,
                if (ts != null) ts.toLocal().toString(),
              ].join(' • ')),
              trailing: Text(q.type.name),
            ),
          );
        },
      ),
    );
  }
}
