import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ads_service.dart';

class ClientBannerAd extends StatefulWidget {
  const ClientBannerAd({super.key});

  @override
  State<ClientBannerAd> createState() => _ClientBannerAdState();
}

class _ClientBannerAdState extends State<ClientBannerAd> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  @override
  void initState() {
    super.initState();
    final adUnitId = AdsService.bannerAdUnitId;
    if (adUnitId == null) return;

    final ad = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Test banner ad failed to load: $error');
          ad.dispose();
          if (mounted) setState(() => _bannerAd = null);
        },
      ),
    );
    _bannerAd = ad;
    unawaited(
      ad.load().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Test banner ad request failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        ad.dispose();
        if (mounted) setState(() => _bannerAd = null);
      }),
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (ad == null) return const SizedBox.shrink();

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SizedBox(
        height: ad.size.height.toDouble(),
        child: _isLoaded
            ? Center(
                child: SizedBox(
                  width: ad.size.width.toDouble(),
                  height: ad.size.height.toDouble(),
                  child: AdWidget(ad: ad),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
