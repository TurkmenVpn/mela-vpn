import 'package:dartx/dartx.dart';
import 'package:melavpn/core/model/environment.dart';
import 'package:melavpn/features/app_update/model/remote_version_entity.dart';

abstract class GithubReleaseParser {
  static RemoteVersionEntity parse(Map<String, dynamic> json) {
    final fullTag = json['tag_name'] as String;
    final fullVersion = fullTag.removePrefix("v").split("-").first.split("+");
    var version = fullVersion.first;
    var buildNumber = fullVersion.elementAtOrElse(1, (index) => "");
    var flavor = Environment.prod;
    for (final env in Environment.values) {
      final suffix = ".${env.name}";
      if (version.endsWith(suffix)) {
        version = version.removeSuffix(suffix);
        flavor = env;
        break;
      } else if (buildNumber.endsWith(suffix)) {
        buildNumber = buildNumber.removeSuffix(suffix);
        flavor = env;
        break;
      }
    }
    final preRelease = json["prerelease"] as bool;
    final publishedAt = DateTime.parse(json["published_at"] as String);
    final assets = (json['assets'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    // Prefer universal APK (no ABI suffix). Fall back to first APK found.
    bool isUniversal(Map<String, dynamic> a) {
      final name = (a['name'] as String? ?? '').toLowerCase();
      return name.endsWith('.apk') &&
          !name.contains('-armeabi-') &&
          !name.contains('-arm64-') &&
          !name.contains('-x86_64-') &&
          !name.contains('-x86-');
    }
    final apkAsset = assets.firstOrNullWhere(isUniversal) ??
        assets.firstOrNullWhere((a) => (a['name'] as String? ?? '').endsWith('.apk'));
    final apkUrl = apkAsset?['browser_download_url'] as String?;
    return RemoteVersionEntity(
      version: version,
      buildNumber: buildNumber,
      releaseTag: fullTag,
      preRelease: preRelease,
      url: json["html_url"] as String,
      publishedAt: publishedAt,
      flavor: flavor,
      apkUrl: apkUrl,
    );
  }
}
