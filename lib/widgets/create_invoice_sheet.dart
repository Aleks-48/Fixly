import 'package:flutter/material.dart';
import 'package:fixly_app/services/billing_service.dart';

class CreateInvoiceSheet extends StatefulWidget {
  final String buildingId;

  const CreateInvoiceSheet({super.key, required this.buildingId});

  static void show(BuildContext context, String buildingId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CreateInvoiceSheet(buildingId: buildingId),
    );
  }

  @override
  State<CreateInvoiceSheet> createState() => _CreateInvoiceSheetState();
}

class _CreateInvoiceSheetState extends State<CreateInvoiceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();
  final _amountController = TextEditingController();
  
  bool _isBuildingWide = true;
  bool _isLoading = false;
  final BillingService _billingService = BillingService();

  Future<void> _submitInvoice() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _billingService.createInvoice(
        buildingId: widget.buildingId,
        amount: double.parse(_amountController.text),
        purpose: _purposeController.text,
        isBuildingWide: _isBuildingWide,
      );

      if (!mounted) return;
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Счет успешно выставлен жильцам!'),
          backgroundColor: Color(0xFF8A9A5B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20, bottom: bottomPadding + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Выставить новый счет',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _purposeController,
              decoration: const InputDecoration(
                labelText: 'Назначение (например, Целевой сбор)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.edit_note),
              ),
              validator: (v) => v!.isEmpty ? 'Введите назначение платежа' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Сумма (в тенге)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (v) {
                if (v!.isEmpty) return 'Введите сумму';
                if (double.tryParse(v) == null) return 'Введите корректное число';
                return null;
              },
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Счет на весь дом'),
              subtitle: const Text('Квитанция появится у всех жителей ЖК'),
              value: _isBuildingWide,
              activeColor: const Color(0xFF8A9A5B),
              onChanged: (val) => setState(() => _isBuildingWide = val),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8A9A5B),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isLoading ? null : _submitInvoice,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Выставить счет', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}