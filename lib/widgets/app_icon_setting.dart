import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mornye/l10n/l10n.dart';
import 'package:mornye/widgets/settings_group.dart';

const _channel = MethodChannel('com.zarz.mornye/app_icon');

/// Home screen icon choices on iOS: the default Mornye icon or one of the
/// Tune icons bundled as alternate icons.
class AppIconSetting extends StatefulWidget {
  const AppIconSetting({super.key});

  static bool get supported => Platform.isIOS;

  @override
  State<AppIconSetting> createState() => _AppIconSettingState();
}

class _AppIconSettingState extends State<AppIconSetting> {
  String? _current;
  bool _loaded = false;

  static const _options = <(String?, String)>[
    (null, 'assets/images/app_icons/mornye.png'),
    ('TuneIconPink', 'assets/images/app_icons/tune_pink.png'),
    ('TuneIconDark', 'assets/images/app_icons/tune_dark.png'),
    ('TuneIconLight', 'assets/images/app_icons/tune_light.png'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final name = await _channel.invokeMethod<String>('get');
      if (mounted) {
        setState(() {
          _current = name;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _select(String? name) async {
    if (name == _current) return;
    final previous = _current;
    setState(() => _current = name);
    try {
      final ok = await _channel.invokeMethod<bool>('set', name) ?? false;
      if (!ok && mounted) setState(() => _current = previous);
    } catch (_) {
      if (mounted) setState(() => _current = previous);
    }
  }

  String _label(BuildContext context, String? name) => switch (name) {
    'TuneIconPink' => context.l10n.appIconTunePink,
    'TuneIconDark' => context.l10n.appIconTuneDark,
    'TuneIconLight' => context.l10n.appIconTuneLight,
    _ => context.l10n.appIconDefault,
  };

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSectionHeader(title: context.l10n.appIconTitle),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              for (final (name, asset) in _options)
                Semantics(
                  button: true,
                  selected: _loaded && _current == name,
                  label: _label(context, name),
                  child: GestureDetector(
                    onTap: _loaded ? () => _select(name) : null,
                    child: ExcludeSemantics(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                width: 2.5,
                                color: _loaded && _current == name
                                    ? colors.primary
                                    : Colors.transparent,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.asset(
                                asset,
                                fit: BoxFit.cover,
                                cacheWidth: 180,
                                errorBuilder: (_, _, _) => ColoredBox(
                                  color: colors.surfaceContainerHighest,
                                  child: const Icon(Icons.music_note),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _label(context, name),
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
