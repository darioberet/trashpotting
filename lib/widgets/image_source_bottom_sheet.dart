import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_icons.dart';

Future<ImageSource?> showImageSourceBottomSheet(
  BuildContext context, {
  String cameraLabel = 'Scatta foto',
}) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.camera),
              title: Text(cameraLabel),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(AppIcons.gallery),
              title: const Text('Scegli dalla galleria'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      );
    },
  );
}
