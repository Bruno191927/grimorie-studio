import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/layer_item.dart';
import '../../services/game_folder_service.dart';
import '../../utils/shape_path_builder.dart';
import '../providers/editor_provider.dart';
import '../../../../core/utils/template_parser.dart';
import '../../../../core/utils/expression_evaluator.dart';
import '../../../../core/utils/rich_text_token_parser.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../../../core/widgets/grimoire_font_picker.dart';
import '../dialogs/layer_delete_dialog.dart';
import '../../../../core/localization/locale_provider.dart';

class _UndoCanvasIntent extends Intent {
  const _UndoCanvasIntent();
}

class _RedoCanvasIntent extends Intent {
  const _RedoCanvasIntent();
}

class _DeleteLayerIntent extends Intent {
  const _DeleteLayerIntent();
}

class _DuplicateLayerIntent extends Intent {
  const _DuplicateLayerIntent();
}

class _CopyLayersIntent extends Intent {
  const _CopyLayersIntent();
}

class _PasteLayersIntent extends Intent {
  const _PasteLayersIntent();
}

class _NudgeLayerIntent extends Intent {
  final double dx;
  final double dy;
  const _NudgeLayerIntent(this.dx, this.dy);
}

enum _ResizeHandle {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

class CardCanvas extends ConsumerStatefulWidget {
  final GlobalKey repaintBoundaryKey;

  const CardCanvas({
    super.key,
    required this.repaintBoundaryKey,
  });

  @override
  ConsumerState<CardCanvas> createState() => _CardCanvasState();
}

class _CardCanvasState extends ConsumerState<CardCanvas> {
  static const double _canvasPad = 48.0;
  static const double _handleHitSize = 24.0;
  static const double _handlePad = _handleHitSize / 2.0; // 12.0
  static const double _topOverlayPad = 30.0;
  static const double _bottomOverlayPad = 24.0;

  // Snapping guide states
  double? _snapGuideX;
  double? _snapGuideY;

  // Viewport Pan & Hand Tool state for inspecting card details when zoomed
  Offset _panOffset = Offset.zero;
  bool _isPanMode = false;
  bool _isMiddleMousePanning = false;

  // Inline text editing state on double-click
  String? _editingLayerId;
  late final TextEditingController _inlineTextController;
  late final FocusNode _inlineTextFocusNode;

  // Fast double-tap detector state
  String? _lastTappedLayerId;
  DateTime _lastTapTime = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _inlineTextController = TextEditingController();
    _inlineTextFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _inlineTextController.dispose();
    _inlineTextFocusNode.dispose();
    super.dispose();
  }

