import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_screen.dart';
import 'features/invoices/invoice_screen.dart';
import 'features/pos/checkout_screen.dart';
import 'features/pos/pos_screen.dart';
import 'features/products/products_screen.dart';
import 'features/products/product_detail_screen.dart';
import 'features/products/product_form_screen.dart';
import 'features/stock/stock_screen.dart';
import 'features/stock/movements_screen.dart';
import 'features/transfers/transfers_screen.dart';
import 'features/transfers/new_transfer_screen.dart';
import 'features/transfers/transfer_detail_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/invoices/invoices_screen.dart';
import 'features/reports/reconciliation_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/production/production_screen.dart';
import 'features/production/batches_screen.dart';
import 'features/production/batch_detail_screen.dart';
import 'features/production/dispatch_screen.dart';
import 'features/production/job_board_screen.dart';
import 'features/production/receive_screen.dart';
import 'features/production/piece_lookup_screen.dart';
import 'features/production/finish_screen.dart';
import 'widgets/placeholder_screen.dart';

/// App router. Redirects between splash / login / app based on auth status; a
/// ValueNotifier bumped on every auth change tells go_router to re-evaluate.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final loc = state.matchedLocation;

      if (auth.status == AuthStatus.unknown) {
        return loc == '/splash' ? null : '/splash';
      }
      if (!auth.isSignedIn) {
        return loc == '/login' ? null : '/login';
      }
      // Signed in — bounce away from the pre-auth screens.
      if (loc == '/login' || loc == '/splash') return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/', builder: (_, _) => const HomeScreen()),

      // POS + invoices — live.
      GoRoute(path: '/pos', builder: (_, _) => const PosScreen()),
      GoRoute(path: '/pos/checkout', builder: (_, _) => const CheckoutScreen()),
      GoRoute(
        path: '/pos/invoice/:id',
        builder: (_, state) =>
            InvoiceScreen(invoiceId: state.pathParameters['id']!, justCreated: true),
      ),
      GoRoute(
        path: '/invoices/:id',
        builder: (_, state) => InvoiceScreen(invoiceId: state.pathParameters['id']!),
      ),

      // Catalogue ( /new before /:id so the static path wins )
      GoRoute(path: '/products', builder: (_, _) => const ProductsScreen()),
      GoRoute(path: '/products/new', builder: (_, _) => const ProductFormScreen()),
      GoRoute(
        path: '/products/:id/edit',
        builder: (_, state) => ProductFormScreen(productId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/products/:id',
        builder: (_, state) => ProductDetailScreen(productId: state.pathParameters['id']!),
      ),

      // Stock
      GoRoute(path: '/stock', builder: (_, _) => const StockScreen()),
      GoRoute(path: '/stock/movements', builder: (_, _) => const MovementsScreen()),

      // Transfers ( /new before /:id so the static path wins )
      GoRoute(path: '/transfers', builder: (_, _) => const TransfersScreen()),
      GoRoute(path: '/transfers/new', builder: (_, _) => const NewTransferScreen()),
      GoRoute(
        path: '/transfers/:id',
        builder: (_, state) => TransferDetailScreen(transferId: state.pathParameters['id']!),
      ),

      // Production / Job Work
      GoRoute(path: '/production', builder: (_, _) => const ProductionScreen()),
      GoRoute(path: '/production/batches', builder: (_, _) => const BatchesScreen()),
      GoRoute(
        path: '/production/batches/:id',
        builder: (_, state) => BatchDetailScreen(batchId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/production/dispatch', builder: (_, _) => const DispatchScreen()),
      GoRoute(path: '/production/board', builder: (_, _) => const JobBoardScreen()),
      GoRoute(
        path: '/production/orders/:id',
        builder: (_, state) => ReceiveScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/production/lookup', builder: (_, _) => const PieceLookupScreen()),
      GoRoute(path: '/production/finish', builder: (_, _) => const FinishScreen()),

      // Dashboard, invoices, reports, settings
      GoRoute(path: '/dashboard', builder: (_, _) => const DashboardScreen()),
      GoRoute(path: '/invoices', builder: (_, _) => const InvoicesScreen()),
      GoRoute(path: '/reports', builder: (_, _) => const ReconciliationScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    ],
  );
});
