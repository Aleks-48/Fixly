import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'building_context_service.dart';

class VotingService {
  static SupabaseClient get _sb => Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> listForCurrentBuilding({
    String status = 'active',
  }) async {
    final context = await BuildingContextService.loadCurrent();
    final buildingId = context?.buildingId;
    if (buildingId == null || buildingId.isEmpty) return [];

    dynamic query = _sb
        .from('proposals')
        .select()
        .eq('building_id', buildingId)
        .order('created_at', ascending: false);

    if (status != 'all') {
      query = query.eq('status', status);
    }

    final response = await query.limit(100);
    return List<Map<String, dynamic>>.from(response as List);
  }

  static Future<Map<String, dynamic>> createProposal({
    required String title,
    String? description,
    int days = 7,
    String status = 'active',
  }) async {
    final context = await BuildingContextService.loadCurrent();
    final user = _sb.auth.currentUser;
    if (context == null || user == null) {
      throw StateError('Пользователь не авторизован');
    }
    if (!context.canManageHouse || !context.hasBuilding) {
      throw StateError('Нет подтвержденных прав на управление домом');
    }

    final now = DateTime.now();
    final row = await _sb
        .from('proposals')
        .insert({
          'title': title.trim(),
          'description': description?.trim(),
          'building_id': context.buildingId,
          'author_id': user.id,
          'created_by': user.id,
          'status': status,
          'is_active': status == 'active',
          'start_at': now.toIso8601String(),
          'end_at': now.add(Duration(days: days)).toIso8601String(),
          'quorum_rule': 'simple_majority',
          'created_at': now.toIso8601String(),
        })
        .select()
        .single();

    return Map<String, dynamic>.from(row);
  }

  static Future<void> submitVote({
    required String proposalId,
    required String choice,
    required Uint8List signatureBytes,
  }) async {
    final context = await BuildingContextService.loadCurrent();
    final user = _sb.auth.currentUser;
    if (context == null || user == null) {
      throw StateError('Пользователь не авторизован');
    }
    if (!context.hasBuilding ||
        context.apartmentId == null ||
        !context.isVerifiedMember) {
      throw StateError(
          'Голосовать можно только после подтверждения дома и квартиры');
    }
    if (await hasCurrentUserVoted(proposalId)) {
      throw StateError('Вы уже голосовали по этому вопросу');
    }

    final signatureHash = sha256.convert(signatureBytes).toString();
    final storagePath = 'votes/$proposalId/${user.id}.png';
    await _sb.storage.from('documents').uploadBinary(
          storagePath,
          signatureBytes,
          fileOptions: const FileOptions(
            upsert: true,
            contentType: 'image/png',
          ),
        );

    final signatureUrl =
        _sb.storage.from('documents').getPublicUrl(storagePath);
    final now = DateTime.now().toIso8601String();
    final displayName = context.profile['full_name']?.toString() ??
        context.profile['name']?.toString() ??
        context.profile['first_name']?.toString();

    await _sb.from('votes').insert({
      'proposal_id': proposalId,
      'user_id': user.id,
      'building_id': context.buildingId,
      'apartment_id': context.apartmentId,
      'apartment': context.apartmentNumber,
      'full_name': displayName,
      'choice': choice,
      'decision': choice,
      'signature_url': signatureUrl,
      'signature_hash': signatureHash,
      'voted_at': now,
      'created_at': now,
    });
  }

  static Future<bool> hasCurrentUserVoted(String proposalId) async {
    final user = _sb.auth.currentUser;
    if (user == null || proposalId.isEmpty) return false;
    final vote = await _sb
        .from('votes')
        .select('id')
        .eq('proposal_id', proposalId)
        .eq('user_id', user.id)
        .maybeSingle();
    return vote != null;
  }

  static Future<List<Map<String, dynamic>>> votesForProposal(
    String proposalId,
  ) async {
    final response = await _sb
        .from('votes')
        .select()
        .eq('proposal_id', proposalId)
        .order('voted_at', ascending: false);
    return List<Map<String, dynamic>>.from(response as List);
  }

  static Future<Map<String, dynamic>?> getUserVote({
    required String proposalId,
    required String userId,
  }) async {
    try {
      return await _sb
          .from('votes')
          .select()
          .eq('proposal_id', proposalId)
          .eq('user_id', userId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }
}
