import 'package:flutter/material.dart';
import '../models/stage_models.dart';
import '../../../core/theme/palette.dart';

/// Stateful wrapper for stage elements that handles drag/resize smoothly
class StageElementWrapper extends StatefulWidget {
  final StageElement element;
  final double displayWidth;
  final double displayHeight;
  final Widget child;
  final Function(String elementId, Rect rect) onUpdate;
  final Function(String elementId) onRemove;
  final VoidCallback? onSecondaryTap;

  const StageElementWrapper({
    super.key,
    required this.element,
    required this.displayWidth,
    required this.displayHeight,
    required this.child,
    required this.onUpdate,
    required this.onRemove,
    this.onSecondaryTap,
  });

  @override
  State<StageElementWrapper> createState() => _StageElementWrapperState();
}

class _StageElementWrapperState extends State<StageElementWrapper> {
  Offset _dragOffset = Offset.zero;
  Offset _resizeOffset = Offset.zero;
  bool _isDragging = false;
  bool _isResizing = false;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: _dragOffset,
      child: Transform.scale(
        scale: 1.0,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width:
              (widget.element.rect.width * widget.displayWidth) +
              _resizeOffset.dx,
          height:
              (widget.element.rect.height * widget.displayHeight) +
              _resizeOffset.dy,
          child: GestureDetector(
            onPanStart: (_) => setState(() => _isDragging = true),
            onPanUpdate: (details) {
              setState(() {
                _dragOffset += details.delta;
              });
            },
            onPanEnd: (details) {
              // Apply final position
              final finalLeft =
                  ((widget.element.rect.left * widget.displayWidth +
                              _dragOffset.dx) /
                          widget.displayWidth)
                      .clamp(0.0, 1.0 - widget.element.rect.width);
              final finalTop =
                  ((widget.element.rect.top * widget.displayHeight +
                              _dragOffset.dy) /
                          widget.displayHeight)
                      .clamp(0.0, 1.0 - widget.element.rect.height);

              widget.onUpdate(
                widget.element.id,
                Rect.fromLTWH(
                  finalLeft,
                  finalTop,
                  widget.element.rect.width,
                  widget.element.rect.height,
                ),
              );

              setState(() {
                _dragOffset = Offset.zero;
                _isDragging = false;
              });
            },
            onSecondaryTap: widget.onSecondaryTap,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white10,
                border: Border.all(
                  color: _isDragging ? AppPalette.accent : Colors.white30,
                  width: _isDragging ? 2 : 1,
                ),
              ),
              child: Stack(
                children: [
                  // Main content
                  Positioned.fill(child: widget.child),

                  // Close button
                  Positioned(
                    right: 2,
                    top: 2,
                    child: GestureDetector(
                      onTap: () => widget.onRemove(widget.element.id),
                      child: const Icon(
                        Icons.close,
                        size: 14,
                        color: Colors.white38,
                      ),
                    ),
                  ),

                  // Resize handle
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onPanStart: (_) => setState(() => _isResizing = true),
                      onPanUpdate: (details) {
                        setState(() {
                          _resizeOffset += details.delta;
                        });
                      },
                      onPanEnd: (details) {
                        // Apply final size
                        final newWidth =
                            ((widget.element.rect.width * widget.displayWidth +
                                        _resizeOffset.dx) /
                                    widget.displayWidth)
                                .clamp(0.05, 1.0 - widget.element.rect.left);
                        final newHeight =
                            ((widget.element.rect.height *
                                            widget.displayHeight +
                                        _resizeOffset.dy) /
                                    widget.displayHeight)
                                .clamp(0.05, 1.0 - widget.element.rect.top);

                        widget.onUpdate(
                          widget.element.id,
                          Rect.fromLTWH(
                            widget.element.rect.left,
                            widget.element.rect.top,
                            newWidth,
                            newHeight,
                          ),
                        );

                        setState(() {
                          _resizeOffset = Offset.zero;
                          _isResizing = false;
                        });
                      },
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeDownRight,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppPalette.accent,
                                AppPalette.accent.withValues(alpha: 0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(2),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppPalette.accent.withValues(alpha: 0.4),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
