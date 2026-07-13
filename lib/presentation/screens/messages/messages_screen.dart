import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/network/api_client.dart';
import 'package:sampada/core/services/chat_service.dart';
import 'package:sampada/core/theme/app_theme.dart';
import 'package:sampada/injection.dart' as di;
import 'package:sampada/presentation/screens/guides/chat_screen.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';
import 'package:sampada/presentation/widgets/common/sampada_app_bar.dart';
import 'package:sampada/providers/guide_provider.dart';

/// One row of the inbox: a booking whose chat channel exists, flattened so the
/// list doesn't care which side of it we are on.
class _Conversation {
  final int bookingId;
  final String otherName;
  final String? otherPhoto;

  /// 'Guide' or 'Tourist' — who the *other* person is, which is the useful
  /// label when a user has conversations on both sides.
  final String otherRole;
  final String date;
  final bool isPast;

  const _Conversation({
    required this.bookingId,
    required this.otherName,
    required this.otherRole,
    required this.date,
    required this.isPast,
    this.otherPhoto,
  });
}

/// Every conversation this user is a member of, on either side of a booking.
///
/// A chat exists only where Django opened a channel — bookings that reached
/// `confirmed`, staying reachable through `completed` for the post-tour grace
/// period (backend/apps/guides/chat.py `chat_state()`). So conversations are
/// derived from the bookings we already hold rather than being a second source
/// of truth: no booking, no chat.
///
/// Both sides are merged deliberately. A guide who also books tours as a tourist
/// has conversations in both directions, and splitting them across two screens
/// would hide half their messages.
class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late final ChatService _chat = ChatService(apiClient: di.sl<ApiClient>());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final gp = context.read<GuideProvider>();
    // Both sides. fetchIncomingBookings is a no-op for a user who isn't a guide
    // (the endpoint refuses and the provider swallows it), so this is safe to
    // call unconditionally rather than branching on a profile we may not have
    // loaded yet.
    await Future.wait([gp.fetchMyBookings(), gp.fetchIncomingBookings()]);
  }

  static bool _hasChat(Map<String, dynamic> b) =>
      b['status'] == 'confirmed' || b['status'] == 'completed';

  List<_Conversation> _conversations(GuideProvider gp) {
    final out = <_Conversation>[];

    // Tours we booked — the other party is the guide.
    for (final b in gp.myBookings.where(_hasChat)) {
      out.add(_Conversation(
        bookingId: b['id'] as int,
        otherName: (b['guide_name'] ?? 'Guide').toString(),
        otherPhoto: b['guide_photo']?.toString(),
        otherRole: 'Guide',
        date: '${b['date'] ?? ''}',
        isPast: b['status'] == 'completed',
      ));
    }

    // Tours we guide — the other party is the tourist.
    for (final b in gp.incomingBookings.where(_hasChat)) {
      out.add(_Conversation(
        bookingId: b['id'] as int,
        otherName: (b['tourist_name'] ?? 'Tourist').toString(),
        otherRole: 'Tourist',
        date: '${b['date'] ?? ''}',
        isPast: b['status'] == 'completed',
      ));
    }

    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: const SampadaAppBar(title: Text('Messages')),
      body: Consumer<GuideProvider>(
        builder: (context, gp, _) {
          final conversations = _conversations(gp);
          return RefreshIndicator(
            color: AppColors.kColorPrimary,
            onRefresh: _load,
            child: conversations.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: const _EmptyInbox(),
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.sp16,
                        vertical: AppDimensions.sp12),
                    itemCount: conversations.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimensions.sp10),
                    itemBuilder: (context, i) => _ConversationTile(
                      conversation: conversations[i],
                      chat: _chat,
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.sp32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.kDarkBgCard : AppColors.kColorBgWarm,
              ),
              child: Icon(Icons.forum_outlined,
                  size: 44,
                  color: isDark
                      ? AppColors.kColorAccentLight
                      : AppColors.kColorAccent),
            ),
            const SizedBox(height: AppDimensions.sp20),
            Text('No conversations yet',
                textAlign: TextAlign.center,
                style: t.titleMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: AppDimensions.sp8),
            Text(
              'A chat opens as soon as a guide accepts a booking.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(
                  color: isDark
                      ? AppColors.kDarkTextMuted
                      : AppColors.kColorTextMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// One conversation. Name, role and date come from the booking; the preview line
/// and the unread dot are streamed live from Firestore, where the messages are.
class _ConversationTile extends StatelessWidget {
  final _Conversation conversation;
  final ChatService chat;

  const _ConversationTile({required this.conversation, required this.chat});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// "14:32" today, "Mon" this week, "12 Jul" beyond.
  String _stamp(DateTime dt) {
    final now = DateTime.now();
    final local = dt.toLocal();
    if (local.year == now.year &&
        local.month == now.month &&
        local.day == now.day) {
      return '${local.hour.toString().padLeft(2, '0')}:'
          '${local.minute.toString().padLeft(2, '0')}';
    }
    if (now.difference(local).inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[local.weekday - 1];
    }
    return '${local.day} ${_months[local.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = isDark ? AppColors.kDarkTextMuted : AppColors.kColorTextMuted;
    final channelId = ChatService.channelIdFor(conversation.bookingId);
    final myUid = chat.currentUid;

    return StreamBuilder<ChatMessage?>(
      stream: chat.lastMessage(channelId),
      builder: (context, msgSnap) {
        final last = msgSnap.data;
        return StreamBuilder<DateTime?>(
          stream: chat.myReadAt(channelId),
          builder: (context, readSnap) {
            final readAt = readSnap.data;
            // Unread == the other party spoke last, and after we last looked.
            final unread = last != null &&
                last.from != myUid &&
                last.sentAt != null &&
                (readAt == null || last.sentAt!.isAfter(readAt));

            return Material(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      bookingId: conversation.bookingId,
                      otherPartyName: conversation.otherName,
                    ),
                  ),
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.sp14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppDimensions.kRadiusXl),
                    border: Border.all(
                        color: isDark
                            ? AppColors.kDarkBorder
                            : AppColors.kColorBorderSubtle),
                  ),
                  child: Row(
                    children: [
                      _Avatar(conversation: conversation),
                      const SizedBox(width: AppDimensions.sp12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    conversation.otherName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.titleSmall?.copyWith(
                                      color: onSurface,
                                      fontWeight: unread
                                          ? FontWeight.w800
                                          : FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (last?.sentAt != null)
                                  Text(
                                    _stamp(last!.sentAt!),
                                    style: t.bodySmall?.copyWith(
                                      color: unread
                                          ? AppColors.kColorPrimary
                                          : muted,
                                      fontWeight: unread
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.sp2),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    last == null
                                        ? 'No messages yet — say hello'
                                        : '${last.from == myUid ? 'You: ' : ''}${last.text}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: t.bodySmall?.copyWith(
                                      color: unread ? onSurface : muted,
                                      fontWeight: unread
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      fontStyle: last == null
                                          ? FontStyle.italic
                                          : FontStyle.normal,
                                    ),
                                  ),
                                ),
                                if (unread) ...[
                                  const SizedBox(width: AppDimensions.sp6),
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.kColorPrimary,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: AppDimensions.sp4),
                            Row(
                              children: [
                                const Icon(Icons.event_outlined,
                                    size: 13,
                                    color: AppColors.kColorAccentSafe),
                                const SizedBox(width: AppDimensions.sp4),
                                Text(conversation.date,
                                    style: t.bodySmall?.copyWith(color: muted)),
                                const SizedBox(width: AppDimensions.sp8),
                                Text(
                                  conversation.isPast
                                      ? '· ${conversation.otherRole} · Past tour'
                                      : '· ${conversation.otherRole}',
                                  style: t.bodySmall?.copyWith(color: muted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _Avatar extends StatelessWidget {
  final _Conversation conversation;
  const _Avatar({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final name = conversation.otherName;
    final photo = conversation.otherPhoto;

    final monogram = Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.avatarGradient,
      ),
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: t.titleMedium?.copyWith(
            color: AppColors.kColorTextOnPrimary, fontWeight: FontWeight.w700),
      ),
    );

    if (photo == null || photo.isEmpty) return monogram;
    return ClipOval(
      child: AppNetworkImage(
        url: photo,
        width: 46,
        height: 46,
        fit: BoxFit.cover,
        errorWidget: monogram,
      ),
    );
  }
}
