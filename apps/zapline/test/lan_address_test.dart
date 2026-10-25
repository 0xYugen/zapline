import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:zapline/src/pairing/pin_server.dart';

void main() {
  int rank(String iface, String ip) =>
      PinServer.addressRank(iface, InternetAddress(ip));

  test('the home Wi-Fi comes before Wi-Fi Direct, hotspots and VPNs', () {
    final home = rank('wlan0', '192.168.1.24');
    expect(home, 0);
    expect(rank('eth0', '10.0.0.5'), 0);
    expect(rank('p2p0', '192.168.49.1'), greaterThan(home));
    expect(rank('wlan1', '192.168.43.1'), greaterThan(home));
    expect(rank('tun0', '10.8.0.2'), greaterThan(home));
    expect(rank('vEthernet (WSL)', '172.20.0.1'), greaterThan(home));
    expect(rank('wlan0', '8.8.8.8'), greaterThan(rank('tun0', '10.8.0.2')));
  });
}
