import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kakao_map_flutter/kakao_map_flutter.dart';
import 'package:kakao_map_flutter/src/kakao_map_state.dart';
import 'package:kakao_map_flutter/src/kakao_map_util.dart';
import 'package:webview_flutter/webview_flutter.dart';

class KakaoMap extends StatelessWidget {
  // widget size
  final double width;
  final double height;

  // initial location
  final KakaoLatLng initLocation;

  // zoom level
  // default is 3
  final int level;

  // auto location using gps
  // default is false
  final bool autoLocationEnable;

  // markers clusterer service
  // default is false
  final bool clustererServiceEnable;

  // kakao dev javascript key
  final String kakaoApiKey;

  // run when map created. at this time, you can get kakaoMapController
  final KakaoMapCreatedCallback? onMapCreated;

  // run when map finished load
  final KakaoMapPageFinishedCallback? onMapLoaded;

  // run when marker touched
  final KakaoMapMarkerTouched? onMarkerTouched;

  KakaoMap(
      {this.width = double.infinity,
      this.height = 500,
      required this.initLocation,
      this.level = 3,
      required this.kakaoApiKey,
      this.autoLocationEnable = false,
      this.clustererServiceEnable = false,
      this.onMapCreated,
      this.onMapLoaded,
      this.onMarkerTouched});

  // map controller
  late final KakaoMapController _kakaoMapController;

  final KakaoMapState _state = KakaoMapState();

  @override
  Widget build(BuildContext context) => SizedBox(
      width: width,
      height: height,
      child: WebView(
        initialUrl: _getMapPage(),
        javascriptMode: JavascriptMode.unrestricted,
        onWebViewCreated: (WebViewController wc) {
          _kakaoMapController = KakaoMapController(wc);
          if (onMapCreated != null) onMapCreated!(_kakaoMapController);
        },
        javascriptChannels: Set.from([
          JavascriptChannel(
              name: 'onMapFinished',
              onMessageReceived: (_) => _onMapLoadFinished()),
          JavascriptChannel(
              name: 'sendCenterPoint',
              onMessageReceived: (m) {
                _state.setCenter(_parseKakaoLatLng(m.message));
              }),
          JavascriptChannel(
              name: 'sendLevel',
              onMessageReceived: (m) {
                _state.setLevel(int.parse(m.message));
              }),
          JavascriptChannel(
              name: 'markerTouch',
              onMessageReceived: (m) {
                if (onMarkerTouched != null) {
                  final List<String> markerInfo = m.message.split('_');
                  onMarkerTouched!(
                    _parseKakaoLatLng(markerInfo[0]),
                    int.parse(markerInfo[1])
                  );
                }
              }),
        ]),
      ));

  String _getMapPage() {
    final String html = '''
<html>
  <head>
    <meta name='viewport' content='width=device-width, initial-scale=1.0, user-scalable=yes'/>
  </head>
  <body style="margin:0; padding:0;">
    <div id='kakao_map_container' style="width:100%; height:100%;" />
	<script type="text/javascript" src='https://dapi.kakao.com/v2/maps/sdk.js?autoload=false&appkey=$kakaoApiKey${clustererServiceEnable ? '&libraries=clusterer' : ''}'></script>
	<script type="text/javascript">
		const container = document.querySelector('#kakao_map_container');
		let map;
		let bounds;
		const customOverlays = [];
		const markers = [];
		
		kakao.maps.load(function() {
		  const options = {
        center: new kakao.maps.LatLng(${initLocation.latitude}, ${initLocation.longitude}),
        level: $level
      };
		  map = new kakao.maps.Map(container, options);
      onMapFinished.postMessage("");
      bounds = new kakao.maps.LatLngBounds();
    });
	</script>
</body>
</html>
    ''';

    return Uri.dataFromString(html,
            mimeType: 'text/html', encoding: Encoding.getByName('utf-8'))
        .toString();
  }

  _onMapLoadFinished() {
    if (autoLocationEnable) _kakaoMapController.setNowLocation();
    if (onMapLoaded != null) onMapLoaded!();
  }

  KakaoLatLng _parseKakaoLatLng(String m) {
    final List<String> latLngStr =
        m.replaceAll(new RegExp(r'[\(\),]'), '').split(' ');
    return KakaoLatLng(double.parse(latLngStr[0]), double.parse(latLngStr[1]));
  }
}

class KakaoMapController {
  final WebViewController _controller;
  final KakaoMapState _state = KakaoMapState();
  bool _isUsingBounds = false;
  int _customOverlayCount = 0;
  int _markerCount = 0;

  KakaoMapController(this._controller);

  _runScript(String script) => _controller.evaluateJavascript(script);

  // reload map
  reload() => _controller.reload();

