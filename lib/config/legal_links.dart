import 'package:url_launcher/url_launcher.dart';

class LegalLinks {
  LegalLinks._();

  static const privacyPolicyUrl = 'https://techxpark.in/privacy';
  static const termsOfServiceUrl = 'https://techxpark.in/terms';
  static const helpCenterUrl = 'https://techxpark.in/contact';

  static Future<bool> openPrivacyPolicy() => _open(privacyPolicyUrl);

  static Future<bool> openTermsOfService() => _open(termsOfServiceUrl);

  static Future<bool> openHelpCenter() => _open(helpCenterUrl);

  static Future<bool> _open(String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
