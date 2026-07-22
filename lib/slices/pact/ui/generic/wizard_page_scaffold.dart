import 'dart:async' show unawaited;

import 'package:flutter/widgets.dart';
import 'package:habit_loop/theme/spacing.dart';
import 'package:habit_loop/theme/typography.dart';

class WizardPageScaffold extends StatefulWidget {
  final int currentPage;
  final int pageCount;
  final Widget Function(int index, FocusNode focusNode) pageBuilder;
  final ValueChanged<int> onPageChanged;
  final String hintText;
  final Color hintTextColor;
  final Key? pageViewKey;

  // Index of the page that owns the text field. requestFocus is called when
  // the user navigates to this page; unfocus is called for all other pages.
  final int firstFocusPageIndex;

  const WizardPageScaffold({
    super.key,
    required this.currentPage,
    required this.pageCount,
    required this.pageBuilder,
    required this.onPageChanged,
    required this.hintText,
    required this.hintTextColor,
    this.pageViewKey,
    this.firstFocusPageIndex = 0,
  });

  @override
  State<WizardPageScaffold> createState() => _WizardPageScaffoldState();
}

class _WizardPageScaffoldState extends State<WizardPageScaffold> {
  late final PageController _pageController;
  late final FocusNode _habitNameFocusNode;

  // Guards against mid-animation onPageChanged callbacks flashing through intermediate steps.
  bool _isProgrammaticAnimation = false;

  static const _animationDuration = Duration(milliseconds: 300);
  static const _animationCurve = Curves.easeInOut;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.currentPage);
    _habitNameFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant WizardPageScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    final targetPage = widget.currentPage;
    if (_pageController.hasClients && _pageController.page?.round() != targetPage) {
      if (_isProgrammaticAnimation || _pageController.position.isScrollingNotifier.value) return;
      _isProgrammaticAnimation = true;
      unawaited(
        _pageController
            .animateToPage(targetPage, duration: _animationDuration, curve: _animationCurve)
            .whenComplete(() {
          if (mounted) _isProgrammaticAnimation = false;
        }),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _habitNameFocusNode.dispose();
    super.dispose();
  }

  void _handlePageChanged(int page) {
    if (!_isProgrammaticAnimation) {
      widget.onPageChanged(page);
    }
    if (page == widget.firstFocusPageIndex) {
      _habitNameFocusNode.requestFocus();
    } else {
      _habitNameFocusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PageView(
            key: widget.pageViewKey,
            controller: _pageController,
            onPageChanged: _handlePageChanged,
            children: List.generate(widget.pageCount, (i) => widget.pageBuilder(i, _habitNameFocusNode)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s0, AppSpacing.s16, AppSpacing.s12),
          child: Text(
            widget.hintText,
            textAlign: TextAlign.center,
            style: AppTypography.caption.copyWith(color: widget.hintTextColor),
          ),
        ),
      ],
    );
  }
}
