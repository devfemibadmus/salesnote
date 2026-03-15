part of '../models.dart';

class LiveAgentSession {
  LiveAgentSession({
    required this.model,
    required this.ephemeralAuthToken,
    required this.sessionExpiresAt,
    required this.newSessionExpiresAt,
    required this.reservedTokenBudget,
    required this.tokensUsed,
    required this.tokensAvailable,
    required this.systemInstruction,
    required this.contract,
  });

  final String model;
  final String ephemeralAuthToken;
  final String sessionExpiresAt;
  final String newSessionExpiresAt;
  final int reservedTokenBudget;
  final int tokensUsed;
  final int tokensAvailable;
  final String systemInstruction;
  final LiveAgentContract contract;

  factory LiveAgentSession.fromJson(dynamic json) {
    return LiveAgentSession(
      model: (json['model'] as String? ?? '').trim(),
      ephemeralAuthToken: (json['ephemeral_auth_token'] as String? ?? '')
          .trim(),
      sessionExpiresAt: (json['session_expires_at'] as String? ?? '').trim(),
      newSessionExpiresAt: (json['new_session_expires_at'] as String? ?? '')
          .trim(),
      reservedTokenBudget:
          (json['reserved_token_budget'] as num?)?.toInt() ?? 0,
      tokensUsed: (json['tokens_used'] as num?)?.toInt() ?? 0,
      tokensAvailable: (json['tokens_available'] as num?)?.toInt() ?? 0,
      systemInstruction: (json['system_instruction'] as String? ?? '').trim(),
      contract: LiveAgentContract.fromJson(json['contract'] ?? const {}),
    );
  }
}

class LiveAgentContract {
  LiveAgentContract({
    this.pages = const <LiveAgentPage>[],
    this.forms = const <LiveAgentForm>[],
    this.actions = const <LiveAgentAction>[],
    this.guardrails = const <String>[],
  });

  final List<LiveAgentPage> pages;
  final List<LiveAgentForm> forms;
  final List<LiveAgentAction> actions;
  final List<String> guardrails;

  factory LiveAgentContract.fromJson(dynamic json) {
    return LiveAgentContract(
      pages: (json['pages'] as List<dynamic>? ?? const [])
          .map(LiveAgentPage.fromJson)
          .toList(),
      forms: (json['forms'] as List<dynamic>? ?? const [])
          .map(LiveAgentForm.fromJson)
          .toList(),
      actions: (json['actions'] as List<dynamic>? ?? const [])
          .map(LiveAgentAction.fromJson)
          .toList(),
      guardrails: (json['guardrails'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class LiveAgentPage {
  LiveAgentPage({required this.id, required this.title, required this.notes});

  final String id;
  final String title;
  final String notes;

  factory LiveAgentPage.fromJson(dynamic json) {
    return LiveAgentPage(
      id: (json['id'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
      notes: (json['notes'] as String? ?? '').trim(),
    );
  }
}

class LiveAgentForm {
  LiveAgentForm({
    required this.id,
    required this.title,
    this.requiredFields = const <String>[],
  });

  final String id;
  final String title;
  final List<String> requiredFields;

  factory LiveAgentForm.fromJson(dynamic json) {
    return LiveAgentForm(
      id: (json['id'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
      requiredFields: (json['required_fields'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

class LiveAgentAction {
  LiveAgentAction({
    required this.name,
    required this.description,
    this.requiredFields = const <String>[],
  });

  final String name;
  final String description;
  final List<String> requiredFields;

  factory LiveAgentAction.fromJson(dynamic json) {
    return LiveAgentAction(
      name: (json['name'] as String? ?? '').trim(),
      description: (json['description'] as String? ?? '').trim(),
      requiredFields: (json['required_fields'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
