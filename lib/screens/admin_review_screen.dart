import 'package:flutter/material.dart';

import '../models/review_entry.dart';
import '../services/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/network_avatar.dart';

const List<(String, int)> kSuspensionPresets = [
  ('1 day', 1),
  ('3 days', 3),
  ('1 week', 7),
  ('2 weeks', 14),
  ('1 month', 30),
];

/// Only reachable if AuthController.checkReviewerStatus() returned true —
/// see the conditional menu tile in ProfileScreen. Every action here is
/// re-verified server-side by banUser regardless (see functions/index.js),
/// so this screen being reachable is a UX gate, not the security boundary.
class AdminReviewScreen extends StatefulWidget {
  const AdminReviewScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<AdminReviewScreen> createState() => _AdminReviewScreenState();
}

class _AdminReviewScreenState extends State<AdminReviewScreen> {
  bool _loading = true;
  List<ReviewEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final entries = await widget.auth.getReviewQueue();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showMessage('Could not load the review queue. Pull down to retry.');
    }
  }

  Future<void> _act(ReviewEntry entry, String action, {int? durationDays}) async {
    try {
      await widget.auth.banUser(
        targetUid: entry.uid,
        action: action,
        durationDays: durationDays,
      );
      if (!mounted) return;
      _showMessage(
        action == 'clear'
            ? '${entry.name}\'s access was restored.'
            : '${entry.name} was ${action == 'permanent' ? 'banned' : 'suspended'}.',
      );
      _load();
    } catch (error) {
      if (!mounted) return;
      _showMessage('Could not complete that action. Please try again.');
    }
  }

  Future<void> _confirmPermanentBan(ReviewEntry entry) async {
    final colors = context.colors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.dialogBackground,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'Permanently ban ${entry.name}?',
          style: TextStyle(color: colors.headerPrimaryText, fontWeight: FontWeight.w900),
        ),
        content: Text(
          'They\'ll be locked out of LooksMatch immediately. You can undo this later '
          'from this screen if needed.',
          style: TextStyle(
            color: colors.headerSecondaryText,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.headerSecondaryText, fontWeight: FontWeight.w800),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'Ban Permanently',
              style: TextStyle(color: colors.deleteBackground, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) await _act(entry, 'permanent');
  }

  Future<void> _pickSuspension(ReviewEntry entry) async {
    final colors = context.colors;

    final days = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: colors.pageBackground,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Suspend ${entry.name} for...',
                  style: TextStyle(
                    color: colors.headerPrimaryText,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...kSuspensionPresets.map(
                (preset) => ListTile(
                  title: Text(
                    preset.$1,
                    style: TextStyle(color: colors.headerPrimaryText, fontWeight: FontWeight.w700),
                  ),
                  onTap: () => Navigator.pop(sheetContext, preset.$2),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (days != null) await _act(entry, 'temporary', durationDays: days);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(message, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
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
          'Review Queue',
          style: TextStyle(
            color: colors.headerPrimaryText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: colors.accent))
          : RefreshIndicator(
              color: colors.accent,
              onRefresh: _load,
              child: _entries.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: Center(
                            child: Text(
                              'Nothing flagged right now.',
                              style: TextStyle(
                                color: colors.headerSecondaryText,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, index) => _entryCard(colors, _entries[index]),
                    ),
            ),
    );
  }

  Widget _entryCard(LooksMatchColors colors, ReviewEntry entry) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NetworkAvatar(url: entry.primaryPhotoUrl, radius: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.age == null ? entry.name : '${entry.name}, ${entry.age}',
                      style: TextStyle(
                        color: colors.headerPrimaryText,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_statusLabel(entry.accountStatus)} · ${entry.reportCount} '
                      '${entry.reportCount == 1 ? 'report' : 'reports'}',
                      style: TextStyle(
                        color: colors.headerSecondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (entry.reports.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...entry.reports.map(
              (report) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: report.reason,
                        style: TextStyle(
                          color: colors.headerPrimaryText,
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                        ),
                      ),
                      if (report.details.isNotEmpty)
                        TextSpan(
                          text: ' — ${report.details}',
                          style: TextStyle(
                            color: colors.headerSecondaryText,
                            fontWeight: FontWeight.w600,
                            fontSize: 12.5,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _act(entry, 'clear'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.accent,
                    side: BorderSide(color: colors.accent.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Clear', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickSuspension(entry),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colors.headerPrimaryText,
                    side: BorderSide(color: colors.outlineButtonBorder),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Suspend', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _confirmPermanentBan(entry),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.deleteBackground,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Ban', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'under_review':
        return 'Under review';
      case 'restricted':
        return 'Restricted';
      case 'suspended':
        return 'Suspended';
      case 'banned':
        return 'Banned';
      default:
        return status;
    }
  }
}
