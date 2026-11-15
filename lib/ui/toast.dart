import 'package:flutter/material.dart';

const retryText = "That didn't go through. Please try again.";

void showToast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
