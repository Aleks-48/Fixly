import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MasterPortfolioScreen extends StatelessWidget {
  final String masterId;
  const MasterPortfolioScreen({super.key, required this.masterId});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Портфолио и отзывы"),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.star), text: "Отзывы"),
              Tab(icon: Icon(Icons.photo_library), text: "Работы"),
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
      stream: supabase.from('reviews').stream(primaryKey: ['id']).eq('master_id', masterId).order('created_at'),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final reviews = snapshot.data!;
        if (reviews.isEmpty) return const Center(child: Text("Отзывов пока нет"));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reviews.length,
          itemBuilder: (context, i) {
            final r = reviews[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: ListTile(
                title: Row(
                  children: List.generate(5, (index) => Icon(
                    Icons.star, 
                    size: 16, 
                    color: index < r['rating'] ? Colors.amber : Colors.grey[300]
                  )),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(r['comment'] ?? '', style: const TextStyle(fontSize: 16, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(r['created_at'].toString().substring(0, 10), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- ВКЛАДКА ГАЛЕРЕИ (Фото и Видео) ---
  Widget _buildGalleryTab() {
    final supabase = Supabase.instance.client;
    // Тянем все выполненные задачи мастера, где есть фото/видео
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: supabase.from('tasks')
          .select('image_url, video_url, title')
          .eq('assignee_id', masterId)
          .eq('status', 'completed')
          .not('image_url', 'is', null),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final works = snapshot.data!;
        if (works.isEmpty) return const Center(child: Text("Галерея пуста"));

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10,
          ),
          itemCount: works.length,
          itemBuilder: (context, i) {
            final work = works[i];
            return ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(work['image_url'], fit: BoxFit.cover),
                  if (work['video_url'] != null)
                    const Center(child: Icon(Icons.play_circle_fill, size: 40, color: Colors.white70)),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      color: Colors.black54,
                      child: Text(work['title'], style: const TextStyle(fontSize: 10, color: Colors.white), textAlign: TextAlign.center),
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
}