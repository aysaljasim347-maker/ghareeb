import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:disasteraid_app/features/tasks/presentation/tasks_provider.dart';
import 'package:disasteraid_app/features/tasks/domain/task_model.dart';
import 'package:disasteraid_app/core/theme/app_theme.dart';
import 'package:disasteraid_app/models/goods_donation_model.dart';
import 'package:disasteraid_app/providers/goods_donation_provider.dart';
import 'package:disasteraid_app/widgets/empty_state.dart';
import 'package:disasteraid_app/widgets/error_view.dart';
import 'package:disasteraid_app/widgets/shimmer_card.dart';

enum VolunteerTaskViewMode { list, map }

enum VolunteerTaskSort { recent, nearest, urgent }

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  VolunteerTaskViewMode _viewMode = VolunteerTaskViewMode.list;
  VolunteerTaskSort _sortMode = VolunteerTaskSort.recent;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Food',
    'Medical',
    'Shelter',
    'Education',
    'Emergency'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  bool _isUrgent(TaskModel task) {
    final title = task.title.toLowerCase();
    final desc = (task.description ?? '').toLowerCase();
    return task.urgency == TaskUrgency.critical ||
        task.urgency == TaskUrgency.high ||
        title.contains('emergency') ||
        desc.contains('urgent');
  }

  List<TaskModel> _getFilteredTasks(List<TaskModel> tasks) {
    return tasks.where((task) {
      // 1. Search Filter
      final matchesSearch = _searchQuery.isEmpty ||
          task.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (task.description ?? '').toLowerCase().contains(_searchQuery.toLowerCase());

      if (!matchesSearch) return false;

      // 2. Category Filter
      if (_selectedCategory == 'All') return true;
      if (_selectedCategory == 'Emergency') return _isUrgent(task);

      final cat = task.category?.toLowerCase() ?? '';
      return cat.contains(_selectedCategory.toLowerCase());
    }).toList()
      ..sort((a, b) {
        switch (_sortMode) {
          case VolunteerTaskSort.urgent:
            final aU = _isUrgent(a) ? 0 : 1;
            final bU = _isUrgent(b) ? 0 : 1;
            return aU.compareTo(bU);
          case VolunteerTaskSort.recent:
            final aD = DateTime.tryParse(a.createdAt ?? '') ?? DateTime(2000);
            final bD = DateTime.tryParse(b.createdAt ?? '') ?? DateTime(2000);
            return bD.compareTo(aD);
          case VolunteerTaskSort.nearest:
            return a.id.compareTo(b.id);
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(availableTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Tasks'),
        actions: [
          IconButton(
            icon: Icon(_viewMode == VolunteerTaskViewMode.list
                ? Icons.map_outlined
                : Icons.list_alt_outlined),
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == VolunteerTaskViewMode.list
                    ? VolunteerTaskViewMode.map
                    : VolunteerTaskViewMode.list;
              });
            },
            tooltip: _viewMode == VolunteerTaskViewMode.list ? 'Map View' : 'List View',
          ),
          PopupMenuButton<VolunteerTaskSort>(
            icon: const Icon(Icons.sort_outlined),
            onSelected: (sort) => setState(() => _sortMode = sort),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: VolunteerTaskSort.recent,
                child: Text('Most Recent'),
              ),
              const PopupMenuItem(
                value: VolunteerTaskSort.urgent,
                child: Text('Urgent First'),
              ),
              const PopupMenuItem(
                value: VolunteerTaskSort.nearest,
                child: Text('Nearest'),
              ),
            ],
          ),
        ],
