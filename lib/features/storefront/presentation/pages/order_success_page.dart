import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OrderSuccessPage extends StatelessWidget {
  const OrderSuccessPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  radius: 48,
                  backgroundColor: Color(0xFF064E3B),
                  child: Icon(Icons.check, size: 60, color: Colors.white),
                ),
                const SizedBox(height: 24),
                Text('Success!', style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 8),
                const Text('Your order #ORD-2023-8472 has been placed. We will keep you updated.', textAlign: TextAlign.center),
                const SizedBox(height: 32),
                FilledButton(onPressed: () => context.go('/profile/orders'), child: const Text('Track My Order')),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: () => context.go('/home'), child: const Text('Continue Shopping')),
              ],
            ),
          ),
        ),
      );
}
