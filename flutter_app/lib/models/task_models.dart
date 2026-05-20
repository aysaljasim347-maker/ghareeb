import 'package:reliefnet_app/utils/safe_parser.dart';

class TaskItem {
  final String item;
  final dynamic quantity;

  TaskItem({required this.item, required this.quantity});

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      item: SafeParser.toStringSafe(json['item'], defaultValue: 'Unknown Item'),
      quantity: json['quantity'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'item': item,
      'quantity': quantity,
    };
  }
}

class Task {
  final int? id;
  final String title;
  final String sourceType;
  final List<TaskItem> itemsNeeded;
  final double latitude;
  final double longitude;
  final double budgetPkr;
  final String status;

  Task({
    this.id,
    required this.title,
    required this.sourceType,
    required this.itemsNeeded,
    required this.latitude,
    required this.longitude,
    this.budgetPkr = 0.0,
    this.status = 'OPEN',
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] != null ? SafeParser.paramInt(json['id']) : null,
      title: SafeParser.toStringSafe(json['title'], defaultValue: 'Untitled Task'),
      sourceType: SafeParser.toStringSafe(
        json['source_type'] ?? json['sourceType'],
        defaultValue: 'BENEFICIARY_REQUEST',
      ),
      itemsNeeded: (json['items_needed'] as List?)
              ?.map((i) => TaskItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      latitude: SafeParser.toDouble(json['latitude']),
      longitude: SafeParser.toDouble(json['longitude']),
      budgetPkr: SafeParser.toDouble(json['budget_pkr']),
      status: SafeParser.toStringSafe(json['status'], defaultValue: 'OPEN'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'source_type': sourceType,
      'items_needed': itemsNeeded.map((i) => i.toJson()).toList(),
      'latitude': latitude,
      'longitude': longitude,
      'budget_pkr': budgetPkr,
      'status': status,
    };
  }
}
