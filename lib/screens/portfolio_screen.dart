import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class MasterPortfolioScreen extends StatelessWidget {
  final String masterId;
  
  const MasterPortfolioScreen({
    super.key, 
    required this.masterId
  });

  // Геттер для проверки UUID (защита от "chat_..." префиксов)
  String get cleanMasterId => masterId.replaceFirst('chat_', '');

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F10), // Темный фон в стиле приложения
        appBar: AppBar(
          elevation: 0,
          title: const Text("Портфолио и отзывы", style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            indicatorColor: Colors.blueAccent,
            indicatorWeight: 3,
            tabs: [
              Tab(icon: Icon(Icons.star_rounded), text: "Отзывы"),
              Tab(icon: Icon(Icons.photo_library_rounded), text: "Работы"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildReviewsTab(),
            _buildGalleryTab(),
          ],
        ),
      ),
    );
  }

  // --- ВКЛАДКА ОТЗЫВОВ ---
  Widget _buildReviewsTab() {
    final supabase = Supabase.instance.client;
    
    return StreamBuilder<List<Map<String, dynamic>>>(
      // Исправленный стрим с сортировкой
      stream: supabase
          .from('reviews')
          .stream(primaryKey: ['id'])
          .eq('master_id', cleanMasterId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Ошибка: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final reviews = snapshot.data!;
        if (reviews.isEmpty) {
          return const Center(
            child: Text("Отзывов пока нет", style: TextStyle(color: Colors.grey))
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          itemBuilder: (context, i) {
            final r = reviews[i];
            final DateTime? date = r['created_at'] != null ? DateTime.parse(r['created_at']) : null;
            
            return Card(
              color: const Color(0xFF1C1C1E),
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: List.generate(5, (index) => Icon(
                            Icons.star_rounded, 
                            size: 18, 
                            color: index < (r['rating'] ?? 0) ? Colors.amber : Colors.grey[700]
                          )),
                        ),
                        if (date != null)
                          Text(
                            DateFormat('dd.MM.yyyy').format(date),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      r['comment'] ?? 'Без комментария', 
                      style: const TextStyle(fontSize: 15, color: Colors.white, height: 1.4)
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- ВКЛАДКА ГАЛЕРЕИ ---
  Widget _buildGalleryTab() {
    final supabase = Supabase.instance.client;

    return FutureBuilder<List<Map<String, dynamic>>>(
      // ВАЖНО: Мы ищем и в 'portfolio', и в выполненных 'tasks'
      future: _fetchMasterWorks(supabase),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final works = snapshot.data ?? [];
        if (works.isEmpty) {
          return const Center(
            child: Text("Галерея работ пуста", style: TextStyle(color: Colors.grey))
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, 
            crossAxisSpacing: 12, 
            mainAxisSpacing: 12,
            childAspectRatio: 1,
          ),
          itemCount: works.length,
          itemBuilder: (context, i) {
            final work = works[i];
            final String? imageUrl = work['image_url'];
            
            return ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    Image.network(
                      imageUrl, 
                      fit: BoxFit.cover,
                      errorBuilder: (context, e, s) => Container(
                        color: Colors.grey[900],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    )
                  else
                    Container(color: Colors.grey[900]),
                  
                  if (work['video_url'] != null)
                    const Center(child: Icon(Icons.play_circle_fill, size: 45, color: Colors.white70)),
                  
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                        ),
                      ),
                      child: Text(
                        work['title'] ?? 'Работа мастера', 
                        style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Метод для сбора работ из разных таблиц
  Future<List<Map<String, dynamic>>> _fetchMasterWorks(SupabaseClient supabase) async {
    try {
      // 1. Берем из таблицы портфолио (то, что мастер грузил в чате)
      final portfolioData = await supabase
          .from('portfolio')
          .select('image_url, created_at')
          .eq('master_id', cleanMasterId);

      // 2. Берем из завершенных задач
      final tasksData = await supabase
          .from('tasks')
          .select('image_url, video_url, title')
          .eq('assignee_id', cleanMasterId)
          .eq('status', 'completed')
          .not('image_url', 'is', null);

      // Объединяем результаты
      return [...portfolioData, ...tasksData];
    } catch (e) {
      debugPrint("Ошибка загрузки работ: $e");
      return [];
    }
  }
}