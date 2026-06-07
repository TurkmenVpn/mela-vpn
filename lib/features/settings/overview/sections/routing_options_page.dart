import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:melavpn/core/localization/translations.dart';
import 'package:melavpn/core/model/region.dart';
import 'package:melavpn/core/preferences/general_preferences.dart';
import 'package:melavpn/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:melavpn/core/router/dialog/dialog_notifier.dart';
import 'package:melavpn/core/theme/mela_colors.dart';
import 'package:melavpn/features/per_app_proxy/model/per_app_proxy_mode.dart';
import 'package:melavpn/features/per_app_proxy/overview/per_app_proxy_notifier.dart';
import 'package:melavpn/features/route_rules/notifier/rules_notifier.dart';
import 'package:melavpn/features/route_rules/widget/rule_tile.dart';
import 'package:melavpn/features/settings/data/config_option_repository.dart';
import 'package:melavpn/features/settings/widget/preference_tile.dart';
import 'package:melavpn/singbox/model/singbox_config_enum.dart';
import 'package:melavpn/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class RoutingOptionsPage extends HookConsumerWidget {
  const RoutingOptionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final perAppProxy = ref.watch(Preferences.perAppProxyMode).enabled;
    final rules = ref.watch(rulesNotifierProvider);
    final showGeneralOptions = ref.watch(Preferences.showRouteGeneralOptions);

    final animationController = useAnimationController(
      duration: const Duration(milliseconds: 300),
      initialValue: showGeneralOptions ? 1.0 : 0.0,
    );

    useEffect(() {
      if (showGeneralOptions) {
        animationController.forward();
      } else {
        animationController.reverse();
      }
      return null;
    }, [showGeneralOptions]);

    final menuItems = <PopupMenuEntry>[
      PopupMenuItem(
        onTap: ref.read(rulesNotifierProvider.notifier).importRulesFromClipboard,
        child: Text(t.pages.settings.routing.routeRule.options.import.clipboard),
      ),
      PopupMenuItem(
        onTap: ref.read(rulesNotifierProvider.notifier).importRulesFromJsonFile,
        child: Text(t.pages.settings.routing.routeRule.options.import.file),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        onTap: () async => await ref.read(rulesNotifierProvider.notifier).exportJsonToClipboard(),
        child: Text(t.pages.settings.routing.routeRule.options.export.clipboard),
      ),
      PopupMenuItem(
        onTap: () async => await ref.read(rulesNotifierProvider.notifier).saveRulesAsJsonFile(),
        child: Text(t.pages.settings.routing.routeRule.options.export.file),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        onTap: ref.read(rulesNotifierProvider.notifier).resetRules,
        child: Text(t.pages.settings.routing.routeRule.options.reset),
      ),
    ];

    return Scaffold(
      backgroundColor: MelaColors.bgDeep,
      appBar: AppBar(
        backgroundColor: MelaColors.bgDeep,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: MelaColors.bgCard.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MelaColors.border, width: 1),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: MelaColors.textSecondary, size: 20),
          ),
          onPressed: () => context.pop(),
        ),
        title: ShaderMask(
          shaderCallback: (b) => MelaColors.primaryGradient.createShader(b),
          child: Text(
            t.pages.settings.routing.title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: MelaColors.bgCard.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: MelaColors.border, width: 1),
            ),
            child: PopupMenuButton(
              icon: const Icon(Icons.more_vert_rounded, color: MelaColors.textSecondary, size: 20),
              color: MelaColors.bgCard,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: MelaColors.border),
              ),
              itemBuilder: (_) => rules.isEmpty ? menuItems.getRange(0, 2).toList() : menuItems,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (rules.isNotEmpty)
                  Positioned.fill(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.only(bottom: 56 + 16 + 16),
                      buildDefaultDragHandles: false,
                      onReorder: ref.read(rulesNotifierProvider.notifier).reorder,
                      itemBuilder: (context, index) => RuleTile(key: Key('$index'), index: index, rule: rules[index]),
                      itemCount: rules.length,
                    ),
                  )
                else
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: MelaColors.bgCard,
                            shape: BoxShape.circle,
                            border: Border.all(color: MelaColors.border),
                          ),
                          child: const Icon(Icons.alt_route_rounded, color: MelaColors.textMuted, size: 32),
                        ),
                        const Gap(16),
                        Text(
                          t.pages.settings.routing.routeRule.empty,
                          style: const TextStyle(color: MelaColors.textSecondary, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                        const Gap(8),
                        Text(
                          t.pages.settings.routing.routeRule.create,
                          style: const TextStyle(color: MelaColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                _ExpandableFab(
                  children: [
                    _FabMenuItem(
                      icon: Icons.rule_rounded,
                      label: t.pages.settings.routing.routeRule.create,
                      onTap: () => context.goNamed('rule', pathParameters: {'orderId': 'new'}),
                    ),
                    _FabMenuItem(
                      icon: Icons.view_list_rounded,
                      label: t.pages.settings.routing.predefinedRules.title,
                      onTap: ref.read(bottomSheetsNotifierProvider.notifier).showPredefinedRules,
                    ),
                  ],
                ),
                Positioned(
                  right: 0,
                  left: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: MelaColors.bgCard,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          border: Border(
                            top: BorderSide(color: MelaColors.border),
                            left: BorderSide(color: MelaColors.border),
                            right: BorderSide(color: MelaColors.border),
                          ),
                        ),
                        child: InkWell(
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          onTap: () =>
                              ref.read(Preferences.showRouteGeneralOptions.notifier).update(!showGeneralOptions),
                          child: Container(
                            height: 36,
                            padding: const EdgeInsetsDirectional.only(start: 16, end: 12),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.tune_rounded, color: MelaColors.primary, size: 16),
                                const Gap(6),
                                Text(
                                  t.pages.settings.routing.generalOptions.title,
                                  style: const TextStyle(
                                    color: MelaColors.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const Gap(4),
                                Icon(
                                  showGeneralOptions ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                                  color: MelaColors.textMuted,
                                  size: 18,
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
            ),
          ),
          SizeTransition(
            sizeFactor: CurvedAnimation(parent: animationController, curve: Curves.easeInOut),
            axisAlignment: -1,
            child: Container(
              decoration: const BoxDecoration(
                color: MelaColors.bgCard,
                border: Border(top: BorderSide(color: MelaColors.border)),
              ),
              child: Column(
                children: [
                  ChoicePreferenceWidget(
                    selected: ref.watch(ConfigOptions.region),
                    preferences: ref.watch(ConfigOptions.region.notifier),
                    choices: Region.values,
                    title: t.pages.settings.routing.generalOptions.region,
                    showFlag: true,
                    icon: Icons.place_rounded,
                    presentChoice: (value) => value.present(t),
                    onChanged: (val) async {
                      await ref.read(ConfigOptions.directDnsAddress.notifier).reset();
                      final autoRegion = ref.read(Preferences.autoAppsSelectionRegion);
                      final mode = ref.read(Preferences.perAppProxyMode).toAppProxy();
                      if (autoRegion != val &&
                          autoRegion != null &&
                          val != Region.other &&
                          mode != null &&
                          PlatformUtils.isAndroid) {
                        await ref
                            .read(dialogNotifierProvider.notifier)
                            .showOk(
                              t.pages.settings.routing.generalOptions.perAppProxy.autoSelection.dialog.title,
                              t.pages.settings.routing.generalOptions.perAppProxy.autoSelection.dialog.msg(region: val.name),
                            );
                        await ref.read(PerAppProxyProvider(mode).notifier).clearAutoSelected();
                      }
                    },
                  ),
                  if (PlatformUtils.isAndroid)
                    ListTile(
                      title: Text(t.pages.settings.routing.generalOptions.perAppProxy.title),
                      leading: const Icon(Icons.apps_rounded, color: MelaColors.primary),
                      trailing: Switch(
                        value: perAppProxy,
                        activeColor: MelaColors.primary,
                        onChanged: (value) async {
                          final newMode = perAppProxy ? PerAppProxyMode.off : PerAppProxyMode.exclude;
                          await ref.read(Preferences.perAppProxyMode.notifier).update(newMode);
                          if (!perAppProxy && context.mounted) context.goNamed('perAppProxy');
                        },
                      ),
                      onTap: () async {
                        if (!perAppProxy) {
                          await ref.read(Preferences.perAppProxyMode.notifier).update(PerAppProxyMode.exclude);
                        }
                        if (context.mounted) context.goNamed('perAppProxy');
                      },
                    ),
                  ChoicePreferenceWidget(
                    title: t.pages.settings.routing.generalOptions.balancerStrategy.title,
                    icon: Icons.balance_rounded,
                    selected: ref.watch(ConfigOptions.balancerStrategy),
                    preferences: ref.watch(ConfigOptions.balancerStrategy.notifier),
                    choices: BalancerStrategy.values,
                    presentChoice: (value) => value.present(t),
                  ),
                  SwitchListTile.adaptive(
                    title: Text(t.pages.settings.routing.generalOptions.resolveDestination),
                    secondary: const Icon(Icons.find_replace_rounded, color: MelaColors.primary),
                    value: ref.watch(ConfigOptions.resolveDestination),
                    activeColor: MelaColors.primary,
                    onChanged: ref.read(ConfigOptions.resolveDestination.notifier).update,
                  ),
                  ChoicePreferenceWidget(
                    selected: ref.watch(ConfigOptions.ipv6Mode),
                    preferences: ref.watch(ConfigOptions.ipv6Mode.notifier),
                    choices: IPv6Mode.values,
                    title: t.pages.settings.routing.generalOptions.ipv6Route,
                    icon: Icons.looks_6_rounded,
                    presentChoice: (value) => value.present(t),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FabMenuItem {
  const _FabMenuItem({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _ExpandableFab extends StatefulWidget {
  // ignore: unused_element_parameter
  const _ExpandableFab({this.isExtended = false, this.extendedLabel = '', required this.children});

  final bool isExtended;
  final String extendedLabel;
  final List<_FabMenuItem> children;

  @override
  State<_ExpandableFab> createState() => _ExpandableFabState();
}

class _ExpandableFabState extends State<_ExpandableFab> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _close() {
    if (_isOpen) _toggle();
  }

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Positioned.fill(
      child: Stack(
        alignment: isRtl ? AlignmentDirectional.bottomStart : AlignmentDirectional.bottomEnd,
        clipBehavior: Clip.none,
        children: [
          // Scrim
          if (_isOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _close,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) =>
                      ColoredBox(color: Colors.black.withValues(alpha: 0.50 * _controller.value)),
                ),
              ),
            ),
          // Mini FABs
          ..._buildMenuItems(isRtl),
          // Main FAB
          Positioned(
            bottom: 16,
            right: isRtl ? null : 16,
            left: isRtl ? 16 : null,
            child: widget.isExtended
                ? FloatingActionButton.extended(
                    onPressed: _toggle,
                    label: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) =>
                          Text(_isOpen ? '' : widget.extendedLabel, maxLines: 1, overflow: TextOverflow.clip),
                    ),
                    icon: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => Transform.rotate(
                        angle: _controller.value * 0.75 * 3.14159,
                        child: const Icon(Icons.add_rounded),
                      ),
                    ),
                  )
                : FloatingActionButton(
                    onPressed: _toggle,
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) => Transform.rotate(
                        angle: _controller.value * 0.75 * 3.14159,
                        child: const Icon(Icons.add_rounded),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildMenuItems(bool isRtl) {
    final items = <Widget>[];
    for (var i = 0; i < widget.children.length; i++) {
      final child = widget.children[i];
      final reverseIndex = widget.children.length - 1 - i;
      final intervalStart = reverseIndex * 0.1;
      final intervalEnd = (intervalStart + 0.6).clamp(0.0, 1.0);

      final animation = CurvedAnimation(
        parent: _controller,
        curve: Interval(intervalStart, intervalEnd, curve: Curves.easeOutCubic),
      );

      items.add(
        Positioned(
          bottom: 16 + 56 + 12 + (i * (40 + 12)),
          right: isRtl ? null : 16 + 4,
          left: isRtl ? 16 + 4 : null,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              return Opacity(
                opacity: animation.value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - animation.value)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isRtl) _buildLabel(child.label),
                      if (!isRtl) const Gap(12),
                      SizedBox(
                        width: 48,
                        height: 40,
                        child: Material(
                          color: MelaColors.bgCard,
                          borderRadius: BorderRadius.circular(12),
                          elevation: 3,
                          shadowColor: Colors.black,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              _close();
                              child.onTap();
                            },
                            child: Icon(child.icon, color: MelaColors.primary),
                          ),
                        ),
                      ),
                      if (isRtl) const Gap(12),
                      if (isRtl) _buildLabel(child.label),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    return items;
  }

  Widget _buildLabel(String label) {
    return Material(
      color: MelaColors.bgCard,
      borderRadius: BorderRadius.circular(8),
      elevation: 2,
      shadowColor: Colors.black,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MelaColors.border),
        ),
        child: Text(
          label,
          style: const TextStyle(color: MelaColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
