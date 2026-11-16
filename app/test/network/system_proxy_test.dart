import 'package:flutter_test/flutter_test.dart';
import 'package:haul/services/network/system_proxy.dart';

const withHttp = '''
<dictionary> {
  ExceptionsList : <array> {
    0 : *.local
    1 : 169.254/16
  }
  FTPPassive : 1
  HTTPEnable : 1
  HTTPPort : 8080
  HTTPProxy : 10.0.0.5
  HTTPSEnable : 1
  HTTPSPort : 8443
  HTTPSProxy : 10.0.0.6
}
''';

void main() {
  test('an HTTP proxy is read with its port and exceptions', () {
    final p = parseScutilProxy(withHttp)!;
    expect(p.host, '10.0.0.5');
    expect(p.port, 8080);
    expect(p.bypass, ['*.local', '169.254/16']);
  });

  test('the HTTPS proxy is used when HTTP is off', () {
    final p = parseScutilProxy(
      withHttp.replaceFirst('HTTPEnable : 1', 'HTTPEnable : 0'),
    )!;
    expect(p.host, '10.0.0.6');
    expect(p.port, 8443);
  });

  test('no proxy enabled gives null', () {
    expect(
      parseScutilProxy(
        '<dictionary> {\n  HTTPEnable : 0\n  HTTPSEnable : 0\n}',
      ),
      isNull,
    );
    expect(parseScutilProxy(''), isNull);
  });

  test('an enabled proxy with no port is ignored', () {
    expect(
      parseScutilProxy('<dictionary> {\n  HTTPEnable : 1\n  HTTPProxy : h\n}'),
      isNull,
    );
  });
}