  // set now location using gps
  // return now location
  Future<KakaoLatLng?> setNowLocation() async {
    final KakaoLatLng? location = await KakaoMapUtil.determinePosition();
    if (location != null) setCenter(location);
    return location;
  }

  // set center point
  setCenter(KakaoLatLng location) {
    final String script =
        '''(()=>{ const location = new kakao.maps.LatLng(${location.latitude}, ${location.longitude}); map.setCenter(location); })()''';
    _runScript(script);
  }

  // return now center point
  Future<KakaoLatLng> getCenter() async {
    final String script = '''(()=>{
  const center = map.getCenter();
  sendCenterPoint.postMessage(center.toString());
})()''';
    await _runScript(script);

    return _state.getCenter()!;
  }

  // set zoom level
  setLevel(int level) {
    final String script = '(()=>map.setLevel($level))()';
    _runScript(script);
  }

  // return now zoom level
  Future<int> getLevel() async {
    final String script = '''(()=>{
  const level = map.getLevel();
  sendLevel.postMessage(level.toString());
})()''';
    await _runScript(script);

    return _state.getLevel()!;
  }

  // add marker
  // if addBounds option is true, you can use setBounds
  // addBounds default value is false
  // return marker index number
  int addMarker(KakaoLatLng location,
      {bool addBounds = false, String? markerImgLink, List<double>? iconSize}) {
    final String script = '''(()=>{
  const location = new kakao.maps.LatLng(${location.latitude}, ${location.longitude});
  ${iconSize != null ? '''const icon = new kakao.maps.MarkerImage(
    '$markerImgLink',
    new kakao.maps.Size(${iconSize[0]}, ${iconSize[1]}));''' : ''}
  const marker = new kakao.maps.Marker({
    position: location,
    ${iconSize != null ? 'image: icon,' : ''}
    clickable: true
  });
  marker.setMap(map);
  ${addBounds ? 'bounds.extend(location);' : ''}
  markers[$_markerCount] = marker;
  kakao.maps.event.addListener(marker, 'click', ()=>{
    markerTouch.postMessage(location.toString()+'_$_markerCount');
  });
})()''';
    _runScript(script);
    if (addBounds && !_isUsingBounds) _isUsingBounds = true;
    return _markerCount++;
  }

  // delete marker
  deleteMarker(int idx) {
    if (idx >= _markerCount) return; // bounds of index
    final String script = 'markers[$idx].setMap(null); markers[$idx] = null;';
    _runScript(script);
  }

  // delete all marker
  deleteAllMarkers() {
    final String script =
        'markers.forEach((v)=>v.setMap(null)); markers.length = 0;';
    _runScript(script);
    _markerCount = 0;
  }

  // resetting level and center point.
  // all markers added with the addBounds option enabled are visible.
  setBounds() {
    if (!_isUsingBounds) return;
    final String script = 'map.setBounds(bounds);';
    _runScript(script);
  }

  // add custom overlay
  // change overlayHtml, using markerHtml option
  // return custom overlay index number
  int addCustomOverlay(KakaoLatLng location, {String? markerHtml}) {
    String html = markerHtml ??
        '''<div style="background-color: orangered; border: 3px solid white; box-shadow: 1px 2px 4px rgba(0,0,0,0.2); border-radius: 9999px; padding: 7px;"/>''';
    final String script = '''(()=>{
  const location = new kakao.maps.LatLng(${location.latitude}, ${location.longitude});
  const customOverlay = new kakao.maps.CustomOverlay({
    position: location,
    content: `$html`
  });
  customOverlay.setMap(map);
  customOverlays[$_customOverlayCount] = customOverlay;
})()''';
    _runScript(script);
    return _customOverlayCount++;
  }

  // number of custom overlays
  int customOverlaysCount() => _customOverlayCount;

  // delete custom overlay using index number
  deleteCustomOverlay(int idx) {
    if (idx >= _customOverlayCount) return; // bounds of index
    final String script =
        'customOverlays[$idx].setMap(null); customOverlays[$idx] = null;';
    _runScript(script);
  }

  // delete all custom overlay
  deleteAllCustomOverlays() {
    final String script =
        'customOverlays.forEach((v)=>v.setMap(null)); customOverlays.length = 0;';
    _runScript(script);
    _customOverlayCount = 0;
  }

  // marker clusterer using added markers
  // make sure enable clustererServiceEnable option.
  startClustering({bool avgCenter = true, int minLevel = 10}) {
    final String script = '''const clusterer = new kakao.maps.MarkerClusterer({
  map: map,
  averageCenter: $avgCenter,
  minLevel: $minLevel
});
clusterer.addMarkers(markers);''';
    _runScript(script);
  }

  // marker clusterer update
  updateClustering() {
    final String script = 'clusterer.addMarkers(markers);';
    _runScript(script);
  }
}
