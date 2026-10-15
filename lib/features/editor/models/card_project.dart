import 'card_template.dart';
import 'package:grimoire_studio/core/constants/app_constants.dart';

class CardProject {
  final String id;
  final String name;
  final double widthMm;
  final double heightMm;
  final List<CardTemplate> templates;
  final int activeTemplateIndex;
  final List<Map<String, dynamic>> rows;
  final int activeRowIndex;
  final String? savePath;

  const CardProject({
    required this.id,
    required this.name,
    this.widthMm = AppConstants.pokerWidthMm,
    this.heightMm = AppConstants.pokerHeightMm,
    this.templates = const [],
    this.activeTemplateIndex = 0,
    this.rows = const [],
    this.activeRowIndex = 0,
    this.savePath,
  });

  CardTemplate get activeTemplate {
    if (templates.isEmpty) {
      return const CardTemplate(id: 'default', name: 'Default');
    }
    if (activeTemplateIndex >= 0 && activeTemplateIndex < templates.length) {
      return templates[activeTemplateIndex];
    }
    return templates.first;
  }

  Map<String, dynamic> get activeRow {
    if (rows.isEmpty) return {};
    if (activeRowIndex >= 0 && activeRowIndex < rows.length) {
      return rows[activeRowIndex];
    }
    return rows.first;
  }

  CardProject copyWith({
    String? id,
    String? name,
    double? widthMm,
    double? heightMm,
    List<CardTemplate>? templates,
    int? activeTemplateIndex,
    List<Map<String, dynamic>>? rows,
    int? activeRowIndex,
    String? savePath,
  }) {
    return CardProject(
      id: id ?? this.id,
      name: name ?? this.name,
      widthMm: widthMm ?? this.widthMm,
      heightMm: heightMm ?? this.heightMm,
      templates: templates ?? this.templates,
      activeTemplateIndex: activeTemplateIndex ?? this.activeTemplateIndex,
      rows: rows ?? this.rows,
      activeRowIndex: activeRowIndex ?? this.activeRowIndex,
      savePath: savePath ?? this.savePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'widthMm': widthMm,
      'heightMm': heightMm,
      'templates': templates.map((t) => t.toJson()).toList(),
      'activeTemplateIndex': activeTemplateIndex,
      'rows': rows,
      'activeRowIndex': activeRowIndex,
      'savePath': savePath,
    };
  }

  factory CardProject.fromJson(Map<String, dynamic> json) {
    return CardProject(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Untitled Project',
      widthMm: (json['widthMm'] as num?)?.toDouble() ?? AppConstants.pokerWidthMm,
      heightMm: (json['heightMm'] as num?)?.toDouble() ?? AppConstants.pokerHeightMm,
      templates: (json['templates'] as List<dynamic>?)
              ?.map((t) => CardTemplate.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
      activeTemplateIndex: json['activeTemplateIndex'] as int? ?? 0,
      rows: (json['rows'] as List<dynamic>?)
              ?.map((r) => Map<String, dynamic>.from(r as Map))
              .toList() ??
          [],
      activeRowIndex: json['activeRowIndex'] as int? ?? 0,
      savePath: json['savePath'] as String?,
    );
  }
}
