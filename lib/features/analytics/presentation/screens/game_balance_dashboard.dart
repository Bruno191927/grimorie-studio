import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../editor/presentation/providers/editor_provider.dart';
import '../../domain/services/deck_analytics_service.dart';
import '../../domain/models/game_balance_metrics.dart';
import '../widgets/cost_curve_chart.dart';
import '../widgets/category_breakdown_widget.dart';
import '../widgets/combat_balance_widget.dart';
import '../widgets/anomalies_detector_widget.dart';

class GameBalanceDashboard extends ConsumerStatefulWidget {
  final VoidCallback onOpenEditor;

  const GameBalanceDashboard({
    super.key,
    required this.onOpenEditor,
  });

  @override
  ConsumerState<GameBalanceDashboard> createState() => _GameBalanceDashboardState();
}

class _GameBalanceDashboardState extends ConsumerState<GameBalanceDashboard> {
  String _selectedGame = 'all';
  String _selectedStatus = 'Definitiva'; // Default to Definitiva so deck analytics are clean!
  String _selectedCategory = 'all';
  bool _respectQuantity = true;
  String? _filterCostBucket;
  String? _filterCategory;

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final rows = editorState.project.rows;
    final gameCategories = editorState.gameCategories;

    // Collect available games
    final availableGames = <String>{};
    for (final r in rows) {
      final g = (r['game'] ?? '').toString().trim();
      if (g.isNotEmpty) availableGames.add(g);
    }
    final sortedGames = availableGames.toList()..sort();

    // If current selected game doesn't exist, reset to all
    if (_selectedGame != 'all' && !sortedGames.contains(_selectedGame)) {
      _selectedGame = 'all';
    }

    // Collect categories for current scope
    final availableCategories = <String>{};
    for (final r in rows) {
      if (_selectedGame != 'all') {
        final g = (r['game'] ?? '').toString().trim().toLowerCase();
        if (g != _selectedGame.toLowerCase()) continue;
      }
      final c = (r['category'] ?? '').toString().trim();
      if (c.isNotEmpty) availableCategories.add(c);
    }
    final sortedCategories = availableCategories.toList()..sort();
    if (_selectedCategory != 'all' && !sortedCategories.contains(_selectedCategory)) {
      _selectedCategory = 'all';
    }

    // Calculate metrics
    final metrics = DeckAnalyticsService.calculateMetrics(
      rows: rows,
      gameCategories: gameCategories,
      respectQuantity: _respectQuantity,
      selectedGame: _selectedGame,
      selectedStatus: _selectedStatus,
      selectedCategory: _selectedCategory,
    );

    // Cards to show in the bottom inspector (filtered by cost bucket or category)
    List<Map<String, dynamic>> inspectedCards = [];
    if (_filterCostBucket != null) {
      final bucket = metrics.costBuckets.firstWhere(
        (b) => b.label == _filterCostBucket,
        orElse: () => CostBucket(label: '', count: 0, percentage: 0, cards: []),
      );
      inspectedCards = bucket.cards;
    } else if (_filterCategory != null) {
      inspectedCards = rows.where((r) {
        if (_selectedGame != 'all') {
          final g = (r['game'] ?? '').toString().trim().toLowerCase();
          if (g != _selectedGame.toLowerCase()) return false;
        }
        if (_selectedStatus != 'all') {
          final s = (r['card_status'] ?? 'Definitiva').toString().trim().toLowerCase();
          if (s != _selectedStatus.toLowerCase()) return false;
        }
        return (r['category'] ?? '').toString().trim().toLowerCase() == _filterCategory!.toLowerCase();
      }).toList();
    }

