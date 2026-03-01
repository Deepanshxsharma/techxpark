/// Centralized map configuration.
///
/// All map tile settings in one place — change the key or provider
/// here and every map in the app updates automatically.
class MapConfig {
  MapConfig._();

  /// MapTiler Cloud API key.
  /// Restrict this key in the MapTiler dashboard to:
  ///   Android: com.techxpark.app
  ///   iOS: your bundle ID
  static const mapTilerKey = '7wrl4CZg7tz46cWZwFSf';

  /// MapTiler Streets tile URL.
  static const tileUrl =
      'https://api.maptiler.com/maps/streets-v2/{z}/{x}/{y}.png?key=$mapTilerKey';

  /// Max zoom supported by MapTiler Streets.
  static const double maxZoom = 19;

  /// User agent for tile requests.
  static const String userAgent = 'com.techxpark.app';
}
