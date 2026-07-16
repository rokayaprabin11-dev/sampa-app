import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/services/support_service.dart';
import 'package:sampada/injection.dart' as di;
import 'package:sampada/presentation/screens/help/help_content.dart';
import 'package:sampada/presentation/screens/help/help_widgets.dart';

Future<void> _launch(BuildContext context, Uri uri, String fallback) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } catch (_) {/* fall through */}
  messenger.showSnackBar(SnackBar(content: Text(fallback)));
}

void pushHelp(BuildContext context, Widget screen) {
  Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
}

// ─────────────────────────────────────────────────────────────────────────────
// Contact Support
// ─────────────────────────────────────────────────────────────────────────────
class HelpContactSupportScreen extends StatefulWidget {
  const HelpContactSupportScreen({super.key});
  @override
  State<HelpContactSupportScreen> createState() => _HelpContactSupportScreenState();
}

class _HelpContactSupportScreenState extends State<HelpContactSupportScreen> {
  static const _categories = [
    'Account Issue', 'Booking Issue', 'Guide Issue', 'Event Issue',
    'Technical Issue', 'Bug Report', 'Other',
  ];
  int _category = 0;
  bool _sending = false;
  final _subject = TextEditingController();
  final _description = TextEditingController();

  @override
  void dispose() {
    _subject.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subject.text.trim().isEmpty) {
      showHelpToast(context, 'Add a short subject first', icon: Icons.info_outline);
      return;
    }
    if (_description.text.trim().isEmpty) {
      showHelpToast(context, 'Describe the issue first', icon: Icons.info_outline);
      return;
    }
    setState(() => _sending = true);
    final ticket = await SupportService(apiClient: di.sl<ApiClient>()).submit(
      kind: 'support',
      category: _categories[_category],
      subject: _subject.text.trim(),
      message: _description.text.trim(),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ticket != null) {
      showHelpToast(context, 'Request sent — we\'ll reply in the app');
      Navigator.pop(context);
    } else {
      showHelpToast(context, 'Couldn\'t send. Check your connection.',
          icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HelpScaffold(
      title: 'Contact Support',
      subtitle: 'Tell us what happened',
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const HelpEyebrow('New request'),
          const HelpSectionTitle('Category', padding: EdgeInsets.only(bottom: 12)),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (int i = 0; i < _categories.length; i++)
                HelpChip(
                  label: _categories[i],
                  selected: _category == i,
                  onTap: () => setState(() => _category = i),
                ),
            ],
          ),
          const SizedBox(height: 20),
          HelpTextField(label: 'Subject', hint: 'A short summary of the issue', controller: _subject),
          const SizedBox(height: 16),
          HelpTextField(
            label: 'Description',
            hint: 'Tell us what happened, when it started, and what you expected instead',
            maxLines: 5,
            controller: _description,
          ),
          const SizedBox(height: 16),
          const _AttachmentRow(),
          const SizedBox(height: 20),
          HelpPrimaryButton(
              label: _sending ? 'Sending…' : 'Submit Request',
              icon: Icons.send,
              onTap: _sending ? null : _submit),
          const SizedBox(height: 10),
          Center(child: Text('We\'ll reply inside the app under "My Support Requests"',
              style: TextStyle(fontSize: 11, color: HelpPalette.of(context).faint))),
        ],
      ),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow();
  @override
  Widget build(BuildContext context) {
    final p = HelpPalette.of(context);
    Widget btn(IconData icon, String label) => Expanded(
          child: GestureDetector(
            onTap: () => showHelpToast(context, 'Attach files in your mail app after tapping Submit',
                icon: Icons.attach_file),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: HelpColors.terracotta.withValues(alpha: p.isDark ? 0.12 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.faint, style: BorderStyle.solid, width: 1),
              ),
              child: Column(
                children: [
                  Icon(icon, size: 16, color: HelpColors.terracottaDeep),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: HelpColors.terracottaDeep)),
                ],
              ),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Attachments', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: p.ink)),
        const SizedBox(height: 7),
        Row(children: [btn(Icons.image_outlined, 'Screenshot'), const SizedBox(width: 10), btn(Icons.videocam_outlined, 'Video')]),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAQs
