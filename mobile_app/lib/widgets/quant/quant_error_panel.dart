import 'package:flutter/material.dart';

import '../../services/api_client.dart';
import '../../utils/theme_helpers.dart';
import 'quant_common_widgets.dart';

class QuantErrorPanel extends StatelessWidget {
  const QuantErrorPanel({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : error.toString();
    return QuantPanel(
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFFF3B45)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: primaryTextColor(context)),
            ),
          ),
        ],
      ),
    );
  }
}
