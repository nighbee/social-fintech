import 'package:app/src/core/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class AlliesPage extends StatefulWidget {
  const AlliesPage({super.key});

  @override
  State<AlliesPage> createState() => _AlliesPageState();
}

class _AlliesPageState extends State<AlliesPage> {
  String _selectedSort = 'Default: Earliest';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.blackBackground,
      appBar: AppBar(
        backgroundColor: AppColors.blackBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Allies',
          style: TextStyles.titleMain.copyWith(color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF333333),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.people, color: Colors.white, size: 16),
                const Gap(6),
                Text(
                  '5',
                  style: TextStyles.bodyMain.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              style: TextStyles.bodyMain.copyWith(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyles.bodyMain.copyWith(
                  color: const Color(0xFF6D6D6D),
                ),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF6D6D6D)),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Sort dropdown
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Sort by',
                  style: TextStyles.bodyMain.copyWith(
                    color: const Color(0xFF6D6D6D),
                  ),
                ),
                const Gap(8),
                DropdownButton<String>(
                  value: _selectedSort,
                  dropdownColor: const Color(0xFF1A1A1A),
                  underline: const SizedBox(),
                  icon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF6D6D6D),
                  ),
                  style: TextStyles.bodyMain.copyWith(
                    color: const Color(0xFF6D6D6D),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Default: Earliest',
                      child: Text('Default: Earliest'),
                    ),
                    DropdownMenuItem(value: 'Latest', child: Text('Latest')),
                    DropdownMenuItem(
                      value: 'Name A-Z',
                      child: Text('Name A-Z'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedSort = value;
                      });
                    }
                  },
                ),
              ],
            ),
          ),

          const Gap(16),

          // Allies list
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _mockAllies.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: Color(0xFF333333), height: 1),
              itemBuilder: (context, index) {
                final ally = _mockAllies[index];
                return _AllyCard(ally: ally);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AllyCard extends StatelessWidget {
  final AllyModel ally;

  const _AllyCard({required this.ally});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          // Profile image
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: NetworkImage(ally.imageUrl),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const Gap(12),
          // Name and info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ally.name,
                  style: TextStyles.bodyMain.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Gap(4),
                Row(
                  children: [
                    Text(
                      ally.role,
                      style: TextStyles.bodySecondary.copyWith(
                        color: _getRoleColor(ally.role),
                      ),
                    ),
                    Text(
                      ' · ',
                      style: TextStyles.bodySecondary.copyWith(
                        color: const Color(0xFF6D6D6D),
                      ),
                    ),
                    Text(
                      ally.status,
                      style: TextStyles.bodySecondary.copyWith(
                        color: _getStatusColor(ally.status),
                      ),
                    ),
                    const Gap(4),
                    Icon(
                      _getStatusIcon(ally.status),
                      size: 14,
                      color: _getStatusColor(ally.status),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    // Parse role color from text (e.g., "Lapir Lazuli" might have different colors)
    return const Color(0xFF5E8DFF);
  }

  Color _getStatusColor(String status) {
    if (status.contains('Acceptance')) return const Color(0xFF5E8DFF);
    if (status.contains('Clarity')) return const Color(0xFF5E8DFF);
    if (status.contains('Fortitude')) return const Color(0xFFFFA500);
    if (status.contains('Integrity')) return const Color(0xFF00FF00);
    return const Color(0xFF6D6D6D);
  }

  IconData _getStatusIcon(String status) {
    if (status.contains('A')) return Icons.circle;
    if (status.contains('S')) return Icons.star;
    return Icons.circle;
  }
}

// Mock data model
class AllyModel {
  final String name;
  final String imageUrl;
  final String role;
  final String status;

  AllyModel({
    required this.name,
    required this.imageUrl,
    required this.role,
    required this.status,
  });
}

// Mock data
final List<AllyModel> _mockAllies = [
  AllyModel(
    name: 'Zhanar Yesmoldayeva',
    imageUrl: 'https://i.pravatar.cc/150?img=1',
    role: 'Lapir Lazuli',
    status: 'Acceptance : A',
  ),
  AllyModel(
    name: 'Kundyz Akzhan',
    imageUrl: 'https://i.pravatar.cc/150?img=2',
    role: 'Moonstone',
    status: 'Clarity : A',
  ),
  AllyModel(
    name: 'Merey Zhumagul',
    imageUrl: 'https://i.pravatar.cc/150?img=3',
    role: 'Moonstone',
    status: 'Clarity : A',
  ),
  AllyModel(
    name: 'Malika Ahmetovna',
    imageUrl: 'https://i.pravatar.cc/150?img=4',
    role: 'Ammolite',
    status: 'Fortitude : S',
  ),
  AllyModel(
    name: 'Kanat Yerzhan',
    imageUrl: 'https://i.pravatar.cc/150?img=5',
    role: 'Jade',
    status: 'Integrity : S',
  ),
];
