import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  static const _allItems = [
    _NavItem('Dashboard', '/dashboard', Icons.grid_view_rounded),
    _NavItem('Customers', '/customers', Icons.people_alt_outlined),
    _NavItem('Bookings', '/orders', Icons.receipt_long_outlined),
    _NavItem('Deliveries', '/deliveries', Icons.local_shipping_outlined),
    _NavItem(
      'Inventory',
      '/inventory',
      Icons.inventory_2_outlined,
      adminOnly: true,
    ),
    _NavItem('Payments', '/payments', Icons.payments_outlined),
    _NavItem('Reports', '/reports', Icons.bar_chart_rounded, adminOnly: true),
    _NavItem('Settings', '/settings', Icons.settings_outlined, adminOnly: true),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(agencyControllerProvider);
    if (!state.signedIn) return const _LoginRequired();
    final location = GoRouterState.of(context).uri.path;
    final items = _allItems
        .where((item) => !item.adminOnly || state.currentRole == 'Admin')
        .toList();
    final selected =
        items
            .where(
              (item) =>
                  item.path == location || location.startsWith('${item.path}/'),
            )
            .firstOrNull ??
        items.first;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;

    return Scaffold(
      drawer: compact
          ? Drawer(
              child: _SideNavigation(
                items: items,
                selected: selected,
                agencyName: state.settings.name,
              ),
            )
          : null,
      body: Row(
        children: [
          if (!compact)
            SizedBox(
              width: 248,
              child: _SideNavigation(
                items: items,
                selected: selected,
                agencyName: state.settings.name,
              ),
            ),
          Expanded(
            child: Column(
              children: [
                _TopBar(
                  title: switch (location) {
                    '/settings/products' => 'Cylinder catalog',
                    '/settings/staff' => 'Staff accounts',
                    _ => selected.label,
                  },
                  userName: state.currentName ?? 'Agency user',
                  role: state.currentRole ?? 'Staff',
                  showMenu: compact,
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginRequired extends StatelessWidget {
  const _LoginRequired();

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Please sign in to continue.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => context.go('/login'),
            child: const Text('Go to sign in'),
          ),
        ],
      ),
    ),
  );
}

class _NavItem {
  const _NavItem(this.label, this.path, this.icon, {this.adminOnly = false});
  final String label;
  final String path;
  final IconData icon;
  final bool adminOnly;
}

class _SideNavigation extends StatelessWidget {
  const _SideNavigation({
    required this.items,
    required this.selected,
    required this.agencyName,
  });
  final String agencyName;
  final List<_NavItem> items;
  final _NavItem selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF102947),
      padding: const EdgeInsets.fromLTRB(16, 22, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 8, 30),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2679E8),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        agencyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'AGENCY MANAGER',
                        style: const TextStyle(
                          color: Color(0xFF9FB2C8),
                          fontSize: 11,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(12, 0, 0, 10),
            child: Text(
              'WORKSPACE',
              style: TextStyle(
                color: Color(0xFF8499B2),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          ...items.map((item) {
            final active = selected.path == item.path;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () {
                  if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
                    Navigator.of(context).pop();
                  }
                  context.go(item.path);
                },
                child: Container(
                  height: 43,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF1E65B6)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        item.icon,
                        size: 19,
                        color: active ? Colors.white : const Color(0xFFA8B9CC),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: active
                              ? Colors.white
                              : const Color(0xFFD1DBE6),
                          fontSize: 14,
                          fontWeight: active
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF193A5E),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.support_agent, color: Color(0xFF9EC7FF), size: 20),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Need a hand?\nYour daily operations, simplified.',
                    style: TextStyle(
                      color: Color(0xFFCCD9E7),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.title,
    required this.userName,
    required this.role,
    required this.showMenu,
  });
  final String title;
  final String userName;
  final String role;
  final bool showMenu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9EDF3))),
      ),
      child: Row(
        children: [
          if (showMenu) ...[
            Builder(
              builder: (context) => IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            ),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1B2A3B),
            ),
          ),
          const Spacer(),
          if (MediaQuery.sizeOf(context).width >= 600) ...[
            const Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: Color(0xFF758399),
            ),
            const SizedBox(width: 8),
            Text(
              _today(),
              style: const TextStyle(fontSize: 14, color: Color(0xFF66758A)),
            ),
            const SizedBox(width: 18),
          ],
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'logout') {
                await ref.read(agencyControllerProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, size: 18),
                    SizedBox(width: 8),
                    Text('Sign out'),
                  ],
                ),
              ),
            ],
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: const Color(0xFFE8F1FF),
                  child: Text(
                    userName.isEmpty ? 'U' : userName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF1769D2),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                if (MediaQuery.sizeOf(context).width >= 600)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        role,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7E8A9B),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 18,
                  color: Color(0xFF748194),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _today() {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }
}
