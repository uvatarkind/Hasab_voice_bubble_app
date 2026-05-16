import 'package:flutter/material.dart';

import 'permission_setup_page.dart';

class PermissionsSettingsPage extends StatelessWidget {
  const PermissionsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const PermissionSetupPage(
      autoNavigate: false,
      showAppBar: true,
    );
  }
}
