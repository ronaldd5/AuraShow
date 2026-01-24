/// WASAPI Capture Facade
/// Conditionally imports implementation or stub based on platform.
library;

export 'wasapi_capture_stub.dart'
    if (dart.library.io) 'wasapi_capture_impl.dart';
