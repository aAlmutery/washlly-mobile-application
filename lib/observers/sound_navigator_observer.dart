import 'dart:async';
import 'package:flutter/material.dart';
import '../services/sound_service.dart';

/// Plays the popup chime whenever a dialog or modal bottom sheet is pushed.
/// Registered on MaterialApp.navigatorObservers so it catches every
/// showDialog / showModalBottomSheet call in the app without any per-site changes.
class SoundNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    if (route is DialogRoute || route is ModalBottomSheetRoute) {
      unawaited(SoundService.instance.playPopupSound());
    }
  }
}
