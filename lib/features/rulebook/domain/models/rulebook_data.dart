class RulebookComponentItem {
  final String name;
  final int quantity;
  final String category;
  final String description;

  const RulebookComponentItem({
    required this.name,
    this.quantity = 1,
    this.category = 'Carta',
    this.description = '',
  });

  RulebookComponentItem copyWith({
    String? name,
    int? quantity,
    String? category,
    String? description,
  }) {
    return RulebookComponentItem(
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      category: category ?? this.category,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'category': category,
        'description': description,
      };

  factory RulebookComponentItem.fromJson(Map<String, dynamic> json) {
    return RulebookComponentItem(
      name: json['name'] as String? ?? 'Componente',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      category: json['category'] as String? ?? 'Carta',
      description: json['description'] as String? ?? '',
    );
  }
}

class RulebookPhase {
  final int phaseNumber;
  final String name;
  final String shortSummary;
  final String details;

  const RulebookPhase({
    required this.phaseNumber,
    required this.name,
    required this.shortSummary,
    this.details = '',
  });

  RulebookPhase copyWith({
    int? phaseNumber,
    String? name,
    String? shortSummary,
    String? details,
  }) {
    return RulebookPhase(
      phaseNumber: phaseNumber ?? this.phaseNumber,
      name: name ?? this.name,
      shortSummary: shortSummary ?? this.shortSummary,
      details: details ?? this.details,
    );
  }

  Map<String, dynamic> toJson() => {
        'phaseNumber': phaseNumber,
        'name': name,
        'shortSummary': shortSummary,
        'details': details,
      };

  factory RulebookPhase.fromJson(Map<String, dynamic> json) {
    return RulebookPhase(
      phaseNumber: (json['phaseNumber'] as num?)?.toInt() ?? 1,
      name: json['name'] as String? ?? 'Fase',
      shortSummary: json['shortSummary'] as String? ?? '',
      details: json['details'] as String? ?? '',
    );
  }
}

class RulebookFaqItem {
  final String question;
  final String answer;

  const RulebookFaqItem({
    required this.question,
    required this.answer,
  });

  RulebookFaqItem copyWith({
    String? question,
    String? answer,
  }) {
    return RulebookFaqItem(
      question: question ?? this.question,
      answer: answer ?? this.answer,
    );
  }

  Map<String, dynamic> toJson() => {
        'question': question,
        'answer': answer,
      };

  factory RulebookFaqItem.fromJson(Map<String, dynamic> json) {
    return RulebookFaqItem(
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
    );
  }
}

class RulebookData {
  final String gameName;
  final String subtitle;
  final String version;
  final String author;
  final String targetPlayers;
  final String playTime;
  final String ageRating;
  final String introduction;
  final String objective;
  final List<RulebookComponentItem> components;
  final List<String> setupSteps;
  final List<RulebookPhase> turnPhases;
  final Map<String, String> cardAnatomy;
  final Map<String, String> glossary;
  final List<RulebookFaqItem> faqs;

  const RulebookData({
    required this.gameName,
    this.subtitle = 'Manual Oficial de Reglas',
    this.version = '1.0',
    this.author = 'Grimoire Studio',
    this.targetPlayers = '2 a 4 Jugadores',
    this.playTime = '30 - 45 Min',
    this.ageRating = '12+',
    this.introduction = '',
    this.objective = '',
    this.components = const [],
    this.setupSteps = const [],
    this.turnPhases = const [],
    this.cardAnatomy = const {},
    this.glossary = const {},
    this.faqs = const [],
  });

  RulebookData copyWith({
    String? gameName,
    String? subtitle,
    String? version,
    String? author,
    String? targetPlayers,
    String? playTime,
    String? ageRating,
    String? introduction,
    String? objective,
    List<RulebookComponentItem>? components,
    List<String>? setupSteps,
    List<RulebookPhase>? turnPhases,
    Map<String, String>? cardAnatomy,
    Map<String, String>? glossary,
    List<RulebookFaqItem>? faqs,
  }) {
    return RulebookData(
      gameName: gameName ?? this.gameName,
      subtitle: subtitle ?? this.subtitle,
      version: version ?? this.version,
      author: author ?? this.author,
      targetPlayers: targetPlayers ?? this.targetPlayers,
      playTime: playTime ?? this.playTime,
      ageRating: ageRating ?? this.ageRating,
      introduction: introduction ?? this.introduction,
      objective: objective ?? this.objective,
      components: components ?? this.components,
      setupSteps: setupSteps ?? this.setupSteps,
      turnPhases: turnPhases ?? this.turnPhases,
      cardAnatomy: cardAnatomy ?? this.cardAnatomy,
      glossary: glossary ?? this.glossary,
      faqs: faqs ?? this.faqs,
    );
  }

  Map<String, dynamic> toJson() => {
        'gameName': gameName,
        'subtitle': subtitle,
        'version': version,
        'author': author,
        'targetPlayers': targetPlayers,
        'playTime': playTime,
        'ageRating': ageRating,
        'introduction': introduction,
        'objective': objective,
        'components': components.map((c) => c.toJson()).toList(),
        'setupSteps': setupSteps,
        'turnPhases': turnPhases.map((p) => p.toJson()).toList(),
        'cardAnatomy': cardAnatomy,
        'glossary': glossary,
        'faqs': faqs.map((f) => f.toJson()).toList(),
      };

  factory RulebookData.fromJson(Map<String, dynamic> json) {
    return RulebookData(
      gameName: json['gameName'] as String? ?? 'Grimoire Card Game',
      subtitle: json['subtitle'] as String? ?? 'Manual Oficial de Reglas',
      version: json['version'] as String? ?? '1.0',
      author: json['author'] as String? ?? 'Grimoire Studio',
      targetPlayers: json['targetPlayers'] as String? ?? '2 a 4 Jugadores',
      playTime: json['playTime'] as String? ?? '30 - 45 Min',
      ageRating: json['ageRating'] as String? ?? '12+',
      introduction: json['introduction'] as String? ?? '',
      objective: json['objective'] as String? ?? '',
      components: (json['components'] as List<dynamic>?)
              ?.map((e) => RulebookComponentItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      setupSteps: (json['setupSteps'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      turnPhases: (json['turnPhases'] as List<dynamic>?)
              ?.map((e) => RulebookPhase.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      cardAnatomy: (json['cardAnatomy'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          const {},
      glossary: (json['glossary'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          const {},
      faqs: (json['faqs'] as List<dynamic>?)
              ?.map((e) => RulebookFaqItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// Generates a rich, smart initial rulebook draft dynamically calculated from game card rows
  factory RulebookData.initial({
    required String gameName,
    required List<Map<String, dynamic>> rows,
  }) {
    // 1. Calculate components from rows
    final categoryCounts = <String, int>{};
    // ignore: unused_local_variable
    int totalCards = 0;
    for (final r in rows) {
      final cat = (r['category'] ?? 'General').toString().trim();
      final qty = int.tryParse(r['qty']?.toString() ?? '1') ?? 1;
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + qty;
      totalCards += qty;
    }

    final initialComponents = <RulebookComponentItem>[];
    categoryCounts.forEach((cat, count) {
      initialComponents.add(RulebookComponentItem(
        name: 'Mazo de $cat',
        quantity: count,
        category: cat,
        description: '$count cartas de categoría $cat listas para el juego.',
      ));
    });

    if (initialComponents.isEmpty) {
      initialComponents.add(const RulebookComponentItem(
        name: 'Mazo de Juego Principal',
        quantity: 60,
        category: 'Cartas',
        description: 'Baraja estándar con cartas de criaturas, hechizos y recursos.',
      ));
    }

    return RulebookData(
      gameName: gameName,
      subtitle: 'Manual Oficial de Reglas y Guía Estratégica',
      version: '1.0',
      author: 'Grimoire Studio',
      targetPlayers: '2 - 4 Jugadores',
      playTime: '30 - 45 Min',
      ageRating: '12+',
      introduction:
          'Bienvenido al universo de $gameName. En este juego de cartas coleccionables, cada jugador asume el rol de un estratega legendario forjando poderosas alianzas, invocando entidades extraordinarias y desatando habilidades tácticas en el campo de batalla.',
      objective:
          'El objetivo de $gameName es superar al oponente reduciendo sus puntos de vida a 0 o completando las condiciones de victoria de tu mazo antes que tus rivales.',
      components: initialComponents,
      setupSteps: [
        'Cada jugador baraja su mazo de juego de forma exhaustiva y lo coloca boca abajo en su zona de biblioteca.',
        'Determinar al azar el jugador inicial (mediante tirada de dados o moneda).',
        'Cada jugador roba una mano inicial de 5 cartas de su mazo.',
        'Cada jugador inicia con un total de 20 puntos de vida (o contadores designados).',
        'Colocar la zona de descarte (cementerio) junto al mazo principal.',
      ],
      turnPhases: [
        const RulebookPhase(
          phaseNumber: 1,
          name: 'Fase de Inicio / Robo',
          shortSummary: 'Enderezar recursos y robar carta',
          details: 'El jugador activo endereza todas sus cartas agotadas ({T}) y roba la carta superior de su mazo.',
        ),
        const RulebookPhase(
          phaseNumber: 2,
          name: 'Fase Principal (Acciones)',
          shortSummary: 'Jugar cartas, invocar y activar habilidades',
          details: 'Pagar el coste requerido ({MANA}) para invocar aliados, equipar artefactos o lanzar hechizos tácticos.',
        ),
        const RulebookPhase(
          phaseNumber: 3,
          name: 'Fase de Combate',
          shortSummary: 'Declarar atacantes y asignar bloqueos',
          details: 'Elegir unidades para atacar. El defensor puede asignar bloqueadores o recibir daño directo a sus puntos de vida.',
        ),
        const RulebookPhase(
          phaseNumber: 4,
          name: 'Fase de Final de Turno',
          shortSummary: 'Resolver efectos de fin de turno y pasar iniciativa',
          details: 'El daño no letal se disipa, se comprueba el límite máximo de mano (máximo 7 cartas) y el turno pasa al rival.',
        ),
      ],
      cardAnatomy: {
        'Coste ({MANA})': 'Ubicado en la esquina superior derecha; indica los recursos necesarios para jugar la carta.',
        'Nombre de Carta': 'Título emblemático de la carta situado en el marco superior.',
        'Tipo & Categoría': 'Clasifica la carta (Unidad, Hechizo, Artefacto, etc.) y define sus tiempos de juego.',
        'Arte Principal': 'Ilustración central de la carta creada para ambientar el universo.',
        'Caja de Habilidades': 'Efectos activos, pasivos y palabras clave que interactúan con las reglas de la partida.',
        'Ataque ({ATK}) / Defensa ({DEF})': 'Valores numéricos de combate para resolver enfrentamientos.',
      },
      glossary: {
        'Girar / Agotar ({T})': 'Girar la carta a 90 grados para indicar que ha utilizado su acción este turno.',
        'Coste de Maná ({1})': 'Cantidad numérica de recursos genéricos o elementales requeridos.',
        'Iniciativa': 'La unidad ataca primero y aplica su daño antes de que el defensor pueda contraatacar.',
        'Letal': 'Cualquier cantidad de daño infligido a una criatura es suficiente para destruirla.',
        'Escudo': 'Absorbe la siguiente fuente de daño que recibiría la carta y luego se rompe.',
      },
      faqs: [
        const RulebookFaqItem(
          question: '¿Qué sucede si un jugador se queda sin cartas para robar en su mazo?',
          answer: 'Si un jugador debe robar una carta y su mazo está vacío, pierde la partida inmediatamente por desgaste.',
        ),
        const RulebookFaqItem(
          question: '¿Puedo jugar hechizos rápidos o instantáneos durante el turno del oponente?',
          answer: 'Sí, las cartas identificadas como Rápidas o Hechizos de Reacción pueden jugarse en respuesta a cualquier acción rival.',
        ),
      ],
    );
  }
}
