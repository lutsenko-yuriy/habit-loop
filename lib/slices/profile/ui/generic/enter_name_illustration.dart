import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:habit_loop/slices/profile/ui/generic/enter_name_constants.dart';

/// Waving-silhouette illustration shown above the title on the Enter Name
/// screen (HAB-272), matching the onboarding carousel's mint-circle visual
/// style and size. Fixed-size via [SizedBox] so its footprint is
/// deterministic regardless of asset decode timing.
class EnterNameIllustration extends StatelessWidget {
  const EnterNameIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: enterNameIllustrationWidth,
      height: enterNameIllustrationHeight,
      child: SvgPicture.asset('assets/enter_name/wave_hello.svg', fit: BoxFit.contain),
    );
  }
}
