import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../utils/theme.dart';

/// Settings restyled as an iOS grouped inset list: section headers outside
/// the group, elevated cells inside with hairline separators.
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
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 104),
      children: [
        _section('Connection'),
        _group(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CupertinoSearchTextField(
                    controller: _urlController,
                    placeholder: 'Backend URL',
                    style: const TextStyle(color: AppColors.textBody, fontSize: 15),
                    placeholderStyle: const TextStyle(
                      color: AppColors.textFaint,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 12),
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
          ],
        ),
        _section('About'),
        _group(
          children: const [
            Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Cricket Streams plays free, publicly listed streams sourced from '
                'the iptv-org open-source project. No ads, no accounts. '
                'Stream availability depends entirely on the upstream providers.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.4),
              ),
            ),
          ],
        ),
        _section('Storage'),
        _group(
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              leading: const Icon(CupertinoIcons.delete, size: 22),
              title: const Text('Clear cache', style: TextStyle(fontSize: 16)),
              subtitle: const Text('Keeps your backend URL', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              onTap: _clearCache,
            ),
          ],
        ),
      ],
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      );

  Widget _group({required List<Widget> children}) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: children),
      );
}
