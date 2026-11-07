import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isLocked = true;
  bool _isChecking = true;
  bool _isAuthenticating = false;
  bool _lockPending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkProtectionAndAuthenticate();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lockPending = true;
      return;
    }

    if (state == AppLifecycleState.resumed && _lockPending) {
      _lockPending = false;

      _checkProtectionAndAuthenticate();
    }
  }

  Future<void> _checkProtectionAndAuthenticate() async {
    if (!mounted || _isAuthenticating) return;

    setState(() {
      _isChecking = true;
      _errorMessage = null;
    });

    try {
      final preferences = await SharedPreferences.getInstance();

      final protectionEnabled =
          preferences.getBool('security_login_protection') ?? true;

      if (!mounted) return;

      if (!protectionEnabled) {
        setState(() {
          _isLocked = false;
          _isChecking = false;
        });
        return;
      }

      setState(() {
        _isLocked = true;
        _isChecking = false;
      });

      await _authenticateDevice();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLocked = true;
        _isChecking = false;
        _errorMessage =
            'Unable to verify security settings. Please try again.';
      });

      debugPrint('App lock settings check failed: $error');
    }
  }

  Future<void> _authenticateDevice() async {
    if (!mounted || _isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _isLocked = true;
      _errorMessage = null;
    });

    try {
      final supported = await _localAuth.isDeviceSupported();

      if (!mounted) return;

      if (!supported) {
        setState(() {
          _errorMessage =
              'Device authentication is unavailable. Please set up a screen lock on your phone.';
        });
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason:
            'Authenticate to access PS Tax Consultancy',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );

      if (!mounted) return;

      final preferences = await SharedPreferences.getInstance();
      final protectionEnabled =
          preferences.getBool('security_login_protection') ?? true;

      if (!mounted) return;

      setState(() {
        _isLocked = protectionEnabled && !authenticated;
        _errorMessage = authenticated
            ? null
            : 'Authentication was not completed. Please try again.';
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLocked = true;
        _errorMessage =
            'Authentication failed. Check your device security and try again.';
      });

      debugPrint('App lock authentication failed: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLocked) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914).withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    size: 52,
                    color: Color(0xFFE50914),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'PS Tax Consultancy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Authenticate to unlock the app',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),
                if (_isChecking || _isAuthenticating) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(
                    color: Color(0xFFE50914),
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFE50914),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isChecking || _isAuthenticating
                        ? null
                        : _checkProtectionAndAuthenticate,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('UNLOCK APP'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE50914),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
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