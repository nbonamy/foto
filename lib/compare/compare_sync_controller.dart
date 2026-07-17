import 'package:flutter/widgets.dart';

@immutable
class ComparePaneTransform {
  const ComparePaneTransform({
    required this.scale,
    required this.position,
  });

  final double scale;
  final Offset position;
}

@immutable
class CompareViewportState {
  const CompareViewportState({
    this.zoom = 1,
    this.normalizedPosition = Offset.zero,
  });

  final double zoom;
  final Offset normalizedPosition;
}

typedef CompareTransformApplier = void Function(ComparePaneTransform transform);

class CompareSyncController extends ChangeNotifier {
  final Map<int, _ComparePane> _panes = {};
  CompareViewportState _viewport = const CompareViewportState();
  bool _synchronized = true;
  bool _broadcasting = false;

  bool get synchronized => _synchronized;
  CompareViewportState get viewport => _viewport;

  void registerPane({
    required int id,
    required double fitScale,
    required Size viewportSize,
    required CompareTransformApplier apply,
  }) {
    if (!fitScale.isFinite || fitScale <= 0 || viewportSize.isEmpty) return;
    final pane = _ComparePane(
      fitScale: fitScale,
      viewportSize: viewportSize,
      apply: apply,
    );
    _panes[id] = pane;
    _applyViewport(pane);
  }

  void unregisterPane(int id) {
    _panes.remove(id);
  }

  void updatePaneMetrics(int id, Size viewportSize) {
    final pane = _panes[id];
    if (pane == null || viewportSize.isEmpty) return;
    pane.viewportSize = viewportSize;
  }

  void updateFromPane({
    required int id,
    required double scale,
    required Offset position,
  }) {
    final pane = _panes[id];
    if (pane == null || _broadcasting || !scale.isFinite || scale <= 0) return;
    _viewport = CompareViewportState(
      zoom: scale / pane.fitScale,
      normalizedPosition: Offset(
        position.dx / pane.viewportSize.width,
        position.dy / pane.viewportSize.height,
      ),
    );
    if (_synchronized) _broadcast(excluding: id);
  }

  void setSynchronized(bool synchronized) {
    if (_synchronized == synchronized) return;
    _synchronized = synchronized;
    if (synchronized) _broadcast();
    notifyListeners();
  }

  void toggleSynchronized() {
    setSynchronized(!_synchronized);
  }

  void fitAll() {
    _viewport = const CompareViewportState();
    _broadcast();
  }

  void showActualPixels({required int sourcePane}) {
    final source = _panes[sourcePane];
    if (source == null) return;
    _viewport = CompareViewportState(zoom: 1 / source.fitScale);
    _broadcastAbsoluteScale(1);
  }

  void _broadcast({int? excluding}) {
    if (_broadcasting) return;
    _broadcasting = true;
    try {
      for (final entry in _panes.entries) {
        if (entry.key != excluding) _applyViewport(entry.value);
      }
    } finally {
      _broadcasting = false;
    }
  }

  void _broadcastAbsoluteScale(double scale) {
    if (_broadcasting) return;
    _broadcasting = true;
    try {
      for (final pane in _panes.values) {
        pane.apply(ComparePaneTransform(
          scale: scale,
          position: Offset(
            _viewport.normalizedPosition.dx * pane.viewportSize.width,
            _viewport.normalizedPosition.dy * pane.viewportSize.height,
          ),
        ));
      }
    } finally {
      _broadcasting = false;
    }
  }

  void _applyViewport(_ComparePane pane) {
    pane.apply(ComparePaneTransform(
      scale: pane.fitScale * _viewport.zoom,
      position: Offset(
        _viewport.normalizedPosition.dx * pane.viewportSize.width,
        _viewport.normalizedPosition.dy * pane.viewportSize.height,
      ),
    ));
  }
}

class _ComparePane {
  _ComparePane({
    required this.fitScale,
    required this.viewportSize,
    required this.apply,
  });

  final double fitScale;
  Size viewportSize;
  final CompareTransformApplier apply;
}
