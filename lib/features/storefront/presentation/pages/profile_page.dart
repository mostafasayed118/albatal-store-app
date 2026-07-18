import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/extensions/build_context_x.dart';
import '../widgets/menu_list_tile.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l.myProfile)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(radius: 30, child: Text(l.mockCustomerName.characters.first)),
              title: Text(l.mockCustomerName),
              subtitle: Text(l.premiumMember),
              trailing: IconButton(
                tooltip: l.editProfile,
                onPressed: () {},
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
          ),
          const SizedBox(height: 16),
          MenuListTile(icon: Icons.receipt_long_outlined, title: l.myOrders, onTap: () => context.push('/profile/orders')),
          MenuListTile(icon: Icons.favorite_border, title: l.wishlist, onTap: () => context.go('/wishlist')),
          MenuListTile(icon: Icons.location_on_outlined, title: l.shippingAddresses),
          MenuListTile(icon: Icons.credit_card_outlined, title: l.paymentMethods),
          MenuListTile(icon: Icons.settings_outlined, title: l.accountSettings, onTap: () => context.push('/settings')),
          TextButton.icon(onPressed: () {}, icon: const Icon(Icons.logout), label: Text(l.logOut)),
        ],
      ),
    );
  }
}
