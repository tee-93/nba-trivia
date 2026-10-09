import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  UpdateInfo({
    required this.current,
    required this.latest,
    required this.apkUrl,
    required this.notes,
  });

  final String current;
  final String latest;
  final String? apkUrl;
  final String notes;

  bool get isNewer => compareVersions(latest, current) > 0;
}

/// Checks the latest GitHub release and opens its APK for download.
class UpdateService {
  static const repo = 'tee-93/nba-trivia';

  Future<String> currentVersion() async =>
      (await PackageInfo.fromPlatform()).version;

  Future<UpdateInfo> check() async {
    final current = await currentVersion();
    final res = await http
        .get(
          Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
          headers: {'Accept': 'application/vnd.github+json'},
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode == 404) {
      throw Exception('No release has been published yet.');
    }
    if (res.statusCode != 200) {
      throw Exception('GitHub returned HTTP ${res.statusCode}.');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final assets = (j['assets'] as List? ?? []).cast<Map<String, dynamic>>();
    final apk = assets.where((a) => (a['name'] as String).endsWith('.apk'));
    return UpdateInfo(
      current: current,
      latest: (j['tag_name'] as String).replaceFirst(RegExp(r'^[vV]'), ''),
      apkUrl: apk.isEmpty ? null : apk.first['browser_download_url'] as String,
      notes: (j['body'] as String?) ?? '',
    );
  }

  /// Opens the APK link; Android downloads it and offers to install.
  Future<bool> download(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}

/// Compares dotted version strings numerically: 1.10.0 > 1.9.0.
int compareVersions(String a, String b) {
  List<int> parse(String v) => v
      .split('+')
      .first
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
  final x = parse(a), y = parse(b);
  for (var i = 0; i < 3; i++) {
    final xi = i < x.length ? x[i] : 0;
    final yi = i < y.length ? y[i] : 0;
    if (xi != yi) return xi.compareTo(yi);
  }
  return 0;
}
