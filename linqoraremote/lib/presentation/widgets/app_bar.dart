import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:linqoraremote/core/constants/names.dart';

import '../../routes/app_routes.dart';

class AppBarCustom extends StatelessWidget implements PreferredSizeWidget {
  const AppBarCustom({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title:  Text(appName),
      elevation: 7,
      actions: [
        IconButton(
          onPressed: () => Get.toNamed(AppRoutes.SETTINGS),
          icon: Icon(Icons.settings),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
