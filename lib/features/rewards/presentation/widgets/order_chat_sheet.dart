import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/rewards.dart';
import '../bloc/order_chat_cubit.dart';

/// The maximum the server accepts for one message.
const _maxMessageLength = 2000;

/// Opens the tracking conversation for [order].
///
/// The cubit is created here and owned by the sheet, so its poll timer is
/// disposed the moment the sheet closes.
Future<void> showOrderChatSheet(
  BuildContext context, {
  required RewardOrder order,
  required OrderChatCubit Function() createCubit,
}) {
  return showAppSheet<void>(
    context,
    title: order.productTitle,
    subtitle: 'Order tracking chat',
    builder: (_) => BlocProvider(
      create: (_) => createCubit()..load(),
      child: const _OrderChatBody(),
    ),
  );
}

class _OrderChatBody extends StatefulWidget {
  const _OrderChatBody();

  @override
  State<_OrderChatBody> createState() => _OrderChatBodyState();
}

class _OrderChatBodyState extends State<_OrderChatBody> {
  final _controller = TextEditingController();
  bool _isSending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    final failure = await context.read<OrderChatCubit>().send(content);
    if (!mounted) return;

    setState(() => _isSending = false);
    if (failure != null) {
      AppToast.failure(context, failure);
      return;
    }
    // Cleared only on success, so a failed send does not lose what was typed.
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<OrderChatCubit>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380, minHeight: 160),
          child: BlocBuilder<OrderChatCubit, RemoteState<List<OrderMessage>>>(
            builder: (context, state) {
              final messages = state.data;

              if (state.isInitialLoading) {
                return const Center(child: AppLoader());
              }
              if (state.status == RemoteStatus.failure &&
                  state.failure != null &&
                  messages == null) {
                return AppErrorView(
                  failure: state.failure!,
                  onRetry: cubit.load,
                );
              }
              if (messages == null || messages.isEmpty) {
                return const AppEmptyState(
                  icon: Icons.forum_outlined,
                  title: 'No messages yet',
                  description:
                      'Ask about your order and the school will reply here.',
                );
              }

              return ListView.separated(
                // Newest at the bottom, so open scrolled to the end.
                reverse: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: messages.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _Bubble(
                  message: messages[messages.length - 1 - index],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: AppInput(
                controller: _controller,
                hint: 'Write a message…',
                maxLines: 4,
                minLines: 1,
                enabled: !_isSending,
                keyboardType: TextInputType.multiline,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(_maxMessageLength),
                ],
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: IconButton.filled(
                onPressed:
                    _controller.text.trim().isEmpty || _isSending ? null : _send,
                icon: _isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                tooltip: 'Send',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final OrderMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final isMine = message.isMine;

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isMine ? scheme.primary : scheme.muted,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppTheme.radiusLg),
          topRight: const Radius.circular(AppTheme.radiusLg),
          bottomLeft: Radius.circular(isMine ? AppTheme.radiusLg : 4),
          bottomRight: Radius.circular(isMine ? 4 : AppTheme.radiusLg),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isMine ? scheme.primaryForeground : scheme.foreground,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            // The sender's name only matters on the side that isn't you.
            isMine
                ? Fmt.dateTime(message.createdAt)
                : '${message.senderName ?? 'School'} · '
                    '${Fmt.dateTime(message.createdAt)}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: isMine
                  ? scheme.primaryForeground.withValues(alpha: 0.75)
                  : scheme.mutedForeground,
            ),
          ),
        ],
      ),
    );

    return Row(
      mainAxisAlignment:
          isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isMine) ...[
          AppAvatar(
            imageUrl: message.senderAvatar,
            name: message.senderName,
            size: 26,
          ),
          const SizedBox(width: 8),
        ],
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.72,
            ),
            child: bubble,
          ),
        ),
      ],
    );
  }
}
