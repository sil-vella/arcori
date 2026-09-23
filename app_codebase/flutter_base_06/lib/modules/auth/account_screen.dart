import 'package:flutter/material.dart';

import '../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../core/screen/module_screen_registrar.dart';
import '../../core/theme/theme.dart';
import '../../core/widgets/app_chrome.dart';
import 'widgets/account_profile_card.dart';
import 'widgets/email_verify_banner.dart';
import 'widgets/guest_convert_banner.dart';
import 'widgets/login_form.dart';
import 'widgets/register_form.dart';

enum AccountTab { signIn, create }

/// Account hub — sign in and create account tabs under shell AppBar.
class AccountScreen extends StatefulWidget {
  const AccountScreen({
    super.key,
    this.initialTab = AccountTab.signIn,
  });

  final AccountTab initialTab;

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == AccountTab.create ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModuleScreenRegistrar(
      appBarItems: const [
        AppBarTitle(text: 'Account', icon: Icons.person_outlined),
      ],
      child: AppChromePage(
        child: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            final top = AppChromePage.topClearance(context);
            return ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                top + AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xxl,
              ),
              children: [
                const AccountProfileCard(),
                const EmailVerifyBanner(),
                GuestConvertBanner(
                  onConvertTap: () => _tabController.animateTo(1),
                ),
                AppChromeSection(
                  title: _tabController.index == 0
                      ? 'Sign in'
                      : 'Create account',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TabBar(
                        controller: _tabController,
                        labelColor: AppChrome.onSurface,
                        unselectedLabelColor: AppChrome.onSurfaceMuted,
                        indicatorColor: AppChrome.accentGold,
                        tabs: const [
                          Tab(text: 'Sign in'),
                          Tab(text: 'Create account'),
                        ],
                      ),
                      AppSpacing.gapMd,
                      if (_tabController.index == 0)
                        const LoginForm()
                      else
                        RegisterForm(
                          onConvertSuccess: () => _tabController.animateTo(0),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

AccountTab accountTabFromQuery(String? tab) {
  if (tab == 'create' || tab == 'register') return AccountTab.create;
  return AccountTab.signIn;
}
