import 'package:flutter/material.dart';
import 'package:sampada/generated/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_dimensions.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import 'package:sampada/providers/profile_provider.dart';
import 'package:sampada/presentation/widgets/downloads_widgets.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().fetchDownloads();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = context.watch<ProfileProvider>();
    final downloads = profileProvider.downloads;

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
                  AppColors.kColorDeep,
                  AppColors.kColorPrimaryMid,
                  AppColors.kColorPrimary,
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
                        const Text(
                          'Downloads',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 52, top: 2),
                      child: Text(
                        'Access heritage content offline',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- Scrollable Content Section ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StorageStatusCard(
                    usedMB: profileProvider.totalDownloadSizeMB,
                    totalGB: 2,
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    'Downloaded Content',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.light ? AppColors.kColorTextSecondary : AppColors.goldMain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  profileProvider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : downloads.isEmpty
                          ? Center(child: Text(AppLocalizations.of(context)!.emptyDownloads))
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: downloads.length,
                              itemBuilder: (context, index) {
                                final download = downloads[index];
                                return DownloadItemCard(
                                  title: download['site_name'] ?? 'Unknown Site',
                                  sitesCount: 1, // Individual site download
                                  size: '${(download['download_size'] ?? 0).toStringAsFixed(1)} MB',
                                  icon: _getIconForCategory(download['site_category'] ?? ''),
                                  isReady: download['status'] == 'completed',
                                );
                              },
                            ),
                  
                  const SizedBox(height: 24),
                  const TipCard(
                    text: 'Downloaded content works without internet.',
                  ),
                  const SizedBox(height: 40),
                ],
              ),
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
}







