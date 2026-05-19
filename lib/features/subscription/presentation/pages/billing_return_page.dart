import 'package:evolua_frontend/features/subscription/application/subscription_controller.dart';
import 'package:evolua_frontend/shared/presentation/widgets/gradient_scaffold.dart';
import 'package:evolua_frontend/shared/presentation/widgets/primary_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class BillingReturnPage extends ConsumerStatefulWidget {
  const BillingReturnPage({
    super.key,
    required this.checkoutId,
    required this.billingReturn,
  });

  final String? checkoutId;
  final String? billingReturn;

  @override
  ConsumerState<BillingReturnPage> createState() => _BillingReturnPageState();
}

class _BillingReturnPageState extends ConsumerState<BillingReturnPage> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _trackCheckout());
  }

  Future<void> _trackCheckout() async {
    final checkoutId = widget.checkoutId;
    if (checkoutId != null && checkoutId.isNotEmpty) {
      await ref.read(subscriptionControllerProvider.notifier).trackCheckout(checkoutId);
    }
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: PrimaryPanel(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 18),
                Text(
                  'Confirmando pagamento',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Estamos verificando o status do checkout para atualizar seu plano.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