  void _startInlineTextEdit(LayerItem layer, Map<String, dynamic> activeRow) {
    final isBoundToRow =
        layer.bindingKey.isNotEmpty && activeRow.containsKey(layer.bindingKey);
    final initialText = isBoundToRow
        ? (activeRow[layer.bindingKey]?.toString() ?? '')
        : layer.text;

    setState(() {
      _editingLayerId = layer.id;
      _inlineTextController.text = initialText;
      _inlineTextController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: initialText.length,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editingLayerId == layer.id) {
        _inlineTextFocusNode.requestFocus();
      }
    });
  }

  void _finishInlineTextEdit() {
    if (_editingLayerId != null) {
      setState(() {
        _editingLayerId = null;
      });
      _inlineTextFocusNode.unfocus();
    }
  }

  bool _isEditingText() {
    if (_editingLayerId != null) return true;
    final focus = FocusManager.instance.primaryFocus;
    if (focus == null) return false;
    if (focus.debugLabel == 'EditableText') return true;
    final ctx = focus.context;
    if (ctx != null) {
      if (ctx.widget is EditableText ||
          ctx.findAncestorWidgetOfExactType<EditableText>() != null) {
        return true;
      }
    }
    return false;
  }

  void _applyInlineTextChange(
    LayerItem layer,
    Map<String, dynamic> activeRow,
    String newValue,
  ) {
    final notifier = ref.read(editorProvider.notifier);
    final hasRows = ref.read(editorProvider).project.rows.isNotEmpty;
    if (layer.bindingKey.isNotEmpty && hasRows && activeRow.containsKey(layer.bindingKey)) {
      notifier.updateActiveRowData(layer.bindingKey, newValue);
      if (!layer.text.contains('{{')) {
        notifier.updateLayer(layer.copyWith(text: newValue));
      }
    } else {
      notifier.updateLayer(layer.copyWith(text: newValue));
    }
  }

  void _handleResizeUpdate(
    LayerItem layer,
    _ResizeHandle handle,
    Offset delta,
    double cardWidth,
    double cardHeight,
  ) {
    if (layer.isLocked || layer.type == LayerType.background) return;

    const double minSize = 16.0;
    final double maxW = cardWidth * 2.5;
    final double maxH = cardHeight * 2.5;

    double newX = layer.x;
    double newY = layer.y;
    double newW = layer.width;
    double newH = layer.height;
    double? newFontSize;

    final dx = delta.dx;
    final dy = delta.dy;

    switch (handle) {
      case _ResizeHandle.topLeft:
        newW = (layer.width - dx).clamp(minSize, maxW);
        newH = (layer.height - dy).clamp(minSize, maxH);
        newX = layer.x + (layer.width - newW);
        newY = layer.y + (layer.height - newH);
        break;
      case _ResizeHandle.topCenter:
        newH = (layer.height - dy).clamp(minSize, maxH);
        newY = layer.y + (layer.height - newH);
        break;
      case _ResizeHandle.topRight:
        newW = (layer.width + dx).clamp(minSize, maxW);
        newH = (layer.height - dy).clamp(minSize, maxH);
        newY = layer.y + (layer.height - newH);
        break;
      case _ResizeHandle.centerLeft:
        newW = (layer.width - dx).clamp(minSize, maxW);
        newX = layer.x + (layer.width - newW);
        break;
      case _ResizeHandle.centerRight:
        newW = (layer.width + dx).clamp(minSize, maxW);
        break;
      case _ResizeHandle.bottomLeft:
        newW = (layer.width - dx).clamp(minSize, maxW);
        newH = (layer.height + dy).clamp(minSize, maxH);
        newX = layer.x + (layer.width - newW);
        break;
      case _ResizeHandle.bottomCenter:
        newH = (layer.height + dy).clamp(minSize, maxH);
        break;
      case _ResizeHandle.bottomRight:
        newW = (layer.width + dx).clamp(minSize, maxW);
        newH = (layer.height + dy).clamp(minSize, maxH);
        break;
    }

    final isCorner = handle == _ResizeHandle.topLeft ||
        handle == _ResizeHandle.topRight ||
        handle == _ResizeHandle.bottomLeft ||
        handle == _ResizeHandle.bottomRight;

    // When resizing a Text layer from any corner handle, proportionally scale font size too
    if (layer.type == LayerType.text && isCorner && layer.height > 0) {
      final ratio = newH / layer.height;
      newFontSize = (layer.fontSize * ratio).clamp(6.0, 120.0);
    }

    ref.read(editorProvider.notifier).updateLayerGeometry(
          layer.id,
          x: newX,
          y: newY,
          width: newW,
          height: newH,
          fontSize: newFontSize,
        );
  }

  @override
  Widget build(BuildContext context) {
    final editorState = ref.watch(editorProvider);
    final project = editorState.project;
    final template = project.activeTemplate;
    final activeRow = project.activeRow;
    final selectedId = editorState.selectedLayerId;
    final layers = template.getLayers(editorState.currentSide);

    // Clear inline editing if selection changed away
    if (_editingLayerId != null && _editingLayerId != selectedId) {
      _editingLayerId = null;
    }

    LayerItem? selectedLayer;
    if (selectedId != null) {
      for (final l in layers) {
        if (l.id == selectedId) {
          selectedLayer = l;
          break;
        }
      }
    }

    // Card dimensions in canvas coordinates
    final cardWidth = project.widthMm * 4.0; // ~254 px
    final cardHeight = project.heightMm * 4.0; // ~355.6 px
    final isTextEditing = _isEditingText();

    return FocusableActionDetector(
      autofocus: false,
      shortcuts: isTextEditing
          ? const <ShortcutActivator, Intent>{}
          : <ShortcutActivator, Intent>{
              const SingleActivator(LogicalKeyboardKey.keyZ, control: true): const _UndoCanvasIntent(),
              const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): const _UndoCanvasIntent(),
              const SingleActivator(LogicalKeyboardKey.keyY, control: true): const _RedoCanvasIntent(),
              const SingleActivator(LogicalKeyboardKey.keyY, meta: true): const _RedoCanvasIntent(),
              const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): const _RedoCanvasIntent(),
              const SingleActivator(LogicalKeyboardKey.keyC, control: true): const _CopyLayersIntent(),
              const SingleActivator(LogicalKeyboardKey.keyC, meta: true): const _CopyLayersIntent(),
              const SingleActivator(LogicalKeyboardKey.keyV, control: true): const _PasteLayersIntent(),
              const SingleActivator(LogicalKeyboardKey.keyV, meta: true): const _PasteLayersIntent(),
              const SingleActivator(LogicalKeyboardKey.keyD, control: true): const _DuplicateLayerIntent(),
              const SingleActivator(LogicalKeyboardKey.keyD, meta: true): const _DuplicateLayerIntent(),
              const SingleActivator(LogicalKeyboardKey.delete): const _DeleteLayerIntent(),
              const SingleActivator(LogicalKeyboardKey.backspace): const _DeleteLayerIntent(),
              const SingleActivator(LogicalKeyboardKey.arrowUp): const _NudgeLayerIntent(0, -1),
              const SingleActivator(LogicalKeyboardKey.arrowDown): const _NudgeLayerIntent(0, 1),
              const SingleActivator(LogicalKeyboardKey.arrowLeft): const _NudgeLayerIntent(-1, 0),
              const SingleActivator(LogicalKeyboardKey.arrowRight): const _NudgeLayerIntent(1, 0),
              const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): const _NudgeLayerIntent(0, -8),
              const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): const _NudgeLayerIntent(0, 8),
              const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): const _NudgeLayerIntent(-8, 0),
              const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): const _NudgeLayerIntent(8, 0),
            },
      actions: <Type, Action<Intent>>{
        _UndoCanvasIntent: CallbackAction<_UndoCanvasIntent>(
          onInvoke: (_) {
            if (_editingLayerId == null) {
              ref.read(editorProvider.notifier).undo();
            }
            return null;
          },
        ),
        _RedoCanvasIntent: CallbackAction<_RedoCanvasIntent>(
          onInvoke: (_) {
            if (_editingLayerId == null) {
              ref.read(editorProvider.notifier).redo();
            }
            return null;
          },
        ),
        _CopyLayersIntent: CallbackAction<_CopyLayersIntent>(
          onInvoke: (_) {
            if (_editingLayerId == null && (selectedId != null || editorState.selectedLayerIds.isNotEmpty)) {
              final count = ref.read(editorProvider.notifier).copySelectedLayers();
              if (count > 0 && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$count ${ref.tr('selected_layers_count')} copiadas'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
            return null;
          },
        ),
        _PasteLayersIntent: CallbackAction<_PasteLayersIntent>(
          onInvoke: (_) {
            if (_editingLayerId == null && editorState.hasClipboardLayers) {
              ref.read(editorProvider.notifier).pasteLayers();
            }
            return null;
          },
        ),
        _DeleteLayerIntent: CallbackAction<_DeleteLayerIntent>(
          onInvoke: (_) {
            if (!_isEditingText() && (selectedId != null || editorState.selectedLayerIds.isNotEmpty)) {
              LayerDeleteDialog.show(context: context, ref: ref);
            }
            return null;
          },
        ),
        _DuplicateLayerIntent: CallbackAction<_DuplicateLayerIntent>(
          onInvoke: (_) {
            if (_editingLayerId == null && (selectedId != null || editorState.selectedLayerIds.isNotEmpty)) {
              ref.read(editorProvider.notifier).duplicateSelectedLayers();
            }
            return null;
          },
        ),
        _NudgeLayerIntent: CallbackAction<_NudgeLayerIntent>(
          onInvoke: (intent) {
            if (_editingLayerId == null) {
              ref.read(editorProvider.notifier).nudgeSelectedLayer(intent.dx, intent.dy);
            }
            return null;
          },
        ),
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
        // 1. Interactive Zoomable & Pannable Viewport
        Listener(
          onPointerSignal: (pointerSignal) {
            if (pointerSignal is PointerScrollEvent) {
              // Mouse wheel zoom
              final scrollDelta = -pointerSignal.scrollDelta.dy;
              final step = scrollDelta > 0 ? 0.12 : -0.12;
              ref.read(editorProvider.notifier).setZoom(editorState.zoom + step);
            }
          },
          onPointerDown: (event) {
            if (event.buttons == kMiddleMouseButton) {
              setState(() => _isMiddleMousePanning = true);
            }
          },
          onPointerMove: (event) {
            if (_isMiddleMousePanning) {
              setState(() {
                _panOffset += event.delta;
              });
            }
          },
          onPointerUp: (_) {
            if (_isMiddleMousePanning) {
              setState(() => _isMiddleMousePanning = false);
            }
          },
          child: MouseRegion(
            cursor: _isPanMode || _isMiddleMousePanning
                ? SystemMouseCursors.grab
                : MouseCursor.defer,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                _finishInlineTextEdit();
                ref.read(editorProvider.notifier).selectLayer(null);
              },
              onPanUpdate: (details) {
                // Dragging on empty background (or anywhere in Pan Mode) moves the viewport
                setState(() {
                  _panOffset += details.delta;
                });
              },
              child: Center(
                child: Transform.translate(
                  offset: _panOffset,
                  child: Transform.scale(
                    scale: editorState.zoom,
                    child: SizedBox(
                      width: cardWidth + _canvasPad * 2,
                      height: cardHeight + _canvasPad * 2,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // A. Actual Card inside RepaintBoundary (Clean for 300 DPI Export)
                          Positioned(
                            left: _canvasPad,
                            top: _canvasPad,
                            width: cardWidth,
                            height: cardHeight,
                            child: IgnorePointer(
                              ignoring: _isPanMode,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(template.cornerRadius),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      blurRadius: 30,
                                      spreadRadius: 1,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      blurRadius: 12,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: RepaintBoundary(
                                  key: widget.repaintBoundaryKey,
                                  child: Container(
                                    width: cardWidth,
                                    height: cardHeight,
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      color: template.getBackgroundColor(editorState.currentSide),
                                      borderRadius: BorderRadius.circular(template.cornerRadius),
                                    ),
                                    child: Stack(
                                      children: [
                                        // Background Tap Detector to Deselect Layer when clicking empty card area
                                        Positioned.fill(
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {
                                              _finishInlineTextEdit();
                                              ref.read(editorProvider.notifier).selectLayer(null);
                                            },
                                          ),
                                        ),

                                        // Optional Card Background Grid
                                        if (editorState.showGrid)
                                          CustomPaint(
                                            size: Size(cardWidth, cardHeight),
                                            painter: _CanvasGridPainter(),
                                          ),

                                        // Render Layers in Order for active side
                                        for (final layer in layers)
                                          if (layer.isVisible)
                                            _buildLayerWidget(
                                              context,
                                              layer,
                                              activeRow,
                                              isSelected: layer.id == selectedId,
                                              cardWidth: cardWidth,
                                              cardHeight: cardHeight,
                                            ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // B. Visual Snapping Guidelines (Outside RepaintBoundary)
                          if (_snapGuideX != null)
                            Positioned(
                              left: _canvasPad + _snapGuideX!,
                              top: _canvasPad,
                              height: cardHeight,
                              child: IgnorePointer(
                                child: Container(
                                  width: 1,
                                  color: GrimoireTheme.accentPink,
                                ),
                              ),
                            ),
                          if (_snapGuideY != null)
                            Positioned(
                              top: _canvasPad + _snapGuideY!,
                              left: _canvasPad,
                              width: cardWidth,
                              child: IgnorePointer(
                                child: Container(
                                  height: 1,
                                  color: GrimoireTheme.accentPink,
                                ),
                              ),
                            ),

                          // C. Bleed (3mm), Trim & Safe Zone Guides Overlay
                          if (editorState.showBleedGuides)
                            Positioned(
                              left: _canvasPad - 12.0,
                              top: _canvasPad - 12.0,
                              width: cardWidth + 24.0,
                              height: cardHeight + 24.0,
                              child: IgnorePointer(
                                child: Stack(
                                  children: [
                                    CustomPaint(
                                      size: Size(cardWidth + 24.0, cardHeight + 24.0),
                                      painter: _BleedGuidePainter(
                                        cornerRadius: template.cornerRadius,
                                      ),
                                    ),
                                    Positioned(
                                      top: 14,
                                      left: 0,
                                      right: 0,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xEE0B1320),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: const Color(0xFF06B6D4).withValues(alpha: 0.7),
                                            ),
                                            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
                                          ),
                                          child: const Text(
                                            '🔴 SANGRADO (+3mm)  •  🔵 CORTE (TRIM)  •  🟢 ZONA SEGURA (-3mm)',
                                            style: TextStyle(
                                              fontSize: 8.5,
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          // D. Selected Layer Interactive Overlay:
                          //    - Purple selection frame
                          //    - 8 Resize Handles (for Text, Shape, and Image layers)
                          //    - Double-Click Inline Text Editor & Quick Edit Pill
                          if (selectedLayer != null && selectedLayer.isVisible && !_isPanMode)
                            _buildSelectedLayerOverlay(
                              context,
                              selectedLayer,
                              activeRow,
                              cardWidth: cardWidth,
                              cardHeight: cardHeight,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // 2. Floating Zoom & Detail Inspection HUD Bar (Bottom-Right of Canvas)
        Positioned(
          right: 14,
          bottom: 14,
          child: _buildZoomHudBar(editorState),
        ),

        // 3. Floating Alignment & Quick Actions Bar (Top-Center of Canvas)
        if (editorState.selectedLayers.any((l) => l.type != LayerType.background))
          Positioned(
            top: 14,
            left: 0,
            right: 0,
            child: Center(
              child: _buildFloatingAlignmentBar(context, editorState),
            ),
          ),
      ],
      ),
    );
  }

  Widget _buildLayerWidget(
    BuildContext context,
    LayerItem layer,
    Map<String, dynamic> activeRow, {
    required bool isSelected,
    required double cardWidth,
    required double cardHeight,
  }) {
    // Evaluate Smart Token conditional rule (if any)
    bool isVisibleByRule = true;
    Color shapeColor = layer.shapeColor;
    Color borderColor = layer.borderColor;

    if (layer.conditionalRules.containsKey('condition')) {
      final condition = layer.conditionalRules['condition'] as String;
      final passes = ExpressionEvaluator.evaluate(condition, activeRow);
      if (!passes) {
        if (layer.conditionalRules['action'] == 'hide') {
          isVisibleByRule = false;
        }
      } else {
        if (layer.conditionalRules.containsKey('accentColor')) {
          borderColor = Color(layer.conditionalRules['accentColor'] as int);
        }
      }
    }

    if (!isVisibleByRule) return const SizedBox.shrink();

    // Background layer always covers full card (0, 0, cardWidth, cardHeight)
    final isBackgroundType = layer.type == LayerType.background;
    final effectiveLeft = isBackgroundType ? 0.0 : layer.x;
    final effectiveTop = isBackgroundType ? 0.0 : layer.y;
    final effectiveWidth = isBackgroundType ? cardWidth : layer.width;
    final effectiveHeight = isBackgroundType ? cardHeight : layer.height;
    final canMove = !layer.isLocked && !isBackgroundType;

    return Positioned(
      left: effectiveLeft,
      top: effectiveTop,
      width: effectiveWidth,
      height: effectiveHeight,
      child: MouseRegion(
        cursor: layer.type == LayerType.text && isSelected
            ? SystemMouseCursors.text
            : (canMove ? SystemMouseCursors.move : SystemMouseCursors.basic),
        child: GestureDetector(
          behavior: (isBackgroundType && layer.isLocked)
              ? HitTestBehavior.deferToChild
              : HitTestBehavior.opaque,
          onTapDown: (_) {
            if (isBackgroundType && layer.isLocked) return;
            final now = DateTime.now();
            final isDoubleTap = _lastTappedLayerId == layer.id &&
                now.difference(_lastTapTime).inMilliseconds < 380;
            _lastTappedLayerId = layer.id;
            _lastTapTime = now;

            if (_editingLayerId != null && _editingLayerId != layer.id) {
              _finishInlineTextEdit();
            }
            final isMulti = HardwareKeyboard.instance.isShiftPressed || HardwareKeyboard.instance.isControlPressed;
            ref.read(editorProvider.notifier).selectLayer(layer.id, multiSelect: isMulti);

            if (isDoubleTap && layer.type == LayerType.text && !layer.isLocked) {
              _startInlineTextEdit(layer, activeRow);
            }
          },
          onTap: () {
            if (isBackgroundType && layer.isLocked) return;
            final isMulti = HardwareKeyboard.instance.isShiftPressed || HardwareKeyboard.instance.isControlPressed;
            ref.read(editorProvider.notifier).selectLayer(layer.id, multiSelect: isMulti);
          },
          onDoubleTap: layer.type == LayerType.text && !layer.isLocked
              ? () {
                  ref.read(editorProvider.notifier).selectLayer(layer.id);
                  _startInlineTextEdit(layer, activeRow);
                }
              : null,
          onPanUpdate: !canMove
              ? null
              : (details) {
                  if (_editingLayerId == layer.id) return;
                  double newX = layer.x + details.delta.dx;
                  double newY = layer.y + details.delta.dy;

                  // Snapping Logic
                  double? snapX;
                  double? snapY;

                  if (ref.read(editorProvider).showSnapping) {
                    // Snap to card horizontal center
                    final centerX = (cardWidth - layer.width) / 2;
                    if ((newX - centerX).abs() < 6) {
                      newX = centerX;
                      snapX = cardWidth / 2;
                    }

                    // Snap to card vertical center
                    final centerY = (cardHeight - layer.height) / 2;
                    if ((newY - centerY).abs() < 6) {
                      newY = centerY;
                      snapY = cardHeight / 2;
                    }
                  }

                  setState(() {
                    _snapGuideX = snapX;
                    _snapGuideY = snapY;
                  });

                  ref.read(editorProvider.notifier).updateLayerPosition(layer.id, newX, newY);
                },
          onPanEnd: (_) {
            if (_snapGuideX != null || _snapGuideY != null) {
              setState(() {
                _snapGuideX = null;
                _snapGuideY = null;
              });
            }
          },
          child: (layer.type == LayerType.image || layer.type == LayerType.background)
              ? DragTarget<String>(
                  onWillAcceptWithDetails: (details) => true,
                  onAcceptWithDetails: (details) {
                    final assetRelativePath = details.data;
                    ref.read(editorProvider.notifier).assignAssetToLayer(layer.id, assetRelativePath);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: GrimoireTheme.accentEmerald,
                        duration: const Duration(milliseconds: 1400),
                        content: Text('Asset asignado a "${layer.name}": ${assetRelativePath.split('/').last}'),
                      ),
                    );
                  },
                  builder: (context, candidateData, rejectedData) {
                    final isHovered = candidateData.isNotEmpty;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        SizedBox(
                          width: effectiveWidth,
                          height: effectiveHeight,
                          child: Opacity(
                            opacity: layer.opacity,
                            child: _buildLayerContent(
                              layer,
                              activeRow,
                              shapeColor,
                              borderColor,
                              effectiveWidth: effectiveWidth,
                              effectiveHeight: effectiveHeight,
                            ),
                          ),
                        ),
                        if (isHovered)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                color: GrimoireTheme.accentEmerald.withValues(alpha: 0.25),
                                border: Border.all(color: GrimoireTheme.accentEmerald, width: 2.5),
                                borderRadius: BorderRadius.circular(layer.borderRadius),
                              ),
                              child: Center(
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.file_download_done, color: GrimoireTheme.accentEmerald, size: 14),
                                        if (effectiveWidth > 50) ...[
                                          const SizedBox(width: 4),
                                          Text(
                                            layer.type == LayerType.background ? 'Soltar como Fondo' : 'Soltar Imagen',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                )
              : SizedBox(
                  width: effectiveWidth,
                  height: effectiveHeight,
                  child: Opacity(
                    opacity: layer.opacity,
                    child: _buildLayerContent(
                      layer,
                      activeRow,
                      shapeColor,
                      borderColor,
                      effectiveWidth: effectiveWidth,
                      effectiveHeight: effectiveHeight,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSelectedLayerOverlay(
    BuildContext context,
    LayerItem layer,
    Map<String, dynamic> activeRow, {
    required double cardWidth,
    required double cardHeight,
  }) {
    final isBackgroundType = layer.type == LayerType.background;
    final effectiveLeft = isBackgroundType ? 0.0 : layer.x;
    final effectiveTop = isBackgroundType ? 0.0 : layer.y;
    final effectiveWidth = isBackgroundType ? cardWidth : layer.width;
    final effectiveHeight = isBackgroundType ? cardHeight : layer.height;
    final canResize = !layer.isLocked && !isBackgroundType;
    final isInlineEditing = _editingLayerId == layer.id && layer.type == LayerType.text;

    final overlayWidth = math.max(effectiveWidth + _handlePad * 2, 160.0);
    final overlayHeight = effectiveHeight + _topOverlayPad + _bottomOverlayPad;

    return Positioned(
      left: _canvasPad + effectiveLeft - _handlePad,
      top: _canvasPad + effectiveTop - _topOverlayPad,
      width: overlayWidth,
      height: overlayHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 1. Purple Selection Outline (IgnorePointer so drags/clicks pass through to layer)
          Positioned(
            left: _handlePad,
            top: _topOverlayPad,
            width: effectiveWidth,
            height: effectiveHeight,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isInlineEditing
                        ? const Color(0xFF38BDF8)
                        : GrimoireTheme.accentPurple,
                    width: isInlineEditing ? 2.0 : 1.75,
                  ),
                  borderRadius: BorderRadius.circular(layer.borderRadius + 2),
                ),
              ),
            ),
          ),

          // 2. Inline TextField Editor when double-clicked on a Text layer
          if (isInlineEditing)
            Positioned(
              left: _handlePad,
              top: _topOverlayPad,
              width: math.max(effectiveWidth, 80.0),
              height: math.max(effectiveHeight, layer.fontSize * 1.8 + 8),
              child: Material(
                color: const Color(0xD90E121E),
                borderRadius: BorderRadius.circular(math.max(4.0, layer.borderRadius)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Center(
                    child: TextField(
                      key: const Key('canvas_inline_text_editor'),
                      controller: _inlineTextController,
                      focusNode: _inlineTextFocusNode,
                      autofocus: true,
                      maxLines: null,
                      textAlign: layer.textAlign,
                      style: GrimoireFontHelper.resolveTextStyle(
                        fontFamily: layer.fontFamily,
                        fontSize: layer.fontSize,
                        isBold: layer.isBold,
                        isItalic: layer.isItalic,
                        color: layer.fontColor,
                        letterSpacing: layer.letterSpacing,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) => _applyInlineTextChange(layer, activeRow, val),
                      onSubmitted: (_) => _finishInlineTextEdit(),
                      onTapOutside: (_) => _finishInlineTextEdit(),
                    ),
                  ),
                ),
              ),
            ),

          // 3. Top Action Pill for Text Layers ("Doble clic o clic aquí para editar" / "Listo")
          if (layer.type == LayerType.text && !layer.isLocked)
            Positioned(
              left: _handlePad,
              top: 2,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (isInlineEditing) {
                    _finishInlineTextEdit();
                  } else {
                    _startInlineTextEdit(layer, activeRow);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isInlineEditing
                        ? const Color(0xFF0284C7)
                        : const Color(0xEE1A1E30),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: isInlineEditing
                          ? const Color(0xFF38BDF8)
                          : GrimoireTheme.accentPurple.withValues(alpha: 0.7),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isInlineEditing ? Icons.check_circle_outline : Icons.edit_note,
                        size: 11,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isInlineEditing ? 'Listo' : 'Editar texto (2x clic)',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 4. Bottom Dimension Badge (W × H)
          if (canResize && !isInlineEditing)
            Positioned(
              left: _handlePad,
              top: _topOverlayPad + effectiveHeight + 4,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xDD131624),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '${effectiveWidth.round()} × ${effectiveHeight.round()}',
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontFamily: 'monospace',
                      color: Color(0xFFE9D5FF),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

          // 5. 8-Direction Resize Handles (Corners & Sides) for Text, Shape, and Image layers
          if (canResize && !isInlineEditing) ...[
            // Top-Left Corner
            Positioned(
              left: 0,
              top: _topOverlayPad - _handlePad,
              child: _buildResizeHandleWidget(
                key: const Key('resize_handle_tl'),
                layer: layer,
                handle: _ResizeHandle.topLeft,
                cursor: SystemMouseCursors.resizeUpLeftDownRight,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                isCorner: true,
              ),
            ),
            // Top-Center Edge
            Positioned(
              left: effectiveWidth / 2,
              top: _topOverlayPad - _handlePad,
              child: _buildResizeHandleWidget(
                key: const Key('resize_handle_tc'),
                layer: layer,
                handle: _ResizeHandle.topCenter,
                cursor: SystemMouseCursors.resizeUpDown,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                isCorner: false,
              ),
            ),
            // Top-Right Corner
            Positioned(
              left: effectiveWidth,
              top: _topOverlayPad - _handlePad,
              child: _buildResizeHandleWidget(
                key: const Key('resize_handle_tr'),
                layer: layer,
                handle: _ResizeHandle.topRight,
                cursor: SystemMouseCursors.resizeUpRightDownLeft,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                isCorner: true,
              ),
            ),
            // Center-Left Edge
            Positioned(
              left: 0,
              top: _topOverlayPad - _handlePad + (effectiveHeight / 2),
              child: _buildResizeHandleWidget(
                key: const Key('resize_handle_cl'),
                layer: layer,
                handle: _ResizeHandle.centerLeft,
                cursor: SystemMouseCursors.resizeLeftRight,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                isCorner: false,
              ),
            ),
            // Center-Right Edge
            Positioned(
              left: effectiveWidth,
              top: _topOverlayPad - _handlePad + (effectiveHeight / 2),
              child: _buildResizeHandleWidget(
                key: const Key('resize_handle_cr'),
                layer: layer,
                handle: _ResizeHandle.centerRight,
                cursor: SystemMouseCursors.resizeLeftRight,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                isCorner: false,
              ),
            ),
            // Bottom-Left Corner
            Positioned(
              left: 0,
              top: _topOverlayPad - _handlePad + effectiveHeight,
              child: _buildResizeHandleWidget(
                key: const Key('resize_handle_bl'),
                layer: layer,
                handle: _ResizeHandle.bottomLeft,
                cursor: SystemMouseCursors.resizeUpRightDownLeft,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                isCorner: true,
              ),
            ),
            // Bottom-Center Edge
            Positioned(
              left: effectiveWidth / 2,
              top: _topOverlayPad - _handlePad + effectiveHeight,
              child: _buildResizeHandleWidget(
                key: const Key('resize_handle_bc'),
                layer: layer,
                handle: _ResizeHandle.bottomCenter,
                cursor: SystemMouseCursors.resizeUpDown,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                isCorner: false,
              ),
            ),
            // Bottom-Right Corner
            Positioned(
              left: effectiveWidth,
              top: _topOverlayPad - _handlePad + effectiveHeight,
              child: _buildResizeHandleWidget(
                key: const Key('resize_handle_br'),
                layer: layer,
                handle: _ResizeHandle.bottomRight,
                cursor: SystemMouseCursors.resizeUpLeftDownRight,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                isCorner: true,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResizeHandleWidget({
    required Key key,
    required LayerItem layer,
    required _ResizeHandle handle,
    required MouseCursor cursor,
    required double cardWidth,
    required double cardHeight,
    required bool isCorner,
  }) {
    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (details) {
          _handleResizeUpdate(layer, handle, details.delta, cardWidth, cardHeight);
        },
        child: SizedBox(
          width: _handleHitSize,
          height: _handleHitSize,
          child: Center(
            child: Container(
              width: isCorner ? 9.5 : 7.5,
              height: isCorner ? 9.5 : 7.5,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: isCorner ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isCorner ? BorderRadius.circular(2.5) : null,
                border: Border.all(
                  color: GrimoireTheme.accentPurple,
                  width: 2.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.45),
                    blurRadius: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomHudBar(EditorState editorState) {
    final zoomPct = (editorState.zoom * 100).round();

    return Container(
      key: const Key('canvas_zoom_hud'),
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: GrimoireTheme.surfaceElevated.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GrimoireTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Select vs Hand (Pan) Mode Toggle
            Tooltip(
              message: _isPanMode
                  ? 'Modo Mano activo (Arrastra para explorar detalle)'
                  : 'Activar Modo Mano para explorar detalle con zoom',
              child: InkWell(
                key: const Key('canvas_pan_mode_toggle'),
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  setState(() {
                    _isPanMode = !_isPanMode;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isPanMode
                        ? GrimoireTheme.accentPurple.withValues(alpha: 0.25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _isPanMode ? GrimoireTheme.accentPurple : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    _isPanMode ? Icons.pan_tool_alt : Icons.pan_tool_alt_outlined,
                    size: 15,
                    color: _isPanMode ? const Color(0xFFE9D5FF) : GrimoireTheme.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),

            // Bleed / Safe Zone Guides Toggle
            Tooltip(
              message: editorState.showBleedGuides
                  ? 'Ocultar guías de corte y sangrado seguro (3mm)'
                  : 'Mostrar guías de corte y zona segura (3mm)',
              child: InkWell(
                key: const Key('canvas_bleed_guide_toggle'),
                borderRadius: BorderRadius.circular(6),
                onTap: () {
                  ref.read(editorProvider.notifier).toggleBleedGuides();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: editorState.showBleedGuides
                        ? const Color(0xFF06B6D4).withValues(alpha: 0.25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: editorState.showBleedGuides ? const Color(0xFF06B6D4) : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    Icons.crop_free,
                    size: 15,
                    color: editorState.showBleedGuides ? const Color(0xFF67E8F9) : GrimoireTheme.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(width: 1, height: 16, color: GrimoireTheme.borderSubtle),
            const SizedBox(width: 4),

            // Zoom Out (-)
            IconButton(
              key: const Key('canvas_hud_zoom_out'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              icon: const Icon(Icons.remove_circle_outline, size: 16, color: GrimoireTheme.textSecondary),
              tooltip: 'Alejar vista',
              onPressed: () {
                ref.read(editorProvider.notifier).setZoom(editorState.zoom - 0.15);
              },
            ),

            // Interactive Zoom Slider (40% to 400%)
            SizedBox(
              width: 95,
              height: 24,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 11),
                  activeTrackColor: GrimoireTheme.accentPurple,
                  inactiveTrackColor: const Color(0xFF23283E),
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  key: const Key('canvas_hud_zoom_slider'),
                  value: editorState.zoom.clamp(0.4, 4.0),
                  min: 0.4,
                  max: 4.0,
                  onChanged: (val) {
                    ref.read(editorProvider.notifier).setZoom(val);
                  },
                ),
              ),
            ),

            // Zoom In (+)
            IconButton(
              key: const Key('canvas_hud_zoom_in'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              icon: const Icon(Icons.add_circle_outline, size: 16, color: GrimoireTheme.textSecondary),
              tooltip: 'Acercar para ver detalle',
              onPressed: () {
                ref.read(editorProvider.notifier).setZoom(editorState.zoom + 0.15);
              },
            ),

            const SizedBox(width: 4),

            // Percentage Badge (Click to reset to 100%)
            Tooltip(
              message: 'Clic para restablecer zoom a 100%',
              child: InkWell(
                key: const Key('canvas_hud_zoom_reset'),
                borderRadius: BorderRadius.circular(5),
                onTap: () {
                  ref.read(editorProvider.notifier).setZoom(1.0);
                  setState(() {
                    _panOffset = Offset.zero;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121626),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: GrimoireTheme.borderSubtle),
                  ),
                  child: Text(
                    '$zoomPct%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE9D5FF),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 4),

            // Center / Fit Card Button
            IconButton(
              key: const Key('canvas_hud_center_card'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              icon: const Icon(Icons.center_focus_strong, size: 15, color: GrimoireTheme.textSecondary),
              tooltip: 'Centrar carta en el lienzo',
              onPressed: () {
                setState(() {
                  _panOffset = Offset.zero;
                  _isPanMode = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingAlignmentBar(BuildContext context, EditorState editorState) {
    final targets = editorState.selectedLayers
        .where((l) => !l.isLocked && l.type != LayerType.background)
        .toList();
    if (targets.isEmpty) return const SizedBox.shrink();

    Widget buildToolBtn({
      required Key key,
      required IconData icon,
      required String tooltip,
      required VoidCallback? onPressed,
      Color? iconColor,
    }) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(5),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
            child: Icon(
              icon,
              size: 15,
              color: onPressed != null
                  ? (iconColor ?? GrimoireTheme.textSecondary)
                  : GrimoireTheme.textMuted.withValues(alpha: 0.3),
            ),
          ),
        ),
      );
    }

    return Container(
      key: const Key('canvas_floating_alignment_bar'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: GrimoireTheme.surfaceElevated.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: GrimoireTheme.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (targets.length > 1) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: GrimoireTheme.accentPurple.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: GrimoireTheme.accentPurple.withValues(alpha: 0.5)),
              ),
              child: Text(
                '${targets.length}',
                style: const TextStyle(fontSize: 10, color: GrimoireTheme.accentPurple, fontWeight: FontWeight.bold),
              ),
            ),
          ],
          // Align Left
          buildToolBtn(
            key: const Key('align_btn_left'),
            icon: Icons.align_horizontal_left,
            tooltip: ref.tr('align_left'),
            onPressed: () => ref.read(editorProvider.notifier).alignSelectedLayers(LayerAlignment.left),
          ),
          // Align Center H
          buildToolBtn(
            key: const Key('align_btn_center_h'),
            icon: Icons.align_horizontal_center,
            tooltip: ref.tr('align_center_h'),
            onPressed: () => ref.read(editorProvider.notifier).alignSelectedLayers(LayerAlignment.centerHorizontal),
          ),
          // Align Right
          buildToolBtn(
            key: const Key('align_btn_right'),
            icon: Icons.align_horizontal_right,
            tooltip: ref.tr('align_right'),
            onPressed: () => ref.read(editorProvider.notifier).alignSelectedLayers(LayerAlignment.right),
          ),
          Container(width: 1, height: 14, margin: const EdgeInsets.symmetric(horizontal: 4), color: GrimoireTheme.borderSubtle),
          // Align Top
          buildToolBtn(
            key: const Key('align_btn_top'),
            icon: Icons.align_vertical_top,
            tooltip: ref.tr('align_top'),
            onPressed: () => ref.read(editorProvider.notifier).alignSelectedLayers(LayerAlignment.top),
          ),
          // Align Center V
          buildToolBtn(
            key: const Key('align_btn_center_v'),
            icon: Icons.align_vertical_center,
            tooltip: ref.tr('align_center_v'),
            onPressed: () => ref.read(editorProvider.notifier).alignSelectedLayers(LayerAlignment.centerVertical),
          ),
          // Align Bottom
          buildToolBtn(
            key: const Key('align_btn_bottom'),
            icon: Icons.align_vertical_bottom,
            tooltip: ref.tr('align_bottom'),
            onPressed: () => ref.read(editorProvider.notifier).alignSelectedLayers(LayerAlignment.bottom),
          ),
          if (targets.length >= 3) ...[
            Container(width: 1, height: 14, margin: const EdgeInsets.symmetric(horizontal: 4), color: GrimoireTheme.borderSubtle),
            buildToolBtn(
              key: const Key('align_btn_distribute_h'),
              icon: Icons.horizontal_distribute,
              tooltip: ref.tr('distribute_h'),
              onPressed: () => ref.read(editorProvider.notifier).alignSelectedLayers(LayerAlignment.distributeHorizontal),
            ),
            buildToolBtn(
              key: const Key('align_btn_distribute_v'),
              icon: Icons.vertical_distribute,
              tooltip: ref.tr('distribute_v'),
              onPressed: () => ref.read(editorProvider.notifier).alignSelectedLayers(LayerAlignment.distributeVertical),
            ),
          ],
          Container(width: 1, height: 14, margin: const EdgeInsets.symmetric(horizontal: 4), color: GrimoireTheme.borderSubtle),
          // Copy
          buildToolBtn(
            key: const Key('layer_btn_copy'),
            icon: Icons.copy,
            tooltip: '${ref.tr('copy_layer')} (Ctrl+C)',
            onPressed: () {
              final count = ref.read(editorProvider.notifier).copySelectedLayers();
              if (count > 0 && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$count ${ref.tr('selected_layers_count')} copiadas'),
                    duration: const Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
          // Paste
          buildToolBtn(
            key: const Key('layer_btn_paste'),
            icon: Icons.content_paste,
            tooltip: '${ref.tr('paste_layer')} (Ctrl+V)',
            onPressed: editorState.hasClipboardLayers
                ? () => ref.read(editorProvider.notifier).pasteLayers()
                : null,
          ),
          // Duplicate
          buildToolBtn(
            key: const Key('layer_btn_duplicate'),
            icon: Icons.copy_all_outlined,
            tooltip: '${ref.tr('duplicate_layer')} (Ctrl+D)',
            onPressed: () => ref.read(editorProvider.notifier).duplicateSelectedLayers(),
          ),
          // Delete
          buildToolBtn(
            key: const Key('layer_btn_delete'),
            icon: Icons.delete_outline,
            tooltip: '${ref.tr('delete')} (Supr)',
            iconColor: GrimoireTheme.accentPink,
            onPressed: () => LayerDeleteDialog.show(context: context, ref: ref),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerContent(
    LayerItem layer,
    Map<String, dynamic> activeRow,
    Color shapeColor,
    Color borderColor, {
    required double effectiveWidth,
    required double effectiveHeight,
  }) {
    switch (layer.type) {
      case LayerType.background:
        File? bgImgFile;
        if (layer.fillMode == LayerFillMode.image) {
          if (layer.imagePath != null && File(layer.imagePath!).existsSync()) {
            bgImgFile = File(layer.imagePath!);
          } else if (layer.bindingKey.isNotEmpty) {
            final game = (activeRow['game'] ?? '').toString();
            final bindingVal = activeRow[layer.bindingKey]?.toString();
            bgImgFile = GameFolderService.resolveCardImageFile(game, bindingVal);
          }
        }

        final Gradient? bgGradient = layer.fillMode == LayerFillMode.gradient
            ? ShapePathBuilder.buildGradient(
                type: layer.gradientType,
                startColor: shapeColor,
                endColor: layer.gradientEndColor,
                middleColor: layer.gradientMiddleColor,
                useThreeStops: layer.useThreeStopGradient,
                angleDegrees: layer.gradientAngle,
              )
            : null;

        return Container(
          width: effectiveWidth,
          height: effectiveHeight,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: layer.fillMode == LayerFillMode.gradient ? null : shapeColor,
            gradient: bgGradient,
            borderRadius: BorderRadius.circular(layer.borderRadius),
            border: layer.borderWidth > 0
                ? Border.all(color: borderColor, width: layer.borderWidth)
                : null,
          ),
          child: layer.fillMode == LayerFillMode.image
              ? (bgImgFile != null && bgImgFile.existsSync()
                  ? Image.file(
                      bgImgFile,
                      fit: layer.imageFit,
                      width: effectiveWidth,
                      height: effectiveHeight,
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [shapeColor, layer.gradientEndColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.wallpaper_outlined,
                          color: Colors.white24,
                          size: 48,
                        ),
                      ),
                    ))
              : null,
        );

      case LayerType.text:
        // Hide static text while inline TextField is actively editing this layer
        if (_editingLayerId == layer.id) {
          return const SizedBox.expand();
        }

        String rawText = layer.bindingKey.isNotEmpty && activeRow.containsKey(layer.bindingKey)
            ? activeRow[layer.bindingKey].toString()
            : layer.text;

        final layerNameLower = layer.name.toLowerCase().trim();
        final rawTextLower = rawText.toLowerCase().trim();

        // Auto-detect title layers if bindingKey was omitted or placeholder was used
        if (layer.bindingKey.isEmpty || layer.bindingKey == 'card_name') {
          if (layerNameLower == 'titulo' ||
              layerNameLower == 'título' ||
              layerNameLower == 'title' ||
              layerNameLower == 'nombre' ||
              layerNameLower.contains('card_name') ||
              rawTextLower == 'título' ||
              rawTextLower == 'titulo' ||
              rawTextLower == 'title') {
            final cardName = (activeRow['card_name'] ?? '').toString().trim();
            if (cardName.isNotEmpty) {
              rawText = cardName;
            }
          }
        }

        // Auto-detect description / rules layers if bindingKey was omitted or placeholder was used
        if (layer.bindingKey.isEmpty || layer.bindingKey == 'rules_text' || layer.bindingKey == 'rules') {
          if (layerNameLower == 'descripcion' ||
              layerNameLower == 'descripción' ||
              layerNameLower == 'rules' ||
              layerNameLower == 'reglas' ||
              layerNameLower.contains('rules') ||
              rawTextLower.contains('descripcion de la carta') ||
              rawTextLower.contains('descripción de la carta')) {
            final rulesText = (activeRow['rules_text'] ?? activeRow['rules'] ?? '').toString().trim();
            if (rulesText.isNotEmpty) {
              rawText = rulesText;
            }
          }
        }

        final displayText = TemplateParser.parse(rawText, activeRow);

        return SizedBox(
          width: effectiveWidth,
          height: effectiveHeight,
          child: Align(
            alignment: _getAlignment(layer.textAlign),
            child: RichTextTokenParser.buildAutoFitCardText(
              text: displayText,
              maxWidth: effectiveWidth,
              maxHeight: effectiveHeight,
              fontFamily: layer.fontFamily,
              baseFontSize: layer.fontSize,
              isBold: layer.isBold,
              isItalic: layer.isItalic,
              fontColor: layer.fontColor,
              letterSpacing: layer.letterSpacing,
              textAlign: layer.textAlign,
              enableAutoFit: true,
              enableInlineSymbols: true,
            ),
          ),
        );

      case LayerType.shape:
        Color effectiveColor = shapeColor;
        if (activeRow.containsKey('art_color') && layer.bindingKey == 'art_color') {
          effectiveColor = Color(activeRow['art_color'] as int);
        }

        // Background frame shape layers should not overlay an artificial border line
        final isBgShape = layer.name.toLowerCase().contains('background') && layer.isLocked;
        final effectiveBorderWidth = (isBgShape && (layer.borderWidth <= 2.0 || layer.borderColor == const Color(0xFF23283E)))
            ? 0.0
            : layer.borderWidth;

        final Gradient? shapeGradient = layer.fillMode == LayerFillMode.gradient
            ? ShapePathBuilder.buildGradient(
                type: layer.gradientType,
                startColor: effectiveColor,
                endColor: layer.gradientEndColor,
                middleColor: layer.gradientMiddleColor,
                useThreeStops: layer.useThreeStopGradient,
                angleDegrees: layer.gradientAngle,
              )
            : null;

        return SizedBox(
          width: effectiveWidth,
          height: effectiveHeight,
          child: CustomPaint(
            painter: LayerShapePainter(
              preset: layer.shapePreset,
              borderRadius: layer.borderRadius,
              customPoints: layer.customPoints,
              closePath: layer.closeCustomPath,
              fillColor: effectiveColor,
              fillGradient: shapeGradient,
              borderColor: borderColor,
              borderWidth: effectiveBorderWidth,
            ),
          ),
        );

      case LayerType.image:
        File? imgFile;
        if (layer.imagePath != null && File(layer.imagePath!).existsSync()) {
          imgFile = File(layer.imagePath!);
        } else if (layer.bindingKey.isNotEmpty) {
          final game = (activeRow['game'] ?? '').toString();
          final bindingVal = activeRow[layer.bindingKey]?.toString();
          imgFile = GameFolderService.resolveCardImageFile(game, bindingVal);
        }

        if (imgFile != null && imgFile.existsSync()) {
          Widget imageWidget = ClipRRect(
            borderRadius: BorderRadius.circular(layer.borderRadius),
            child: Image.file(
              imgFile,
              fit: layer.imageFit,
              width: effectiveWidth,
              height: effectiveHeight,
            ),
          );

          if (layer.borderWidth > 0 && layer.borderColor != Colors.transparent && layer.borderColor.a > 0) {
            imageWidget = Container(
              width: effectiveWidth,
              height: effectiveHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(layer.borderRadius),
                border: Border.all(
                  color: layer.borderColor,
                  width: layer.borderWidth,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(layer.borderRadius > layer.borderWidth ? layer.borderRadius - layer.borderWidth : 0),
                child: Image.file(
                  imgFile,
                  fit: layer.imageFit,
                  width: effectiveWidth,
                  height: effectiveHeight,
                ),
              ),
            );
          }

          return SizedBox(
            width: effectiveWidth,
            height: effectiveHeight,
            child: imageWidget,
          );
        }
        return Container(
          width: effectiveWidth,
          height: effectiveHeight,
          decoration: BoxDecoration(
            color: const Color(0xFF131826),
            borderRadius: BorderRadius.circular(layer.borderRadius),
            border: Border.all(
              color: borderColor,
              width: layer.borderWidth > 0 ? layer.borderWidth : 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                color: GrimoireTheme.accentPurple,
                size: (effectiveHeight * 0.28).clamp(20.0, 36.0),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Arrastra un asset aquí',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: (effectiveHeight * 0.09).clamp(9.0, 11.0),
                    color: GrimoireTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  Alignment _getAlignment(TextAlign align) {
    switch (align) {
      case TextAlign.left:
        return Alignment.centerLeft;
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.right:
        return Alignment.centerRight;
      default:
        return Alignment.centerLeft;
    }
  }
}

class _CanvasGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;

    const step = 16.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BleedGuidePainter extends CustomPainter {
  final double cornerRadius;
  static const double bleedPad = 12.0; // 3mm at 4px/mm
  static const double safeMargin = 12.0; // 3mm inside trim line

  _BleedGuidePainter({
    required this.cornerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Outer Bleed Line (🔴 Red / Coral Dashed)
    final bleedPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    _drawDashedRect(canvas, Rect.fromLTWH(0, 0, size.width, size.height), bleedPaint, dashWidth: 6.0, dashSpace: 4.0);

    // 2. Exact Trim Line (🔵 Cyan Solid)
    final trimRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bleedPad, bleedPad, size.width - bleedPad * 2, size.height - bleedPad * 2),
      Radius.circular(cornerRadius),
    );
    final trimPaint = Paint()
      ..color = const Color(0xFF06B6D4).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(trimRect, trimPaint);

    // 3. Inner Safe Zone Line (🟢 Lime / Emerald Dashed)
    final safeLeft = bleedPad + safeMargin;
    final safeTop = bleedPad + safeMargin;
    final safeWidth = math.max(10.0, size.width - safeLeft * 2);
    final safeHeight = math.max(10.0, size.height - safeTop * 2);
    final safeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(safeLeft, safeTop, safeWidth, safeHeight),
      Radius.circular(math.max(2.0, cornerRadius - 4)),
    );
    final safePaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    _drawDashedRRect(canvas, safeRect, safePaint, dashWidth: 5.0, dashSpace: 3.5);

    // 4. Corner Crop Marks (Alignment Ticks)
    final cropPaint = Paint()
      ..color = const Color(0xFF06B6D4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const tick = 12.0;
    // Top-left
    canvas.drawLine(const Offset(bleedPad, 0), const Offset(bleedPad, tick), cropPaint);
    canvas.drawLine(const Offset(0, bleedPad), const Offset(tick, bleedPad), cropPaint);
    // Top-right
    canvas.drawLine(Offset(size.width - bleedPad, 0), Offset(size.width - bleedPad, tick), cropPaint);
    canvas.drawLine(Offset(size.width, bleedPad), Offset(size.width - tick, bleedPad), cropPaint);
    // Bottom-left
    canvas.drawLine(Offset(bleedPad, size.height), Offset(bleedPad, size.height - tick), cropPaint);
    canvas.drawLine(Offset(0, size.height - bleedPad), Offset(tick, size.height - bleedPad), cropPaint);
    // Bottom-right
    canvas.drawLine(Offset(size.width - bleedPad, size.height), Offset(size.width - bleedPad, size.height - tick), cropPaint);
    canvas.drawLine(Offset(size.width, size.height - bleedPad), Offset(size.width - tick, size.height - bleedPad), cropPaint);
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint, {double dashWidth = 5.0, double dashSpace = 4.0}) {
    final path = Path()..addRect(rect);
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = math.min(dashWidth, metric.length - distance);
        canvas.drawPath(metric.extractPath(distance, distance + length), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  void _drawDashedRRect(Canvas canvas, RRect rrect, Paint paint, {double dashWidth = 5.0, double dashSpace = 4.0}) {
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final length = math.min(dashWidth, metric.length - distance);
        canvas.drawPath(metric.extractPath(distance, distance + length), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BleedGuidePainter oldDelegate) =>
      oldDelegate.cornerRadius != cornerRadius;
}
