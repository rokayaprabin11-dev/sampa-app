import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/providers/heritage_provider.dart';
import 'package:sampada/presentation/widgets/heritage_widgets.dart';

class HeritageSearchScreen extends StatefulWidget {
  const HeritageSearchScreen({super.key});

  @override
  State<HeritageSearchScreen> createState() => _HeritageSearchScreenState();
}

class _HeritageSearchScreenState extends State<HeritageSearchScreen> {
  late final TextEditingController _searchController;

  final List<String> _categories = ['All', 'Temples', 'Durbar Sq.', 'Stupas', 'Monasteries'];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<HeritageProvider>(context, listen: false);
    _searchController = TextEditingController(text: provider.currentQuery);
    
    // Initial fetch if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (provider.sites.isEmpty) {
        provider.fetchSites();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  Consumer<HeritageProvider>(
                    builder: (context, provider, child) {
                      return Text(
                        '${provider.sites.length} results found',
                        style: TextStyle(
                          color: AppColors.textTertiary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Consumer<HeritageProvider>(
                      builder: (context, provider, child) {
                        if (provider.isLoading && provider.sites.isEmpty) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final sites = provider.sites;
                        
                        if (sites.isEmpty && !provider.isLoading) {
                          return const Center(
                            child: Text(
                              'No heritage sites found matching your search.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF8C7162)),
                            ),
                          );
                        }

                        return GridView.builder(
                          padding: const EdgeInsets.only(bottom: 20),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                          ),
                          itemCount: sites.length,
                          itemBuilder: (context, index) {
                            final site = sites[index];
                            return HeritageGridCard(
                              name: site.name,
                              location: site.district,
                              distance: '1.2km', // Mock distance
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
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 0),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 20,
        right: 20,
        bottom: 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF5D1700), Color(0xFF9E3D1A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Explore Heritage',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Text(
            'Search across 77 districts of Nepal',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColors.goldMain, width: 2),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                Provider.of<HeritageProvider>(context, listen: false).search(query: value);
              },
              decoration: InputDecoration(
                hintText: 'Search heritage sites...',
                border: InputBorder.none,
                icon: const Icon(Icons.search, color: Color(0xFF8C7162)),
                suffixIcon: GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    Provider.of<HeritageProvider>(context, listen: false).search(query: '');
                  },
                  child: const Icon(Icons.close, color: Color(0xFF8C7162)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Consumer<HeritageProvider>(
              builder: (context, provider, child) {
                return Row(
                  children: _categories.map((category) {
                    return CategoryChip(
                      label: category,
                      isSelected: provider.currentCategory == category,
                      isDesignStyle: true,
                      onTap: () {
                        provider.search(category: category);
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}







