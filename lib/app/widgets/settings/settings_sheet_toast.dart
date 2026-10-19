import 'package:bilirec/shared/app_toast.dart';
import 'package:flutter/material.dart';

void showSettingsToast(
  BuildContext context,
  String message, {
  AppToastLocation location = AppToastLocation.top,
}) {
  showAppToast(
    context,
    message,
    animation: AppToastAnimation.fade,
    location: location,
    edgeDistance: 72,
  );
}
