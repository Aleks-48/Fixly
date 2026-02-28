import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/ai_service.dart';
import '../services/sound_service.dart'; 

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  _AIChatScreenState createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<Map<String, String>> _messages = [
    {
      "role": "ai", 
      "text": "Привет! Я твой ИИ-помощник Fixly. ✨\nЧем могу помочь с заявками или планом работ?"
    }
  ];
  
  bool _isLoading = false;

  final List<String> _quickSuggestions = [
    "Как создать заказ?",
    "Какой статус моей заявки?",
    "Помоги составить план ремонта",
    "Как связаться с мастером?"
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;
    
    // Воспроизводим звук нажатия
    SoundService.playClick();
    
    setState(() {
      _messages.add({"role": "user", "text": text});
      _isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();

    try {
      String aiResponse = await AIService.generateActionPlan(
        text, 
        "Чат поддержка Fixly", 
        "ru"
      );

      if (mounted) {
        setState(() {
          _messages.add({"role": "ai", "text": aiResponse});
          _isLoading = false;
        });
        
        // Воспроизводим звук ответа ИИ
        SoundService.playNotification();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _messages.add({"role": "ai", "text": "Извините, произошла ошибка. Попробуйте еще раз."});
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121214) : const Color(0xFFF0F2F5);
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0.5,
        backgroundColor: cardColor,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(8)), child: const Center(child: Text("F", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Fixly AI", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                const Text("в сети", style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isAI = msg["role"] == "ai";
                return _buildMessageBubble(msg["text"]!, isAI, isDark, cardColor);
              },
            ),
          ),
          
          if (_messages.length == 1)
            Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _quickSuggestions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) => ActionChip(
                  label: Text(_quickSuggestions[index], style: const TextStyle(fontSize: 12)),
                  onPressed: () => _sendMessage(_quickSuggestions[index]),
                ),
              ),
            ),

          if (_isLoading) 
            const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Center(child: CircularProgressIndicator(color: Color(0xFF9C27B0), strokeWidth: 2))),
          
          _buildInputArea(isDark, cardColor),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isAI, bool isDark, Color cardColor) {
    return Align(
      alignment: isAI ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isAI ? cardColor : const Color(0xFF9C27B0),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isAI ? 0 : 18),
            bottomRight: Radius.circular(isAI ? 18 : 0),
          ),
        ),
        child: Text(text, style: TextStyle(color: isAI ? (isDark ? Colors.white : Colors.black87) : Colors.white, fontSize: 15, height: 1.4)),
      ),
    );
  }

  Widget _buildInputArea(bool isDark, Color cardColor) {
    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(color: cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -2))]),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(color: isDark ? Colors.white.withOpacity(0.05) : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(28)),
              child: TextField(
                controller: _controller,
                maxLines: null,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: const InputDecoration(hintText: "Спросите ИИ...", hintStyle: TextStyle(color: Colors.grey, fontSize: 14), border: InputBorder.none),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _sendMessage(_controller.text),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFBA68C8), Color(0xFF9C27B0)]), shape: BoxShape.circle),
              child: const Icon(LucideIcons.send, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}