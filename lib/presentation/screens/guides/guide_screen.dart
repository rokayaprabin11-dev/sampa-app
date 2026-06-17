import 'package:flutter/material.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header Section ---
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: size.height * 0.25, // Optimized mobile height
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
                            const SizedBox(width: 40), // Placeholder to keep title centered
                            const Text(
                              'SAMPADA • सम्पदा',
                              style: TextStyle(
                                color: Color(0xFFDCA73A),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                fontSize: 14,
                              ),
                            ),
                            _buildHeaderButton(Icons.tune),
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
                          width: 40,
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDCA73A),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Search Bar
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
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, color: isDark ? AppColors.goldMain : const Color(0xFF7B1E00), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
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

            const SizedBox(height: 52),

            // --- Stats Row ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  _buildStatCard(context, '248', 'Guides Available'),
                  const SizedBox(width: 12),
                  _buildStatCard(context, '77', 'Districts Covered'),
                  const SizedBox(width: 12),
                  _buildStatCard(context, '4.8', 'Avg Rating'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- Categories ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildCategoryChip(context, 'Nearby', isSelected: true),
                  _buildCategoryChip(context, 'Top Rated'),
                  _buildCategoryChip(context, 'Temple Expert'),
                  _buildCategoryChip(context, 'Trekking'),
                  _buildCategoryChip(context, 'Culture'),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- Featured Guides Section ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'FEATURED GUIDES',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF4A342B) : AppColors.goldMain,
                      letterSpacing: 0.5,
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: const Row(
                      children: [
                        Text(
                          'See all',
                          style: TextStyle(color: Color(0xFFD4520A), fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Icon(Icons.arrow_forward, size: 14, color: Color(0xFFD4520A)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            _buildFeaturedGuideCard(context),

            const SizedBox(height: 24),

            // --- Nearby Guides Section ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                'NEARBY GUIDES',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF4A342B) : AppColors.goldMain,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const SizedBox(height: 16),
            _buildNearbyGuideCard(context),

            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }

  Widget _buildHeaderButton(IconData icon) {
    return IconButton(
      onPressed: () {},
      icon: Icon(icon, color: Colors.white, size: 20),
      hoverColor: Colors.white.withValues(alpha: 0.1),
      splashColor: Colors.white.withValues(alpha: 0.2),
    );
  }

  Widget _buildStatCard(BuildContext context, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF7EED3) : AppColors.darkBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF7B1E00) : AppColors.goldMain,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF8C7162) : AppColors.darkTextSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(BuildContext context, String label, {bool isSelected = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: isSelected ? (Theme.of(context).brightness == Brightness.light ? const Color(0xFF3A241C) : AppColors.goldMain) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: isSelected ? (Theme.of(context).brightness == Brightness.light ? const Color(0xFF3A241C) : AppColors.goldMain) : (Theme.of(context).brightness == Brightness.light ? const Color(0xFFF7EED3) : AppColors.darkBorder)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? (Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black) : Theme.of(context).colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildFeaturedGuideCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF7EED3) : AppColors.darkBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    Container(
                      width: 65,
                      height: 65,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF3A241C) : AppColors.darkBgCard,
                        shape: BoxShape.circle,
                        border: Theme.of(context).brightness == Brightness.dark ? Border.all(color: AppColors.darkBorder) : null,
                      ),
                      child: const Center(
                        child: Text(
                          'RB',
                          style: TextStyle(color: Color(0xFFDCA73A), fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ramesh Bajracharya',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF8C7162) : AppColors.darkTextTertiary),
                          const SizedBox(width: 4),
                          Text('0.4 km - Kathmandu', style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF6B5041) : AppColors.darkTextSecondary, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _buildSmallTag(context, 'Temples'),
                          _buildSmallTag(context, 'Stupas'),
                          _buildSmallTag(context, 'Newari Culture'),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStatusBadge('TOP GUIDE', const Color(0xFFDCA73A), Colors.white),
                    const SizedBox(height: 6),
                    _buildStatusBadge('✓ VERIFIED', const Color(0xFFF7EED3), const Color(0xFFDCA73A)),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Divider(height: 1, color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF7EED3) : AppColors.darkBorder),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFDCA73A), size: 14),
                        const SizedBox(width: 4),
                        Text('4.9', style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                        const SizedBox(width: 4),
                        Text('(312 reviews)', style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF8C7162) : AppColors.darkTextTertiary, fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Available 9 AM – 6 PM', style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF6B5041) : AppColors.darkTextSecondary, fontSize: 11)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('NPR 2,500', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF7B1E00) : AppColors.goldMain)),
                    Text('per half day', style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF8C7162) : AppColors.darkTextSecondary, fontSize: 11)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {},
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF7EED3) : AppColors.darkBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Message', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).brightness == Brightness.light ? const Color(0xFF3A241C) : AppColors.goldMain,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text('Hire Now', style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? Colors.white : Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearbyGuideCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF7EED3) : AppColors.darkBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF3A241C) : AppColors.darkBgCard,
                      shape: BoxShape.circle,
                      border: Theme.of(context).brightness == Brightness.dark ? Border.all(color: AppColors.darkBorder) : null,
                    ),
                    child: const Center(
                      child: Text(
                        'SP',
                        style: TextStyle(color: Color(0xFFDCA73A), fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sita Prajapati', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF8C7162) : AppColors.darkTextTertiary),
                        const SizedBox(width: 4),
                        Text('1.2 km - Lalitpur', style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF6B5041) : AppColors.darkTextSecondary, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFDCA73A), size: 14),
                        const SizedBox(width: 4),
                        Text('4.7', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Theme.of(context).colorScheme.onSurface)),
                        const SizedBox(width: 4),
                        Text('(189)', style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF8C7162) : AppColors.darkTextTertiary, fontSize: 11)),
                        const Spacer(),
                        Text('NPR 1,800', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF7B1E00) : AppColors.goldMain)),
                        Text('/ half', style: TextStyle(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF8C7162) : AppColors.darkTextSecondary, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF7EED3) : AppColors.darkBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text('Request Guide', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: 9, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSmallTag(BuildContext context, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light ? const Color(0xFFF5EFEC) : AppColors.darkBgCard,
        borderRadius: BorderRadius.circular(6),
        border: Theme.of(context).brightness == Brightness.dark ? Border.all(color: AppColors.darkBorder) : null,
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF6B5041) : AppColors.darkTextSecondary)),
    );
  }
}







