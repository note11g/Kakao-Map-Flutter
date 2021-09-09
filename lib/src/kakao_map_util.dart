import 'package:kakao_map_flutter/kakao_map_flutter.dart';
import 'package:location/location.dart';

class KakaoMapUtil {
  static Future<KakaoLatLng?> determinePosition() async {
    Location location = new Location();

    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    LocationData _locationData;

    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled) {
        return null; // todo : exception processing
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return null; // todo : exception processing
      }
    }

    _locationData = await location.getLocation();

    return KakaoLatLng(_locationData.latitude ?? 37.56633045338814,
        _locationData.longitude ?? 126.97703388516338);
  }
}
