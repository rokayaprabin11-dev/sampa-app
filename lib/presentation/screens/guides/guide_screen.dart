import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/providers/guide_provider.dart';
import 'package:sampada/presentation/screens/guides/guide_detail_screen.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  String _selectedFilter = 'All';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GuideProvider>().fetchGuides();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> guides) {
    final q = _searchController.text.toLowerCase();
    return guides.where((g) {
      final user = g['user'] as Map<String, dynamic>? ?? {};
      final name = (user['full_name'] ?? user['username'] ?? '').toString().toLowerCase();
      final specialties = ((g['specialties'] as List?) ?? []).join(' ').toLowerCase();
      final languages = ((g['languages'] as List?) ?? []).join(' ').toLowerCase();
      final matchesSearch = q.isEmpty || name.contains(q) || specialties.contains(q) || languages.contains(q);
      if (_selectedFilter == 'All') return matchesSearch;
      final filterLower = _selectedFilter.toLowerCase();
      return matchesSearch && (specialties.contains(filterLower) || languages.contains(filterLower));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Consumer<GuideProvider>(
        builder: (context, guideProvider, _) {
          final allGuides = guideProvider.guides;
          final filtered = _applyFilter(allGuides);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: size.height * 0.25,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            isDark ? AppColors.brownDeep : const Color(0xFF5D1700),
                            isDark ? AppColors.brownDark : const Color(0xFF9E3D1A),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                    ),
                    SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const SizedBox(width: 40),
                                const Text(
                                  'SAMPADA • सम्पदा',
                                  style: TextStyle(
                                    color: Color(0xFFDCA73A),
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.2,
                                    fontSize: 14,
                                  ),
                                ),
                                if (guideProvider.isLoading)
                                  const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                else
                                  IconButton(
                                    onPressed: () => guideProvider.fetchGuides(),
                                    icon: const Icon(Icons.refresh, color: Colors.white, size: 20),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Find Your\nHeritage Guide',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 40, height: 3,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCA73A),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -28,
                      left: 24,
                      right: 24,
                      child: Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBgCard : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00), size: 24),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (_) => setState(() {}),
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                                decoration: InputDecoration(
                                  hintText: 'Search guides by name, language...',
                                  hintStyle: TextStyle(color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162), fontSize: 14),
                                  border: InputBorder.none,
                                  isDense: true,
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

              const SliverToBoxAdapter(child: SizedBox(height: 52)),

              // Stats row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Row(
                    children: [
                      _buildStatCard(context, '${allGuides.length}', 'Guides Available'),
                      const SizedBox(width: 12),
                      _buildStatCard(context, '77', 'Districts Covered'),
                      const SizedBox(width: 12),
                      _buildStatCard(
                        context,
                        allGuides.isEmpty
                            ? '–'
                            : (allGuides.map((g) {
                                  final r = g['rating_avg'];
                                  return r is num ? r.toDouble() : double.tryParse('${r ?? ''}') ?? 0.0;
                                }).reduce((a, b) => a + b) / allGuides.length).toStringAsFixed(1),
                        'Avg Rating',
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Filter chips
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: ['All', 'Temples', 'Trekking', 'Culture', 'Nepali', 'English']
                        .map((f) => _buildCategoryChip(context, f, isSelected: _selectedFilter == f))
                        .toList(),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // Error state
              if (guideProvider.error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          Expanded(child: Text('Failed to load guides. Tap refresh to retry.', style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
                        ],
                      ),
                    ),
                  ),
                ),

              // Loading skeleton
              if (guideProvider.isLoading && allGuides.isEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildGuideCardSkeleton(context),
                    childCount: 3,
                  ),
                )
              // Empty state
              else if (filtered.isEmpty && !guideProvider.isLoading)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.person_search, size: 64, color: isDark ? AppColors.darkTextTertiary : const Color(0xFFD4B8A8)),
                        const SizedBox(height: 16),
                        Text(
                          allGuides.isEmpty ? 'No guides registered yet.' : 'No guides match your search.',
                          style: TextStyle(color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162)),
                        ),
                      ],
                    ),
                  ),
                )
              // Guide cards
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _buildGuideCard(context, filtered[i]),
                    childCount: filtered.length,
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }

  Widget _buildStatCard(BuildContext context, String value, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00))),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162))),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(BuildContext context, String label, {bool isSelected = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? AppColors.goldMain : const Color(0xFF3A241C)) : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: isSelected ? (isDark ? AppColors.goldMain : const Color(0xFF3A241C)) : (isDark ? AppColors.darkBorder : const Color(0xFFF7EED3))),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? (isDark ? Colors.black : Colors.white) : Theme.of(context).colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCard(BuildContext context, Map<String, dynamic> guide) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = guide['user'] as Map<String, dynamic>? ?? {};
    final fullName = (user['full_name'] ?? user['username'] ?? 'Unknown').toString();
    final initials = fullName.split(' ').take(2).map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join();
    final rating = double.tryParse('${guide['rating_avg'] ?? ''}') ?? 0.0;
    final reviewCount = (guide['review_count'] as int?) ?? 0;
    final rate = guide['hourly_rate'];
    final specialties = ((guide['specialties'] as List?) ?? []).cast<String>();
    final languages = ((guide['languages'] as List?) ?? []).cast<String>();
    final isVerified = (guide['is_verified'] as bool?) ?? false;
    final photoUrl = guide['photo_url'] as String?;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GuideDetailScreen(guide: guide)),
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3), width: 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: isDark ? AppColors.darkBgCard : const Color(0xFF3A241C),
                        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                        child: (photoUrl == null || photoUrl.isEmpty)
                            ? Text(initials, style: const TextStyle(color: Color(0xFFDCA73A), fontSize: 18, fontWeight: FontWeight.bold))
                            : null,
                      ),
                      if (isVerified)
                        Positioned(
                          bottom: 2, right: 2,
                          child: Container(
                            width: 14, height: 14,
                            decoration: BoxDecoration(color: const Color(0xFF2E7D32), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fullName, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Color(0xFFDCA73A), size: 14),
                            const SizedBox(width: 4),
                            Text(rating.toStringAsFixed(1), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
                            const SizedBox(width: 4),
                            Text('($reviewCount reviews)', style: TextStyle(color: isDark ? AppColors.darkTextTertiary : const Color(0xFF8C7162), fontSize: 11)),
                          ],
                        ),
                        if (specialties.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6, runSpacing: 4,
                            children: specialties.take(3).map((s) => _buildTag(context, s)).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isVerified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFF7EED3), borderRadius: BorderRadius.circular(4)),
                      child: const Text('✓ VERIFIED', style: TextStyle(color: Color(0xFFDCA73A), fontSize: 9, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              if (languages.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.language, size: 14, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162)),
                    const SizedBox(width: 6),
                    Text(languages.join(', '), style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B5041))),
                  ],
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Divider(height: 1, color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (rate != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NPR ${rate.toString()}',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00)),
                        ),
                        Text('per hour', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162), fontSize: 11)),
                      ],
                    )
                  else
                    Text('Rate on request', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : const Color(0xFF8C7162), fontSize: 13)),
                  ElevatedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => GuideDetailScreen(guide: guide)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.goldMain : const Color(0xFF3A241C),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: Text('View & Book', style: TextStyle(color: isDark ? Colors.black : Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideCardSkeleton(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0EDED);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? AppColors.darkBorder : const Color(0xFFF7EED3)),
      ),
      child: Row(
        children: [
          CircleAvatar(radius: 30, backgroundColor: baseColor),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 14, width: 120, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(7))),
                const SizedBox(height: 8),
                Container(height: 12, width: 80, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 8),
                Container(height: 10, width: 160, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(5))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(BuildContext context, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : const Color(0xFFF5EFEC),
        borderRadius: BorderRadius.circular(6),
        border: isDark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextSecondary : const Color(0xFF6B5041))),
    );
  }
}
