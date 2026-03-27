import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/config/app_config.dart';
import 'package:evolua_frontend/core/network/paginated_response.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/auth/application/auth_controller.dart';
import 'package:evolua_frontend/features/chat/application/chat_message_controller.dart';
import 'package:evolua_frontend/features/chat/data/models/chat_message_dto.dart';
import 'package:evolua_frontend/features/chat/domain/entities/chat_message.dart';
import 'package:evolua_frontend/shared/presentation/widgets/guided_empty_state.dart';
import 'package:evolua_frontend/shared/presentation/widgets/pagination_controls.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

class ChatModuleView extends ConsumerStatefulWidget {
  const ChatModuleView({super.key});

  @override
  ConsumerState<ChatModuleView> createState() => _ChatModuleViewState();
}

class _ChatModuleViewState extends ConsumerState<ChatModuleView> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController(text: 'user-2');
  final _contentController = TextEditingController();
  final _searchController = TextEditingController();
  bool _isRealtimeConnected = false;
  StompClient? _stompClient;

  @override
  void initState() {
    super.initState();
    ref.listenManual(chatMessageControllerProvider, (previous, next) {
      if (next.hasError) {
        final error = next.error;
        final message = error is DioException
            ? (error.response?.data is Map<String, dynamic>
                ? ((error.response?.data['details'] as List?)?.join(', ') ??
                    error.message ??
                    'Nao foi possivel enviar a mensagem.')
                : error.message ?? 'Nao foi possivel enviar a mensagem.')
            : 'Nao foi possivel enviar a mensagem.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _connectRealtime());
  }

  @override
  void dispose() {
    _stompClient?.deactivate();
    _recipientController.dispose();
    _contentController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _connectRealtime() {
    final currentUserId = ref.read(authControllerProvider).asData?.value?.email;

    if (currentUserId == null || currentUserId.isEmpty) {
      return;
    }

    _stompClient = StompClient(
      config: StompConfig(
        url: '${AppConfig.chatSocketUrl}/ws/chat',
        reconnectDelay: const Duration(seconds: 5),
        heartbeatIncoming: const Duration(seconds: 10),
        heartbeatOutgoing: const Duration(seconds: 10),
        onConnect: (frame) {
          if (!mounted) {
            return;
          }

          setState(() => _isRealtimeConnected = true);

          _stompClient?.subscribe(
            destination: '/topic/chat/$currentUserId',
            callback: (messageFrame) {
              final body = messageFrame.body;

              if (body == null || body.isEmpty) {
                return;
              }

              final payload = jsonDecode(body) as Map<String, dynamic>;
              final liveMessage = ChatMessageDto.fromJson(payload).toEntity();
              ref.read(chatMessageControllerProvider.notifier).prependRealtime(liveMessage);
            },
          );
        },
        onStompError: (frame) {
          if (mounted) {
            setState(() => _isRealtimeConnected = false);
          }
        },
        onWebSocketError: (dynamic error) {
          if (mounted) {
            setState(() => _isRealtimeConnected = false);
          }
        },
        onDisconnect: (_) {
          if (mounted) {
            setState(() => _isRealtimeConnected = false);
          }
        },
      ),
    );

    _stompClient?.activate();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref.read(chatMessageControllerProvider.notifier).create(
          recipientId: _recipientController.text.trim(),
          content: _contentController.text.trim(),
        );

    if (!mounted) {
      return;
    }

    _contentController.clear();
  }

  Future<void> _applyFilters() {
    return ref.read(chatMessageControllerProvider.notifier).applyFilters(
          search: _searchController.text.trim().isEmpty ? null : _searchController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(chatMessageControllerProvider);
    final liveInboxId = ref.watch(authControllerProvider).asData?.value?.email ?? 'sem sessao';

    return Column(
      children: [
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Conversa em tempo real',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: (_isRealtimeConnected ? AppColors.accent : AppColors.danger)
                          .withValues(alpha: 0.16),
                    ),
                    child: Text(
                      _isRealtimeConnected ? 'Ao vivo' : 'Reconectando',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _isRealtimeConnected ? AppColors.accent : AppColors.danger,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Mensagens novas destinadas ao seu canal entram sozinhas. Canal atual: $liveInboxId',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _recipientController,
                      decoration: const InputDecoration(
                        labelText: 'Com quem voce quer falar?',
                        prefixIcon: Icon(Icons.person_search_rounded),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Informe o destinatario.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contentController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Escreva sua mensagem',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'Escreva a mensagem.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton.icon(
                        onPressed: messagesState.isLoading && !messagesState.hasValue ? null : _submit,
                        icon: const Icon(Icons.send_and_archive_rounded),
                        label: const Text('Enviar mensagem'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        messagesState.when(
          data: (result) => _ChatHistory(
            result: result,
            searchController: _searchController,
            onSearchChanged: (_) => _applyFilters(),
            onPageChanged: (page) => ref.read(chatMessageControllerProvider.notifier).goToPage(page),
          ),
          error: (error, stackTrace) => const _ChatErrorState(),
          loading: () => const _ChatLoadingState(),
        ),
      ],
    );
  }
}

class _ChatHistory extends StatelessWidget {
  const _ChatHistory({
    required this.result,
    required this.searchController,
    required this.onSearchChanged,
    required this.onPageChanged,
  });

  final PaginatedResponse<ChatMessage> result;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PrimaryPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: searchController,
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'Buscar por pessoa ou mensagem',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${result.totalItems} mensagens nesta busca.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (result.items.isEmpty)
          GuidedEmptyState(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Nenhuma conversa apareceu por aqui.',
            subtitle: 'Envie a primeira mensagem ou limpe a busca para enxergar melhor o historico.',
            actionLabel: 'Limpar busca',
            onAction: () {
              searchController.clear();
              onSearchChanged('');
            },
          )
        else
          Column(
            children: [
              ...result.items.map(
                (message) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: PrimaryPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Para ${message.recipientId}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppColors.textPrimary,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(message.content, style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  ),
                ),
              ),
              PaginationControls(
                page: result.page,
                totalPages: result.totalPages,
                onPageChanged: onPageChanged,
              ),
            ],
          ),
      ],
    );
  }
}

class _ChatLoadingState extends StatelessWidget {
  const _ChatLoadingState();

  @override
  Widget build(BuildContext context) {
    return const PrimaryPanel(
      child: Row(
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Carregando mensagens...'),
        ],
      ),
    );
  }
}

class _ChatErrorState extends StatelessWidget {
  const _ChatErrorState();

  @override
  Widget build(BuildContext context) {
    return GuidedEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'Nao conseguimos abrir o chat agora.',
      subtitle: 'Atualize a pagina ou aguarde a reconexao do canal ao vivo.',
      actionLabel: 'Tentar novamente',
      onAction: () {},
    );
  }
}
