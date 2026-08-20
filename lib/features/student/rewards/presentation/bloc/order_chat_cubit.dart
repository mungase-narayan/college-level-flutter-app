import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/common/bloc/remote_cubit.dart';
import '../../../../../core/error/failures.dart';
import '../../../../../core/usecases/usecase.dart';
import '../../domain/entities/rewards.dart';
import '../../domain/usecases/rewards_usecases.dart';

/// One order's tracking conversation.
///
/// Bespoke rather than a [RemoteCubit] because it owns a poll timer: the web
/// refetches every 8s while the sheet is open, which is how a student sees the
/// school's reply without pulling to refresh. The timer starts with [load] and
/// is cancelled in [close], so it cannot outlive the sheet.
class OrderChatCubit extends Cubit<RemoteState<List<OrderMessage>>> {
  OrderChatCubit({
    required this.orderId,
    required ListOrderMessagesUseCase listMessages,
    required SendOrderMessageUseCase sendMessage,
  })  : _listMessages = listMessages,
        _sendMessage = sendMessage,
        super(RemoteState<List<OrderMessage>>());

  static const pollInterval = Duration(seconds: 8);

  final String orderId;
  final ListOrderMessagesUseCase _listMessages;
  final SendOrderMessageUseCase _sendMessage;

  Timer? _poll;
  bool _isSending = false;

  bool get isSending => _isSending;

  /// Fetches the thread and, on the first call, starts polling.
  ///
  /// [silent] is what the timer uses: it must not flip the state to `loading`,
  /// or the sheet would flash its spinner every eight seconds.
  Future<void> load({bool silent = false}) async {
    if (isClosed) return;
    if (!silent) {
      emit(state.copyWith(status: RemoteStatus.loading, clearFailure: true));
    }

    final result = await _listMessages(IdParams(orderId));
    if (isClosed) return;

    result.fold(
      (failure) {
        // A failed poll keeps the messages already on screen — only a failed
        // first load has nothing to fall back to.
        if (silent && state.hasData) return;
        emit(state.copyWith(status: RemoteStatus.failure, failure: failure));
      },
      (messages) => emit(
        state.copyWith(
          status: RemoteStatus.success,
          data: messages,
          clearFailure: true,
        ),
      ),
    );

    _poll ??= Timer.periodic(pollInterval, (_) => load(silent: true));
  }

  /// Posts [content] and refreshes the thread. Returns the failure to show, or
  /// null on success.
  Future<Failure?> send(String content) async {
    final trimmed = content.trim();
    if (isClosed || _isSending || trimmed.isEmpty) return null;
    _isSending = true;

    final result = await _sendMessage(
      SendMessageParams(orderId: orderId, content: trimmed),
    );

    _isSending = false;
    if (isClosed) return null;

    final failure = result.fold<Failure?>((f) => f, (_) => null);
    if (failure == null) await load(silent: true);
    return failure;
  }

  @override
  Future<void> close() {
    _poll?.cancel();
    _poll = null;
    return super.close();
  }
}
