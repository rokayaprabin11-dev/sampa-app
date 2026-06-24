import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sampada/injection.dart' as di;
import 'package:sampada/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'dart:io';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  double _passwordStrength = 0.0;
  String _strengthText = 'Password strength: Weak — use more characters';
  Color _strengthColor = Colors.red;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    if (user != null) {
      _usernameController.text = user.displayName ?? '';
      _emailController.text = user.email ?? '';
    }
    _newPasswordController.addListener(_updatePasswordStrength);
  }

  void _updatePasswordStrength() {
    final password = _newPasswordController.text;
    if (password.isEmpty) {
      setState(() {
        _passwordStrength = 0.0;
        _strengthText = 'Password strength: Weak — use more characters';
        _strengthColor = Colors.red;
      });
      return;
    }

    double strength = 0;
    if (password.length >= 8) strength += 0.25;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.25;
    if (password.contains(RegExp(r'[a-z]'))) strength += 0.1;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.2;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.2;

    setState(() {
      _passwordStrength = strength;
      if (strength <= 0.3) {
        _strengthText = 'Password strength: Weak — use more characters';
        _strengthColor = Colors.red;
      } else if (strength <= 0.7) {
        _strengthText = 'Password strength: Medium — use symbols for stronger security';
        _strengthColor = Colors.orange;
      } else {
        _strengthText = 'Password strength: Strong';
        _strengthColor = Colors.green;
      }
    });
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_updatePasswordStrength);
    _usernameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _uploadingPhoto = false;

  Future<void> _pickAndUploadImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 800);
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final apiClient = di.sl<ApiClient>();

      // Get Cloudinary signature
      final sig = await apiClient.post(
        '/heritage/upload-signature/',
        data: {'folder': 'sampada/avatars'},
      );

      final file = File(picked.path);
      final bytes = await file.readAsBytes();

      final formData = <String, dynamic>{
        'file': 'data:image/jpeg;base64,${_base64Encode(bytes)}',
        'api_key': sig['api_key'],
        'timestamp': sig['timestamp'].toString(),
        'signature': sig['signature'],
        'folder': sig['folder'],
      };

      final uploadRes = await apiClient.dio.post(
        'https://api.cloudinary.com/v1_1/${sig['cloud_name']}/image/upload',
        data: formData,
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );

      final url = uploadRes.data['secure_url'] as String;
      if (!mounted) return;
      await context.read<AuthProvider>().updatePhotoUrl(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  String _base64Encode(List<int> bytes) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final result = StringBuffer();
    for (var i = 0; i < bytes.length; i += 3) {
      final b0 = bytes[i];
      final b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
      final b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
      result.write(chars[(b0 >> 2) & 0x3F]);
      result.write(chars[((b0 << 4) | (b1 >> 4)) & 0x3F]);
      result.write(i + 1 < bytes.length ? chars[((b1 << 2) | (b2 >> 6)) & 0x3F] : '=');
      result.write(i + 2 < bytes.length ? chars[b2 & 0x3F] : '=');
    }
    return result.toString();
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAndUploadImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();
    final isGoogle = authProvider.isGoogleUser;

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
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Settings',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Manage your profile & security',
                                style: TextStyle(
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

          // --- Scrollable Content ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Profile Avatar Section
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _showImageSourceSheet,
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7B1E00),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFFF7EED3), width: 2),
                                ),
                                child: ClipOval(
                                  child: _uploadingPhoto
                                      ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                      : authProvider.user?.photoURL != null
                                          ? Image.network(authProvider.user!.photoURL!, fit: BoxFit.cover)
                                          : Center(
                                              child: Text(
                                                authProvider.user?.displayName?.substring(0, 1).toUpperCase() ?? 'P',
                                                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFC89932),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          authProvider.user?.displayName ?? 'User',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          authProvider.user?.email ?? 'user@example.com',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Profile Information Section
                  _buildSectionHeader('Profile Information'),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Username',
                    controller: _usernameController,
                    hint: 'Enter username',
                    icon: Icons.edit_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'Email Address',
                    controller: _emailController,
                    hint: 'Enter email address',
                    icon: Icons.edit_outlined,
                    readOnly: isGoogle,
                  ),
                  if (isGoogle) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Email is managed by Google and cannot be changed here.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _buildPrimaryButton(
                    authProvider.isLoading ? 'Processing...' : 'Save Profile Changes',
                    authProvider.isLoading
                        ? () {}
                        : () async {
                            Future<void> doUpdate(String? password) async {
                              final ap = context.read<AuthProvider>();
                              try {
                                await ap.updateProfile(
                                  displayName: _usernameController.text.trim(),
                                  email: isGoogle ? null : _emailController.text.trim(),
                                  password: password,
                                );
                                if (context.mounted) {
                                  setState(() {
                                    final user = ap.user;
                                    if (user != null) {
                                      _usernameController.text = user.displayName ?? '';
                                      _emailController.text = user.email ?? '';
                                    }
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(ap.error ?? 'Profile updated successfully!')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(ap.error ?? 'Update failed.')),
                                  );
                                }
                              }
                            }

                            if (isGoogle) {
                              await doUpdate(null);
                            } else {
                              _showPasswordConfirmationDialog(onConfirm: (p) => doUpdate(p));
                            }
                          },
                  ),

                  const SizedBox(height: 40),

                  if (!isGoogle) ...[
                    const SizedBox(height: 40),
                    _buildSectionHeader('Change Password'),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Current Password',
                      controller: _currentPasswordController,
                      hint: 'Enter current password',
                      isPassword: true,
                      obscureText: !_showCurrentPassword,
                      onToggleVisibility: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
                      suffix: TextButton(
                        onPressed: () async {
                          final email = _emailController.text.trim();
                          if (email.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter your email to reset password')),
                            );
                            return;
                          }
                          await authProvider.sendPasswordResetEmail(email);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Password reset email sent!')),
                            );
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: Color(0xFFC89932),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildTextField(
                      label: 'New Password',
                      controller: _newPasswordController,
                      hint: 'Minimum 8 characters',
                      isPassword: true,
                      obscureText: !_showNewPassword,
                      onToggleVisibility: () => setState(() => _showNewPassword = !_showNewPassword),
                    ),
                    if (_newPasswordController.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _passwordStrength,
                              backgroundColor: Colors.grey.withValues(alpha: 0.1),
                              color: _strengthColor,
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _strengthText,
                            style: const TextStyle(fontSize: 10, color: Color(0xFF8C7162)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: 'Confirm New Password',
                      controller: _confirmPasswordController,
                      hint: 'Re-enter new password',
                      isPassword: true,
                      obscureText: !_showConfirmPassword,
                      onToggleVisibility: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7EED3).withValues(alpha: isDark ? 0.1 : 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF7EED3).withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lightbulb_outline, color: Color(0xFFC89932), size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Use 8+ characters with a mix of letters, numbers & symbols.',
                              style: TextStyle(fontSize: 11, color: Color(0xFF8C7162)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildPrimaryButton('Update Password', () {}),
                  ],

                  const SizedBox(height: 40),

                  // Bottom Actions
                  OutlinedButton(
                    onPressed: authProvider.isLoading ? null : () async {
                      await authProvider.logout();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppStrings.onboardingPath,
                          (route) => false,
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF7B1E00),
                      side: const BorderSide(color: Color(0xFFF7EED3)),
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                    child: authProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF7B1E00)),
                          )
                        : const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () async {
                      final authProvider = context.read<AuthProvider>();
                      final isGoogle = authProvider.isGoogleUser;
                      final passwordController = TextEditingController();
                      bool obscure = true;

                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => StatefulBuilder(
                          builder: (ctx, setState) => AlertDialog(
                            title: const Text('Delete Account'),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'This will permanently delete your account and all your data including bookmarks, visits, and bookings. This action cannot be undone.',
                                  style: TextStyle(fontSize: 13),
                                ),
                                if (!isGoogle) ...[
                                  const SizedBox(height: 16),
                                  TextField(
                                    controller: passwordController,
                                    obscureText: obscure,
                                    decoration: InputDecoration(
                                      labelText: 'Enter your password to confirm',
                                      border: const OutlineInputBorder(),
                                      suffixIcon: IconButton(
                                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
                                        onPressed: () => setState(() => obscure = !obscure),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  const SizedBox(height: 12),
                                  const Text(
                                    'You will be asked to re-sign in with Google to confirm.',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      );
                      final password = passwordController.text;
                      passwordController.dispose();

                      if (confirmed == true && context.mounted) {
                        if (!isGoogle && password.isEmpty) return;
                        await authProvider.deleteAccount(password: isGoogle ? null : password);
                        if (context.mounted && authProvider.error == null) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            AppStrings.onboardingPath,
                            (route) => false,
                          );
                        } else if (context.mounted && authProvider.error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(authProvider.error!), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFEBEE),
                      foregroundColor: Colors.red,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                      elevation: 0,
                    ),
                    child: const Text('Delete Account', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.light ? const Color(0xFF8C7162) : const Color(0xFFC89932),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(child: Divider(color: Color(0xFFF7EED3))),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    bool isPassword = false,
    bool obscureText = false,
    bool readOnly = false,
    VoidCallback? onToggleVisibility,
    IconData? icon,
    Widget? suffix,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            if (suffix != null) suffix,
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: readOnly
                ? const Color(0xFFF5F5F5)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF7EED3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: isPassword ? obscureText : false,
                  readOnly: readOnly,
                  style: TextStyle(
                    color: readOnly ? Colors.grey : Theme.of(context).colorScheme.onSurface,
                    fontSize: 15,
                  ),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                    border: InputBorder.none,
                  ),
                ),
              ),
              if (isPassword)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: const Color(0xFFDCA73A),
                    size: 18,
                  ),
                  onPressed: onToggleVisibility,
                )
              else if (icon != null)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7EED3).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(icon, color: const Color(0xFF7B1E00), size: 16),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF7B1E00),
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 2,
      ),
      child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  void _showPasswordConfirmationDialog({required Function(String) onConfirm}) {
    final passwordController = TextEditingController();
    bool obscurePassword = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Confirm Changes'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please enter your current password to save changes.'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final password = passwordController.text.trim();
                if (password.isNotEmpty) {
                  Navigator.pop(context);
                  onConfirm(password);
                }
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      ),
    );
  }
}







