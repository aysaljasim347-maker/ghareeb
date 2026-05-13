class TaskItem {
  final String item;
  final dynamic quantity;

  TaskItem({required this.item, required this.quantity});

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      item: json['item'],
      quantity: json['quantity'],
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
      id: json['id'],
      title: json['title'],
      sourceType: json['source_type'] ?? json['sourceType'] ?? 'BENEFICIARY_REQUEST',
      itemsNeeded: (json['items_needed'] as List?)?.map((i) => TaskItem.fromJson(i)).toList() ?? [],
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      budgetPkr: json['budget_pkr']?.toDouble() ?? 0.0,
      status: json['status'] ?? 'OPEN',
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
