import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sampada/core/constants/app_colors.dart';
import 'package:sampada/core/constants/app_strings.dart';
import 'package:sampada/presentation/navigation/app_bottom_nav.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authProvider = context.watch<AuthProvider>();

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
                        Stack(
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
                              child: Center(
                                child: Text(
                                  authProvider.user?.displayName?.substring(0, 1).toUpperCase() ?? 'P',
                                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
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
                  ),
                  const SizedBox(height: 24),
                  _buildPrimaryButton(
                    authProvider.isLoading ? 'Processing...' : 'Save Profile Changes',
                    authProvider.isLoading
                        ? () {}
                        : () => _showPasswordConfirmationDialog(
                            onConfirm: (password) async {
                              final authProvider = context.read<AuthProvider>();
                              try {
                                await authProvider.updateProfile(
                                  displayName: _usernameController.text.trim(),
                                  email: _emailController.text.trim(),
                                  password: password,
                                );
                                if (context.mounted) {
                                  // Explicitly reset fields and rebuild with current user data
                                  setState(() {
                                    final user = authProvider.user;
                                    if (user != null) {
                                      _usernameController.text = user.displayName ?? '';
                                      _emailController.text = user.email ?? '';
                                    }
                                  });

                                  if (authProvider.error != null && !authProvider.error!.contains('verification email')) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(authProvider.error!)),
                                    );
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(authProvider.error ?? 'Profile updated successfully!')),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  // Explicitly reset fields and rebuild on error
                                  setState(() {
                                    final user = authProvider.user;
                                    if (user != null) {
                                      _usernameController.text = user.displayName ?? '';
                                      _emailController.text = user.email ?? '';
                                    }
                                  });

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(authProvider.error ?? 'Wrong password. Please try again.')),
                                  );
                                }
                              }
                            },
                          ),
                  ),

                  const SizedBox(height: 40),

                  // Change Password Section
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
                    // Password Strength
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
                  // Tip
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
                      final passwordController = TextEditingController();
                      bool obscure = true;
                      final password = await showDialog<String>(
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
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, passwordController.text),
                                child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      );
                      passwordController.dispose();
                      if (password != null && password.isNotEmpty && context.mounted) {
                        final authProvider = context.read<AuthProvider>();
                        await authProvider.deleteAccount(password);
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
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFF7EED3)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: isPassword ? obscureText : false,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15),
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







