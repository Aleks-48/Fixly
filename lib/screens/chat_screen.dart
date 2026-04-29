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
import 'package:flutter/foundation.dart' show kIsWeb;

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
    _initializeChat();
    _messageController.addListener(() {
      final isNotEmpty = _messageController.text.trim().isNotEmpty;
      if (_showSendButton != isNotEmpty) setState(() => _showSendButton = isNotEmpty);
    });
  }

  void _initializeChat() {
    _repairReceiverId();
    _markMessagesAsRead();
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

  // --- ЛОГИКА СТАТУСОВ И СООБЩЕНИЙ ---

  Future<void> _updateTaskStatus(String newStatus) async {
    try {
      if (newStatus == 'completed') {
        _showInvoiceSheet();
        return;
      }

      Map<String, dynamic> updateData = {'status': newStatus, 'master_id': myId};

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
    } catch (e) {
      _showSnackBar("Ошибка изменения статуса", Colors.redAccent);
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
    } catch (_) {}
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
      _messageController.text = text;
      _showSnackBar("Ошибка отправки", Colors.redAccent);
    } finally {
      setState(() => _isSending = false);
    }
  }

  // --- UI КОМПОНЕНТЫ ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F10) : const Color(0xFFF8F9FB),
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
      elevation: 0.5,
      backgroundColor: isDark ? const Color(0xFF1A1A1C) : Colors.white,
      leading: IconButton(
        icon: Icon(LucideIcons.chevronLeft, color: isDark ? Colors.white : Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.blueAccent.withOpacity(0.2),
            child: Text(
              widget.receiverName.isNotEmpty ? widget.receiverName[0].toUpperCase() : "?",
              style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.taskTitle,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.receiverName,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: _updateTaskStatus,
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'traveling', child: Row(children: [Icon(LucideIcons.truck, size: 18), SizedBox(width: 8), Text("Я выехал")])),
            const PopupMenuItem(value: 'working', child: Row(children: [Icon(LucideIcons.wrench, size: 18), SizedBox(width: 8), Text("В работе")])),
            const PopupMenuItem(value: 'completed', child: Row(children: [Icon(LucideIcons.checkCircle, size: 18, color: Colors.green), SizedBox(width: 8), Text("Завершено")])),
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
        if (snapshot.hasError) return const Center(child: Text("Ошибка загрузки чата"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator.adaptive());

        final messages = snapshot.data!;
        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.messageSquare, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text("Напишите первое сообщение", style: TextStyle(color: Colors.grey[500])),
              ],
            ),
          );
        }

        return ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: messages.length,
          itemBuilder: (context, index) => _buildMessageBubble(messages[index]),
        );
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final bool isMe = msg['sender_id'] == myId;
    final bool isSystem = msg['type'] == 'system';
    
    if (isSystem) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(color: Colors.blueAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
          child: Text(msg['content'], textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.blueAccent, fontWeight: FontWeight.w500)),
        ),
      );
    }

    final String time = msg['created_at'] != null
        ? DateFormat('HH:mm').format(DateTime.parse(msg['created_at']).toLocal())
        : '--:--';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? Colors.blueAccent : (isDark ? const Color(0xFF2C2C2E) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [if (!isMe) BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (msg['image_url'] != null && msg['image_url'].isNotEmpty)
              GestureDetector(
                onTap: () => _showFullImage(msg['image_url']),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(msg['image_url'], fit: BoxFit.cover),
                  ),
                ),
              ),
            if (msg['audio_url'] != null && msg['audio_url'].isNotEmpty)
              _buildAudioPlayer(msg),
            if (msg['content'] != null && msg['content'].isNotEmpty && msg['type'] != 'voice')
              Text(
                msg['content'],
                style: TextStyle(color: isMe || isDark ? Colors.white : Colors.black87, fontSize: 15),
              ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Spacer(),
                Text(time, style: TextStyle(color: isMe ? Colors.white70 : Colors.grey, fontSize: 10)),
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
        IconButton(
          constraints: const BoxConstraints(),
          padding: EdgeInsets.zero,
          icon: Icon(isPlaying ? LucideIcons.pauseCircle : LucideIcons.playCircle, 
                color: (msg['sender_id'] == myId) ? Colors.white : Colors.blueAccent, size: 32),
          onPressed: () async {
            if (isPlaying) {
              await _audioPlayer.pause();
              setState(() => _playingAudioId = null);
            } else {
              setState(() => _playingAudioId = msg['id'].toString());
              await _audioPlayer.play(UrlSource(msg['audio_url']));
              _audioPlayer.onPlayerComplete.listen((_) { if (mounted) setState(() => _playingAudioId = null); });
            }
          },
        ),
        const SizedBox(width: 8),
        Text("Голосовой отзыв", style: TextStyle(color: (msg['sender_id'] == myId) ? Colors.white70 : Colors.grey[600], fontSize: 13)),
      ],
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)]
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(icon: const Icon(LucideIcons.paperclip, color: Colors.blueAccent), onPressed: _pickImage),
            Expanded(
              child: TextField(
                controller: _messageController,
                maxLines: 4, minLines: 1,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: _awaitingPortfolioPhoto ? "Отправьте фото работы..." : "Сообщение",
                  hintStyle: const TextStyle(fontSize: 15, color: Colors.grey),
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
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: _isRecording ? Colors.red : Colors.blueAccent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _showSendButton ? LucideIcons.send : (_isRecording ? LucideIcons.stopCircle : LucideIcons.mic),
                  color: Colors.white, size: 22
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- ДОПОЛНИТЕЛЬНЫЕ МЕТОДЫ (MEDIA, LOCATION, ETC) ---

  Future<void> _pickImage() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (img == null) return;
    setState(() => _isSending = true);
    try {
      final bytes = await img.readAsBytes();
      final name = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = 'chat_media/${widget.taskId}/$name';
      await supabase.storage.from('task_images').uploadBinary(path, bytes);
      final url = supabase.storage.from('task_images').getPublicUrl(path);

      await supabase.from('messages').insert({
        'task_id': widget.taskId,
        'sender_id': myId,
        'receiver_id': effectiveReceiverId,
        'image_url': url,
        'content': _awaitingPortfolioPhoto ? 'Фото работы' : '',
        'type': 'image',
      });
      if (_awaitingPortfolioPhoto) {
        await supabase.from('portfolio').insert({'master_id': myId, 'image_url': url});
        setState(() => _awaitingPortfolioPhoto = false);
      }
    } catch (_) {
      _showSnackBar("Ошибка загрузки фото", Colors.redAccent);
    } finally {
      setState(() => _isSending = false);
    }
  }

  Future<void> _startRecording() async {
    if (await _audioRecorder.hasPermission()) {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/v_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _audioRecorder.start(const RecordConfig(), path: path);
      setState(() => _isRecording = true);
    }
  }

  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() => _isRecording = false);
    if (path == null) return;

    setState(() => _isSending = true);
    try {
      final file = File(path);
      final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await supabase.storage.from('task_images').uploadBinary('audio/$fileName', await file.readAsBytes());
      final url = supabase.storage.from('task_images').getPublicUrl('audio/$fileName');

      await supabase.from('messages').insert({
        'task_id': widget.taskId, 'sender_id': myId, 'receiver_id': effectiveReceiverId,
        'audio_url': url, 'content': 'Голосовое сообщение', 'type': 'voice',
      });
    } catch (_) {
      _showSnackBar("Ошибка записи", Colors.redAccent);
    } finally {
      setState(() => _isSending = false);
    }
  }

  void _showInvoiceSheet() {
    final laborCtrl = TextEditingController();
    final partsCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, top: 20, left: 20, right: 20),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF17212D) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text("Выставление счета", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(controller: laborCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Стоимость работы (₸)", prefixIcon: Icon(LucideIcons.wrench))),
          const SizedBox(height: 12),
          TextField(controller: partsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Запчасти / Материалы (₸)", prefixIcon: Icon(LucideIcons.package))),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 56, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () async {
              final labor = int.tryParse(laborCtrl.text) ?? 0;
              final parts = int.tryParse(partsCtrl.text) ?? 0;
              final total = labor + parts;
              await supabase.from('tasks').update({'status': 'completed', 'final_price': total, 'payment_status': 'waiting_confirm'}).eq('id', widget.taskId);
              await _sendSystemMessage("🧾 ВЫСТАВЛЕН СЧЕТ\nРабота: $labor ₸\nМатериалы: $parts ₸\nИТОГО: $total ₸");
              Navigator.pop(context);
              setState(() => _awaitingPortfolioPhoto = true);
            },
            child: const Text("Отправить клиенту", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          )),
        ]),
      ),
    );
  }

  void _markMessagesAsRead() async {
    try {
      await supabase.from('messages').update({'is_read': true}).eq('task_id', widget.taskId).neq('sender_id', myId);
    } catch (_) {}
  }

  Future<void> _startLocationTracking() async {
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      try {
        Position pos = await Geolocator.getCurrentPosition();
        await supabase.from('tasks').update({'master_lat': pos.latitude, 'master_lng': pos.longitude}).eq('id', widget.taskId);
      } catch (_) {}
    });
  }

  void _stopLocationTracking() => _locationTimer?.cancel();

  void _openCall(bool video) => Navigator.push(context, MaterialPageRoute(builder: (_) => CallScreen(taskId: widget.taskId, hasVideo: video, userName: widget.receiverName, avatarUrl: '', remoteUserId: '', remoteUserName: '', taskTitle: '', isIncoming: false,)));

  void _showSnackBar(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), backgroundColor: color, behavior: SnackBarBehavior.floating));
  }

  void _showFullImage(String url) {
    showDialog(context: context, builder: (_) => Dialog.fullscreen(child: Stack(children: [Image.network(url, fit: BoxFit.contain, width: double.infinity, height: double.infinity), Positioned(top: 40, right: 20, child: IconButton(icon: const Icon(Icons.close, color: Colors.white, size: 30), onPressed: () => Navigator.pop(context)))])));
  }

  Widget _buildStatusStepper() {
    return StreamBuilder(
      stream: supabase.from('tasks').stream(primaryKey: ['id']).eq('id', widget.taskId),
      builder: (context, snapshot) {
        final status = (snapshot.hasData && snapshot.data!.isNotEmpty) ? snapshot.data!.first['status'] : 'open';
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
          color: isDark ? const Color(0xFF1A1A1C) : Colors.white,
          child: Row(
            children: [
              _step('Выезд', ['traveling', 'working', 'completed'].contains(status)),
              _line(['working', 'completed'].contains(status)),
              _step('Работа', ['working', 'completed'].contains(status)),
              _line(status == 'completed'),
              _step('Готово', status == 'completed'),
            ],
          ),
        );
      },
    );
  }

  Widget _step(String label, bool active) => Column(children: [
    Icon(active ? LucideIcons.checkCircle2 : LucideIcons.circle, color: active ? Colors.blueAccent : Colors.grey[300], size: 18),
    const SizedBox(height: 4),
    Text(label, style: TextStyle(fontSize: 10, fontWeight: active ? FontWeight.bold : FontWeight.normal, color: active ? (isDark?Colors.white:Colors.black) : Colors.grey)),
  ]);

  Widget _line(bool active) => Expanded(child: Container(height: 2, color: active ? Colors.blueAccent : Colors.grey[200], margin: const EdgeInsets.symmetric(horizontal: 8)));

  Widget _buildPaymentShield() {
    return StreamBuilder(
      stream: supabase.from('tasks').stream(primaryKey: ['id']).eq('id', widget.taskId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox();
        final d = snapshot.data!.first;
        final reserved = d['payment_status'] == 'reserved';
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0), padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: reserved ? Colors.green.withOpacity(0.08) : Colors.orange.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: reserved ? Colors.green.withOpacity(0.2) : Colors.orange.withOpacity(0.2)),
          ),
          child: Row(children: [
            Icon(reserved ? LucideIcons.shieldCheck : LucideIcons.info, color: reserved ? Colors.green : Colors.orange, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(
                reserved ? "Оплата зарезервирована: ${d['reserved_amount']} ₸" : "Ожидаем резервирование оплаты клиентом",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: reserved ? Colors.green[700] : Colors.orange[800]))),
          ]),
        );
      },
    );
  }

  Widget _buildQuickReplies() {
    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12),
        children: ["Буду через 10 мин", "Выезжаю 🚀", "Нужно фото работы", "Ок 👍"].map((t) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            elevation: 0,
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            side: BorderSide(color: Colors.grey.withOpacity(0.2)),
            label: Text(t, style: const TextStyle(fontSize: 13)),
            onPressed: () {
              if (t.contains("фото")) {
                setState(() => _awaitingPortfolioPhoto = true);
                _showSnackBar("Нажмите на скрепку для фото", Colors.blueAccent);
              } else {
                _messageController.text = t; _sendMessage();
              }
            },
          ),
        )).toList(),
      ),
    );
  }
}