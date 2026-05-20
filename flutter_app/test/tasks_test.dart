import 'package:flutter_test/flutter_test.dart';
import 'package:reliefnet_app/features/tasks/domain/task_model.dart';

void main() {
  group('TaskModel', () {
    test('should create from JSON', () {
      final json = {
        'id': 1,
        'campaign_id': 5,
        'beneficiary_id': null,
        'created_by': 2,
        'claimed_by': null,
        'coordinator_id': null,
        'source_type': 'BENEFICIARY_REQUEST',
        'title': 'Deliver food supplies to Sindh flood victims',
        'description': 'Urgent delivery needed',
        'category': 'FOOD',
        'family_size': 4,
        'items_needed': ['Rice 10kg', 'Oil 5L', 'Sugar 5kg'],
        'latitude': 24.8607,
        'longitude': 67.0011,
        'location_text': 'Karachi, Sindh',
        'radius_km': 10,
        'budget_pkr': 5000.0,
        'urgency': 'HIGH',
        'status': 'OPEN',
        'upvotes': 5,
        'downvotes': 0,
        'view_count': 23,
        'created_at': '2024-01-01T00:00:00Z',
        'updated_at': '2024-01-01T00:00:00Z',
        'claimed_at': null,
        'created_by_name': 'Test NGO',
        'claimed_by_name': null,
      };

      final task = TaskModel.fromJson(json);

      expect(task.id, 1);
      expect(task.title, 'Deliver food supplies to Sindh flood victims');
      expect(task.urgency, 'HIGH');
      expect(task.status, 'OPEN');
      expect(task.budgetPkr, 5000.0);
      expect(task.latitude, 24.8607);
      expect(task.longitude, 67.0011);
      expect(task.familySize, 4);
      expect(task.itemsNeeded.length, 3);
      expect(task.isOpen, true);
      expect(task.isHigh, true);
      expect(task.isCritical, false);
    });

    test('should handle minimal JSON with defaults', () {
      final json = {
        'id': 2,
        'source_type': 'NGO_CAMPAIGN',
        'title': 'Minimal Task',
      };

      final task = TaskModel.fromJson(json);

      expect(task.id, 2);
      expect(task.title, 'Minimal Task');
      expect(task.familySize, 1);
      expect(task.budgetPkr, 0);
      expect(task.urgency, 'MEDIUM');
      expect(task.status, 'OPEN');
      expect(task.itemsNeeded, isEmpty);
      expect(task.latitude, null);
      expect(task.longitude, null);
    });

    test('urgency helpers should return correct values', () {
      const critical = TaskModel(
        id: 1,
        sourceType: 'ADMIN_CREATED',
        title: 'Test',
        urgency: TaskUrgency.critical,
      );
      const low = TaskModel(
        id: 2,
        sourceType: 'ADMIN_CREATED',
        title: 'Test',
        urgency: TaskUrgency.low,
      );

      expect(critical.isCritical, true);
      expect(critical.isHigh, false);
      expect(low.isCritical, false);
      expect(low.isHigh, false);
    });

    test('isOpen should reflect status', () {
      const open = TaskModel(
        id: 1,
        sourceType: 'ADMIN_CREATED',
        title: 'Test',
        status: TaskStatus.open,
      );
      const claimed = TaskModel(
        id: 2,
        sourceType: 'ADMIN_CREATED',
        title: 'Test',
        status: TaskStatus.claimed,
      );

      expect(open.isOpen, true);
      expect(claimed.isOpen, false);
    });
  });
}
