import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:grimoire_studio/core/theme/grimoire_theme.dart';

class PlaytestAnalyticsDialog extends StatefulWidget {
  final List<Map<String, dynamic>> deckCards;
  final String gameName;

  const PlaytestAnalyticsDialog({
    super.key,
    required this.deckCards,
    required this.gameName,
  });

  static Future<void> show(
    BuildContext context, {
    required List<Map<String, dynamic>> deckCards,
    required String gameName,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => PlaytestAnalyticsDialog(
        deckCards: deckCards,
        gameName: gameName,
      ),
    );
  }

  @override
  State<PlaytestAnalyticsDialog> createState() => _PlaytestAnalyticsDialogState();
}

class _PlaytestAnalyticsDialogState extends State<PlaytestAnalyticsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _handSize = 5;
  List<List<Map<String, dynamic>>> _simulatedHands = [];

  // Hypergeometric Calculator inputs
  int _calcDeckSize = 40;
  int _calcCopiesInDeck = 4;
  int _calcCardsDrawn = 7;
  int _calcDesiredSuccesses = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _calcDeckSize = math.max(1, widget.deckCards.length);
    _generateMulliganHands();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _generateMulliganHands() {
    final rand = math.Random();
    final List<List<Map<String, dynamic>>> hands = [];

    for (int h = 0; h < 10; h++) {
      final shuffled = List<Map<String, dynamic>>.from(widget.deckCards)..shuffle(rand);
      hands.add(shuffled.take(math.min(_handSize, shuffled.length)).toList());
    }

    setState(() {
      _simulatedHands = hands;
    });
  }

  // Hypergeometric distribution: P(X >= k)
  double _calculateHypergeometric({
    required int N, // Deck size
    required int K, // Successes in deck
    required int n, // Sample size (cards drawn)
    required int k, // Desired successes
  }) {
    if (N <= 0 || K <= 0 || n <= 0 || k <= 0) return 0.0;
    if (k > n || k > K) return 0.0;

    double combination(int n, int r) {
      if (r < 0 || r > n) return 0;
      if (r == 0 || r == n) return 1;
      if (r > n / 2) r = n - r;

      double res = 1.0;
      for (int i = 1; i <= r; i++) {
        res = res * (n - i + 1) / i;
      }
      return res;
    }

    final totalCombinations = combination(N, n);
    if (totalCombinations == 0) return 0.0;

    double cumulativeProb = 0.0;
    final maxSuccesses = math.min(n, K);
    for (int i = k; i <= maxSuccesses; i++) {
      final waysToPickSuccesses = combination(K, i);
      final waysToPickFailures = combination(N - K, n - i);
      cumulativeProb += (waysToPickSuccesses * waysToPickFailures) / totalCombinations;
    }

    return (cumulativeProb * 100).clamp(0.0, 100.0);
  }

  Map<int, int> _getManaCurve() {
    final curve = <int, int>{};
    for (int i = 0; i <= 6; i++) {
      curve[i] = 0;
    }
    for (final c in widget.deckCards) {
      final costStr = (c['cost'] ?? '0').toString().trim();
      final cost = int.tryParse(costStr) ?? 0;
      final bucket = cost.clamp(0, 6);
      curve[bucket] = (curve[bucket] ?? 0) + 1;
    }
    return curve;
  }

  Map<String, int> _getTypeDistribution() {
    final types = <String, int>{};
    for (final c in widget.deckCards) {
      final type = (c['type'] ?? 'Sin Tipo').toString().trim();
      types[type] = (types[type] ?? 0) + 1;
    }
    return types;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: GrimoireTheme.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: GrimoireTheme.borderSubtle),
      ),
      child: Container(
        width: 720,
        height: 580,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.analytics_outlined, color: GrimoireTheme.accentPurple, size: 22),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Laboratorio de Probabilidades & Mulligan',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          'Juego: ${widget.gameName} • ${widget.deckCards.length} cartas en el mazo',
                          style: const TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: GrimoireTheme.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Tab Bar
            TabBar(
              controller: _tabController,
              indicatorColor: GrimoireTheme.accentPurple,
              labelColor: Colors.white,
              unselectedLabelColor: GrimoireTheme.textMuted,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(icon: Icon(Icons.restart_alt, size: 16), text: 'Simulador Mulligan (10 Manos)'),
                Tab(icon: Icon(Icons.bar_chart, size: 16), text: 'Curva de Maná y Tipos'),
                Tab(icon: Icon(Icons.calculate_outlined, size: 16), text: 'Calculadora Hipergeométrica'),
              ],
            ),
            const SizedBox(height: 14),

            // Tab View Body
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMulliganTab(),
                  _buildCurveTab(),
                  _buildHypergeometricTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMulliganTab() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text('Tamaño de Mano Inicial: ', style: TextStyle(fontSize: 12, color: GrimoireTheme.textSecondary)),
                for (final size in [4, 5, 6, 7])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('$size cartas', style: const TextStyle(fontSize: 11)),
                      selected: _handSize == size,
                      selectedColor: GrimoireTheme.accentPurple,
                      onSelected: (val) {
                        if (val) {
                          setState(() => _handSize = size);
                          _generateMulliganHands();
                        }
                      },
                    ),
                  ),
              ],
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GrimoireTheme.accentIndigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text('Volver a Simular 10 Manos', style: TextStyle(fontSize: 11)),
              onPressed: _generateMulliganHands,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: _simulatedHands.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, idx) {
              final hand = _simulatedHands[idx];
              double avgCost = 0;
              for (final c in hand) {
                avgCost += int.tryParse((c['cost'] ?? '0').toString()) ?? 0;
              }
              if (hand.isNotEmpty) avgCost /= hand.length;

              final isBalanced = avgCost >= 1.0 && avgCost <= 3.5;

              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF131522),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: GrimoireTheme.borderSubtle),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: isBalanced
                            ? GrimoireTheme.accentEmerald.withValues(alpha: 0.15)
                            : GrimoireTheme.accentAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isBalanced ? GrimoireTheme.accentEmerald : GrimoireTheme.accentAmber,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text('Mano #${idx + 1}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isBalanced ? GrimoireTheme.accentEmerald : GrimoireTheme.accentAmber,
                              )),
                          Text('Avg ${avgCost.toStringAsFixed(1)}',
                              style: const TextStyle(fontSize: 9, color: Colors.white70)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final card in hand)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2235),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.white12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(card['icon']?.toString() ?? '🃏', style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 4),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 90),
                                    child: Text(
                                      card['card_name']?.toString() ?? 'Carta',
                                      style: const TextStyle(fontSize: 11, color: Colors.white),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: GrimoireTheme.accentPurple.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${card['cost'] ?? 0}💎',
                                      style: const TextStyle(fontSize: 9, color: Color(0xFFE9D5FF)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCurveTab() {
    final manaCurve = _getManaCurve();
    final typeDist = _getTypeDistribution();
    final totalCards = widget.deckCards.isEmpty ? 1 : widget.deckCards.length;
    final maxCurveCount = manaCurve.values.isEmpty ? 1 : math.max(1, manaCurve.values.reduce(math.max));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mana Curve Bar Chart
        Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF131522),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: GrimoireTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_graph, size: 14, color: GrimoireTheme.accentPurple),
                    SizedBox(width: 6),
                    Text('Curva de Coste de Maná', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (int cost = 0; cost <= 6; cost++) ...[
                        Builder(builder: (ctx) {
                          final count = manaCurve[cost] ?? 0;
                          final pct = ((count / totalCards) * 100).toStringAsFixed(0);
                          final heightPct = (count / maxCurveCount).clamp(0.08, 1.0);

                          return Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('$count', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(height: 2),
                              Text('$pct%', style: const TextStyle(fontSize: 9, color: GrimoireTheme.textMuted)),
                              const SizedBox(height: 6),
                              Container(
                                width: 34,
                                height: 160 * heightPct,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [GrimoireTheme.accentPurple, GrimoireTheme.accentIndigo],
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(cost == 6 ? '6+' : '$cost',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF93C5FD))),
                            ],
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),

        // Type Distribution Breakdown
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF131522),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: GrimoireTheme.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pie_chart_outline, size: 14, color: GrimoireTheme.accentAmber),
                    SizedBox(width: 6),
                    Text('Tipos de Carta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      for (final entry in typeDist.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(entry.key, style: const TextStyle(fontSize: 11, color: Colors.white)),
                                  Text('${entry.value} (${((entry.value / totalCards) * 100).toStringAsFixed(1)}%)',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GrimoireTheme.accentAmber)),
                                ],
                              ),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: entry.value / totalCards,
                                  backgroundColor: Colors.white10,
                                  color: GrimoireTheme.accentAmber,
                                  minHeight: 5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHypergeometricTab() {
    final prob = _calculateHypergeometric(
      N: _calcDeckSize,
      K: _calcCopiesInDeck,
      n: _calcCardsDrawn,
      k: _calcDesiredSuccesses,
    );

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: GrimoireTheme.accentPurple.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.35)),
            ),
            child: Row(
              children: [
                const Icon(Icons.psychology, color: GrimoireTheme.accentPurple, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cálculo de Consistencia de Mazo (Distribución Hipergeométrica)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Determina la probabilidad matemática exacta de robar tus cartas clave sin reemplazo en mano inicial o turnos avanzados.',
                        style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Presets
          const Text('PRESETS RÁPIDOS DE TESTEO',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: GrimoireTheme.textMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                label: const Text('Carta clave x4 en Mano Inicial (7 cartas)', style: TextStyle(fontSize: 11)),
                backgroundColor: const Color(0xFF1A1D33),
                onPressed: () {
                  setState(() {
                    _calcCopiesInDeck = 4;
                    _calcCardsDrawn = 7;
                    _calcDesiredSuccesses = 1;
                  });
                },
              ),
              ActionChip(
                label: const Text('Recurso/Tierra x16 en Turno 2 (8 cartas)', style: TextStyle(fontSize: 11)),
                backgroundColor: const Color(0xFF1A1D33),
                onPressed: () {
                  setState(() {
                    _calcCopiesInDeck = 16;
                    _calcCardsDrawn = 8;
                    _calcDesiredSuccesses = 2;
                  });
                },
              ),
              ActionChip(
                label: const Text('Carta Única Legendaria x1 en Turno 5 (11 cartas)', style: TextStyle(fontSize: 11)),
                backgroundColor: const Color(0xFF1A1D33),
                onPressed: () {
                  setState(() {
                    _calcCopiesInDeck = 1;
                    _calcCardsDrawn = 11;
                    _calcDesiredSuccesses = 1;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Interactive Sliders / Inputs
          Row(
            children: [
              Expanded(
                child: _buildParamCard(
                  label: 'Tamaño del Mazo (N)',
                  value: '$_calcDeckSize',
                  icon: Icons.layers,
                  onMinus: () => setState(() => _calcDeckSize = math.max(1, _calcDeckSize - 1)),
                  onPlus: () => setState(() => _calcDeckSize++),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildParamCard(
                  label: 'Copias en Mazo (K)',
                  value: '$_calcCopiesInDeck',
                  icon: Icons.copy,
                  onMinus: () => setState(() => _calcCopiesInDeck = math.max(1, _calcCopiesInDeck - 1)),
                  onPlus: () => setState(() => _calcCopiesInDeck++),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildParamCard(
                  label: 'Cartas Robadas (n)',
                  value: '$_calcCardsDrawn',
                  icon: Icons.pan_tool_alt,
                  onMinus: () => setState(() => _calcCardsDrawn = math.max(1, _calcCardsDrawn - 1)),
                  onPlus: () => setState(() => _calcCardsDrawn++),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildParamCard(
                  label: 'Éxitos Deseados (k)',
                  value: '$_calcDesiredSuccesses',
                  icon: Icons.check_circle_outline,
                  onMinus: () => setState(() => _calcDesiredSuccesses = math.max(1, _calcDesiredSuccesses - 1)),
                  onPlus: () => setState(() => _calcDesiredSuccesses++),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Result Display
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  prob >= 75 ? const Color(0xFF064E3B) : (prob >= 50 ? const Color(0xFF312E81) : const Color(0xFF450A0A)),
                  const Color(0xFF0F111D),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: prob >= 75 ? GrimoireTheme.accentEmerald : (prob >= 50 ? GrimoireTheme.accentIndigo : GrimoireTheme.accentPink),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Probabilidad de robar al menos $_calcDesiredSuccesses copia(s):',
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${prob.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: prob >= 75 ? GrimoireTheme.accentEmerald : (prob >= 50 ? const Color(0xFF818CF8) : const Color(0xFFF87171)),
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    prob >= 75 ? '🟢 Alta Consistencia' : (prob >= 50 ? '🟡 Regular / Aceptable' : '🔴 Riesgo de Bloqueo'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParamCard({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF131522),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GrimoireTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: GrimoireTheme.accentPurple),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 14, color: Colors.white70),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onMinus,
              ),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
              IconButton(
                icon: const Icon(Icons.add, size: 14, color: Colors.white70),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onPlus,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
