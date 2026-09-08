import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:habit_loop/slices/profile/ui/generic/enter_name_constants.dart';

/// Small waving-silhouette illustration shown above the title on the Enter
/// Name screen (HAB-272), matching the onboarding carousel's mint-circle
/// visual style. Fixed-size via [SizedBox] so its footprint is deterministic
/// regardless of asset decode timing — deliberately smaller than the
/// carousel's own illustrations so the keyboard doesn't push the field
/// off-screen on a short device.
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