bottom: TabBar(
  controller: _tabController,
  indicatorWeight: 3,
  labelStyle: const TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 14,
  ),
  unselectedLabelStyle: const TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 14,
  ),
  tabs: const [
    Tab(text: 'Tasks'),
    Tab(text: 'Goods Pickup'),
  ],
),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── Tab 0: Regular tasks ──
          tasksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => ErrorView(
          message: 'Failed to load tasks',
          onRetry: () => ref.invalidate(availableTasksProvider),
        ),
        data: (tasks) {
          final filtered = _getFilteredTasks(tasks);
          final urgentTasks = tasks.where(_isUrgent).toList();

          return Column(
            children: [
              // ── Search Bar ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search tasks...',
                    prefixIcon: const Icon(Icons.search),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),

              // ── Category Filter ──
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: _categories.map((cat) {
                    final isSelected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(cat),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() => _selectedCategory = cat);
                        },
                        selectedColor: cat == 'Emergency' 
                            ? Colors.red.shade100 
                            : Theme.of(context).colorScheme.primaryContainer,
                        labelStyle: TextStyle(
                          color: isSelected 
                              ? (cat == 'Emergency' ? Colors.red.shade900 : Theme.of(context).colorScheme.onPrimaryContainer)
                              : null,
                          fontWeight: isSelected ? FontWeight.bold : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 8),

              Expanded(
                child: _viewMode == VolunteerTaskViewMode.map
                    ? _TaskMapView(tasks: filtered)
                    : _buildListView(filtered, urgentTasks),
              ),
            ],
          );
        },
      ),
          // ── Tab 1: Goods pickup tasks ──
          const _GoodsPickupTab(),
        ],
      ),
    );
  }

  Widget _buildListView(List<TaskModel> filtered, List<TaskModel> urgentTasks) {
    if (filtered.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_outlined,
        title: 'No tasks found',
        subtitle: 'Try adjusting your search or category filters.',
        ctaLabel: 'Reset Filters',
        onCta: () {
          setState(() {
            _selectedCategory = 'All';
            _searchQuery = '';
            _searchController.clear();
          });
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(availableTasksProvider),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filtered.length + (urgentTasks.isNotEmpty ? 1 : 0) + 1,
        itemBuilder: (context, index) {
          // 1. Show Urgent strip at the top
          if (urgentTasks.isNotEmpty && index == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    '🚨 Urgent Near You',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: urgentTasks.length,
                    itemBuilder: (context, idx) => _UrgentTaskCard(task: urgentTasks[idx]),
                  ),
                ),
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'All Available Tasks',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            );
          }

          // 2. Show History section at the bottom
          final isHistoryIndex = urgentTasks.isNotEmpty 
              ? index == filtered.length + 1 
              : index == filtered.length;
              
          if (isHistoryIndex) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 12),
                  child: Text(
                    'Recently Completed',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                // Since we don't have a separate history API, we show a tip
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.history, color: Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your claimed and completed tasks will appear here in the next update.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80), // Space for FAB
              ],
            );
          }

          final taskIndex = urgentTasks.isNotEmpty ? index - 1 : index;
          return _TaskCard(
            task: filtered[taskIndex],
            isUrgent: _isUrgent(filtered[taskIndex]),
          );
        },
      ),
    );
  }
}

class _TaskMapView extends StatelessWidget {
  final List<TaskModel> tasks;

