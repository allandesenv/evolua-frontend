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
    return PrimaryPanel(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Publicar no feed',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Escolha uma comunidade real, controle a visibilidade e publique sem depender de texto livre para o grupo.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: contentController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'O que voce quer compartilhar?',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.forum_rounded),
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Escreva o conteudo.' : null,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: selectedCommunitySlug,
                    decoration: const InputDecoration(
                      labelText: 'Publicar em',
                      prefixIcon: Icon(Icons.groups_rounded),
                    ),
                    items: joinedCommunities
                        .map(
                          (community) => DropdownMenuItem<String>(
                            value: community.slug,
                            child: Text(community.name),
                          ),
                        )
                        .toList(),
                    onChanged: onCommunityChanged,
                    validator: (value) =>
                        value == null || value.isEmpty ? 'Escolha uma comunidade.' : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: onSubmit,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Publicar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
