import 'package:flutter_test/flutter_test.dart';
import 'package:grimoire_studio/features/rulebook/domain/models/rulebook_data.dart';
import 'package:grimoire_studio/features/rulebook/services/rulebook_service.dart';

void main() {
  group('Rulebook Builder Tests', () {
    test('Initializes smart draft rulebook from game rows', () {
      final sampleRows = [
        {'card_name': 'Héroe Solar', 'game': 'Chronicles', 'category': 'Héroe', 'qty': '2'},
        {'card_name': 'Rayo Ígneo', 'game': 'Chronicles', 'category': 'Hechizo', 'qty': '4'},
        {'card_name': 'Escudo Sagrado', 'game': 'Chronicles', 'category': 'Artefacto', 'qty': '1'},
      ];

      final rulebook = RulebookData.initial(gameName: 'Chronicles', rows: sampleRows);

      expect(rulebook.gameName, 'Chronicles');
      expect(rulebook.components.length, 3);
      expect(rulebook.components.any((c) => c.category == 'Héroe' && c.quantity == 2), isTrue);
      expect(rulebook.components.any((c) => c.category == 'Hechizo' && c.quantity == 4), isTrue);
      expect(rulebook.components.any((c) => c.category == 'Artefacto' && c.quantity == 1), isTrue);
      expect(rulebook.turnPhases.length, 4);
      expect(rulebook.setupSteps.isNotEmpty, isTrue);
      expect(rulebook.cardAnatomy.containsKey('Coste ({MANA})'), isTrue);
    });

    test('Serializes to and from JSON without data loss', () {
      final initial = RulebookData(
        gameName: 'Grimoire Duel',
        subtitle: 'Edición Torneo',
        version: '2.5',
        author: 'Grimoire Designer',
        targetPlayers: '2 Jugadores',
        playTime: '20 min',
        ageRating: '10+',
        introduction: 'Un duelo arcano legendario.',
        objective: 'Reducir los puntos de vida rivales a 0.',
        components: const [
          RulebookComponentItem(name: 'Baraja Principal', quantity: 40, category: 'Cartas', description: 'Mazo'),
        ],
        setupSteps: const ['Barajar mazo', 'Robar 5 cartas'],
        turnPhases: const [
          RulebookPhase(phaseNumber: 1, name: 'Robo', shortSummary: 'Robar 1 carta', details: 'Inicio de turno'),
        ],
        cardAnatomy: const {'Ataque': 'Fuerza de la criatura'},
        glossary: const {'Volar': 'Solo puede ser bloqueado por criaturas que vuelan'},
        faqs: const [
          RulebookFaqItem(question: '¿Qué pasa en empate?', answer: 'Se juega muerte súbita.'),
        ],
      );

      final json = initial.toJson();
      final deserialized = RulebookData.fromJson(json);

      expect(deserialized.gameName, 'Grimoire Duel');
      expect(deserialized.version, '2.5');
      expect(deserialized.components.first.quantity, 40);
      expect(deserialized.turnPhases.first.name, 'Robo');
      expect(deserialized.faqs.first.answer, 'Se juega muerte súbita.');
    });

    test('Auto-synchronizes components with new game rows', () {
      final current = RulebookData(
        gameName: 'BattleCards',
        components: const [
          RulebookComponentItem(name: 'Dados D20', quantity: 2, category: 'Dado', description: 'Contador de vida'),
        ],
      );

      final newRows = [
        {'card_name': 'Dragón', 'category': 'Monstruo', 'qty': '3'},
        {'card_name': 'Trampa', 'category': 'Trampa', 'qty': '2'},
      ];

      final synced = RulebookService.autoSyncComponents(current, newRows);

      expect(synced.components.length, 3); // 2 categories + 1 custom non-card component (Dados D20)
      expect(synced.components.any((c) => c.category == 'Monstruo' && c.quantity == 3), isTrue);
      expect(synced.components.any((c) => c.category == 'Trampa' && c.quantity == 2), isTrue);
      expect(synced.components.any((c) => c.category == 'Dado'), isTrue);
    });
  });
}
