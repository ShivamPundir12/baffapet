import 'package:url_launcher/url_launcher.dart';

bool shouldOpenExternally(Uri url, List<String> hosts) {
  final s = url.scheme;
  if (s == "tel" || s == "mailto" || s == "sms" || s == "intent") return true;
  final host = url.host.toLowerCase();
  return hosts.any((h) => host.contains(h));
}

Future<bool> tryOpenExternal(Uri url) async {
  final u = url.toString();
  if (await canLaunchUrl(Uri.parse(u))) {
    await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
    return true;
  }
  return false;
}
