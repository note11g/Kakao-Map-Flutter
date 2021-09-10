import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kakao_map_flutter/kakao_map_flutter.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  MyApp({Key? key}) : super(key: key);

  late final KakaoMapController _mapController;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
          body: SafeArea(
        child: Column(children: [
          Expanded(
              child: KakaoMap(
            initLocation: KakaoLatLng(33.450701, 126.570667),
            kakaoApiKey: "kakao javascript api key here",
            autoLocationEnable: true,
            clustererServiceEnable: true,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onMarkerTouched: (markerLocation, markerIndex) {
              Get.rawSnackbar(
                  message: "$markerLocation, $markerIndex",
                  margin: const EdgeInsets.all(8),
                  borderRadius: 12.0,
                  snackPosition: SnackPosition.TOP);
            },
          )),
          _customButton("현재 위치로 이동하고 커스텀 오버레이 추가하기", onTap: () async {
            final location = await _mapController.setNowLocation();
            if (location != null) {
              _mapController.deleteAllCustomOverlays();
              _mapController.addCustomOverlay(location);
            }
          }),
          _customButton("지도 위치에 마커 추가하기", onTap: () async {
            _mapController.addMarker(await _mapController.getCenter());
          }, color: Colors.green),
          _customButton("모든 마커 삭제하기", onTap: () {
            _mapController.deleteAllMarkers();
          }, color: Colors.red),
          _customButton("모든 마커 클러스터링하기", onTap: () {
            if (!_mapController.nowClusteringEnabled())
              _mapController.startClustering(minLevel: 5, calculator: [
                10,
                30,
                50
              ], texts: [
                "삐약",
                "꼬꼬",
                "꼬끼오",
                "치멘"
              ], styles: [
                {
                  'width': '30px',
                  'height': '30px',
                  'background': 'rgba(51,204,255,.8)',
                  'borderRadius': '15px',
                  'color': '#000',
                  'textAlign': 'center',
                  'fontWeight': 'bold',
                  'lineHeight': '31px'
                },
                {
                  'width': '40px',
                  'height': '40px',
                  'background': 'rgba(255, 153, 0, .8)',
                  'borderRadius': '20px',
                  'color': '#000',
                  'textAlign': 'center',
                  'fontWeight': 'bold',
                  'lineHeight': '41px'
                },
                {
                  'width': '50px',
                  'height': '50px',
                  'background': 'rgba(255, 51, 204, .8)',
                  'borderRadius': '25px',
                  'color': '#000',
                  'textAlign': 'center',
                  'fontWeight': 'bold',
                  'lineHeight': '51px'
                },
                {
                  'width': '60px',
                  'height': '60px',
                  'background': 'rgba(255, 80, 80, .8)',
                  'borderRadius': '30px',
                  'color': '#000',
                  'textAlign': 'center',
                  'fontWeight': 'bold',
                  'lineHeight': '61px'
                }
              ]);
            else
              _mapController.updateClustering();
          }, color: Colors.black87),
        ]),
      )),
    );
  }

  Widget _customButton(String text,
          {Function()? onTap, Color color = Colors.lightBlue}) =>
      SizedBox(
          width: double.infinity,
          child: Material(
            color: color,
            child: InkWell(
                onTap: onTap,
                child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
                    child: Text(text,
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center))),
          ));
}
