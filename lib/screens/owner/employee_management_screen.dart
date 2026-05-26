import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets/bottom_nav_scaffold.dart';

class EmployeeManagementScreen extends StatefulWidget {
  static const routeName = '/employees';

  final String stationId;
  final String ownerPhone;
  final String sessionToken;

  const EmployeeManagementScreen({
    super.key,
    required this.stationId,
    required this.ownerPhone,
    required this.sessionToken,
  });

  @override
  State<EmployeeManagementScreen> createState() => _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  late Future<List<Map<String, dynamic>>> _employeesFuture;
  bool _showAddForm = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final Set<String> _selectedPermissions = {};

  final List<Map<String, String>> _availablePermissions = [
    {'id': 'view_bookings', 'label': 'View Bookings'},
    {'id': 'approve_bookings', 'label': 'Approve Bookings'},
    {'id': 'reject_bookings', 'label': 'Reject Bookings'},
    {'id': 'modify_prices', 'label': 'Modify Prices'},
    {'id': 'manage_employees', 'label': 'Manage Employees'},
    {'id': 'view_reports', 'label': 'View Reports'},
    {'id': 'manage_services', 'label': 'Manage Services'},
  ];

  @override
  void initState() {
    super.initState();
    _employeesFuture = _loadEmployees();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadEmployees() async {
    try {
      final client = SupabaseService.instance.client;
      final data = await client
          .from('employees')
          .select('*')
          .eq('station_id', widget.stationId)
          .order('created_at', ascending: false);

      return (data as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  Future<void> _addEmployee() async {
    if (_nameController.text.isEmpty ||
        _phoneController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _selectedPermissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields and select permissions')),
      );
      return;
    }

    try {
      await SupabaseService.instance.client.functions.invoke(
        'create-employee',
        body: {
          'station_id': widget.stationId,
          'owner_phone': widget.ownerPhone,
          'session_token': widget.sessionToken,
          'employee_name': _nameController.text,
          'employee_phone': _phoneController.text,
          'employee_email': _emailController.text,
          'permissions': _selectedPermissions.toList(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee added successfully')),
        );
        setState(() {
          _nameController.clear();
          _phoneController.clear();
          _emailController.clear();
          _selectedPermissions.clear();
          _showAddForm = false;
          _employeesFuture = _loadEmployees();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding employee: $e')),
        );
      }
    }
  }

  Future<void> _removeEmployee(String employeeId) async {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove Employee'),
        content: const Text('Are you sure you want to remove this employee?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await SupabaseService.instance.client
                    .from('employees')
                    .delete()
                    .eq('id', employeeId);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Employee removed')),
                  );
                  setState(() => _employeesFuture = _loadEmployees());
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavScaffold(
      currentIndex: 4,
      title: 'Employee Management',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton.icon(
              onPressed: () => setState(() => _showAddForm = !_showAddForm),
              icon: const Icon(Icons.person_add),
              label: const Text('Add Employee'),
            ),
          ),
          if (_showAddForm) _buildAddEmployeeForm(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _employeesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final employees = snapshot.data ?? [];

                if (employees.isEmpty) {
                  return const Center(child: Text('No employees added yet'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: employees.length,
                  itemBuilder: (context, index) {
                    final employee = employees[index];
                    final permissions = (employee['permissions'] as List?)
                            ?.map((p) => p as String)
                            .toList() ??
                        [];

                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(employee['employee_name'] ?? 'Unknown',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                IconButton(
                                  onPressed: () => _removeEmployee(employee['id']),
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Phone: ${employee['employee_phone'] ?? 'N/A'}'),
                            Text('Email: ${employee['employee_email'] ?? 'N/A'}'),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: permissions
                                  .map((perm) => Chip(
                                        label: Text(perm),
                                        backgroundColor: Colors.blue[100],
                                      ))
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddEmployeeForm() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add New Employee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Employee Name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            const Text('Permissions:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _availablePermissions
                  .map((perm) => FilterChip(
                        label: Text(perm['label']!),
                        selected: _selectedPermissions.contains(perm['id']),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedPermissions.add(perm['id']!);
                            } else {
                              _selectedPermissions.remove(perm['id']);
                            }
                          });
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => setState(() => _showAddForm = false),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _addEmployee,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                  child: const Text('Add Employee'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
