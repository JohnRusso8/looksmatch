import 'package:flutter/material.dart';

import '../models/profile_extras.dart';
import '../theme/app_theme.dart';

/// Full-screen prompt editor — shows the currently chosen prompt (tappable
/// to change) and a full-width answer field. Returns the finished
/// ProfilePrompt via Navigator.pop, or null if the user backs out.
class PromptEditScreen extends StatefulWidget {
  const PromptEditScreen({
    super.key,
    required this.availablePrompts,
    this.initialPrompt,
    this.initialAnswer = '',
  });

  final List<String> availablePrompts;
  final String? initialPrompt;
  final String initialAnswer;

  @override
  State<PromptEditScreen> createState() => _PromptEditScreenState();
}

class _PromptEditScreenState extends State<PromptEditScreen> {
  late String? _selectedPrompt = widget.initialPrompt;
  late final TextEditingController _answerController = TextEditingController(
    text: widget.initialAnswer,
  );

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  bool get _canSave =>
      _selectedPrompt != null && _answerController.text.trim().isNotEmpty;

  Future<void> _choosePrompt() async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PromptOptionsSheet(
        options: widget.availablePrompts,
        selected: _selectedPrompt,
      ),
    );
    if (chosen != null) setState(() => _selectedPrompt = chosen);
  }

  void _save() {
    if (!_canSave) return;
    Navigator.pop(
      context,
      ProfilePrompt(prompt: _selectedPrompt!, answer: _answerController.text.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      backgroundColor: colors.pageBackground,
      appBar: AppBar(
        backgroundColor: colors.headerBackground,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: colors.headerIconColor),
        title: Text(
          'Edit Prompt',
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _canSave ? _save : null,
            child: Text(
              'Save',
              style: TextStyle(
                color: _canSave ? colors.accent : colors.headerSecondaryText,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Prompt',
                style: TextStyle(
                  color: colors.headerPrimaryText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _choosePrompt,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.inputBackground,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: colors.inputBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedPrompt ?? 'Choose a prompt',
                            style: TextStyle(
                              color: _selectedPrompt == null
                                  ? colors.inputHint
                                  : colors.headerPrimaryText,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                        Icon(Icons.unfold_more_rounded, color: colors.accent),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Your answer',
                style: TextStyle(
                  color: colors.headerPrimaryText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 9),
              Expanded(
                child: TextField(
                  controller: _answerController,
                  maxLength: 150,
                  expands: true,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Your answer',
                    hintStyle: TextStyle(color: colors.inputHint, fontWeight: FontWeight.w600),
                    filled: true,
                    fillColor: colors.inputBackground,
                    alignLabelWithHint: true,
                    contentPadding: const EdgeInsets.all(16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: colors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: colors.accent, width: 1.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PromptOptionsSheet extends StatelessWidget {
  const _PromptOptionsSheet({required this.options, this.selected});

  final List<String> options;
  final String? selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.pageBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.divider,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose a prompt',
                style: TextStyle(
                  color: colors.headerPrimaryText,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  itemCount: options.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: colors.divider),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final isSelected = option == selected;
                    return ListTile(
                      title: Text(
                        option,
                        style: TextStyle(
                          color: colors.headerPrimaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_rounded, color: colors.accent)
                          : null,
                      onTap: () => Navigator.pop(context, option),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
