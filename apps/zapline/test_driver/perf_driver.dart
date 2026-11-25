import 'package:integration_test/integration_test_driver.dart';

/// Runs integration_test/perf_test.dart on a device and writes the frame
/// timings to build/integration_response_data.json. See that test.
Future<void> main() => integrationDriver();
