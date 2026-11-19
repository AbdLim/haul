import 'package:flutter_test/flutter_test.dart';
import 'package:haul/services/network/windows_system_proxy.dart';

const withHttp = r'''
HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Internet Settings
    ProxyEnable    REG_DWORD    0x1
    ProxyServer    REG_SZ    http=proxy.example:8080;https=proxy.example:8443
    ProxyOverride    REG_SZ    *.local;169.254/16;<local>
''';

void main() {
  group('reading reg query output', () {
    test('every value comes back by name', () {
      final values = parseRegQuery(withHttp);
      expect(values['ProxyEnable'], '0x1');
      expect(
        values['ProxyServer'],
        'http=proxy.example:8080;https=proxy.example:8443',
      );
      expect(values['ProxyOverride'], '*.local;169.254/16;<local>');
    });

    test('the key line and other text are not values', () {
      expect(parseRegQuery(''), isEmpty);
      expect(
        parseRegQuery(
          'HKEY_CURRENT_USER\\Software\\Some Key\n'
          '    Empty    REG_SZ    \n',
        ),
        {'Empty': ''},
      );
    });
  });

  group('a system proxy', () {
    test('is read from the HTTP entry, with the bypass list', () {
      final p = parseWindowsProxy(withHttp)!;
      expect(p.host, 'proxy.example');
      expect(p.port, 8080);
      expect(p.bypass, ['*.local', '169.254/16']);
    });

    test('falls back to the HTTPS entry when there is no HTTP one', () {
      final p = parseWindowsProxy(
        withHttp.replaceFirst('http=proxy.example:8080;', ''),
      )!;
      expect(p.host, 'proxy.example');
      expect(p.port, 8443);
    });

    test('accepts a single host and port, with no scheme', () {
      final p = parseWindowsProxy(
        withHttp.replaceFirst(
          'ProxyServer    REG_SZ    '
              'http=proxy.example:8080;https=proxy.example:8443',
          'ProxyServer    REG_SZ    proxy.example:3128',
        ),
      )!;
      expect(p.host, 'proxy.example');
      expect(p.port, 3128);
    });

    test('is null when the setting is off', () {
      expect(parseWindowsProxy(withHttp.replaceFirst('0x1', '0x0')), isNull);
    });

    test('is null with no server, no port, or a scheme Haul cannot use', () {
      String replace(String value) => withHttp.replaceFirst(
        RegExp(r'ProxyServer    REG_SZ    .*'),
        'ProxyServer    REG_SZ    $value',
      );
      expect(parseWindowsProxy(replace('')), isNull);
      expect(parseWindowsProxy(replace('proxy.example')), isNull);
      expect(parseWindowsProxy(replace('proxy.example:abc')), isNull);
      expect(parseWindowsProxy(replace('socks=socks.example:1080')), isNull);
    });
  });

  group('the bypass list', () {
    test('is split on semicolons, trimmed, without Windows own <local>', () {
      expect(parseWindowsBypass(' *.local ; 169.254/16 ;<local>; '), [
        '*.local',
        '169.254/16',
      ]);
      expect(parseWindowsBypass(''), isEmpty);
    });
  });
}
