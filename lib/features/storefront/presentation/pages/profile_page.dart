import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const CircleAvatar(radius: 30, child: Text('AM')),
                title: const Text('Ahmed Mansour'),
                subtitle: const Text('Premium Member'),
                trailing: IconButton(onPressed: () {}, icon: const Icon(Icons.edit_outlined)),
              ),
            ),
            const SizedBox(height: 16),
            ...[
              (Icons.receipt_long_outlined, 'My Orders', () => context.push('/profile/orders')),
              (Icons.favorite_border, 'Wishlist', () => context.go('/wishlist')),
              (Icons.location_on_outlined, 'Shipping Addresses', () {}),
              (Icons.credit_card_outlined, 'Payment Methods', () {}),
              (Icons.settings_outlined, 'Account Settings', () => context.push('/settings')),
            ].map(
              (x) => Card(
                child: ListTile(leading: Icon(x.$1), title: Text(x.$2), trailing: const Icon(Icons.chevron_right), onTap: x.$3),
              ),
            ),
            TextButton.icon(onPressed: () {}, icon: const Icon(Icons.logout), label: const Text('Log out')),
          ],
        ),
      );
}
