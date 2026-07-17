import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/menu_list_tile.dart';

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
            MenuListTile(icon: Icons.receipt_long_outlined, title: 'My Orders', onTap: () => context.push('/profile/orders')),
            MenuListTile(icon: Icons.favorite_border, title: 'Wishlist', onTap: () => context.go('/wishlist')),
            MenuListTile(icon: Icons.location_on_outlined, title: 'Shipping Addresses'),
            MenuListTile(icon: Icons.credit_card_outlined, title: 'Payment Methods'),
            MenuListTile(icon: Icons.settings_outlined, title: 'Account Settings', onTap: () => context.push('/settings')),
            TextButton.icon(onPressed: () {}, icon: const Icon(Icons.logout), label: const Text('Log out')),
          ],
        ),
      );
}
