import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:linqoraremote/core/themes/theme.dart';
import 'package:linqoraremote/presentation/bindings/ws_host_binding.dart';
import 'package:linqoraremote/routes/app_routes.dart';

import 'data/models/ws_host_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  Hive.registerAdapter(WsHostModelAdapter());

  WsHostBinding().dependencies();

  runApp(
    GetMaterialApp(
      initialRoute: AppRoutes.DEVICE_AUTH,
      debugShowCheckedModeBanner: false,
      getPages: AppRoutes.routes,
      themeMode: ThemeMode.dark,
      theme: MaterialTheme.lightTheme,
      darkTheme: MaterialTheme.darkTheme,
    ),
  );
}
