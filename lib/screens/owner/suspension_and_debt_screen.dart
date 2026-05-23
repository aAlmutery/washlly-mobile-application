import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets/bottom_nav_scaffold.dart';

class SuspensionAndDebtScreen extends StatefulWidget {
  static const routeName = '/suspension-debt';

  const SuspensionAndDebtScreen({super.key});

  @override
  State<SuspensionAndDebtScreen> createState() => _SuspensionAndDebtScreenState();
}

class _SuspensionAndDebtScreenState extends State<SuspensionAndDebtScreen> {
  late String customerPhone;
  late Future<Map<String, dynamic>> _debtFuture;
  bool _showPaymentForm = false;
  final TextEditingController _paymentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    customerPhone = ''; // TODO: Get from session
    _debtFuture = _loadDebtInfo();
  }

  @override
  void dispose() {
    _paymentController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadDebtInfo() async {
    try {
      final client = SupabaseService.instance.client;
      final data = await client
          .from('customer_debt')
          .select('*')
          .eq('customer_phone', customerPhone)
          .single();
      return data;
    } catch (e) {
      return {
        'total_debt': 0,
        'outstanding_amount': 0,
        'suspension_status': 'none',
        'unpaid_bookings': 0,
      };
    }
  }

  Future<void> _submitPayment() async {
    if (_paymentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter payment amount')),
      );
      return;
    }

    try {
      await SupabaseService.instance.client.functions.invoke(
        'process-debt-payment',
        body: {
          'customer_phone': customerPhone,
          'amount': double.parse(_paymentController.text),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment processed successfully')),
        );
        setState(() {
          _debtFuture = _loadDebtInfo();
          _paymentController.clear();
          _showPaymentForm = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavScaffold(
      currentIndex: 2,
      title: 'Account & Suspension',
      body: FutureBuilder<Map<String, dynamic>>(
        future: _debtFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final debtData = snapshot.data ?? {};
          final totalDebt = debtData['total_debt'] ?? 0;
          final outstandingAmount = debtData['outstanding_amount'] ?? 0;
          final suspensionStatus = debtData['suspension_status'] ?? 'none';
          final unpaidBookings = debtData['unpaid_bookings'] ?? 0;
          final isSuspended = suspensionStatus != 'none';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Suspension Status Card
              if (isSuspended)
                Card(
                  color: Colors.red[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning, color: Colors.red, size: 32),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Account Suspended',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('Reason: $suspensionStatus'),
                        const SizedBox(height: 8),
                        const Text(
                          'Your account has been suspended due to outstanding debt. Please settle the amount below to restore access.',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  color: Colors.green[50],
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 32),
                        const SizedBox(width: 12),
                        const Text(
                          'Account Active',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 24),

              // Debt Summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Debt Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Debt:'),
                          Text('$totalDebt IQD', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Outstanding Amount:'),
                          Text('$outstandingAmount IQD',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.red,
                              )),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Unpaid Bookings:'),
                          Text('$unpaidBookings', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Payment Form
              if (_showPaymentForm) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Make Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _paymentController,
                          decoration: InputDecoration(
                            labelText: 'Amount (IQD)',
                            prefixIcon: const Icon(Icons.money),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              onPressed: () => setState(() => _showPaymentForm = false),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: _submitPayment,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              child: const Text('Pay Now'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: outstandingAmount > 0
                      ? () => setState(() => _showPaymentForm = true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text('Make Payment'),
                ),
              ],
              const SizedBox(height: 24),

              // Unpaid Bookings List
              if (unpaidBookings > 0) ...[
                const Text('Unpaid Bookings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'You have $unpaidBookings unpaid booking(s). Please settle the outstanding amount to restore your account.',
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
