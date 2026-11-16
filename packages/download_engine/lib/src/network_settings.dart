import 'models/network_config.dart';

/// A shared, replaceable [NetworkConfig]. Tasks and workers read it each
/// time they build a request, so a change applies to the next request while
/// running workers finish the one in flight.
class NetworkSettings {
  NetworkSettings([this.config = const NetworkConfig()]);
  NetworkConfig config;
}
