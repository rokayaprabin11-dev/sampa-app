import 'package:flutter/material.dart';
import 'package:sampada/presentation/widgets/common/app_network_image.dart';
import 'package:provider/provider.dart';
import 'package:sampada/providers/profile_provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';

class VisitHistoryScreen extends StatefulWidget {
  const VisitHistoryScreen({super.key});

  @override
  State<VisitHistoryScreen> createState() => _VisitHistoryScreenState();
}

class _VisitHistoryScreenState extends State<VisitHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().fetchVisitHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // --- Header Section ---
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF5C1A0A),
                  Color(0xFFA83210),
                  Color(0xFFC8501A),
                ],
                stops: [0.0, 0.6, 1.0],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(AppDimensions.kRadiusXxl),
                bottomRight: Radius.circular(AppDimensions.kRadiusXxl),
              ),
            ),
            // Sizes to its content instead of a fixed screen-height fraction.
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Visit History',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Your journey through heritage',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.white),
                      onPressed: () => _showDeleteConfirmation(context),
                      tooltip: 'Clear History',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- Results List ---
          Expanded(
            child: profileProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : profileProvider.visitHistory.isEmpty
                    ? const Center(child: Text('No visit history found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: profileProvider.visitHistory.length,
                        itemBuilder: (context, index) {
                          final site = profileProvider.visitHistory[index];
                          return _VisitHistoryCard(
                            name: site.name,
                            location: site.location,
                            category: site.category,
                            imageUrl: site.imageUrl,
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

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to delete all visit history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<ProfileProvider>().clearVisitHistory();
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _VisitHistoryCard extends StatelessWidget {
  final String name;
  final String location;
  final String category;
  final String? imageUrl;
  final VoidCallback onTap;

  const _VisitHistoryCard({
    required this.name,
    required this.location,
    required this.category,
    this.imageUrl,
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
          borderRadius: BorderRadius.circular(AppDimensions.kRadiusXxl),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.light
                ? const Color(0xFFF7EED3)
                : AppColors.darkBorder,
          ),
        ),
        child: Row(
          children: [
            // Left Image/Icon Placeholder
            Container(
              width: 80,
              height: 80,
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
                  topLeft: Radius.circular(AppDimensions.kRadiusXxl),
                  bottomLeft: Radius.circular(AppDimensions.kRadiusXxl),
                ),
              ),
              child: Center(
                child: imageUrl != null
                    ? AppNetworkImage(url: imageUrl, fit: BoxFit.cover)
                    : const Icon(Icons.history, color: Colors.white38, size: 30),
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
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
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFC89932).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppDimensions.kRadiusSm),
                ),
                child: Text(
                  category,
                  style: const TextStyle(
                    color: Color(0xFFC89932),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}







