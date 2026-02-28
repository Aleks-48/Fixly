import 'dart:io' show File;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fixly_app/screens/call_screen.dart';

class ChatScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final String receiverId;
  final String receiverName;

  const ChatScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _awaitingPortfolioPhoto = false;
  bool _isSending = false;
  bool _showSendButton = false;
  bool _isRecording = false;
  String? _playingAudioId;
  Timer? _locationTimer;
  String? _detectedReceiverId;

  String get myId => supabase.auth.currentUser?.id ?? '';
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  String get effectiveReceiverId {
    final id = (widget.receiverId.isEmpty || widget.receiverId == "null")
        ? _detectedReceiverId
        : widget.receiverId;
    return id ?? "";
  }

  @override
  void initState() {
    super.initState();
    _detectedReceiverId = widget.receiverId;
    _repairReceiverId();
    _markMessagesAsRead();
    _messageController.addListener(() {
      final isNotEmpty = _messageController.text.trim().isNotEmpty;
      if (_showSendButton != isNotEmpty) setState(() => _showSendButton = isNotEmpty);
    });
  }

  Future<void> _repairReceiverId() async {
    if (effectiveReceiverId.isNotEmpty && effectiveReceiverId != "null") return;
    try {
      final data = await supabase.from('tasks')
          .select('client_id, master_id, chairman_id, user_id, assignee_id')
          .eq('id', widget.taskId)
          .single();

      if (mounted) {
        setState(() {
          if (data['user_id'] == myId) {
            _detectedReceiverId = data['master_id'] ?? data['assignee_id'] ?? data['chairman_id'];
          } else {
            _detectedReceiverId = data['user_id'] ?? data['client_id'] ?? data['chairman_id'];
          }
        });
      }
    } catch (e) {
      debugPrint("Error repairing receiver ID: $e");
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _messageController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _updateTaskStatus(String newStatus) async {
    try {
      if (newStatus == 'completed') {
        _showInvoiceSheet();
        return;
      }

      Map<String, dynamic> updateData = {'status': newStatus};
      updateData['master_id'] = myId;

      if (newStatus == 'traveling') {
        final taskData = await supabase.from('tasks').select('payment_status').eq('id', widget.taskId).single();
        if (taskData['payment_status'] != 'reserved') {
          _showSnackBar("⚠️ Клиент еще не зарезервировал оплату!", Colors.orange);
          return;
        }
        await _startLocationTracking();
        await _sendSystemMessage("🚀 Я выехал к вам!");
      } else {
        _stopLocationTracking();
      }

      await supabase.from('tasks').update(updateData).eq('id', widget.taskId);
      _repairReceiverId();
    } catch (e) {
      _showSnackBar("Ошибка статуса: $e", Colors.redAccent);
    }
  }

  Future<void> _sendSystemMessage(String text) async {
    if (effectiveReceiverId.isEmpty) await _repairReceiverId();
    if (effectiveReceiverId.isEmpty) return;

    try {
      await supabase.from('messages').insert({
        'task_id': widget.taskId,
        'content': text,
        'sender_id': myId,
        'receiver_id': effectiveReceiverId,
        'type': 'system',
        'is_read': false,
        'is_deleted': false,
      });
    } catch (e) {
      debugPrint("System message error: $e");
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (effectiveReceiverId.isEmpty) await _repairReceiverId();
    if (effectiveReceiverId.isEmpty) {
      _showSnackBar("Собеседник не определен", Colors.redAccent);
      return;
    }

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      await supabase.from('messages').insert({
        'task_id': widget.taskId,
        'sender_id': myId,
        'receiver_id': effectiveReceiverId,
        'content': text,
        'type': 'text',
        'is_read': false,
        'is_deleted': false,
      });
    } catch (e) {
      debugPrint("Ошибка отправки: $e");
      _showSnackBar("Ошибка отправки", Colors.redAccent);
      _messageController.text = text;
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F10) : const Color(0xFFF2F3F5),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildStatusStepper(),
          _buildPaymentShield(),
          if (_isSending) const LinearProgressIndicator(minHeight: 2, backgroundColor: Colors.transparent),
          Expanded(child: _buildMessagesList()),
          _buildQuickReplies(),
          _buildInputArea(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: isDark ? const Color(0xFF17212D) : Colors.white,
      leading: IconButton(
        icon: const Icon(LucideIcons.chevronLeft),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF64B5F6), Color(0xFF1976D2)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : "?",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.taskTitle,
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const Text("онлайн • Специалист", style: TextStyle(fontSize: 11, color: Colors.greenAccent)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(icon: const Icon(LucideIcons.phone, size: 20), onPressed: () => _openCall(false)),
        IconButton(icon: const Icon(LucideIcons.video, size: 20), onPressed: () => _openCall(true)),
        PopupMenuButton<String>(
          icon: const Icon(LucideIcons.moreVertical),
          onSelected: _updateTaskStatus,
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'traveling', child: Text("🚀 Я выехал")),
            const PopupMenuItem(value: 'working', child: Text("🛠 В работе")),
            const PopupMenuItem(value: 'completed', child: Text("✅ Завершено")),
          ],
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: supabase
          .from('messages')
          .stream(primaryKey: ['id'])
          .eq('task_id', widget.taskId)
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Ошибка: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final messages = snapshot.data!;
        if (messages.isEmpty) {
          return const Center(child: Text("Сообщений пока нет", style: TextStyle(color: Colors.grey)));
        }

        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) => _buildMessageBubble(messages[index]),
        );
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final bool isMe = msg['sender_id'] == myId;
    final String time = msg['created_at'] != null
        ? DateFormat('HH:mm').format(DateTime.parse(msg['created_at']).toLocal())
        : '--:--';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: isMe ? Colors.blueAccent : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            if (!isMe) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg['image_url'] != null && msg['image_url'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    msg['image_url'],
                    loadingBuilder: (context, child, loadingProgress) =>
                    loadingProgress == null ? child : const SizedBox(height: 150, child: Center(child: CircularProgressIndicator())),
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                  ),
                ),
              ),
            if (msg['audio_url'] != null && msg['audio_url'].toString().isNotEmpty)
              _buildAudioPlayer(msg),
            if (msg['content'] != null && msg['content'].toString().isNotEmpty)
              Text(
                msg['content'],
                style: TextStyle(color: isMe || isDark ? Colors.white : Colors.black, fontSize: 15),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spacer(),
                Text(time, style: TextStyle(color: isMe ? Colors.white60 : Colors.grey, fontSize: 10)),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(msg['is_read'] == true ? Icons.done_all : Icons.done, size: 14, color: Colors.white70),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayer(Map<String, dynamic> msg) {
    final bool isPlaying = _playingAudioId == msg['id'].toString();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () async {
            try {
              if (isPlaying) {
                await _audioPlayer.pause();
                setState(() => _playingAudioId = null);
              } else {
                setState(() => _playingAudioId = msg['id'].toString());
                await _audioPlayer.play(UrlSource(msg['audio_url']));
                _audioPlayer.onPlayerComplete.listen((event) {
                  if (mounted) setState(() => _playingAudioId = null);
                });
              }
            } catch (e) {
              _showSnackBar("Ошибка воспроизведения", Colors.redAccent);
            }
          },
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white24,
            child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 8),
        const Text("Голосовое сообщение", style: TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: isDark ? const Color(0xFF17212D) : Colors.white,
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
                icon: const Icon(LucideIcons.paperclip, color: Colors.blueAccent),
                onPressed: _pickImage
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLines: 4,
                minLines: 1,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: _awaitingPortfolioPhoto ? "Прикрепите фото работы..." : "Сообщение",
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onLongPressStart: (_) => _startRecording(),
              onLongPressEnd: (_) => _stopRecording(),
              onTap: _showSendButton ? _sendMessage : null,
              child: CircleAvatar(
                radius: 24,
                backgroundColor: _isRecording ? Colors.red : Colors.blueAccent,
                child: Icon(
                    _showSendButton ? Icons.send : (_isRecording ? Icons.stop : LucideIcons.mic),
                    color: Colors.white,
                    size: 20
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInvoiceSheet() {
    final laborCtrl = TextEditingController();
    final partsCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF17212D) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Формирование счета", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          const SizedBox(height: 16),
          TextField(controller: laborCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Стоимость работы (₸)")),
          TextField(controller: partsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Материалы (₸)")),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 50, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () async {
              final labor = int.tryParse(laborCtrl.text) ?? 0;
              final parts = int.tryParse(partsCtrl.text) ?? 0;
              final total = labor + parts;

              try {
                await supabase.from('tasks').update({
                  'status': 'completed',
                  'final_price': total,
                  'payment_status': 'waiting_confirm',
                  'master_id': myId
                }).eq('id', widget.taskId);

                await _sendSystemMessage("🧾 СЧЕТ ВЫСТАВЛЕН\n🛠 Работа: $labor ₸\n📦 Материалы: $parts ₸\n💰 ИТОГО: $total ₸");

                if (mounted) Navigator.pop(context);
                setState(() => _awaitingPortfolioPhoto = true);
              } catch (e) {
                _showSnackBar("Ошибка при выставлении счета", Colors.redAccent);
              }
            },
            child: const Text("Отправить чек", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )),
        ]),
      ),
    );
  }

  Future<void> _pickImage() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (img == null) return;

    if (effectiveReceiverId.isEmpty) await _repairReceiverId();
    if (effectiveReceiverId.isEmpty) {
      _showSnackBar("Ошибка: Получатель не найден", Colors.redAccent);
      return;
    }

    setState(() => _isSending = true);
    try {
      final bytes = await img.readAsBytes();
      final name = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'chat_media/${widget.taskId}/$name';

      await supabase.storage.from('task_images').uploadBinary(path, bytes);
      final url = supabase.storage.from('task_images').getPublicUrl(path);

      await supabase.from('messages').insert({
        'task_id': widget.taskId,
        'sender_id': myId,
        'receiver_id': effectiveReceiverId,
        'image_url': url,
        'content': _awaitingPortfolioPhoto ? 'Фото выполненной работы' : '',
        'type': 'image',
        'is_read': false,
        'is_deleted': false,
      });

      if (_awaitingPortfolioPhoto) {
        await supabase.from('portfolio').insert({'master_id': myId, 'image_url': url});
        setState(() => _awaitingPortfolioPhoto = false);
      }
    } catch (e) {
      _showSnackBar("Ошибка загрузки", Colors.redAccent);
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final dir = await getTemporaryDirectory();
        final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        await _audioRecorder.start(const RecordConfig(), path: path);
        setState(() => _isRecording = true);
      }
    } catch (e) {
      debugPrint("Record error: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);
      if (path == null) return;

      if (effectiveReceiverId.isEmpty) await _repairReceiverId();
      setState(() => _isSending = true);
      final file = File(path);
      final bytes = await file.readAsBytes();
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      final storagePath = 'audio/$fileName';

      await supabase.storage.from('task_images').uploadBinary(storagePath, bytes);
      final url = supabase.storage.from('task_images').getPublicUrl(storagePath);

      await supabase.from('messages').insert({
        'task_id': widget.taskId,
        'sender_id': myId,
        'receiver_id': effectiveReceiverId,
        'audio_url': url,
        'content': 'Голосовое сообщение',
        'type': 'voice',
        'is_read': false,
        'is_deleted': false,
      });
    } catch (e) {
      _showSnackBar("Ошибка записи", Colors.redAccent);
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _startLocationTracking() async {
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      try {
        Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        await supabase.from('tasks').update({
          'master_lat': pos.latitude,
          'master_lng': pos.longitude
        }).eq('id', widget.taskId);
      } catch (_) {}
    });
  }

  void _stopLocationTracking() => _locationTimer?.cancel();

  void _markMessagesAsRead() async {
    try {
      await supabase.from('messages')
          .update({'is_read': true})
          .eq('task_id', widget.taskId)
          .neq('sender_id', myId);
    } catch (_) {}
  }

  void _openCall(bool video) => Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(taskId: widget.taskId, hasVideo: video, userName: '', avatarUrl: '',)));

  void _showSnackBar(String text, Color color) {
    if(!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _buildStatusStepper() {
    return StreamBuilder(
      stream: supabase.from('tasks').stream(primaryKey: ['id']).eq('id', widget.taskId),
      builder: (context, snapshot) {
        final status = (snapshot.data != null && snapshot.data!.isNotEmpty) ? snapshot.data!.first['status'] : 'open';
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          color: isDark ? const Color(0xFF17212D) : Colors.white,
          child: Row(
            children: [
              _step('Поиск', true), _line(status != 'open'),
              _step('В пути', ['traveling', 'working', 'completed'].contains(status)),
              _line(['working', 'completed'].contains(status)),
              _step('В работе', ['working', 'completed'].contains(status)),
              _line(status == 'completed'),
              _step('Готово', status == 'completed'),
            ],
          ),
        );
      },
    );
  }

  Widget _step(String label, bool active) => Column(children: [
    Icon(active ? LucideIcons.checkCircle2 : LucideIcons.circle, color: active ? Colors.blueAccent : Colors.grey, size: 16),
    const SizedBox(height: 4),
    Text(label, style: TextStyle(fontSize: 9, fontWeight: active ? FontWeight.bold : FontWeight.normal, color: active ? (isDark?Colors.white:Colors.black) : Colors.grey)),
  ]);

  Widget _line(bool active) => Expanded(child: Container(height: 2, color: active ? Colors.blueAccent : Colors.grey.withOpacity(0.2), margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8)));

  Widget _buildPaymentShield() {
    return StreamBuilder(
      stream: supabase.from('tasks').stream(primaryKey: ['id']).eq('id', widget.taskId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
        final d = snapshot.data!.first;
        final reserved = d['payment_status'] == 'reserved';
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: (reserved ? Colors.green : Colors.orange).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: (reserved ? Colors.green : Colors.orange).withOpacity(0.3), width: 1),
          ),
          child: Row(children: [
            Icon(reserved ? LucideIcons.shieldCheck : LucideIcons.shieldAlert, color: reserved ? Colors.green : Colors.orange, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(
                reserved ? "Оплата зарезервирована (${d['reserved_amount'] ?? 0} ₸)." : "Ожидание резервирования оплаты.",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: reserved ? (isDark ? Colors.greenAccent : Colors.green[700]) : (isDark ? Colors.orangeAccent : Colors.orange[800])))),
          ]),
        );
      },
    );
  }

  Widget _buildQuickReplies() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
        children: ["Буду через 15 мин", "Выезжаю 🚀", "Нужно фото", "Ок 👍"].map((t) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            backgroundColor: isDark ? Colors.grey[850] : Colors.white,
            label: Text(t, style: const TextStyle(fontSize: 13)),
            onPressed: () {
              if (t == "Нужно фото") {
                setState(() => _awaitingPortfolioPhoto = true);
                _showSnackBar("Прикрепите фото работы через скрепку", Colors.blue);
              } else {
                _messageController.text = t;
                _sendMessage();
              }
            },
          ),
        )).toList(),
      ),
    );
  }
}