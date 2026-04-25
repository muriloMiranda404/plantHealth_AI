import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/diary_provider.dart';
import '../../domain/entities/diary_note.dart';

class DiaryListDialog extends StatefulWidget {
  final bool isDarkMode;

  const DiaryListDialog({super.key, required this.isDarkMode});

  @override
  State<DiaryListDialog> createState() => _DiaryListDialogState();
}

class _DiaryListDialogState extends State<DiaryListDialog> {
  String filter = "Tudo";

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<DiaryProvider>().loadNotes());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white54 : Colors.black54;

    return Consumer<DiaryProvider>(
      builder: (context, provider, child) {
        final filteredNotes = provider.notes.where((note) {
          if (filter == "Lembretes") return note.isReminder;
          if (filter == "Recados") return !note.isReminder;
          return true;
        }).toList();

        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.history, color: Colors.blueAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Diário (${provider.notes.length})",
                      style: TextStyle(color: textColor, fontSize: 16),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: () => provider.loadNotes(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ["Tudo", "Lembretes", "Recados"].map((f) {
                    final isSelected = filter == f;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f, style: const TextStyle(fontSize: 12)),
                        selected: isSelected,
                        selectedColor: Colors.blueAccent.withOpacity(0.2),
                        onSelected: (val) {
                          if (val) setState(() => filter = f);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredNotes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              filter == "Lembretes" ? Icons.alarm_off : Icons.note_alt_outlined,
                              size: 40,
                              color: subTextColor.withOpacity(0.3),
                            ),
                            const SizedBox(height: 10),
                            Text("Nenhum registro em \"$filter\"", style: TextStyle(color: subTextColor)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredNotes.length,
                        itemBuilder: (context, index) {
                          final note = filteredNotes[index];
                          return _buildDiaryCard(context, note, provider);
                        },
                      ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("FECHAR", style: TextStyle(color: Colors.blueAccent)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDiaryCard(BuildContext context, DiaryNote note, DiaryProvider provider) {
    return Card(
      child: ListTile(
        title: Text(note.note),
        subtitle: Text(DateTime.fromMillisecondsSinceEpoch(note.timestamp).toString()),
        trailing: IconButton(
          icon: const Icon(Icons.delete, color: Colors.redAccent),
          onPressed: () => provider.deleteNote(note.id!),
        ),
      ),
    );
  }
}
