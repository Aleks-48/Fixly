import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final _binController = TextEditingController();
  bool _isLoading = false;
  String? _companyName; // Сюда подтянем название ТОО после проверки

  // Функция валидации БИН (алгоритм 12 цифр)
  bool _isValidBIN(String bin) {
    if (bin.length != 12) return false;
    return RegExp(r'^[0-9]+$').hasMatch(bin);
  }

  Future<void> _verifyBIN() async {
    final bin = _binController.text.trim();
    if (!_isValidBIN(bin)) {
      _showSnackBar("Введите корректный БИН (12 цифр)", Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Имитация запроса к API реестра (stats.gov.kz или подобным)
      // В реальности тут будет http.get или вызов Edge Function в Supabase
      await Future.delayed(const Duration(seconds: 2)); 
      
      setState(() {
        _companyName = "ТОО 'FIXLY SERVICES KAZAKHSTAN'"; // Пример ответа
      });

      // Сохраняем БИН в таблицу профиля мастера в Supabase
      final userId = Supabase.instance.client.auth.currentUser?.id;
      await Supabase.instance.client.from('profiles').update({
        'bin': bin,
        'is_verified': true,
        'business_name': _companyName,
      }).eq('id', userId ?? '');

      _showSnackBar("БИН успешно верифицирован!", Colors.green);
    } catch (e) {
      _showSnackBar("Ошибка проверки: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E1621),
      appBar: AppBar(
        title: const Text("Верификация бизнеса"),
        backgroundColor: const Color(0xFF17212D),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Введите БИН вашего ТОО или ИП",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Это позволит вам выставлять счета клиентам и работать официально.",
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _binController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
              style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 2),
              decoration: InputDecoration(
                hintText: "000000000000",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.1)),
                filled: true,
                fillColor: const Color(0xFF17212D),
                prefixIcon: const Icon(LucideIcons.briefcase, color: Color(0xFF4FA9E3)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            if (_companyName != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.withOpacity(0.3))),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_companyName!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyBIN,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FA9E3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("Проверить БИН", style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}