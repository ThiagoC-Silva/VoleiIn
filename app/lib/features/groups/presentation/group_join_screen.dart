import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/errors/error_code.dart';
import '../../../core/errors/error_text.dart';
import '../../../core/router/routes.dart';
import '../../../core/submit_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/form_fields.dart';
import '../../../shared/widgets/form_scroll_view.dart';
import '../../../shared/widgets/inline_notice.dart';
import '../../../shared/widgets/inner_app_bar.dart';
import '../../../shared/widgets/snack.dart';
import '../domain/group_models.dart';
import '../domain/invite_code.dart';
import 'group_avatar_view.dart';
import 'group_controllers.dart';

/// Estado da prévia (docs/ui/telas.md, 6.3).
enum _PreviewState { canRequest, pending, member }

/// Entrar com código (RF16, RN12; telas.md, 6.3; groupsJoin-*.png). Duas
/// etapas na mesma rota. O código fica só nesta tela, em memória.
class GroupJoinScreen extends ConsumerStatefulWidget {
  const GroupJoinScreen({super.key});

  @override
  ConsumerState<GroupJoinScreen> createState() => _GroupJoinScreenState();
}

class _GroupJoinScreenState extends ConsumerState<GroupJoinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();

  /// Erro vindo do servidor (`INVITE_INVALID`), mostrado no campo.
  String? _serverError;

  /// O código conferido, enviado à prévia e ao pedido.
  String? _sentCode;
  InvitePreview? _preview;
  _PreviewState _state = _PreviewState.canRequest;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  GroupJoinController get _controller =>
      ref.read(groupJoinControllerProvider.notifier);

  void _backToStep1({bool clear = false, String? error}) {
    setState(() {
      _preview = null;
      _serverError = error;
      if (clear) _code.clear();
    });
  }

  Future<void> _continue() async {
    setState(() => _serverError = null);
    await afterServerErrorCleared();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final code = normalizeInviteCode(_code.text)!;
    final (preview, error) = await _controller.preview(code);
    if (!mounted) return;
    if (error != null) {
      if (error.hasCode(ErrorCode.inviteInvalid)) {
        setState(() => _serverError = _errorText(error));
      } else {
        showErrorSnack(context, error);
      }
      return;
    }
    setState(() {
      _sentCode = code;
      _preview = preview;
      _state = preview!.isMember
          ? _PreviewState.member
          : preview.hasPendingRequest
          ? _PreviewState.pending
          : _PreviewState.canRequest;
    });
  }

  Future<void> _request() async {
    final error = await _controller.request(_sentCode!);
    if (!mounted) return;
    switch (error?.code) {
      case null:
      // Outro aparelho da pessoa já pediu: o mesmo estado, sem SnackBar.
      case ErrorCode.joinRequestPending:
        setState(() => _state = _PreviewState.pending);
      case ErrorCode.alreadyMember:
        setState(() => _state = _PreviewState.member);
      // O código foi regenerado ou desativado entre a prévia e o pedido.
      case ErrorCode.inviteInvalid:
        _backToStep1(error: _errorText(error!));
      default:
        showErrorSnack(context, error!);
    }
  }

  String _errorText(AppException error) =>
      errorText(AppLocalizations.of(context), error.code);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final preview = _preview;
    final busy = ref.watch(groupJoinControllerProvider).isLoading;

    return PopScope(
      // Na etapa 2, o voltar leva à etapa 1.
      canPop: preview == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _backToStep1();
      },
      child: Scaffold(
        appBar: InnerAppBar(
          title: l10n.groupsJoin,
          onBack: preview == null ? null : _backToStep1,
        ),
        body: preview == null
            ? _step1(l10n, busy)
            : _step2(l10n, preview, busy),
      ),
    );
  }

  Widget _step1(AppLocalizations l10n, bool busy) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: FormScrollView(
        content: [
          Text(l10n.groupJoinIntro, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          // O código diferencia maiúsculas de minúsculas: sem correção e sem
          // maiúscula automática.
          LabeledField(
            label: l10n.groupJoinCodeLabel,
            controller: _code,
            enabled: !busy,
            autocorrect: false,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.go,
            forceErrorText: _serverError,
            onChanged: (_) {
              if (_serverError != null) setState(() => _serverError = null);
            },
            onFieldSubmitted: (_) => _continue(),
            validator: (value) {
              if ((value ?? '').trim().isEmpty) {
                return l10n.groupJoinCodeRequired;
              }
              if (normalizeInviteCode(value!) == null) {
                return l10n.groupJoinCodeInvalid;
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: l10n.groupJoinContinue,
            loading: busy,
            onPressed: _continue,
          ),
        ],
      ),
    );
  }

  Widget _step2(AppLocalizations l10n, InvitePreview preview, bool busy) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final state = switch (_state) {
      _PreviewState.canRequest => [
        Text(
          l10n.groupJoinApprovalNeeded,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: l10n.groupJoinRequest,
          loading: busy,
          onPressed: _request,
        ),
      ],
      _PreviewState.pending => [
        InlineNotice(
          icon: Symbols.hourglass_top,
          color: VoleiColors.of(context).wait,
          text: l10n.groupJoinPending,
        ),
        const SizedBox(height: 16),
        Text(l10n.groupJoinPendingHint, style: muted),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => context.pop(),
          child: Text(l10n.groupJoinBackToGroups, textAlign: TextAlign.center),
        ),
      ],
      _PreviewState.member => [
        Text(
          l10n.groupJoinAlreadyMember,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: l10n.groupJoinOpen,
          onPressed: () => context.goNamed(
            Routes.group,
            pathParameters: {'groupId': preview.groupId},
          ),
        ),
      ],
    };

    return FormScrollView(
      content: [
        const SizedBox(height: 16),
        Center(
          child: GroupAvatarView(
            id: preview.groupId,
            name: preview.name,
            imageUrl: preview.photoUrl,
            size: 96,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          preview.name,
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ...state,
      ],
      footer: [
        Center(
          child: TextButton(
            onPressed: busy ? null : () => _backToStep1(clear: true),
            child: Text(l10n.groupJoinOtherCode),
          ),
        ),
      ],
    );
  }
}
