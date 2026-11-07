
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TermsConditionsSettingsScreen extends StatefulWidget {
  const TermsConditionsSettingsScreen({super.key});

  @override
  State<TermsConditionsSettingsScreen> createState() =>
      _TermsConditionsSettingsScreenState();
}

class _TermsConditionsSettingsScreenState
    extends State<TermsConditionsSettingsScreen> {
  static const String _storageKey = 'invoice_terms_conditions';

  final TextEditingController _termsController =
      TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _includeTermsInInvoice = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final preferences = await SharedPreferences.getInstance();

      final savedTerms = preferences.getStringList(_storageKey);

      if (!mounted) return;

      _termsController.text = savedTerms?.join('\n') ??
          'Payment terms are as agreed from date of invoice generation.\n'
              'Please mention the invoice number in transaction advice.\n'
              'Any applicable statutory deductions or TDS shall be dealt with as per applicable requirements.';

      setState(() {
        _includeTermsInInvoice =
            preferences.getBool('invoice_include_terms_conditions') ??
                true;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Settings load செய்ய முடியவில்லை: $e'),
        ),
      );
    }
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final preferences = await SharedPreferences.getInstance();

      final terms = _termsController.text
          .split('\n')
          .map((term) => term.trim())
          .where((term) => term.isNotEmpty)
          .toList();

      await preferences.setStringList(_storageKey, terms);
      await preferences.setBool(
        'invoice_include_terms_conditions',
        _includeTermsInInvoice,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terms & Conditions சேமிக்கப்பட்டது'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('சேமிக்க முடியவில்லை: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _termsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryRed = Color(0xFFE50914);
    const darkBlack = Color(0xFF111111);
    const background = Color(0xFFF6F7F9);

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        backgroundColor: darkBlack,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.description_outlined,
                                color: primaryRed,
                                size: 28,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Invoice Terms & Conditions',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    color: darkBlack,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'ஒவ்வொரு வரியிலும் ஒரு நிபந்தனையை உள்ளிடுங்கள். '
                            'சேமித்த பிறகு இந்த விவரங்களை Invoice PDF-ல் '
                            'பயன்படுத்தலாம்.',
                            style: TextStyle(
                              color: Colors.black87,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeThumbColor: primaryRed,
                            title: const Text(
                              'Invoice-ல் Terms காட்டவும்',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: const Text(
                              'Invoice PDF-ல் நிபந்தனைகளைக் காட்டும் அமைப்பு',
                            ),
                            value: _includeTermsInInvoice,
                            onChanged: (value) {
                              setState(() {
                                _includeTermsInInvoice = value;
                              });
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _termsController,
                            minLines: 8,
                            maxLines: 16,
                            textCapitalization:
                                TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: 'Terms & Conditions',
                              hintText:
                                  'ஒவ்வொரு நிபந்தனையையும் தனி வரியில் எழுதவும்',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(
                                  color: primaryRed,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _isSaving ? null : _saveSettings,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(
                                _isSaving ? 'சேமிக்கிறது...' : 'சேமிக்கவும்',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryRed,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'குறிப்பு: இந்தத் திரை Terms-ஐச் சேமிக்கிறது. '
                    'PDF உருவாக்கும் code-உடன் இணைத்த பிறகே, '
                    'சேமித்த Terms Invoice PDF-ல் தோன்றும்.',
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
