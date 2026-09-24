import 'package:flutter/material.dart';

import 'src/flatpak_service.dart';
import 'src/instance_store.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

class ErApp extends StatelessWidget {
  const ErApp({super.key, required this.service, required this.store});

  final FlatpakService service;
  final InstanceStore store;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'er',
        debugShowCheckedModeBanner: false,
        theme: erTheme(),
        home: HomePage(service: service, store: store),
      );
}
