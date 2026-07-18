import 'package:go_router/go_router.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/storefront/presentation/pages/store_pages.dart';
import '../../features/addresses/presentation/pages/addresses_page.dart';
import '../components/app_shell.dart';
final appRouter=GoRouter(initialLocation:'/home',routes:[ShellRoute(builder:(_,__,child)=>AppShell(child:child),routes:[GoRoute(path:'/home',builder:(_,__)=>const HomePage()),GoRoute(path:'/categories',builder:(_,__)=>const CategoriesPage()),GoRoute(path:'/wishlist',builder:(_,__)=>const WishlistPage()),GoRoute(path:'/cart',builder:(_,__)=>const CartPage()),GoRoute(path:'/profile',builder:(_,__)=>const ProfilePage())]),GoRoute(path:'/product/:id',builder:(_,s)=>DetailsPage(id:s.pathParameters['id']!)),GoRoute(path:'/checkout',builder:(_,__)=>const CheckoutPage()),GoRoute(path:'/order-success',builder:(_,__)=>const OrderSuccessPage()),GoRoute(path:'/profile/orders',builder:(_,__)=>const OrdersPage()),GoRoute(path:'/profile/addresses',builder:(_,__)=>const AddressesPage()),GoRoute(path:'/settings',builder:(_,__)=>const SettingsPage())]);
