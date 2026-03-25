import 'dart:async';
import 'package:flutter/material.dart';

class SheberAtaHelper extends StatefulWidget {
  final Map<String, String> messages;
  final VoidCallback? onTap;
  final String languageCode;
  final List<Widget>? actions;

  const SheberAtaHelper({
    super.key,
    required this.messages,
    this.onTap,
    this.languageCode = 'ru', // Установим дефолт ru
    this.actions,
  });

  @override
  State<SheberAtaHelper> createState() => _SheberAtaHelperState();
}

class _SheberAtaHelperState extends State<SheberAtaHelper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _yAnim, _scaleAnim;
  String _displayText = "";
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 3), vsync: this)..repeat(reverse: true);
    _yAnim = Tween<double>(begin: 0, end: 10).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.05).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _startTyping();
  }

  @override
  void didUpdateWidget(covariant SheberAtaHelper oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Проверяем изменение сообщения или кода языка
    if (oldWidget.messages != widget.messages || oldWidget.languageCode != widget.languageCode) {
      _startTyping();
    }
  }

  void _startTyping() {
    _typingTimer?.cancel();
    
    if (widget.messages.isEmpty) {
      if (mounted) setState(() => _displayText = "");
      return;
    }

    // Извлекаем текст по коду (ru или kk)
    String? fullText = widget.messages[widget.languageCode];
    
    // Если по коду не нашли, берем любой первый доступный текст
    fullText ??= widget.messages.values.isNotEmpty ? widget.messages.values.first : "";

    if (fullText.isEmpty) {
      if (mounted) setState(() => _displayText = "");
      return;
    }

    int i = 0;
    _displayText = ""; 
    _typingTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (i >= fullText!.length) {
        timer.cancel();
      } else {
        if (mounted) setState(() => _displayText = fullText!.substring(0, i + 1));
        i++;
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Transform.translate(
        offset: Offset(0, -_yAnim.value),
        child: Transform.scale(
          scale: _scaleAnim.value,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (_displayText.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                        bottomRight: Radius.circular(4),
                      ),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0, 4))]
                    ),
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayText, 
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)
                        ),
                        if (widget.actions != null) ...[
                          const SizedBox(height: 8),
                          ...widget.actions!,
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Image.asset(
                  'assets/images/sheber_ata.png', // Проверь, чтобы в ассетах было ata, а не aga
                  width: 80, height: 80, fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}