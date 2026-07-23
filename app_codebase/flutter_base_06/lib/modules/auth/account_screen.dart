import 'package:flutter/material.dart';

import '../../core/app_bar/contracts/register_app_bar_contract.dart';
import '../../core/screen/module_screen_registrar.dart';
import '../../core/theme/theme.dart';
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
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: AppSpacing.screenPadding.copyWith(bottom: 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AccountProfileCard(),
                      const EmailVerifyBanner(),
                      GuestConvertBanner(
                        onConvertTap: () => _tabController.animateTo(1),
                      ),
                    ],
                  ),
                ),
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Sign in'),
                    Tab(text: 'Create account'),
                  ],
                ),
                if (_tabController.index == 0)
                  const LoginForm()
                else
                  RegisterForm(
                    onConvertSuccess: () => _tabController.animateTo(0),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

AccountTab accountTabFromQuery(String? tab) {
  if (tab == 'create' || tab == 'register') return AccountTab.create;
  return AccountTab.signIn;
}