// ─────────────────────────────────────────────────────────────────────────────
class HelpFaqsScreen extends StatefulWidget {
  const HelpFaqsScreen({super.key});
  @override
  State<HelpFaqsScreen> createState() => _HelpFaqsScreenState();
}

class _HelpFaqsScreenState extends State<HelpFaqsScreen> {
  String _query = '';
  final Set<String> _open = {};

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    return HelpScaffold(
      title: 'FAQs',
      subtitle: 'Quick answers',
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          HelpSearchField(hint: 'Search FAQs...', onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 18),
          for (final cat in helpFaqs) ...[
            () {
              final matches = cat.items.where((f) =>
                  q.isEmpty || f.question.toLowerCase().contains(q) || f.answer.toLowerCase().contains(q)).toList();
              if (matches.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Text(cat.label.toUpperCase(), style: helpLabel(size: 10, color: HelpColors.terracottaDeep)),
                  ),
                  for (final f in matches) _FaqTile(
                    faq: f,
                    open: _open.contains(f.question),
                    onTap: () => setState(() =>
                        _open.contains(f.question) ? _open.remove(f.question) : _open.add(f.question)),
                  ),
                  const SizedBox(height: 14),
                ],
              );
            }(),
          ],
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final HelpFaq faq;
  final bool open;
  final VoidCallback onTap;
  const _FaqTile({required this.faq, required this.open, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = HelpPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: p.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  Expanded(child: Text(faq.question,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: p.ink))),
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    turns: open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down, size: 18, color: p.muted),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
              child: Text(faq.answer, style: TextStyle(fontSize: 12.5, height: 1.55, color: p.muted)),
            ),
            crossFadeState: open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Troubleshooting  →  Article
// ─────────────────────────────────────────────────────────────────────────────
class HelpTroubleshootingScreen extends StatelessWidget {
  const HelpTroubleshootingScreen({super.key});
  @override
  Widget build(BuildContext context) {
    const items = [
      ('gps', Icons.location_on_outlined),
      ('notif', Icons.notifications_none),
      ('login', Icons.lock_outline),
      ('offline', Icons.wifi_off),
      ('guideloc', Icons.person_pin_circle_outlined),
    ];
    return HelpScaffold(
      title: 'Troubleshooting',
      subtitle: 'Fix common issues',
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const HelpEyebrow('Common issues'),
          const SizedBox(height: 8),
          HelpMenuList(children: [
            for (final it in items)
              HelpMenuItem(
                icon: it.$2,
                title: helpArticles[it.$1]!.title,
                onTap: () => pushHelp(context, HelpArticleScreen(articleKey: it.$1)),
              ),
          ]),
        ],
      ),
    );
  }
}

