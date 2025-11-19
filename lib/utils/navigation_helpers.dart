import 'package:flutter/material.dart';

import 'package:outlet_app/ui/screens/customer_create_screen.dart';

Future<bool?> openCustomerCreateScreen(BuildContext context) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => const CustomerCreateScreen()),
  );
}
