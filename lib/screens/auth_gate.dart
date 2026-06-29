import 'package:flutter/widgets.dart';

import '../models/driver_user.dart';
import '../services/auth_service.dart';
import 'customer_shell_screen.dart';
import 'driver_change_password_screen.dart';
import 'driver_shell_screen.dart';

Widget authenticatedEntryFor({
  required DriverUser user,
  bool restoredOffline = false,
}) {
  if (!user.isDriver) {
    return CustomerShellScreen(user: user);
  }
  if (user.mustChangePassword) {
    return DriverChangePasswordScreen(
      user: user,
      restoredOffline: restoredOffline,
    );
  }
  return DriverShellScreen(user: user);
}

Widget authenticatedEntryFromRestore(SessionRestoreResult restored) {
  return authenticatedEntryFor(
    user: restored.user,
    restoredOffline: restored.restoredOffline,
  );
}
