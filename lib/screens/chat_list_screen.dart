import 'package:fixly_app/screens/chat_screen.dart';
import 'package:fixly_app/screens/ai_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final Set<String> _localHiddenIds = {};
  late TabController _tabController;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F10) : const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: const Text('Общение', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: -1)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            child: IconButton(
              onPressed: () async {
                final result = await showSearch(context: context, delegate: ChatSearchDelegate());
                if (result != null) setState(() => _searchQuery = result);
              },
              icon: const Icon(LucideIcons.search, size: 20),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF3B82F6),
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          labelColor: isDark ? Colors.white : Colors.black,
          unselectedLabelColor: Colors.grey,
          tabs: const [Tab(text: "ЧАТЫ"), Tab(text: "ЗВОНКИ")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatTab(isDark),
          _buildCallsTab(isDark),
        ],
      ),
    );
  }

Widget _buildChatTab(bool isDark) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase.from('tasks').stream(primaryKey: ['id']).eq('is_deleted', false).order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final myId = supabase.auth.currentUser?.id;
        final tasks = snapshot.data!.where((t) {
          // Условие 1: Я создатель или заказчик
          final bool isOwner = t['user_id'] == myId || t['client_id'] == myId;
          
          // Условие 2: Я был назначен мастером (даже если заказ завершен)
          final bool wasMaster = t['master_id'] == myId;
          
          // Условие 3: Поиск
          final bool matchesSearch = _searchQuery.isEmpty || 
              (t['title']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
          
          // ВАЖНО: Разрешаем видеть чат, если ты участник (владелец или мастер) 
          // И заказ НЕ скрыт локально. Статус больше не влияет на видимость!
          return (isOwner || wasMaster) && matchesSearch && !_localHiddenIds.contains(t['id'].toString());
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: tasks.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _buildAITile(context, isDark);
            return _buildPremiumTile(context, tasks[index - 1], isDark);
          },
        );
      },
    );
  }

  Widget _buildCallsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ListTile(
          leading: CircleAvatar(backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.grey.shade200, child: const Icon(LucideIcons.user, size: 18, color: Colors.grey)),
          title: const Text("Иван Иванович", style: TextStyle(fontWeight: FontWeight.w500)),
          subtitle: const Row(children: [Icon(LucideIcons.phoneIncoming, size: 14, color: Colors.green), SizedBox(width: 5), Text("Сегодня, 14:20")]),
          trailing: const Icon(LucideIcons.phone, color: Color(0xFF3B82F6)),
        ),
      ],
    );
  }

  Widget _buildAITile(BuildContext context, bool isDark) => Container(margin: const EdgeInsets.only(bottom: 12), child: InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AIChatScreen())), borderRadius: BorderRadius.circular(28), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: LinearGradient(colors: isDark ? [const Color(0xFF2E1A47), const Color(0xFF1A1A1C)] : [const Color(0xFFF3E5F5), Colors.white]), borderRadius: BorderRadius.circular(28)), child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF9C27B0), Color(0xFF4A148C)]), borderRadius: BorderRadius.circular(20)), child: const Icon(LucideIcons.sparkles, color: Colors.white)), const SizedBox(width: 16), const Text('Fixly AI Помощник', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))]))));

  Widget _buildPremiumTile(BuildContext context, Map<String, dynamic> task, bool isDark) {
    final style = _getStatusStyle(task['status'] ?? 'new');
    return Dismissible(key: Key(task['id'].toString()), direction: DismissDirection.endToStart, onDismissed: (_) => setState(() => _localHiddenIds.add(task['id'].toString())), background: _buildDismissBackground(), child: Container(margin: const EdgeInsets.only(bottom: 12), child: InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(taskId: task['id'].toString(), taskTitle: task['title'] ?? 'Чат', receiverId: task['master_id']?.toString() ?? '', receiverName: 'Мастер'))), borderRadius: BorderRadius.circular(28), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDark ? const Color(0xFF1A1A1C) : Colors.white, borderRadius: BorderRadius.circular(28)), child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(gradient: style['gradient'], borderRadius: BorderRadius.circular(20)), child: Icon(style['icon'], color: Colors.white)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(task['title'] ?? 'Заказ', style: const TextStyle(fontWeight: FontWeight.bold)), Text(style['label'], style: TextStyle(color: style['color'], fontSize: 10))]))])))));
  }

  Map<String, dynamic> _getStatusStyle(String status) {
    switch (status) {
      case 'traveling': return {'icon': LucideIcons.truck, 'label': 'В ПУТИ', 'color': Colors.blueAccent, 'gradient': const LinearGradient(colors: [Color(0xFF64B5F6), Color(0xFF1976D2)])};
      case 'working': return {'icon': LucideIcons.wrench, 'label': 'В РАБОТЕ', 'color': Colors.orangeAccent, 'gradient': const LinearGradient(colors: [Color(0xFFFFB74D), Color(0xFFF57C00)])};
      case 'completed': return {'icon': LucideIcons.checkCircle, 'label': 'ГОТОВО', 'color': Colors.greenAccent, 'gradient': const LinearGradient(colors: [Color(0xFF81C784), Color(0xFF388E3C)])};
      default: return {'icon': LucideIcons.messageCircle, 'label': 'НОВЫЙ', 'color': Colors.purpleAccent, 'gradient': const LinearGradient(colors: [Color(0xFFBA68C8), Color(0xFF7B1FA2)])};
    }
  }

  Widget _buildDismissBackground() => Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(28)), alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 25), child: const Icon(LucideIcons.trash2, color: Colors.white));
}

class ChatSearchDelegate extends SearchDelegate<String> {
  @override
  List<Widget> buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = "")];
  @override
  Widget buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ""));
  @override
  Widget buildResults(BuildContext context) { close(context, query); return Container(); }
  @override
  Widget buildSuggestions(BuildContext context) => Container();
}