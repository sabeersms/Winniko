import 'dart:js' as js;
import 'package:flutter/foundation.dart';

bool isPwaInstallAvailable() {
  try {
    return js.context.hasProperty('isInstallPromptAvailable') &&
        js.context.callMethod('isInstallPromptAvailable') == true;
  } catch (e) {
    debugPrint('Error checking PWA install availability: $e');
    return false;
  }
}

bool isRunningStandalone() {
  try {
    return js.context.callMethod('eval', [
          "window.matchMedia('(display-mode: standalone)').matches || window.navigator.standalone === true",
        ]) ==
        true;
  } catch (e) {
    debugPrint('Error checking standalone mode: $e');
    return false;
  }
}

Future<void> showPwaInstallPrompt() async {
  try {
    if (js.context.hasProperty('showInstallPrompt')) {
      js.context.callMethod('showInstallPrompt');
    }
  } catch (e) {
    debugPrint('Error showing PWA install prompt: $e');
  }
}
