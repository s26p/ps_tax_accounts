import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState
    extends State<AccountSettingsScreen> {
  static const Color primaryRed = Color(0xFFE50914);
  static const Color darkBlack = Color(0xFF111111);
  static const Color background = Color(0xFFF6F7F9);

  final TextEditingController usernameController =
      TextEditingController();

  final TextEditingController newPasswordController =
      TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool obscureNewPassword = true;
  bool obscureConfirmPassword = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAccount();
  }

  @override
  void dispose() {
    usernameController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadAccount() async {
    final preferences =
        await SharedPreferences.getInstance();

    final username =
        preferences.getString('login_username') ?? 'admin';

    if (!mounted) return;

    usernameController.text = username;
  }

  Future<void> _saveAccount() async {
    final username =
        usernameController.text.trim();

    final newPassword =
        newPasswordController.text.trim();

    final confirmPassword =
        confirmPasswordController.text.trim();

    if (username.isEmpty) {
      _showMessage(
        'Username / Mobile number is required.',
      );
      return;
    }

    if (newPassword.isNotEmpty &&
        newPassword.length < 4) {
      _showMessage(
        'Password must contain at least 4 characters.',
      );
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage(
        'New password and confirm password do not match.',
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final preferences =
          await SharedPreferences.getInstance();

      await preferences.setString(
        'login_username',
        username,
      );

      if (newPassword.isNotEmpty) {
        await preferences.setString(
          'login_password',
          newPassword,
        );
      }

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      newPasswordController.clear();
      confirmPasswordController.clear();

      _showMessage(
        'Account settings saved successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        'Unable to save account settings.',
      );
    }
  }

  Future<void> _resetAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Reset Account',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Reset username and password to the default account?\n\n'
            'Username: admin\n'
            'Password: 123456',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('RESET'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    final preferences =
        await SharedPreferences.getInstance();

    await preferences.setString(
      'login_username',
      'admin',
    );

    await preferences.setString(
      'login_password',
      '123456',
    );

    if (!mounted) return;

    setState(() {
      usernameController.text = 'admin';
      newPasswordController.clear();
      confirmPasswordController.clear();
    });

    _showMessage(
      'Account reset successfully.',
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: primaryRed,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Account Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: darkBlack,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.grey.shade300,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: 0.05,
                      ),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: primaryRed.withValues(
                          alpha: 0.10,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 38,
                        color: primaryRed,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Account Settings',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                        color: darkBlack,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Manage your login username and password',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Login Username',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: darkBlack,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: usernameController,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      decoration: _inputDecoration(
                        hint: 'Enter username or mobile',
                        icon:
                            Icons.person_outline_rounded,
                      ),
                    ),

                    const SizedBox(height: 22),

                    const Text(
                      'New Password',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: darkBlack,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNewPassword,
                      textInputAction:
                          TextInputAction.next,
                      decoration: _inputDecoration(
                        hint:
                            'Leave empty to keep current password',
                        icon: Icons.lock_outline_rounded,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              obscureNewPassword =
                                  !obscureNewPassword;
                            });
                          },
                          icon: Icon(
                            obscureNewPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'Confirm New Password',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: darkBlack,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller:
                          confirmPasswordController,
                      obscureText: obscureConfirmPassword,
                      textInputAction:
                          TextInputAction.done,
                      decoration: _inputDecoration(
                        hint: 'Re-enter new password',
                        icon: Icons.lock_reset_rounded,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              obscureConfirmPassword =
                                  !obscureConfirmPassword;
                            });
                          },
                          icon: Icon(
                            obscureConfirmPassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 25),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed:
                            isSaving ? null : _saveAccount,
                        icon: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2.3,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.save_rounded,
                              ),
                        label: Text(
                          isSaving
                              ? 'SAVING...'
                              : 'SAVE ACCOUNT',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryRed,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(15),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.orange.shade200,
                  ),
                ),
                child: const Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Leave the password fields empty if you only want to change the username.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _resetAccount,
                  icon: const Icon(
                    Icons.restart_alt_rounded,
                  ),
                  label: const Text(
                    'RESET ACCOUNT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryRed,
                    side: const BorderSide(
                      color: primaryRed,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}