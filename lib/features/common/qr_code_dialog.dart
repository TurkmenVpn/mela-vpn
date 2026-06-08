import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:melavpn/core/notification/in_app_notification_controller.dart';
import 'package:melavpn/core/theme/mela_colors.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrCodeDialog extends ConsumerWidget {
  const QrCodeDialog(this.data, {super.key, this.message, this.width = 268, this.backgroundColor = Colors.white});

  final String data;
  final String? message;
  final double width;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qrSize = width - 32;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: width + 48,
            decoration: BoxDecoration(
              color: MelaColors.card(context),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: MelaColors.brd(context), width: 1),
              boxShadow: [
                BoxShadow(
                  color: MelaColors.primary.withValues(alpha: 0.18),
                  blurRadius: 40,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (b) => MelaColors.primaryGradient.createShader(b),
                      child: const Text(
                        'Mela VPN',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: MelaColors.surf(context),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(Icons.close_rounded, size: 16, color: MelaColors.textHint(context)),
                      ),
                    ),
                  ],
                ),
                const Gap(16),
                // QR code frame
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: MelaColors.primary.withValues(alpha: 0.35), width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: MelaColors.primary.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: QrImageView(
                    data: data,
                    backgroundColor: Colors.white,
                    size: qrSize,
                  ),
                ),
                if (message != null) ...[
                  const Gap(14),
                  Text(
                    message!,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: MelaColors.textPrim(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Gap(16),
                // Copy button
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: data));
                    ref.read(inAppNotificationControllerProvider).showSuccessToast('Ссылка скопирована');
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [MelaColors.primary, Color(0xFF5B8BF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: MelaColors.primary.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.copy_rounded, color: Colors.white, size: 17),
                        Gap(8),
                        Text(
                          'Копировать ссылку',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
