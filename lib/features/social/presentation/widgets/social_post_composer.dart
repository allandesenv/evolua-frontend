import 'package:evolua_frontend/core/theme/app_colors.dart';
import 'package:evolua_frontend/features/social/domain/entities/community.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';

class SocialPostComposer extends StatelessWidget {
  const SocialPostComposer({
    super.key,
    required this.formKey,
    required this.contentController,
    required this.visibility,
    required this.selectedCommunitySlug,
    required this.joinedCommunities,
    required this.onVisibilityChanged,
    required this.onCommunityChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController contentController;
  final String visibility;
  final String? selectedCommunitySlug;
  final List<Community> joinedCommunities;
  final ValueChanged<String> onVisibilityChanged;
  final ValueChanged<String?> onCommunityChanged;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.of(context).size.width < 760;

    return PrimaryPanel(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Registrar uma reflexao curta',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Um insight, um aprendizado ou um relato curto ja basta. Compartilhe sem transformar isso em uma tarefa longa.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: contentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Hoje percebi que...',
                hintText: 'Ou: estou aprendendo a... / assumir meu estado me ajudou a...',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.forum_rounded),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Escreva sua reflexao.'
                  : null,
            ),
            const SizedBox(height: 14),
            if (compact)
              Column(
                children: [
                  _SpaceSelector(
                    selectedCommunitySlug: selectedCommunitySlug,
                    joinedCommunities: joinedCommunities,
                    onCommunityChanged: onCommunityChanged,
                  ),
                  const SizedBox(height: 16),
                  _VisibilitySelector(
                    visibility: visibility,
                    onVisibilityChanged: onVisibilityChanged,
                  ),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _SpaceSelector(
                      selectedCommunitySlug: selectedCommunitySlug,
                      joinedCommunities: joinedCommunities,
                      onCommunityChanged: onCommunityChanged,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _VisibilitySelector(
                      visibility: visibility,
                      onVisibilityChanged: onVisibilityChanged,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 14),
            if (joinedCommunities.isEmpty)
              Text(
                'Entre em um espaco para compartilhar reflexoes sem quebrar o seu ritmo.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              )
            else
              const SizedBox.shrink(),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: onSubmit,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Compartilhar reflexao'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpaceSelector extends StatelessWidget {
  const _SpaceSelector({
    required this.selectedCommunitySlug,
    required this.joinedCommunities,
    required this.onCommunityChanged,
  });

  final String? selectedCommunitySlug;
  final List<Community> joinedCommunities;
  final ValueChanged<String?> onCommunityChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: selectedCommunitySlug,
      decoration: const InputDecoration(
        labelText: 'Compartilhar em',
        prefixIcon: Icon(Icons.groups_rounded),
      ),
      items: joinedCommunities
          .map(
            (community) => DropdownMenuItem<String>(
              value: community.slug,
              child: Text(
                community.name,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          )
          .toList(),
      selectedItemBuilder: (context) {
        return joinedCommunities
            .map(
              (community) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  community.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            )
            .toList();
      },
      onChanged: onCommunityChanged,
      validator: (value) => value == null || value.isEmpty ? 'Escolha um espaco.' : null,
    );
  }
}

class _VisibilitySelector extends StatelessWidget {
  const _VisibilitySelector({
    required this.visibility,
    required this.onVisibilityChanged,
  });

  final String visibility;
  final ValueChanged<String> onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: visibility,
      decoration: const InputDecoration(labelText: 'Visibilidade'),
      items: const [
        DropdownMenuItem(value: 'PUBLIC', child: Text('Publica')),
        DropdownMenuItem(value: 'PRIVATE', child: Text('Privada')),
      ],
      onChanged: (value) {
        if (value != null) {
          onVisibilityChanged(value);
        }
      },
    );
  }
}
