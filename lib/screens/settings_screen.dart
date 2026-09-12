import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlController = TextEditingController();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _urlController.text =
          prefs.getString(AppConstants.apiBaseUrlKey) ?? AppConstants.apiBaseUrl;
      _loaded = true;
    });
  }

  Future<void> _saveUrl() async {
    final value = _urlController.text.trim();
    if (value.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.apiBaseUrlKey, value);
    if (!mounted) return;
    // The provider reads the base URL at construction, so a restart is needed
    // for it to take effect.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Saved. Restart the app to apply the new backend URL.'),
      ),
    );
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString(AppConstants.apiBaseUrlKey);
    await prefs.clear();
    if (url != null) await prefs.setString(AppConstants.apiBaseUrlKey, url);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Cache cleared')),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      children: [
        _header('Connection'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Backend URL',
                    hintText: 'http://10.0.2.2:8000',
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _saveUrl,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _header('Appearance'),
        const Card(
          child: ListTile(
            leading: Icon(Icons.dark_mode_outlined),
            title: Text('Theme'),
            subtitle: Text('Dark (default)'),
          ),
        ),
        const SizedBox(height: 24),
        _header('About'),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Cricket Streams plays free, publicly listed streams sourced from '
              'the iptv-org open-source project. No ads, no accounts. '
              'Stream availability depends entirely on the upstream providers.',
            ),
          ),
        ),
        const SizedBox(height: 24),
        _header('Storage'),
        Card(
          child: ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Clear cache'),
            subtitle: const Text('Keeps your backend URL'),
            onTap: _clearCache,
          ),
        ),
      ],
    );
  }

  Widget _header(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
}