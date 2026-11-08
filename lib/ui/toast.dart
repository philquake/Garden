import 'package:flutter/material.dart';

const retryText =
    "That didn't go through. Your garden has been refreshed, "
    'so please try again.';

const gardenFullText =
    "Your garden is full for now. You can remove a flower you've "
    'finished with to make room.';

void showToast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
