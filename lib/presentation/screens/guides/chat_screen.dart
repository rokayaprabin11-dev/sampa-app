import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/services/chat_service.dart';
import 'package:sampada/core/services/secure_screen.dart';
import 'package:sampada/injection.dart' as di;
import 'package:sampada/presentation/widgets/common/sampada_app_bar.dart';
import 'package:url_launcher/url_launcher.dart';

/// Booking chat. The conversation lives in Firestore (real-time + offline
/// cache); Django decides whether it may be opened at all — this screen asks it
/// first and shows an explanation rather than an empty thread if the answer is
/// no.
class ChatScreen extends StatefulWidget {
  final int bookingId;

  /// Who we're talking to. Optional: a chat notification carries only the
  /// booking id, so when this is null the screen resolves the name from the
  /// channel's `participants` map instead of showing a blank title.
  final String? otherPartyName;

  const ChatScreen({
    super.key,
    required this.bookingId,
    this.otherPartyName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SecureScreenMixin {
  late final ChatService _chat;
  final _composer = TextEditingController();
  final _scroll = ScrollController();

  ChatChannel? _channel;
  bool _loading = true;
  bool _sending = false;
  String? _resolvedName;

  /// The title: whatever the caller passed, else whatever the channel told us,
  /// else a neutral placeholder while that is in flight.
  String get _title => widget.otherPartyName ?? _resolvedName ?? 'Chat';

  /// Ring the other party on the number they gave. Guides supply one when they
  /// apply; tourists are never asked for one, so this is often absent — and the
  /// button is hidden rather than shown dead.
  Future<void> _call() async {
    final phone = _channel?.otherPartyPhone ?? '';
    if (phone.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: phone);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final launched = await launchUrl(uri);
      if (!launched) throw Exception('no dialer');
    } catch (_) {
      // No dialer (a tablet, an emulator) — show the number so it is still
      // usable rather than failing silently.
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not open the dialer. $_title: $phone'),
          action: SnackBarAction(
            label: 'Copy',
            onPressed: () => Clipboard.setData(ClipboardData(text: phone)),
          ),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _chat = ChatService(apiClient: di.sl<ApiClient>());
    _open();
  }

  Future<void> _open() async {
    final channel = await _chat.openChannel(widget.bookingId);
    if (!mounted) return;
    setState(() {
      _channel = channel;
      _loading = false;
    });
    if (channel == null) return;
    _chat.markRead(channel.channelId);

    // Opened from a notification, which knows the booking but not the person.
    // Django already told us who they are when it handed over the channel; only
    // fall back to the Firestore participants map if it did not.
    if (widget.otherPartyName == null) {
      if (channel.otherPartyName.isNotEmpty) {
        setState(() => _resolvedName = channel.otherPartyName);
        return;
      }
      final other = await _chat.otherParticipant(channel.channelId);
      if (mounted && other != null && other.name.isNotEmpty) {
        setState(() => _resolvedName = other.name);
      }
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final channel = _channel;
    final text = _composer.text.trim();
    if (channel == null || text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _composer.clear();
    try {
      await _chat.send(channel: channel, text: text);
    } catch (e) {
      if (mounted) {
        // Put the text back rather than losing what they typed.
        _composer.text = text;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final canCall = _channel?.canCall ?? false;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: SampadaAppBar(
        title: Text(_title),
        actions: [
          if (canCall)
            IconButton(
              tooltip: 'Call $_title',
              icon: const Icon(Icons.call),
              onPressed: _call,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _channel == null
              ? _unavailable(context, isDark)
              : Column(
                  children: [
                    Expanded(child: _thread(context, isDark, _channel!)),
                    _composerBar(context, isDark, _channel!),
                  ],
                ),
    );
  }

  /// Django refused to hand out a channel — the booking isn't confirmed, or this
  /// user isn't a participant. Say so plainly instead of showing a chat box that
  /// would fail on send.
  Widget _unavailable(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline, size: 56, color: isDark ? AppColors.darkTextTertiary : Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Chat opens once the guide accepts your booking.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _thread(BuildContext context, bool isDark, ChatChannel channel) {
    final myUid = _chat.currentUid;

    return StreamBuilder<List<ChatMessage>>(
      stream: _chat.messages(channel.channelId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final messages = snapshot.data ?? const <ChatMessage>[];
        if (messages.isEmpty) {
          return Center(
            child: Text(
              'Say hello 👋',
              style: TextStyle(color: isDark ? AppColors.darkTextTertiary : Colors.grey),
            ),
          );
        }

        // A message arriving while the thread is open has been seen.
        _chat.markRead(channel.channelId);

        return ListView.builder(
          controller: _scroll,
          reverse: true, // newest at the bottom, and the list opens there
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          itemCount: messages.length,
          itemBuilder: (context, i) {
            final message = messages[messages.length - 1 - i];
            return _bubble(context, isDark, message, mine: message.from == myUid);
          },
        );
      },
    );
  }

  Widget _bubble(BuildContext context, bool isDark, ChatMessage message, {required bool mine}) {
    final mineBg = isDark ? AppColors.goldMain : const Color(0xFF7B1E00);
    final theirsBg = isDark ? AppColors.darkBgCard : const Color(0xFFF0EAE4);

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? mineBg : theirsBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(AppDimensions.kRadiusLg),
            topRight: const Radius.circular(AppDimensions.kRadiusLg),
            bottomLeft: Radius.circular(mine ? AppDimensions.kRadiusLg : 2),
            bottomRight: Radius.circular(mine ? 2 : AppDimensions.kRadiusLg),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: mine
                    ? (isDark ? Colors.black : Colors.white)
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _timeLabel(message),
                  style: TextStyle(
                    fontSize: 9,
                    color: mine
                        ? (isDark ? Colors.black54 : Colors.white70)
                        : (isDark ? AppColors.darkTextTertiary : Colors.grey),
                  ),
                ),
                if (mine) ...[
                  const SizedBox(width: 3),
                  Icon(
                    // Firestore hands us the message from its local cache before
                    // the server acknowledges it, so an unsent message is visible
                    // (and honest about being in flight) even offline.
                    message.isPending ? Icons.schedule : Icons.check,
                    size: 10,
                    color: isDark ? Colors.black54 : Colors.white70,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(ChatMessage message) {
    final at = message.sentAt;
    if (at == null) return 'sending…'; // server timestamp not yet resolved
    final local = at.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Widget _composerBar(BuildContext context, bool isDark, ChatChannel channel) {
    // A closed chat (cancelled booking, or past the post-tour grace period) stays
    // readable but takes no new messages — the server rules would reject a write
    // anyway, so don't offer the box.
    if (!channel.writable) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        color: isDark ? AppColors.darkBgCard : const Color(0xFFF0EAE4),
        child: Text(
          'This conversation is closed.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : AppColors.kColorTextSecondary,
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.kColorBorderSubtle),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _composer,
                maxLength: ChatService.messageMaxLength,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  counterText: '',
                  filled: true,
                  fillColor: isDark ? AppColors.darkBgCard : const Color(0xFFF7F3EF),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimensions.kRadiusPill),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _sending ? null : _send,
                child: SizedBox(
                  width: 44, height: 44,
                  child: Icon(
                    Icons.send,
                    size: 18,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
