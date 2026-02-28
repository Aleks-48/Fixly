import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fixly_app/main.dart'; 
import 'package:fixly_app/screens/order_details_page.dart'; 
import 'package:lucide_icons/lucide_icons.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  final supabase = Supabase.instance.client;
  String _selectedFilter = 'all'; 
  String _searchQuery = '';

  String _translateStatus(String? status, String lang) {
    final ru = {'new': 'Новая', 'in_progress': 'В работе', 'completed': 'Готово'};
    final kz = {'new': 'Жаңа', 'in_progress': 'Жұмыста', 'completed': 'Дайын'};
    return (lang == 'ru' ? ru[status] : kz[status]) ?? status ?? '...';
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'new': return const Color(0xFF2979FF); // Ярко-синий
      case 'in_progress': return Colors.orangeAccent;
      case 'completed': return const Color(0xFF00C853); // Сочный зеленый
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser?.id;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
      valueListenable: appLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: StreamBuilder<List<Map<String, dynamic>>>(
            stream: supabase.from('tasks').stream(primaryKey: ['id']).order('created_at', ascending: false),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Center(child: Text("Ошибка загрузки данных"));
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              
              final tasks = (snapshot.data ?? []).where((t) {
                final bool isWorker = (userRole.value == 'master' || userRole.value == 'contractor');
                final bool isOwner = (t['user_id'] == currentUserId);
                if (!isWorker && !isOwner) return false;

                bool matchesFilter = _selectedFilter == 'all' || 
                                     (_selectedFilter == 'my' && t['assignee_id'] == currentUserId) || 
                                     (t['status'] == _selectedFilter);

                final matchesSearch = (t['title'] ?? '').toString().toLowerCase().contains(_searchQuery);
                return matchesFilter && matchesSearch;
              }).toList();

              return Column(
                children: [
                  _buildHeader(lang, isDark),
                  _buildFilterBar(lang, isDark),
                  Expanded(
                    child: tasks.isEmpty 
                      ? _buildEmptyState(lang)
                      : ListView.builder(
                          itemCount: tasks.length,
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(0, 10, 0, 100),
                          itemBuilder: (context, index) => _taskItem(tasks[index], lang, isDark),
                        ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(String lang, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 15),
      child: Column(
        children: [
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            decoration: InputDecoration(
              hintText: lang == 'ru' ? "Поиск заявок..." : "Іздеу...",
              prefixIcon: const Icon(LucideIcons.search, size: 20, color: Colors.blueAccent),
              filled: true,
              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.transparent)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar(String lang, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Row(
        children: [
          _fChip('all', lang == 'ru' ? 'Все' : 'Барлығы', isDark),
          if (userRole.value != 'user') _fChip('my', lang == 'ru' ? 'Мои' : 'Менің', isDark),
          _fChip('new', lang == 'ru' ? 'Новые' : 'Жаңа', isDark),
          _fChip('in_progress', lang == 'ru' ? 'В работе' : 'Жұмыста', isDark),
          _fChip('completed', lang == 'ru' ? 'Готово' : 'Дайын', isDark),
        ],
      ),
    );
  }

  Widget _fChip(String f, String l, bool isDark) {
    bool isSelected = _selectedFilter == f;
    return Padding(
      padding: const EdgeInsets.only(right: 8), 
      child: ChoiceChip(
        label: Text(l),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
        ),
        selected: isSelected, 
        onSelected: (v) => setState(() => _selectedFilter = f),
        selectedColor: Colors.blueAccent,
        backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
        elevation: 0,
        pressElevation: 0,
        side: BorderSide(color: isSelected ? Colors.blueAccent : Colors.transparent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        checkmarkColor: Colors.white,
      ),
    );
  }

  Widget _taskItem(Map<String, dynamic> task, String lang, bool isDark) {
    final sColor = _getStatusColor(task['status']);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.03) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade100),
        boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => OrderDetailsPage(order: task))),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Иконка категории с подложкой
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(LucideIcons.wrench, color: sColor, size: 24),
              ),
              const SizedBox(width: 16),
              // Инфо о заказе
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(task['title'] ?? 'Без названия', 
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, letterSpacing: -0.5)),
                    const SizedBox(height: 6),
                    Text(task['description'] ?? '', 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis, 
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                    const SizedBox(height: 12),
                    // Статус-тег
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: sColor.withOpacity(0.1), 
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sColor.withOpacity(0.2)),
                      ),
                      child: Text(
                        _translateStatus(task['status'], lang).toUpperCase(), 
                        style: TextStyle(color: sColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                      ),
                    ),
                  ],
                ),
              ),
              // Бадж сообщений
              _chatBadge(task['id']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chatBadge(dynamic taskId) {
    return StreamBuilder(
      stream: supabase.from('messages').stream(primaryKey: ['id']).eq('task_id', taskId),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.length : 0;
        return Column(
          children: [
            const Icon(LucideIcons.chevronRight, color: Colors.grey, size: 20),
            if (count > 0)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.blue]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 5)],
                ),
                child: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(String lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: 0.3,
            child: Icon(LucideIcons.clipboardList, size: 80, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 16),
          Text(lang == 'ru' ? "Заявок пока нет" : "Тапсырыстар жоқ", 
            style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}