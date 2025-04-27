import 'package:flutter/material.dart';

class AppBarCustom extends StatelessWidget implements PreferredSizeWidget {
  const AppBarCustom({super.key});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: const Text('Linqora Remote'),
      actions: [
        IconButton(onPressed: () {}, icon: Icon(Icons.qr_code_scanner)),
        IconButton(onPressed: () {}, icon: Icon(Icons.settings)),
      ],
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}
