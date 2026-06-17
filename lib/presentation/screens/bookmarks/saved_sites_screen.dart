import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/providers/profile_provider.dart';

class SavedSitesScreen extends StatefulWidget {
  const SavedSitesScreen({super.key});

  @override
  State<SavedSitesScreen> createState() => _SavedSitesScreenState();
}

class _SavedSitesScreenState extends State<SavedSitesScreen> {
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().fetchBookmarks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final profileProvider = context.watch<ProfileProvider>();
    final bookmarks = profileProvider.bookmarks;
    
    // Filter by category if not 'All'
    final filteredBookmarks = _selectedCategory == 'All'
        ? bookmarks
        : bookmarks.where((s) => s.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // --- Header Section ---
          Stack(
            children: [
              Container(
                height: size.height * 0.15,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF5D1700),
                      Color(0xFF9E3D1A),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                        hoverColor: Colors.white.withValues(alpha: 0.1),
                        splashColor: Colors.white.withValues(alpha: 0.2),
                      ),
                      const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Saved Sites',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${profileProvider.bookmarksCount} bookmarked heritage sites',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // --- Categories ---
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildCategoryChip(context, 'All', isSelected: _selectedCategory == 'All'),
                _buildCategoryChip(context, 'Temples', isSelected: _selectedCategory == 'Temples'),
                _buildCategoryChip(context, 'Stupas', isSelected: _selectedCategory == 'Stupas'),
                _buildCategoryChip(context, 'Palaces', isSelected: _selectedCategory == 'Palaces'),
              ],
            ),
          ),

          // --- Results List ---
          Expanded(
            child: profileProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredBookmarks.isEmpty
                    ? const Center(child: Text('No bookmarks found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: filteredBookmarks.length,
                        itemBuilder: (context, index) {
                          final site = filteredBookmarks[index];
                          return _SavedSiteCard(
                            name: site.name,
                            location: site.location,
                            type: site.category,
                            icon: _getIconForCategory(site.category),
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                AppStrings.heritageDetailsPath,
                                arguments: site,
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 4),
    );
  }

  IconData _getIconForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'temple':
        return Icons.temple_hindu;
      case 'stupa':
        return Icons.temple_buddhist;
      case 'palace':
        return Icons.castle;
      default:
        return Icons.account_balance;
    }
  }

  Widget _buildCategoryChip(BuildContext context, String label, {bool isSelected = false}) {
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = label),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFC89932) : (Theme.of(context).brightness == Brightness.light ? const Color(0xFF3A0A00) : AppColors.darkBgSurface),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: isSelected ? const Color(0xFFC89932) : (Theme.of(context).brightness == Brightness.light ? const Color(0xFF3A0A00) : AppColors.darkBorder)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _SavedSiteCard extends StatelessWidget {
  final String name;
  final String location;
  final String type;
  final IconData icon;
  final VoidCallback onTap;

  const _SavedSiteCard({
    required this.name,
    required this.location,
    required this.type,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF7EED3) : AppColors.darkBorder),
        ),
        child: Row(
          children: [
            // Left Image/Icon Placeholder
            Container(
              width: 100,
              height: 100,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF5D1700),
                    Color(0xFF9E3D1A),
                  ],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
              child: Center(
                child: Icon(icon, color: Colors.white38, size: 40),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        const Icon(Icons.bookmark, color: Color(0xFFC89932), size: 24),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Color(0xFF8C7162)),
                        const SizedBox(width: 4),
                        Text(
                          location,
                          style: const TextStyle(color: Color(0xFF8C7162), fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC89932),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        type,
                        style: const TextStyle(
                          color: Color(0xFF331609),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}







