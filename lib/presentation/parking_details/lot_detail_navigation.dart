import 'package:flutter/material.dart';

import 'parking_details_screen.dart';

void openLotDetail(
  BuildContext context,
  String lotId,
  Map<String, dynamic> data, {
  String collectionName = 'parking_locations',
}) {
  final resolvedLotId = lotId.trim().isNotEmpty
      ? lotId.trim()
      : data['id']?.toString().trim() ?? '';
  final routeData = <String, dynamic>{
    ...data,
    if (resolvedLotId.isNotEmpty) 'id': resolvedLotId,
  };

  debugPrint('Opening Lot Detail for: $resolvedLotId');

  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          ParkingDetailsScreen(data: routeData, collectionName: collectionName),
    ),
  );
}
