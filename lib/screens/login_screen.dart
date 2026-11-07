import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color primaryRed = Color(0xFFE50914);
  static const Color darkBlack = Color(0xFF111111);
  static const Color background = Color(0xFFF6F7F9);

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();

  bool obscurePassword = true;
  bool isLoading = false;
  bool allowPasswordVisibilityToggle = true;

  @override
  void initState() {
    super.initState();
    _loadPasswordVisibilitySetting();
  }

  Future<void> _loadPasswordVisibilitySetting() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('security_password_visibility') ?? true;

    if (!mounted) return;

    setState(() {
      allowPasswordVisibilityToggle = enabled;
      if (!enabled) {
        obscurePassword = true;
      }
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // LOGIN WITH FIREBASE
  // ------------------------------------------------------------

  Future<void> _login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty) {
      _showMessage('Please enter your email address.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('Please enter a valid email address.');
      return;
    }

    if (password.isEmpty) {
      _showMessage('Please enter your password.');
      return;
    }

    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    debugPrint('[LOGIN] Sign-in started');

    try {
      final credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      debugPrint(
        '[LOGIN] Sign-in completed; user exists: ${credential.user != null}',
      );
      debugPrint(
        '[LOGIN] Current Firebase user exists: '
        '${FirebaseAuth.instance.currentUser != null}',
      );

      if (!mounted) return;

      if (credential.user == null) {
        _showMessage('Login failed. Please try again.');
      }
    } on FirebaseAuthException catch (error) {
      debugPrint('[LOGIN] FirebaseAuthException code: ${error.code}');

      if (!mounted) return;
      _showMessage(_getFirebaseErrorMessage(error.code));
    } catch (error, stackTrace) {
      debugPrint('[LOGIN] Unexpected error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      _showMessage(
        'Unable to log in. Please check your internet connection.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }

      debugPrint('[LOGIN] Sign-in handler finished');
    }
  }

  // ------------------------------------------------------------
  // FORGOT PASSWORD / RESET PASSWORD
  // ------------------------------------------------------------

  Future<void> _resetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      _showMessage(
        'Enter your registered email address first.',
      );
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('Please enter a valid email address.');
      return;
    }

    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: email,
      );

      if (!mounted) return;

      // Avoid revealing whether an email is registered.
      _showMessage(
        'If an account exists for this email, a password reset '
        'message will be sent. Check your inbox and spam folder.',
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;

      switch (error.code) {
        case 'invalid-email':
          _showMessage('Please enter a valid email address.');
          break;

        case 'network-request-failed':
          _showMessage(
            'Internet connection failed. Please try again.',
          );
          break;

        case 'too-many-requests':
          _showMessage(
            'Too many attempts. Please wait and try again later.',
          );
          break;

        case 'operation-not-allowed':
          _showMessage(
            'Password reset is not enabled in Firebase Authentication.',
          );
          break;

        default:
          _showMessage(
            'Unable to request a password reset. Please try again later.',
          );
          debugPrint(
            'Firebase password reset error: ${error.code}',
          );
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage('Something went wrong. Please try again.');

      debugPrint('Password reset error: $error');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // EMAIL VALIDATION
  // ------------------------------------------------------------

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

  // ------------------------------------------------------------
  // FIREBASE ERROR MESSAGES
  // ------------------------------------------------------------

  String _getFirebaseErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';

      case 'user-disabled':
        return 'This account has been disabled. Contact your administrator.';

      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Email address or password is incorrect.';

      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';

      case 'network-request-failed':
        return 'Check your internet connection and try again.';

      case 'operation-not-allowed':
        return 'Email and password login is not enabled in Firebase.';

      default:
        return 'Login failed. Please check your details and try again.';
    }
  }

  // ------------------------------------------------------------
  // DISPLAY MESSAGE
  // ------------------------------------------------------------

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ------------------------------------------------------------
  // LOGIN SCREEN UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 30,
            ),
            child: Column(
              children: [
                // BUSINESS LOGO
                Container(
                  width: 110,
                  height: 110,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/ps_tax_consultancy_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.business_rounded,
                        size: 58,
                        color: primaryRed,
                      );
                    },
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'PS Tax Consultancy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.bold,
                    color: darkBlack,
                  ),
                ),

                const SizedBox(height: 7),

                const Text(
                  'GST • TAX • ACCOUNTS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: primaryRed,
                    letterSpacing: 1.2,
                  ),
                ),

                const SizedBox(height: 35),

                // LOGIN CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.grey.shade300,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: darkBlack,
                        ),
                      ),

                      const SizedBox(height: 6),

                      const Text(
                        'Login to continue to your dashboard',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),

                      const SizedBox(height: 25),

                      // EMAIL LABEL
                      const Text(
                        'Email Address',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // EMAIL FIELD
                      TextField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        enableSuggestions: false,
                        enabled: !isLoading,
                        decoration: InputDecoration(
                          hintText: 'Enter your Firebase email',
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                          ),
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
                        ),
                      ),

                      const SizedBox(height: 18),

                      // PASSWORD LABEL
                      const Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // PASSWORD FIELD
                      TextField(
                        controller: passwordController,
                        obscureText: obscurePassword,
                        textInputAction: TextInputAction.done,
                        enabled: !isLoading,
                        onSubmitted: (_) {
                          if (!isLoading) {
                            _login();
                          }
                        },
                        decoration: InputDecoration(
                          hintText: 'Enter password',
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                          ),
                          suffixIcon: allowPasswordVisibilityToggle
                              ? IconButton(
                                  onPressed: isLoading
                                      ? null
                                      : () {
                                          setState(() {
                                            obscurePassword =
                                                !obscurePassword;
                                          });
                                        },
                                  icon: Icon(
                                    obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                  ),
                                )
                              : null,
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
                        ),
                      ),

                      // FORGOT PASSWORD LINK
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed:
                              isLoading ? null : _resetPassword,
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              color: primaryRed,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      // LOGIN BUTTON
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryRed,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                primaryRed.withValues(alpha: 0.6),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 23,
                                  height: 23,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                const Text(
                  'Professional Tax & Business Solutions',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black45,
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  '© PS Tax Consultancy',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}




