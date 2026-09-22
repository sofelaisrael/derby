import 'package:flutter/material.dart';

void showCenteredPopup(BuildContext context, String message) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => _CenteredPopup(message: message),
  );
}

class _CenteredPopup extends StatefulWidget {
  final String message;
  const _CenteredPopup({required this.message});

  @override
  State<_CenteredPopup> createState() => _CenteredPopupState();
}

class _CenteredPopupState extends State<_CenteredPopup> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Text(
        widget.message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      ),
    );
  }
}