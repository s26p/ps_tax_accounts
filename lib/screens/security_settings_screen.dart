import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() =>
      _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState
    extends State<SecuritySettingsScreen> {
  static const Color primaryRed = Color(0xFFE50914);
  static const Color darkBlack = Color(0xFF111111);
  static const Color background = Color(0xFFF6F7F9);

  bool loginProtection = true;
  bool passwordVisibilityControl = true;

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadSecuritySettings() async {
    try {
      final preferences =
          await SharedPreferences.getInstance();

      final savedLoginProtection =
          preferences.getBool(
        'security_login_protection',
      );

      final savedPasswordVisibility =
          preferences.getBool(
        'security_password_visibility',
      );

      if (!mounted) return;

      setState(() {
        loginProtection =
            savedLoginProtection ?? true;

        passwordVisibilityControl =
            savedPasswordVisibility ?? true;

        isLoading = false;
      });

      // Save defaults on first use.
      if (savedLoginProtection == null) {
        await preferences.setBool(
          'security_login_protection',
          true,
        );
      }

      if (savedPasswordVisibility == null) {
        await preferences.setBool(
          'security_password_visibility',
          true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showMessage(
        'Unable to load security settings.',
      );
    }
  }

  Future<void> _saveSecuritySettings() async {
    setState(() {
      isSaving = true;
    });

    try {
      final preferences =
          await SharedPreferences.getInstance();

      await preferences.setBool(
        'security_login_protection',
        loginProtection,
      );

      await preferences.setBool(
        'security_password_visibility',
        passwordVisibilityControl,
      );

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        'Security settings saved successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage(
        'Unable to save security settings.',
      );
    }
  }

  Future<void> _resetSecuritySettings() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Reset Security Settings',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Reset security settings to the default values?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
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

    try {
      final preferences =
          await SharedPreferences.getInstance();

      await preferences.setBool(
        'security_login_protection',
        true,
      );

      await preferences.setBool(
        'security_password_visibility',
        true,
      );

      if (!mounted) return;

      setState(() {
        loginProtection = true;
        passwordVisibilityControl = true;
      });

      _showMessage(
        'Security settings reset successfully.',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'Unable to reset security settings.',
      );
    }
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

  Widget _securityTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.035,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: primaryRed,
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 7,
        ),
        secondary: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: primaryRed.withValues(
              alpha: 0.09,
            ),
            borderRadius:
                BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: primaryRed,
            size: 23,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: darkBlack,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(
            top: 4,
          ),
          child: Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.black54,
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.blue.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: Colors.blue.shade700,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Username and password are managed from Account Settings. '
              'These security options control app security preferences.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text(
          'Security Settings',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: darkBlack,
        elevation: 0,
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: primaryRed,
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(22),
                        border: Border.all(
                          color:
                              Colors.grey.shade300,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Colors.black.withValues(
                              alpha: 0.05,
                            ),
                            blurRadius: 15,
                            offset:
                                const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration:
                                BoxDecoration(
                              color: primaryRed
                                  .withValues(
                                alpha: 0.10,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.security_rounded,
                              size: 38,
                              color: primaryRed,
                            ),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Security Settings',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight:
                                  FontWeight.bold,
                              color: darkBlack,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Manage your app security preferences',
                            textAlign:
                                TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _securityTile(
                      icon:
                          Icons.lock_outline_rounded,
                      title: 'Login Protection',
                      subtitle:
                          'Keep login protection enabled when using the app',
                      value: loginProtection,
                      onChanged: (value) {
                        setState(() {
                          loginProtection = value;
                        });
                      },
                    ),

                    _securityTile(
                      icon:
                          Icons.visibility_outlined,
                      title:
                          'Password Visibility Control',
                      subtitle:
                          'Show or hide password using the visibility button on login',
                      value:
                          passwordVisibilityControl,
                      onChanged: (value) {
                        setState(() {
                          passwordVisibilityControl =
                              value;
                        });
                      },
                    ),

                    const SizedBox(height: 4),

                    _infoCard(),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed:
                            isSaving
                                ? null
                                : _saveSecuritySettings,
                        icon: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(
                                  strokeWidth: 2.3,
                                  color:
                                      Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.save_rounded,
                              ),
                        label: Text(
                          isSaving
                              ? 'SAVING...'
                              : 'SAVE SECURITY SETTINGS',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        style:
                            ElevatedButton.styleFrom(
                          backgroundColor:
                              primaryRed,
                          foregroundColor:
                              Colors.white,
                          elevation: 0,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              15,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        onPressed:
                            _resetSecuritySettings,
                        icon: const Icon(
                          Icons.restart_alt_rounded,
                        ),
                        label: const Text(
                          'RESET SECURITY SETTINGS',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        style:
                            OutlinedButton.styleFrom(
                          foregroundColor:
                              primaryRed,
                          side: const BorderSide(
                            color: primaryRed,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }
}
