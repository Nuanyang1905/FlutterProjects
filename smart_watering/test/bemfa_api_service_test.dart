import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_watering/config/app_config.dart';
import 'package:smart_watering/services/bemfa_api_service.dart';

void main() {
  test('checkOnline returns data boolean', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/va/online');
      expect(request.url.queryParameters['uid'], 'uid123');
      expect(request.url.queryParameters['topic'], 'plant001');
      expect(request.url.queryParameters['type'], '1');
      return http.Response(
        jsonEncode({'code': 0, 'message': 'OK', 'data': true}),
        200,
      );
    });

    final api = BemfaApiService(
      config: const AppConfig(
        uid: 'uid123',
        controlTopic: 'plant001',
        reportTopic: 'plant001up',
        type: 1,
      ),
      httpClient: client,
    );

    final result = await api.checkOnline();
    expect(result, isTrue);
  });

  test('sendCommand posts json body', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/va/postJsonMsg');
      expect(request.method, 'POST');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['uid'], 'uid123');
      expect(body['topic'], 'plant001');
      expect(body['type'], 1);
      expect(body['msg'], 'on');
      return http.Response(
        jsonEncode({'code': 0, 'message': 'OK'}),
        200,
      );
    });

    final api = BemfaApiService(
      config: const AppConfig(
        uid: 'uid123',
        controlTopic: 'plant001',
        reportTopic: 'plant001up',
        type: 1,
      ),
      httpClient: client,
    );

    final result = await api.sendCommand('on');
    expect(result, isTrue);
  });

  test('fetchLatestState parses nested msg json', () async {
    final nested =
        '{"ver":2,"type":"status","hum":45,"raw":500,"pump":0,"mode":"auto","th_low":30,"th_high":60,"lock":0,"sensor_ok":1}';
    final client = MockClient((request) async {
      expect(request.url.path, '/va/getmsg');
      expect(request.url.queryParameters['topic'], 'plant001up');
      return http.Response(
        jsonEncode({
          'code': 0,
          'message': 'OK',
          'data': [
            {
              'msg': nested,
              'time': '2022-08-03 17:26:34',
              'unix': 1659518794,
            },
          ],
        }),
        200,
      );
    });

    final api = BemfaApiService(
      config: const AppConfig(
        uid: 'uid123',
        controlTopic: 'plant001',
        reportTopic: 'plant001up',
        type: 1,
      ),
      httpClient: client,
    );

    final state = await api.fetchLatestState();
    expect(state, isNotNull);
    expect(state!.humidity, 45);
    expect(state.isPumpOn, isFalse);
    expect(state.isAutoMode, isTrue);
    expect(state.thL, 30);
    expect(state.thH, 60);
  });
}
