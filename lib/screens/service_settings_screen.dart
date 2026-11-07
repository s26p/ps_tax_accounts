import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServiceSettingsScreen extends StatefulWidget {
  const ServiceSettingsScreen({super.key});

  @override
  State<ServiceSettingsScreen> createState() =>
      _ServiceSettingsScreenState();
}

class _ServiceSettingsScreenState
    extends State<ServiceSettingsScreen> {
  static const Color primaryRed = Color(0xFFE50914);
  static const Color darkBlack = Color(0xFF111111);
  static const Color background = Color(0xFFF6F7F9);

  List<String> services = [];

  bool isLoading = true;

  final List<String> defaultServices = [
    'GST Registration',
    'GST Monthly Filing',
    'Income Tax Filing',
    'TDS Services',
    'Accounting',
    'PAN Services',
    'EPF / ESI',
    'MSME Registration',
    'Trademark Registration',
    'Import & Export',
  ];

  @override
  void initState() {
    super.initState();
    loadServices();
  }

  // ============================================================
  // LOAD SERVICES
  // ============================================================

  Future<void> loadServices() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final savedServices =
          prefs.getStringList('consultancy_services');

      if (savedServices == null || savedServices.isEmpty) {
        services = List<String>.from(defaultServices);

        await prefs.setStringList(
          'consultancy_services',
          services,
        );
      } else {
        services = List<String>.from(savedServices);
      }
    } catch (_) {
      services = List<String>.from(defaultServices);
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  // ============================================================
  // SAVE SERVICES
  // ============================================================

  Future<void> saveServices() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setStringList(
      'consultancy_services',
      services,
    );
  }

  // ============================================================
  // ADD SERVICE
  // ============================================================

  Future<void> addService() async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Add Service',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Service Name',
              hintText: 'Example: GST Audit',
              prefixIcon: const Icon(
                Icons.business_center_outlined,
                color: primaryRed,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: primaryRed,
                  width: 1.5,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final value = controller.text.trim();

                if (value.isNotEmpty) {
                  Navigator.pop(context, value);
                }
              },
              child: const Text('ADD'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null || result.trim().isEmpty) {
      return;
    }

    final newService = result.trim();

    final alreadyExists = services.any(
      (service) =>
          service.toLowerCase() ==
          newService.toLowerCase(),
    );

    if (alreadyExists) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This service already exists',
          ),
        ),
      );

      return;
    }

    setState(() {
      services.add(newService);
    });

    await saveServices();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Service added successfully',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ============================================================
  // EDIT SERVICE
  // ============================================================

  Future<void> editService(int index) async {
    final controller = TextEditingController(
      text: services[index],
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Edit Service',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Service Name',
              prefixIcon: const Icon(
                Icons.edit_outlined,
                color: primaryRed,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: primaryRed,
                  width: 1.5,
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final value = controller.text.trim();

                if (value.isNotEmpty) {
                  Navigator.pop(context, value);
                }
              },
              child: const Text('SAVE'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null || result.trim().isEmpty) {
      return;
    }

    final updatedService = result.trim();

    final duplicateExists = services.asMap().entries.any(
      (entry) =>
          entry.key != index &&
          entry.value.toLowerCase() ==
              updatedService.toLowerCase(),
    );

    if (duplicateExists) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'This service already exists',
          ),
        ),
      );

      return;
    }

    setState(() {
      services[index] = updatedService;
    });

    await saveServices();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Service updated successfully',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ============================================================
  // DELETE SERVICE
  // ============================================================

  Future<void> deleteService(int index) async {
    final serviceName = services[index];

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Delete Service?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$serviceName"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('DELETE'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    setState(() {
      services.removeAt(index);
    });

    await saveServices();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Service deleted',
        ),
      ),
    );
  }

  // ============================================================
  // RESTORE DEFAULT SERVICES
  // ============================================================

  Future<void> restoreDefaults() async {
    final shouldRestore = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Restore Default Services?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: const Text(
            'Your current service list will be replaced '
            'with the default PS Tax Consultancy services.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text(
                'CANCEL',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryRed,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('RESTORE'),
            ),
          ],
        );
      },
    );

    if (shouldRestore != true) {
      return;
    }

    setState(() {
      services = List<String>.from(defaultServices);
    });

    await saveServices();

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Default services restored',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  // ============================================================
  // SERVICE CARD
  // ============================================================

  Widget serviceCard({
    required int index,
    required String service,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.04,
            ),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 5,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: primaryRed.withValues(
              alpha: 0.10,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.business_center_outlined,
            color: primaryRed,
          ),
        ),
        title: Text(
          service,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: darkBlack,
          ),
        ),
        subtitle: const Text(
          'Consultancy Service',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              editService(index);
            } else if (value == 'delete') {
              deleteService(index);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(
                    Icons.edit_outlined,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: primaryRed,
                  ),
                  SizedBox(width: 10),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: darkBlack,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Services',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Restore Defaults',
            onPressed: restoreDefaults,
            icon: const Icon(
              Icons.restore,
            ),
          ),
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        onPressed: addService,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Service',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: primaryRed,
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                16,
                18,
                16,
                100,
              ),
              children: [
                // ==================================================
                // HEADER
                // ==================================================

                Container(
                  padding: const EdgeInsets.all(18),
                  margin: const EdgeInsets.only(
                    bottom: 20,
                  ),
                  decoration: BoxDecoration(
                    color: darkBlack,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: primaryRed,
                          borderRadius:
                              BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.business_center,
                          color: Colors.white,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Consultancy Services',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${services.length} services available',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Text(
                  'SERVICE LIST',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    letterSpacing: 0.8,
                  ),
                ),

                const SizedBox(height: 12),

                if (services.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(30),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(16),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons
                              .business_center_outlined,
                          size: 50,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'No services added',
                          style: TextStyle(
                            fontWeight:
                                FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Tap "Add Service" to create a service.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...List.generate(
                    services.length,
                    (index) => serviceCard(
                      index: index,
                      service: services[index],
                    ),
                  ),
              ],
            ),
    );
  }
}