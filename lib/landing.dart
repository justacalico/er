import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'ui/theme.dart';

const releasesUrl = 'https://gitlab.com/HttpAnimations/er/-/releases';
const repoUrl = 'https://gitlab.com/HttpAnimations/er';

class LandingApp extends StatelessWidget {
  const LandingApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'er — run flatpaks twice',
        debugShowCheckedModeBanner: false,
        theme: erTheme(),
        home: const LandingPage(),
      );
}

void _open(String url) {
  launchUrl(Uri.parse(url)).catchError((_) => false);
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
            children: [
              const Text('er 二',
                  style: TextStyle(
                      fontSize: 72,
                      fontWeight: FontWeight.w800,
                      color: erAccent,
                      height: 1)),
              const SizedBox(height: 8),
              const Text(
                'Run the same flatpak. Twice. Ten times.',
                style: TextStyle(fontSize: 22, color: erInk),
              ),
              const SizedBox(height: 16),
              const Text(
                'er launches extra copies of any installed flatpak in their own '
                'container — a private home directory and a private D-Bus '
                'session — so single-instance apps run side by side. Built to '
                'multi-box Mocktail, works with everything else.',
                style: TextStyle(fontSize: 15, color: Color(0xFF9BA7B4)),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: () => _open(releasesUrl),
                    icon: const Icon(Icons.download),
                    label: const Text('Download for Linux'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _open(repoUrl),
                    icon: const Icon(Icons.code),
                    label: const Text('Source'),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              const _Feature(
                icon: Icons.layers,
                title: 'Real isolation',
                body:
                    'Each instance sees its own \$HOME. Config, saves, logins and '
                    '~/.var/app data never touch the original.',
              ),
              const _Feature(
                icon: Icons.hub,
                title: 'Private session bus',
                body:
                    'Every instance runs on its own D-Bus session, so apps that '
                    'detect "already running" simply don\'t.',
              ),
              const _Feature(
                icon: Icons.bolt,
                title: 'Zero setup',
                body:
                    'No daemon, no root, no config files. Pick an app, name the '
                    'instance, hit launch.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature(
      {required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: erAccent, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: erInk)),
                const SizedBox(height: 4),
                Text(body,
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF9BA7B4))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
