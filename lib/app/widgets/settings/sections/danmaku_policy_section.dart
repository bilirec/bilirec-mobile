import 'package:bilirec/app/widgets/settings/settings_section_card.dart';
import 'package:bilirec/app/widgets/settings/settings_segmented_field.dart';
import 'package:bilirec/l10n/app_localizations.dart';
import 'package:bilirec/shared/managed_environment_store.dart';
import 'package:bilirec/shared/preferences.dart';
import 'package:flutter/material.dart';

class DanmakuPolicySection extends StatefulWidget {
  const DanmakuPolicySection({
    required this.enabled,
    required this.managedEnvironment,
    super.key,
  });

  final bool enabled;
  final ManagedEnvironmentStore managedEnvironment;

  @override
  State<DanmakuPolicySection> createState() => _DanmakuPolicySectionState();
}

class _DanmakuPolicySectionState extends State<DanmakuPolicySection> {
  static const String _defaultDanmakuOutputFormat = 'jsonl';
  static const String _defaultDanmakuOverflowPolicy = 'drop';

  String? _danmakuOutputFormat;
  String? _danmakuOverflowPolicy;

  AppLocalizations get l10n => AppLocalizations.of(context);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await Preferences.getManagedEnvironmentSettings();
    if (!mounted) return;
    setState(() {
      _danmakuOutputFormat = _readDanmakuOutputFormat(settings);
      _danmakuOverflowPolicy = _readDanmakuOverflowPolicy(settings);
    });
  }

  String _readDanmakuOutputFormat(Map<String, String> env) {
    final raw = (env['DANMAKU_OUTPUT_FORMAT'] ?? '').trim().toLowerCase();
    if (raw == 'xml') {
      return 'xml';
    }
    return _defaultDanmakuOutputFormat;
  }

  String _readDanmakuOverflowPolicy(Map<String, String> env) {
    final raw = (env['DANMAKU_OVERFLOW_POLICY'] ?? '').trim().toLowerCase();
    if (raw == 'block') {
      return 'block';
    }
    return _defaultDanmakuOverflowPolicy;
  }

  Future<void> _setDanmakuOutputFormat(String value) async {
    final normalized = value == 'xml' ? 'xml' : _defaultDanmakuOutputFormat;
    await widget.managedEnvironment.set(
      'DANMAKU_OUTPUT_FORMAT',
      normalized,
    );
    if (!mounted) return;
    setState(() {
      _danmakuOutputFormat = normalized;
    });
  }

  Future<void> _setDanmakuOverflowPolicy(String value) async {
    final normalized =
        value == 'block' ? 'block' : _defaultDanmakuOverflowPolicy;
    await widget.managedEnvironment.set(
      'DANMAKU_OVERFLOW_POLICY',
      normalized,
    );
    if (!mounted) return;
    setState(() {
      _danmakuOverflowPolicy = normalized;
    });
  }

  @override
  Widget build(BuildContext context) {
    final format = _danmakuOutputFormat;
    final overflow = _danmakuOverflowPolicy;
    if (format == null || overflow == null) {
      return const SizedBox(height: 48);
    }

    return SettingsSectionCard(
      icon: Icons.subtitles_outlined,
      title: l10n.tr('danmakuPolicyTitle'),
      description: l10n.tr('danmakuPolicyDescription'),
      children: [
        SettingsSegmentedField<String>(
          key: const Key('danmaku_output_format_segments'),
          title: l10n.tr('danmakuOutputFormatTitle'),
          description: l10n.tr('danmakuOutputFormatDescription'),
          hint: format == 'xml'
              ? l10n.tr('danmakuOutputFormatXmlHint')
              : l10n.tr('danmakuOutputFormatJsonlHint'),
          segments: [
            ButtonSegment<String>(
              value: 'jsonl',
              label: Text(
                l10n.tr('danmakuOutputFormatJsonl'),
              ),
            ),
            ButtonSegment<String>(
              value: 'xml',
              label: Text(
                l10n.tr('danmakuOutputFormatXml'),
              ),
            ),
          ],
          selected: format,
          enabled: widget.enabled,
          onSelectionChanged: (value) {
            setState(() {
              _danmakuOutputFormat = value;
            });
            _setDanmakuOutputFormat(value);
          },
        ),
        const SizedBox(height: 14),
        SettingsSegmentedField<String>(
          key: const Key('danmaku_overflow_policy_segments'),
          title: l10n.tr('danmakuOverflowPolicyTitle'),
          description: l10n.tr('danmakuOverflowPolicyDescription'),
          hint: overflow == 'block'
              ? l10n.tr('danmakuOverflowPolicyBlockHint')
              : l10n.tr('danmakuOverflowPolicyDropHint'),
          segments: [
            ButtonSegment<String>(
              value: 'drop',
              label: Text(
                l10n.tr('danmakuOverflowPolicyDrop'),
              ),
            ),
            ButtonSegment<String>(
              value: 'block',
              label: Text(
                l10n.tr('danmakuOverflowPolicyBlock'),
              ),
            ),
          ],
          selected: overflow,
          enabled: widget.enabled,
          onSelectionChanged: (value) {
            setState(() {
              _danmakuOverflowPolicy = value;
            });
            _setDanmakuOverflowPolicy(value);
          },
        ),
      ],
    );
  }
}
