import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart' show Share;

import '../../core/providers/data_providers.dart';
import '../../core/providers/repository_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/farm.dart';
import '../../data/models/share_link.dart';

void showShareLinkSheet(BuildContext context, {required Farm farm}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.scrim,
    builder: (_) => _ShareLinkSheet(farm: farm),
  );
}

class _ShareLinkSheet extends ConsumerStatefulWidget {
  const _ShareLinkSheet({required this.farm});
  final Farm farm;

  @override
  ConsumerState<_ShareLinkSheet> createState() => _ShareLinkSheetState();
}

class _ShareLinkSheetState extends ConsumerState<_ShareLinkSheet> {
  ShareLinkExpiry _expiry = ShareLinkExpiry.thirtyDays;
  ShareLink? _link;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _createLink();
  }

  Future<void> _createLink() async {
    setState(() => _loading = true);
    final link = await ref.read(shareLinkRepositoryProvider).createShareLink(
          farmId: widget.farm.id,
          expiry: _expiry,
        );
    ref.invalidate(shareLinksProvider);
    if (mounted) {
      setState(() {
        _link = link;
        _loading = false;
      });
    }
  }

  // The app uses go_router's default hash URL strategy, so the public
  // page lives at <origin>/#/r/<token> on whatever host serves this build.
  String get _url => '${Uri.base.origin}/#${_link?.urlPath() ?? ''}';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFDCE3EC), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Text('리포트 링크 공유', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text('${widget.farm.name} · 어가가 설치 없이 웹으로 열람', style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: AppColors.background, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 15, color: AppColors.neutralIcon),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _loading ? '링크 생성 중...' : _url,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () async {
                            await Clipboard.setData(ClipboardData(text: _url));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('링크를 복사했습니다.')));
                            }
                          },
                    child: const Text('복사', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.brand)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('만료 기한', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Row(
              children: ShareLinkExpiry.values.map((e) {
                final selected = e == _expiry;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _expiry = e);
                      _createLink();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.brandTint : AppColors.background,
                        border: Border.all(color: selected ? AppColors.brand : AppColors.border),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(e.label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w700 : FontWeight.w600, color: selected ? AppColors.brand : AppColors.textTertiary)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: AppColors.warningTint, borderRadius: BorderRadius.circular(10)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 13, color: AppColors.warningDark),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '어가의 영업 정보를 담고 있는 링크입니다. 발급 이력은 마이페이지 > 공유 링크 관리에서 확인·회수할 수 있습니다.',
                      style: TextStyle(fontSize: 10.5, color: AppColors.warningTintInk, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading
                    ? null
                    : () => Share.share(_url, subject: '${widget.farm.name} 리포트 링크'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.kakaoYellow,
                  foregroundColor: AppColors.kakaoInk,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.chat_bubble, size: 16),
                label: const Text('공유하기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
