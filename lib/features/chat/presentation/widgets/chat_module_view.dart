import 'package:dio/dio.dart';
import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/chat/application/chat_message_controller.dart';
import 'package:evolua_frontend/features/chat/domain/entities/chat_message.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatModuleView extends ConsumerStatefulWidget {
  const ChatModuleView({super.key});

  @override
  ConsumerState<ChatModuleView> createState() => _ChatModuleViewState();
}

class _ChatModuleViewState extends ConsumerState<ChatModuleView> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController(text: 'user-2');
  final _contentController = TextEditingController();

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
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _contentController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final messagesState = ref.watch(chatMessageControllerProvider);

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
                      'Mensagens e conversa',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => ref.read(chatMessageControllerProvider.notifier).refresh(),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Atualizar'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Envie mensagens para validar o fluxo inicial do chat em tempo real e a persistencia do historico.',
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
                        labelText: 'Destinatario',
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
                        labelText: 'Mensagem',
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
          data: (messages) => _ChatMessageList(messages: messages),
          error: (error, stackTrace) => const _ChatErrorState(),
          loading: () => const _ChatLoadingState(),
        ),
      ],
    );
  }
}

class _ChatMessageList extends StatelessWidget {
  const _ChatMessageList({required this.messages});

  final List<ChatMessage> messages;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _ChatEmptyState();
    }

    return Column(
      children: messages
          .map(
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
          )
          .toList(),
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

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState();

  @override
  Widget build(BuildContext context) {
    return const PrimaryPanel(
      child: Text('Nenhuma mensagem enviada ainda.'),
    );
  }
}

class _ChatErrorState extends StatelessWidget {
  const _ChatErrorState();

  @override
  Widget build(BuildContext context) {
    return const PrimaryPanel(
      child: Text(
        'Nao foi possivel carregar mensagens.',
        style: TextStyle(color: AppColors.danger),
      ),
    );
  }
}