    return Scaffold(
      backgroundColor: GrimoireTheme.bgCanvas,
      body: CustomScrollView(
        slivers: [
          // Header & Filter Bar
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: GrimoireTheme.surfacePanel,
                border: Border(bottom: BorderSide(color: GrimoireTheme.borderSubtle)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 12,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [GrimoireTheme.accentPurple, GrimoireTheme.accentIndigo],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: GrimoireTheme.accentPurple.withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Analítica y Balance del Mazo',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          Text(
                            'Curva de costes, distribución de arquetipos y balance de estadísticas',
                            style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Filter Controls
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      // Game selector
                      _buildSelectorContainer(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedGame,
                            dropdownColor: GrimoireTheme.surfaceElevated,
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                            icon: const Icon(Icons.arrow_drop_down, size: 16, color: GrimoireTheme.textMuted),
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.apps, size: 13, color: GrimoireTheme.accentPurple),
                                    SizedBox(width: 6),
                                    Text('Todos los juegos'),
                                  ],
                                ),
                              ),
                              for (final g in sortedGames)
                                DropdownMenuItem(
                                  value: g,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.style, size: 13, color: GrimoireTheme.accentAmber),
                                      SizedBox(width: 6),
                                      Text(g),
                                    ],
                                  ),
                                ),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedGame = val);
                            },
                          ),
                        ),
                      ),

                      // Status selector
                      _buildSelectorContainer(
                        borderColor: _selectedStatus == 'Definitiva' ? GrimoireTheme.accentEmerald.withValues(alpha: 0.5) : null,
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedStatus,
                            dropdownColor: GrimoireTheme.surfaceElevated,
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                            icon: const Icon(Icons.arrow_drop_down, size: 16, color: GrimoireTheme.textMuted),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('Todas las cartas'),
                              ),
                              DropdownMenuItem(
                                value: 'Definitiva',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_outline, size: 13, color: GrimoireTheme.accentEmerald),
                                    SizedBox(width: 6),
                                    Text('Solo Definitivas'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Muestra',
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.bookmark_border, size: 13, color: GrimoireTheme.accentAmber),
                                    SizedBox(width: 6),
                                    Text('Solo Muestras'),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedStatus = val);
                            },
                          ),
                        ),
                      ),

                      // Category filter selector
                      if (sortedCategories.isNotEmpty)
                        _buildSelectorContainer(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCategory,
                              dropdownColor: GrimoireTheme.surfaceElevated,
                              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                              icon: const Icon(Icons.arrow_drop_down, size: 16, color: GrimoireTheme.textMuted),
                              items: [
                                const DropdownMenuItem(
                                  value: 'all',
                                  child: Text('Todas las categorías'),
                                ),
                                for (final c in sortedCategories)
                                  DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCategory = val);
                              },
                            ),
                          ),
                        ),

                      // Respect QTY Switch
                      InkWell(
                        onTap: () => setState(() => _respectQuantity = !_respectQuantity),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _respectQuantity ? GrimoireTheme.accentPurple.withValues(alpha: 0.15) : GrimoireTheme.surfaceElevated,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _respectQuantity ? GrimoireTheme.accentPurple.withValues(alpha: 0.5) : GrimoireTheme.borderSubtle,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _respectQuantity ? Icons.check_box : Icons.check_box_outline_blank,
                                size: 14,
                                color: _respectQuantity ? GrimoireTheme.accentPurple : GrimoireTheme.textMuted,
                              ),
                              const SizedBox(width: 6),
                              const Text('Copias (QTY)', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Main Dashboard Body
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 1. KPI Highlight Cards
                _buildKpiGrid(metrics),
                const SizedBox(height: 20),

                // 2. Tempo & Curve Diagnosis Banner
                _buildDiagnosisBanner(metrics.diagnosis),
                const SizedBox(height: 20),

                // 3. Two-Column Visual Analytics
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth > 900;
                    if (isWide) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                CostCurveChart(
                                  buckets: metrics.costBuckets,
                                  selectedCostLabel: _filterCostBucket,
                                  onCostSelected: (bucketLabel) {
                                    setState(() {
                                      _filterCostBucket = bucketLabel;
                                      _filterCategory = null;
                                    });
                                  },
                                ),
                                const SizedBox(height: 20),
                                CombatBalanceWidget(combat: metrics.combat),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            flex: 4,
                            child: Column(
                              children: [
                                CategoryBreakdownWidget(
                                  categoryMetrics: metrics.categoryMetrics,
                                  rarityMetrics: metrics.rarityMetrics,
                                  typeMetrics: metrics.typeMetrics,
                                  selectedCategory: _filterCategory,
                                  onCategorySelected: (cat) {
                                    setState(() {
                                      _filterCategory = cat;
                                      _filterCostBucket = null;
                                    });
                                  },
                                ),
                                const SizedBox(height: 20),
                                AnomaliesDetectorWidget(
                                  anomalies: metrics.anomalies,
                                  onInspectCard: (card) {
                                    final rowIdx = rows.indexOf(card);
                                    if (rowIdx != -1) {
                                      ref.read(editorProvider.notifier).setActiveRow(rowIdx);
                                      widget.onOpenEditor();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          CostCurveChart(
                            buckets: metrics.costBuckets,
                            selectedCostLabel: _filterCostBucket,
                            onCostSelected: (bucketLabel) {
                              setState(() {
                                _filterCostBucket = bucketLabel;
                                _filterCategory = null;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          CategoryBreakdownWidget(
                            categoryMetrics: metrics.categoryMetrics,
                            rarityMetrics: metrics.rarityMetrics,
                            typeMetrics: metrics.typeMetrics,
                            selectedCategory: _filterCategory,
                            onCategorySelected: (cat) {
                              setState(() {
                                _filterCategory = cat;
                                _filterCostBucket = null;
                              });
                            },
                          ),
                          const SizedBox(height: 20),
                          CombatBalanceWidget(combat: metrics.combat),
                          const SizedBox(height: 20),
                          AnomaliesDetectorWidget(
                            anomalies: metrics.anomalies,
                            onInspectCard: (card) {
                              final rowIdx = rows.indexOf(card);
                              if (rowIdx != -1) {
                                ref.read(editorProvider.notifier).setActiveRow(rowIdx);
                                widget.onOpenEditor();
                              }
                            },
                          ),
                        ],
                      );
                    }
                  },
                ),

                // 4. Inspected Cards Section (When a bucket or category is clicked)
                if (inspectedCards.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildInspectedCardsSection(inspectedCards, rows),
                ],

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorContainer({required Widget child, Color? borderColor}) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: GrimoireTheme.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor ?? GrimoireTheme.borderSubtle),
      ),
      child: child,
    );
  }

  Widget _buildKpiGrid(GameBalanceMetrics metrics) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth > 900 ? (constraints.maxWidth - 36) / 4 : (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'Total en Mazo',
                value: '${metrics.totalCards}',
                subtitle: '${metrics.uniqueCards} cartas únicas',
                icon: Icons.layers_outlined,
                color: GrimoireTheme.accentPurple,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'Coste Promedio',
                value: metrics.hasNumericCost ? metrics.avgCost.toStringAsFixed(1) : '-',
                subtitle: 'Pico en coste: ${metrics.diagnosis.peakCost}',
                icon: Icons.diamond_outlined,
                color: GrimoireTheme.accentAmber,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'Balance de Combate',
                value: metrics.combat.hasCombat
                    ? '${metrics.combat.avgAttack.toStringAsFixed(1)} / ${metrics.combat.avgDefense.toStringAsFixed(1)}'
                    : 'N/A',
                subtitle: metrics.combat.hasCombat ? 'ATK Prom / DEF Prom' : 'Sin stats de combate',
                icon: Icons.flash_on,
                color: const Color(0xFFF43F5E),
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _buildKpiCard(
                title: 'Arquetipos / Tipos',
                value: '${metrics.categoryMetrics.length}',
                subtitle: '${metrics.typeMetrics.length} tipos de carta',
                icon: Icons.category_outlined,
                color: GrimoireTheme.accentCyan,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111422),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GrimoireTheme.borderSubtle),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 11, color: GrimoireTheme.textSecondary)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 10, color: GrimoireTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiagnosisBanner(CurveDiagnosis diagnosis) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF171B30),
            const Color(0xFF131728),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: GrimoireTheme.accentPurple.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: GrimoireTheme.accentPurple, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Ritmo del Mazo: ', style: TextStyle(fontSize: 13, color: GrimoireTheme.textSecondary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: GrimoireTheme.accentPurple.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.6)),
                      ),
                      child: Text(
                        diagnosis.archetype,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  diagnosis.summary,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
                ),
                if (diagnosis.recommendations.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final rec in diagnosis.recommendations)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        rec,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectedCardsSection(List<Map<String, dynamic>> cards, List<Map<String, dynamic>> allRows) {
    final title = _filterCostBucket != null
        ? 'Cartas con Coste $_filterCostBucket (${cards.length})'
        : 'Cartas en categoría "$_filterCategory" (${cards.length})';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111422),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GrimoireTheme.accentCyan.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.search, size: 18, color: GrimoireTheme.accentCyan),
                  const SizedBox(width: 8),
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: GrimoireTheme.textMuted),
                onPressed: () => setState(() {
                  _filterCostBucket = null;
                  _filterCategory = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final card in cards)
                InkWell(
                  onTap: () {
                    final idx = allRows.indexOf(card);
                    if (idx != -1) {
                      ref.read(editorProvider.notifier).setActiveRow(idx);
                      widget.onOpenEditor();
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 220,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF181C2E),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: GrimoireTheme.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        Text(card['icon']?.toString() ?? '🃏', style: const TextStyle(fontSize: 18)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                card['card_name']?.toString() ?? 'Sin nombre',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  if (card['cost']?.toString().isNotEmpty == true) ...[
                                    Text('Coste: ${card['cost']}', style: const TextStyle(fontSize: 10, color: GrimoireTheme.accentAmber)),
                                    const SizedBox(width: 6),
                                  ],
                                  if (card['attack']?.toString().isNotEmpty == true || card['defense']?.toString().isNotEmpty == true)
                                    Text(
                                      '⚔️${card['attack'] ?? '0'}/🛡️${card['defense'] ?? '0'}',
                                      style: const TextStyle(fontSize: 10, color: GrimoireTheme.accentCyan),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 10, color: GrimoireTheme.textMuted),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