  const _TaskMapView({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final center = tasks.isNotEmpty && tasks.first.latitude != null
        ? LatLng(tasks.first.latitude!, tasks.first.longitude!)
        : const LatLng(30.3753, 69.3451);

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 6,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.disasteraid.app',
        ),
        MarkerLayer(
          markers: tasks
              .where((t) => t.latitude != null && t.longitude != null)
              .map((t) => Marker(
                    point: LatLng(t.latitude!, t.longitude!),
                    width: 40,
                    height: 40,
                    child: GestureDetector(
                      onTap: () => context.push('/volunteer/task/${t.id}'),
                      child: Icon(
                        Icons.location_on,
                        color: t.urgency == TaskUrgency.critical ? Colors.red : AppTheme.primaryColor,
                        size: 30,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _UrgentTaskCard extends StatelessWidget {
  final TaskModel task;
  const _UrgentTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
      child: Card(
        color: Colors.red.shade50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.shade200, width: 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/volunteer/task/${task.id}'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.red, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      task.urgency.value,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'PKR ${task.budgetPkr.toInt()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  task.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        task.locationText ?? 'Location set',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  final bool isUrgent;

  const _TaskCard({required this.task, this.isUrgent = false});

  Color _urgencyColor() {
    switch (task.urgency) {
      case TaskUrgency.critical:
        return AppTheme.urgencyCritical;
      case TaskUrgency.high:
        return AppTheme.urgencyHigh;
      case TaskUrgency.medium:
        return AppTheme.urgencyMedium;
      case TaskUrgency.low:
        return AppTheme.urgencyLow;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (task.id == 0) return;
          context.push('/volunteer/task/${task.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header Row ──
              Row(
                children: [
                  if (isUrgent)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.warning_amber_rounded, color: Colors.red, size: 16),
                    ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _urgencyColor().withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _urgencyColor(), width: 1),
                    ),
                    child: Text(
                      task.urgency.value,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: _urgencyColor(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (task.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        task.category!.toUpperCase(),
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    'PKR ${task.budgetPkr.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Title ──
              Text(
                task.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (task.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  task.description!,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),

              // ── Progress Mini Bar ──
              if (task.status != TaskStatus.open)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: _getStatusProgress(task.status),
                          minHeight: 4,
                          backgroundColor: Colors.grey.shade100,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${task.status.value}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),

              // ── Footer ──
              Row(
                children: [
                  Icon(Icons.location_on,
                      size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      task.locationText ?? 'Location set',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.people, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    '${task.familySize}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.visibility, size: 14, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    '${task.viewCount}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _getStatusProgress(TaskStatus status) {
    switch (status) {
      case TaskStatus.claimed: return 0.33;
      case TaskStatus.inProgress: return 0.66;
      case TaskStatus.submitted: return 1.0;
      case TaskStatus.coordinatorVerified: return 1.0;
      case TaskStatus.paid: return 1.0;
      default: return 0.0;
    }
  }
}

// ── Goods pickup tab ──────────────────────────────────────────────────────────

class _GoodsPickupTab extends ConsumerWidget {
  const _GoodsPickupTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(goodsPickupTasksProvider);
    return async.when(
      loading: () => const ShimmerList(count: 4, itemHeight: 100),
      error: (e, _) => ErrorView(
        message: 'Could not load goods pickup tasks.',
        onRetry: () => ref.invalidate(goodsPickupTasksProvider),
      ),
      data: (tasks) {
        final pending =
            tasks.where((t) => t.isPending || t.isAssigned).toList();
        if (pending.isEmpty) {
          return const EmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No pickup tasks',
            subtitle: 'Goods pickup tasks will appear here once donors submit donations.',
          );
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(goodsPickupTasksProvider),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: pending.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _PickupTaskCard(donation: pending[i]),
          ),
        );
      },
    );
  }
}

class _PickupTaskCard extends StatelessWidget {
  final GoodsDonation donation;
  const _PickupTaskCard({required this.donation});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final date = DateTime.tryParse(donation.submittedAt);
    final dateLabel = date != null
        ? DateFormat('MMM d').format(date.toLocal())
        : '';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            context.push('/volunteer/goods-task/${donation.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_categoryIcon(donation.category),
                    color: Colors.teal, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            donation.itemName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusBadge(status: donation.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_qtyLabel(donation.quantity)} ${donation.unit}  ·  ${donation.donorName}',
                      style: TextStyle(
                          fontSize: 12, color: cs.onSurfaceVariant),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 12, color: cs.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            donation.pickupAddress,
                            style: TextStyle(
                                fontSize: 11, color: cs.onSurfaceVariant),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          dateLabel,
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  String _qtyLabel(double qty) =>
      qty == qty.toInt() ? qty.toInt().toString() : qty.toString();

  IconData _categoryIcon(String cat) {
    switch (cat.toUpperCase()) {
      case 'MEDICINES':
        return Icons.medical_services_outlined;
      case 'CLOTHES':
        return Icons.checkroom_outlined;
      case 'FOOD':
        return Icons.rice_bowl_outlined;
      case 'SHELTER':
        return Icons.home_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }

  (Color, Color) _colors(String s) {
    switch (s.toUpperCase()) {
      case 'PENDING':
        return (Colors.orange.withValues(alpha: 0.15),
            Colors.orange.shade700);
      case 'ASSIGNED':
        return (Colors.blue.withValues(alpha: 0.12), Colors.blue.shade700);
      default:
        return (Colors.grey.withValues(alpha: 0.12), Colors.grey.shade700);
    }
  }
}
