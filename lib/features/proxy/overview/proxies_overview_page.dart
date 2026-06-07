import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gap/gap.dart';
import 'package:melavpn/core/localization/translations.dart';
import 'package:melavpn/core/model/failures.dart';
import 'package:melavpn/core/theme/mela_colors.dart';
import 'package:melavpn/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:melavpn/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:melavpn/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// Russian IP block countries
const _blockedCountryCodes = {'RU', 'BY'};

class ProxiesOverviewPage extends HookConsumerWidget with PresLogger {
  const ProxiesOverviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final proxies = ref.watch(proxiesOverviewNotifierProvider);
    final sortBy = ref.watch(proxiesSortNotifierProvider);
    final blockRussian = ref.watch(_blockRussianProvider);

    return Scaffold(
      backgroundColor: MelaColors.bg(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: ShaderMask(
          shaderCallback: (bounds) => MelaColors.primaryGradient.createShader(bounds),
          child: const Text(
            'Серверы',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ),
        centerTitle: true,
        actions: [
          // Block Russian servers toggle
          Tooltip(
            message: blockRussian ? 'Российские серверы скрыты' : 'Показать все серверы',
            child: GestureDetector(
              onTap: () => ref.read(_blockRussianProvider.notifier).state = !blockRussian,
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: blockRussian
                      ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                      : MelaColors.card(context),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: blockRussian
                        ? const Color(0xFFEF4444).withValues(alpha: 0.5)
                        : MelaColors.brd(context),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '🇷🇺',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const Gap(4),
                    Icon(
                      blockRussian ? Icons.block_rounded : Icons.visibility_rounded,
                      size: 14,
                      color: blockRussian ? const Color(0xFFEF4444) : MelaColors.textHint(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Sort menu
          _SortMenuButton(sortBy: sortBy, ref: ref, t: t),
          const Gap(8),
        ],
      ),
      body: proxies.when(
        data: (group) {
          if (group == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.cloud_off_rounded, size: 52, color: MelaColors.textHint(context)),
                  const Gap(12),
                  Text(
                    t.pages.proxies.empty,
                    style: TextStyle(color: MelaColors.textHint(context)),
                  ),
                ],
              ),
            );
          }
          final allItems = group.items;
          final items = blockRussian
              ? allItems.where((p) => !_blockedCountryCodes.contains(p.ipinfo.countryCode.toUpperCase())).toList()
              : allItems;

          return Stack(
            children: [
              if (items.isEmpty)
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🇷🇺', style: TextStyle(fontSize: 40)),
                      const Gap(12),
                      Text(
                        'Все серверы заблокированы',
                        style: TextStyle(color: MelaColors.textHint(context), fontSize: 15),
                      ),
                      const Gap(6),
                      Text(
                        'Отключите фильтр для просмотра',
                        style: TextStyle(color: MelaColors.textHint(context), fontSize: 12),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  padding: const EdgeInsets.only(bottom: 100, top: 8, left: 12, right: 12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final proxy = items[index];
                    return _ProxyCard(
                      proxy: proxy,
                      selected: group.selected == proxy.tag,
                      onTap: () async {
                        await ref.read(proxiesOverviewNotifierProvider.notifier).changeProxy(group.tag, proxy.tag);
                      },
                      index: index,
                    );
                  },
                ),
              // Blocked count chip
              if (blockRussian && allItems.length != items.length)
                Positioned(
                  bottom: 16,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '🚫 ${allItems.length - items.length} российских серверов скрыто',
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.signal_wifi_off_rounded, size: 52, color: MelaColors.textHint(context)),
              const Gap(12),
              Text(
                t.presentShortError(error),
                style: TextStyle(color: MelaColors.textHint(context)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async => await ref.read(proxiesOverviewNotifierProvider.notifier).urlTest(""),
        backgroundColor: MelaColors.primary,
        foregroundColor: Colors.white,
        label: const Text('Пинг', style: TextStyle(fontWeight: FontWeight.w700)),
        icon: const Icon(FluentIcons.flash_24_filled),
      ),
    );
  }
}

final _blockRussianProvider = StateProvider<bool>((ref) => false);

class _SortMenuButton extends StatelessWidget {
  const _SortMenuButton({required this.sortBy, required this.ref, required this.t});
  final ProxiesSort sortBy;
  final WidgetRef ref;
  final TranslationsEn t;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ProxiesSort>(
      initialValue: sortBy,
      onSelected: ref.read(proxiesSortNotifierProvider.notifier).update,
      tooltip: t.pages.proxies.sort,
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: MelaColors.card(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MelaColors.brd(context), width: 1),
        ),
        child: Icon(FluentIcons.arrow_sort_24_regular, color: MelaColors.textSec(context), size: 18),
      ),
      itemBuilder: (context) => [
        ...ProxiesSort.values.map((e) => PopupMenuItem(value: e, child: Text(e.present(t)))),
      ],
    );
  }
}

class _ProxyCard extends StatelessWidget {
  const _ProxyCard({
    required this.proxy,
    required this.selected,
    required this.onTap,
    required this.index,
  });

  final OutboundInfo proxy;
  final bool selected;
  final VoidCallback onTap;
  final int index;

  Color _delayColor(int delay) {
    if (delay <= 0 || delay >= 65000) return const Color(0xFF94A3B8);
    if (delay < 800) return const Color(0xFF22C55E);
    if (delay < 1500) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _delayText(int delay) {
    if (delay <= 0) return '–';
    if (delay >= 65000) return '×';
    return '${delay}мс';
  }

  @override
  Widget build(BuildContext context) {
    final isRussian = _blockedCountryCodes.contains(proxy.ipinfo.countryCode.toUpperCase());
    final delayColor = _delayColor(proxy.urlTestDelay);
    final hasDelay = proxy.urlTestDelay > 0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? MelaColors.primary.withValues(alpha: 0.1)
              : MelaColors.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? MelaColors.primary.withValues(alpha: 0.5)
                : MelaColors.brd(context),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: MelaColors.primary.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Country / flag area
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? MelaColors.primary.withValues(alpha: 0.1)
                    : MelaColors.surf(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: proxy.ipinfo.countryCode.isNotEmpty
                    ? Text(
                        _countryFlag(proxy.ipinfo.countryCode),
                        style: const TextStyle(fontSize: 22),
                      )
                    : Icon(
                        Icons.language_rounded,
                        color: MelaColors.textHint(context),
                        size: 20,
                      ),
              ),
            ),
            const Gap(12),
            // Name + type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          proxy.tagDisplay,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? MelaColors.primary : MelaColors.textPrim(context),
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      if (isRussian)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'RU',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Gap(3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: MelaColors.secondary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          proxy.type,
                          style: const TextStyle(
                            color: MelaColors.secondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (proxy.isGroup && proxy.groupSelectedTagDisplay.isNotEmpty) ...[
                        const Gap(6),
                        Flexible(
                          child: Text(
                            proxy.groupSelectedTagDisplay,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: MelaColors.textHint(context), fontSize: 11),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const Gap(10),
            // Delay + check
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasDelay)
                  Text(
                    _delayText(proxy.urlTestDelay),
                    style: TextStyle(
                      color: delayColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Text(
                    '–',
                    style: TextStyle(color: MelaColors.textHint(context), fontSize: 12),
                  ),
                const Gap(4),
                if (selected)
                  const Icon(Icons.check_circle_rounded, color: MelaColors.primary, size: 18)
                else
                  Icon(
                    Icons.radio_button_unchecked_rounded,
                    color: MelaColors.textHint(context),
                    size: 18,
                  ),
              ],
            ),
          ],
        ),
      ),
    ).animate(delay: (index * 20).ms).fadeIn(duration: 250.ms).slideX(begin: 0.03, end: 0);
  }
}

String _countryFlag(String code) {
  if (code.length != 2) return '🌐';
  final c = code.toUpperCase();
  final a = c.codeUnitAt(0) - 0x41 + 0x1F1E6;
  final b = c.codeUnitAt(1) - 0x41 + 0x1F1E6;
  return String.fromCharCode(a) + String.fromCharCode(b);
}
