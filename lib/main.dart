import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';

import 'app/deliverex_driver_app.dart';
import 'services/background_sync.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Workmanager().initialize(backgroundSyncCallback);

  runApp(const DeliverexDriverApp());
}
    