class HelpArticleScreen extends StatelessWidget {
  final String articleKey;
  const HelpArticleScreen({super.key, required this.articleKey});
  @override
  Widget build(BuildContext context) {
    final a = helpArticles[articleKey]!;
    final p = HelpPalette.of(context);
    Widget block(String label, Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(), style: helpLabel(size: 10, color: HelpColors.terracottaDeep)),
              const SizedBox(height: 8),
              child,
            ],
          ),
        );
    return HelpScaffold(
      title: a.title,
      subtitle: 'Troubleshooting',
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          block('Problem', Text(a.problem, style: TextStyle(fontSize: 13, height: 1.6, color: p.ink))),
          block('Possible causes', Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in a.causes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 7, right: 8),
                        child: Container(width: 5, height: 5, decoration: BoxDecoration(
                            color: p.faint, shape: BoxShape.circle))),
                    Expanded(child: Text(c, style: TextStyle(fontSize: 13, height: 1.5, color: p.ink))),
                  ]),
                ),
            ],
          )),
          block('Step-by-step solution', Column(
            children: [
              for (int i = 0; i < a.steps.length; i++) _StepRow(number: i + 1, text: a.steps[i]),
            ],
          )),
          const SizedBox(height: 4),
          HelpSecondaryButton(
            label: 'Still need help?',
            onTap: () => pushHelp(context, const HelpContactSupportScreen()),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final int number;
  final String text;
  const _StepRow({required this.number, required this.text});
  @override
  Widget build(BuildContext context) {
    final p = HelpPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20, height: 20, alignment: Alignment.center,
            decoration: const BoxDecoration(color: HelpColors.terracotta, shape: BoxShape.circle),
            child: Text('$number', style: const TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, height: 1.5, color: p.ink))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Emergency Contacts
// ─────────────────────────────────────────────────────────────────────────────
class HelpEmergencyScreen extends StatelessWidget {
  const HelpEmergencyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final p = HelpPalette.of(context);
    return HelpScaffold(
      title: 'Emergency Contacts',
      subtitle: 'One tap in a crisis',
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const HelpEyebrow('Nepal · dial directly'),
          const SizedBox(height: 10),
          for (final e in helpEmergencyContacts)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line)),
              child: Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: HelpColors.alert.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.emergency_share_outlined, size: 18, color: HelpColors.alert),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.name, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.ink)),
                        Text(e.number, style: TextStyle(fontSize: 12, color: p.muted)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _launch(context, Uri.parse('tel:${e.number}'), 'Dial ${e.number}'),
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(color: HelpColors.sage, shape: BoxShape.circle),
                      child: const Icon(Icons.call, size: 17, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Center(child: Text('If you are in immediate danger, move to a public place first.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: p.faint))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Contact Information
// ─────────────────────────────────────────────────────────────────────────────
class HelpContactInfoScreen extends StatelessWidget {
  const HelpContactInfoScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return HelpScaffold(
      title: 'Contact Information',
      subtitle: 'Reach the Sampada team',
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          HelpMenuList(children: [
            HelpMenuItem(
              icon: Icons.email_outlined, title: 'Email', subtitle: helpSupportEmail,
              onTap: () => _launch(context, Uri.parse('mailto:$helpSupportEmail'),
                  'Write to $helpSupportEmail'),
            ),
            HelpMenuItem(
              icon: Icons.call_outlined, title: 'Phone', subtitle: helpSupportPhone,
              onTap: () => _launch(context, Uri.parse('tel:${helpSupportPhone.replaceAll(' ', '')}'),
                  'Call $helpSupportPhone'),
            ),
            HelpMenuItem(icon: Icons.schedule, title: 'Office hours', subtitle: helpOfficeHours),
            HelpMenuItem(icon: Icons.place_outlined, title: 'Office', subtitle: 'Banepa, Kavre, Nepal'),
          ]),
          const SizedBox(height: 14),
          HelpCard(
            onTap: () async {
              await Clipboard.setData(const ClipboardData(text: helpSupportEmail));
              if (context.mounted) showHelpToast(context, 'Email copied', icon: Icons.copy);
            },
            child: Row(children: [
              const Icon(Icons.copy, size: 16, color: HelpColors.terracottaDeep),
              const SizedBox(width: 10),
              Expanded(child: Text('Copy support email',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: HelpPalette.of(context).ink))),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Feedback
// ─────────────────────────────────────────────────────────────────────────────
class HelpFeedbackScreen extends StatefulWidget {
  const HelpFeedbackScreen({super.key});
  @override
  State<HelpFeedbackScreen> createState() => _HelpFeedbackScreenState();
}

class _HelpFeedbackScreenState extends State<HelpFeedbackScreen> {
  int _rating = 0;
  bool _sending = false;
  final _comment = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      showHelpToast(context, 'Tap a star to rate first', icon: Icons.info_outline);
      return;
    }
    setState(() => _sending = true);
    final comment = _comment.text.trim();
    final ticket = await SupportService(apiClient: di.sl<ApiClient>()).submit(
      kind: 'feedback',
      category: 'App rating',
      subject: '$_rating/5 stars',
      message: comment.isEmpty ? '($_rating stars, no comment)' : comment,
      rating: _rating,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ticket != null) {
      showHelpToast(context, 'Thanks for the feedback!');
      Navigator.pop(context);
    } else {
      showHelpToast(context, 'Couldn\'t send. Check your connection.',
          icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = HelpPalette.of(context);
    return HelpScaffold(
      title: 'Feedback',
      subtitle: 'Tell us how we\'re doing',
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const SizedBox(height: 8),
          Center(child: Text('How would you rate Sampada?',
              style: helpSerif(size: 16, color: p.ink))),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 1; i <= 5; i++)
                GestureDetector(
                  onTap: () => setState(() => _rating = i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 38,
                      color: i <= _rating ? HelpColors.gold : p.faint,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 22),
          HelpTextField(
            label: 'Anything you\'d like to add?',
            hint: 'What do you love, what could be better?',
            maxLines: 5,
            controller: _comment,
          ),
          const SizedBox(height: 20),
          HelpPrimaryButton(
              label: _sending ? 'Sending…' : 'Send Feedback',
              icon: Icons.send,
              onTap: _sending ? null : _submit),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Report a Problem  →  Report form
// ─────────────────────────────────────────────────────────────────────────────
class HelpReportScreen extends StatelessWidget {
  const HelpReportScreen({super.key});
  @override
  Widget build(BuildContext context) {
    const items = [
      ('Report Guide', Icons.badge_outlined, 'Conduct, no-show, misrepresentation'),
      ('Report User', Icons.person_outline, 'Abuse, spam, impersonation'),
      ('Report Event', Icons.event_outlined, 'Wrong details, cancelled, unsafe'),
      ('Report Heritage Site', Icons.account_balance_outlined, 'Incorrect info, closed, damaged'),
      ('Report App Bug', Icons.bug_report_outlined, 'Crashes, glitches, broken screens'),
    ];
    return HelpScaffold(
      title: 'Report a Problem',
      subtitle: 'Flag something that isn\'t right',
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const HelpEyebrow('What would you like to report?'),
          const SizedBox(height: 10),
          HelpMenuList(children: [
            for (final it in items)
              HelpMenuItem(
                icon: it.$2, title: it.$1, subtitle: it.$3, tint: HelpColors.alert,
                onTap: () => pushHelp(context, HelpReportFormScreen(kind: it.$1)),
              ),
          ]),
        ],
      ),
    );
  }
}

class HelpReportFormScreen extends StatefulWidget {
  final String kind;
  const HelpReportFormScreen({super.key, required this.kind});
  @override
  State<HelpReportFormScreen> createState() => _HelpReportFormScreenState();
}

class _HelpReportFormScreenState extends State<HelpReportFormScreen> {
  static const _reasons = ['Behavior', 'Safety concern', 'Incorrect info', 'Other'];
  int _reason = 0;
  bool _sending = false;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  String _targetType() {
    final k = widget.kind.toLowerCase();
    if (k.contains('guide')) return 'guide';
    if (k.contains('user')) return 'user';
    if (k.contains('event')) return 'event';
    if (k.contains('site') || k.contains('heritage')) return 'site';
    if (k.contains('bug')) return 'bug';
    return 'other';
  }

  Future<void> _submit() async {
    if (_details.text.trim().isEmpty) {
      showHelpToast(context, 'Add some detail so we can look into it', icon: Icons.info_outline);
      return;
    }
    setState(() => _sending = true);
    final ticket = await SupportService(apiClient: di.sl<ApiClient>()).submit(
      kind: 'report',
      category: _reasons[_reason],
      subject: widget.kind,
      message: _details.text.trim(),
      targetType: _targetType(),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ticket != null) {
      showHelpToast(context, 'Report submitted — our team will review it');
      Navigator.pop(context);
    } else {
      showHelpToast(context, 'Couldn\'t submit. Check your connection.',
          icon: Icons.error_outline);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HelpScaffold(
      title: widget.kind,
      subtitle: 'Our team reviews every report',
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          HelpEyebrow(widget.kind),
          const SizedBox(height: 14),
          Text('Reason', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: HelpPalette.of(context).ink)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (int i = 0; i < _reasons.length; i++)
              HelpChip(label: _reasons[i], selected: _reason == i, onTap: () => setState(() => _reason = i)),
          ]),
          const SizedBox(height: 18),
          HelpTextField(
            label: 'Description',
            hint: 'Share details so our team can look into this',
            maxLines: 5,
            controller: _details,
          ),
          const SizedBox(height: 16),
          const _AttachmentRow(),
          const SizedBox(height: 20),
          HelpPrimaryButton(
              label: _sending ? 'Submitting…' : 'Submit Report',
              icon: Icons.flag_outlined,
              onTap: _sending ? null : _submit),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Safety Center  /  Generic topic  (shared info-card layout)
// ─────────────────────────────────────────────────────────────────────────────
class HelpInfoScreen extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? eyebrow;
  final List<HelpTopicInfo> points;
  const HelpInfoScreen({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    required this.points,
  });
  @override
  Widget build(BuildContext context) {
    final p = HelpPalette.of(context);
    return HelpScaffold(
      title: title,
      subtitle: subtitle,
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (eyebrow != null) ...[HelpEyebrow(eyebrow!), const SizedBox(height: 6)],
          for (final pt in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: HelpCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pt.heading, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.ink)),
                    const SizedBox(height: 5),
                    Text(pt.body, style: TextStyle(fontSize: 12.5, height: 1.55, color: p.muted)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Live Chat  (front-end shell — see note in the Help home)
// ─────────────────────────────────────────────────────────────────────────────
class HelpLiveChatScreen extends StatefulWidget {
  const HelpLiveChatScreen({super.key});
  @override
  State<HelpLiveChatScreen> createState() => _HelpLiveChatScreenState();
}

class _HelpLiveChatScreenState extends State<HelpLiveChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<({bool me, String text})> _messages = [
    (me: false, text: 'Namaste! I\'m Sujata from Sampada support. How can I help today?'),
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send() {
    final t = _input.text.trim();
    if (t.isEmpty) return;
    setState(() {
      _messages.add((me: true, text: t));
      _input.clear();
    });
    _scrollToEnd();
    // Canned acknowledgement so the shell feels alive until the backend lands.
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() => _messages.add((
            me: false,
            text: 'Thanks — a support agent will reply here shortly. '
                'For anything urgent, tap Contact Support to email us.',
          )));
      _scrollToEnd();
    });
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = HelpPalette.of(context);
    return HelpScaffold(
      title: 'Live Chat',
      subtitle: 'Sujata is online',
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                return Align(
                  alignment: m.me ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                    decoration: BoxDecoration(
                      color: m.me ? HelpColors.terracotta : p.card,
                      border: m.me ? null : Border.all(color: p.line),
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(m.me ? 16 : 4),
                        bottomRight: Radius.circular(m.me ? 4 : 16),
                      ),
                    ),
                    child: Text(m.text, style: TextStyle(
                        fontSize: 12.5, height: 1.5, color: m.me ? Colors.white : p.ink)),
                  ),
                );
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(color: p.page, border: Border(top: BorderSide(color: p.line))),
            padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    onSubmitted: (_) => _send(),
                    style: TextStyle(fontSize: 13, color: p.ink),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: p.faint, fontSize: 13),
                      filled: true, fillColor: p.card,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: p.line)),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: p.line)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: const BorderSide(color: HelpColors.terracotta)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _send,
                  child: Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(color: HelpColors.terracotta, shape: BoxShape.circle),
                    child: const Icon(Icons.send, size: 17, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My Support Requests  (real tickets + the admin's reply)
// ─────────────────────────────────────────────────────────────────────────────
({Color bg, Color fg, String label}) ticketStatusStyle(String s) {
  switch (s) {
    case 'resolved':
      return (bg: const Color(0xFFEAF4EC), fg: const Color(0xFF2D7A3A), label: 'Resolved');
    case 'in_progress':
      return (bg: const Color(0xFFE8F0FB), fg: const Color(0xFF1B5FA8), label: 'In progress');
    case 'closed':
      return (bg: const Color(0xFFEAE4DC), fg: const Color(0xFF6B5F57), label: 'Closed');
    default:
      return (bg: AppColors.kColorPendingBg, fg: AppColors.kColorPendingText, label: 'Open');
  }
}

class HelpMyRequestsScreen extends StatefulWidget {
  const HelpMyRequestsScreen({super.key});
  @override
  State<HelpMyRequestsScreen> createState() => _HelpMyRequestsScreenState();
}

class _HelpMyRequestsScreenState extends State<HelpMyRequestsScreen> {
  late final SupportService _svc = SupportService(apiClient: di.sl<ApiClient>());
  List<SupportTicket>? _tickets;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final t = await _svc.myTickets();
      if (mounted) setState(() { _tickets = t; _error = false; });
    } catch (_) {
      if (mounted) setState(() { _error = true; _tickets = const []; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = HelpPalette.of(context);
    final tickets = _tickets;
    return HelpScaffold(
      title: 'My Support Requests',
      subtitle: 'Track your requests and replies',
      body: tickets == null
          ? const Center(child: CircularProgressIndicator())
          : _error
              ? _message(p, 'Couldn\'t load your requests.\nPull to try again.')
              : tickets.isEmpty
                  ? _empty(context, p)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(18),
                        itemCount: tickets.length,
                        itemBuilder: (_, i) => _ticketCard(context, p, tickets[i]),
                      ),
                    ),
    );
  }

  Widget _message(HelpPalette p, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: p.muted)),
        ),
      );

  Widget _empty(BuildContext context, HelpPalette p) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: p.faint),
              const SizedBox(height: 16),
              Text('No requests yet', style: helpSerif(size: 16, color: p.ink)),
              const SizedBox(height: 6),
              Text('When you contact support or report a problem, it appears here with our reply.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, height: 1.5, color: p.muted)),
              const SizedBox(height: 20),
              HelpPrimaryButton(
                label: 'Contact Support', icon: Icons.chat_bubble_outline,
                onTap: () => pushHelp(context, const HelpContactSupportScreen()),
              ),
            ],
          ),
        ),
      );

  Widget _ticketCard(BuildContext context, HelpPalette p, SupportTicket t) {
    final st = ticketStatusStyle(t.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: HelpCard(
        onTap: () => _showTicket(context, t),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    t.subject.isNotEmpty ? t.subject : (t.category.isNotEmpty ? t.category : 'Request'),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: p.ink),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(20)),
                  child: Text(st.label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: st.fg)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(t.message, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, height: 1.4, color: p.muted)),
            if (t.hasReply) ...[
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.mark_chat_read_outlined, size: 14, color: HelpColors.sage),
                const SizedBox(width: 6),
                Text('Support replied', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: HelpColors.sage)),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  void _showTicket(BuildContext context, SupportTicket t) {
    final p = HelpPalette.of(context);
    final st = ticketStatusStyle(t.status);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 10), width: 40, height: 4,
                decoration: BoxDecoration(color: p.faint.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text(
                        t.subject.isNotEmpty ? t.subject : (t.category.isNotEmpty ? t.category : 'Request'),
                        style: helpSerif(size: 17, color: p.ink))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: st.bg, borderRadius: BorderRadius.circular(20)),
                        child: Text(st.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: st.fg)),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    const HelpEyebrow('Your message'),
                    const SizedBox(height: 4),
                    Text(t.message, style: TextStyle(fontSize: 13.5, height: 1.55, color: p.ink)),
                    if (t.hasReply) ...[
                      const SizedBox(height: 18),
                      const HelpEyebrow('Support reply'),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: p.isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFEAF4EC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: p.isDark ? p.line : const Color(0xFFCFE6D3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (t.respondedByName.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Text(t.respondedByName,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: HelpColors.sage)),
                              ),
                            Text(t.adminResponse, style: TextStyle(fontSize: 13.5, height: 1.55, color: p.ink)),
                          ],
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: 18),
                      Text('No reply yet — we\'ll notify you when support responds.',
                          style: TextStyle(fontSize: 12.5, color: p.muted)),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// About  (routes into the app's existing About screen from the home)
// ─────────────────────────────────────────────────────────────────────────────
void openAbout(BuildContext context) => Navigator.pushNamed(context, AppStrings.aboutPath);
