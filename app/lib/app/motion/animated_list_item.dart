import 'package:flutter/widgets.dart';

import 'motion.dart';

/// The enter and exit of one list row.
///
/// Entering: it fades in, slides up 12 points and its height opens, over
/// 280 ms (ease out cubic). Leaving: it fades out and its height closes over
/// 220 ms (ease in-out cubic). With Reduce Motion on it only fades, in 120 ms
/// or less, and the height changes at once.
class AnimatedListItem extends StatelessWidget {
  const AnimatedListItem({
    required this.animation,
    required this.child,
    this.removing = false,
    super.key,
  });

  /// 0 when the row is absent, 1 when it is fully there.
  final Animation<double> animation;
  final Widget child;

  /// True for the exit animation, which uses a different curve.
  final bool removing;

  /// How long a row takes to come in.
  static Duration enterDuration(BuildContext context) =>
      Motion.of(context, Motion.rowIn);

  /// How long a row takes to leave.
  static Duration exitDuration(BuildContext context) =>
      Motion.of(context, Motion.rowOut);

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: removing ? Motion.easeInOutCubic : Motion.easeOutCubic,
    );
    if (Motion.reduce(context)) {
      return FadeTransition(opacity: curved, child: child);
    }
    return SizeTransition(
      sizeFactor: curved,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 12 / 64),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      ),
    );
  }
}

/// A list that animates rows in and out as its items change, and builds only
/// the rows that are on screen. Items are told apart by [idOf]; rows that stay
/// are never rebuilt into something new.
class HaulAnimatedList<T> extends StatefulWidget {
  const HaulAnimatedList({
    required this.items,
    required this.idOf,
    required this.itemBuilder,
    this.controller,
    this.padding,
    super.key,
  });

  final List<T> items;
  final Object Function(T item) idOf;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  @override
  State<HaulAnimatedList<T>> createState() => _HaulAnimatedListState<T>();
}

class _HaulAnimatedListState<T> extends State<HaulAnimatedList<T>> {
  // Replaced with a fresh key to start the list over when rows were reordered.
  var _key = GlobalKey<AnimatedListState>();

  /// The rows the AnimatedList currently holds, in order. It only changes in
  /// step with calls to insertItem and removeItem.
  late List<T> _shown = List.of(widget.items);

  /// Newest data for every row by id, so a row that stays shows fresh values
  /// at once even before the list has caught up on rows that came or went.
  late Map<Object, T> _latest = _index(widget.items);

  bool _syncScheduled = false;

  Map<Object, T> _index(List<T> items) => {
    for (final i in items) widget.idOf(i): i,
  };

  @override
  void didUpdateWidget(HaulAnimatedList<T> old) {
    super.didUpdateWidget(old);
    _latest = _index(widget.items);
    // The list's state cannot be changed while the tree is being built, so
    // the insert and remove calls wait until the frame is done.
    if (!_syncScheduled) {
      _syncScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncScheduled = false;
        if (mounted) _apply();
      });
    }
  }

  void _apply() {
    final next = widget.items;
    final list = _key.currentState;
    final oldIds = [for (final i in _shown) widget.idOf(i)];
    final newIds = [for (final i in next) widget.idOf(i)];
    final oldSet = oldIds.toSet();
    final newSet = newIds.toSet();

    // Rows that stay must keep their relative order, or there is nothing
    // sensible to animate and the list simply starts over.
    final keptOld = oldIds.where(newSet.contains).toList();
    final keptNew = newIds.where(oldSet.contains).toList();
    if (list == null || !_same(keptOld, keptNew)) {
      setState(() {
        _shown = List.of(next);
        _key = GlobalKey<AnimatedListState>();
      });
      return;
    }

    // Take rows out from the bottom up so earlier indexes stay valid.
    for (var i = _shown.length - 1; i >= 0; i--) {
      final item = _shown[i];
      if (!newSet.contains(widget.idOf(item))) {
        _shown.removeAt(i);
        list.removeItem(
          i,
          (context, animation) => AnimatedListItem(
            animation: animation,
            removing: true,
            child: IgnorePointer(child: widget.itemBuilder(context, item, i)),
          ),
          duration: AnimatedListItem.exitDuration(context),
        );
      }
    }
    // Put new rows in at their final positions, top down.
    for (var i = 0; i < next.length; i++) {
      if (!oldSet.contains(widget.idOf(next[i]))) {
        _shown.insert(i, next[i]);
        list.insertItem(i, duration: AnimatedListItem.enterDuration(context));
      }
    }
    setState(() {});
  }

  static bool _same(List<Object> a, List<Object> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      key: _key,
      controller: widget.controller,
      padding: widget.padding,
      initialItemCount: _shown.length,
      itemBuilder: (context, index, animation) {
        if (index >= _shown.length) return const SizedBox.shrink();
        final id = widget.idOf(_shown[index]);
        final item = _latest[id] ?? _shown[index];
        final row = widget.itemBuilder(context, item, index);
        return KeyedSubtree(
          key: ValueKey(id),
          // Always wrapped, so a row never changes shape when its entrance
          // finishes. Rows present at the start are already fully shown.
          child: AnimatedListItem(animation: animation, child: row),
        );
      },
    );
  }
}
