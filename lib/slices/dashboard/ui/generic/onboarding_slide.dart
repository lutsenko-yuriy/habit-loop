import 'package:habit_loop/l10n/generated/app_localizations.dart';

/// Immutable data for a single onboarding carousel slide.
final class OnboardingSlide {
  const OnboardingSlide({required this.assetPath, required this.title, required this.body});

  final String assetPath;
  final String Function(AppLocalizations) title;
  final String Function(AppLocalizations) body;

  static const List<OnboardingSlide> slides = [
    OnboardingSlide(
      assetPath: 'assets/onboarding/slide_0_habit_loop.svg',
      title: _slide0Title,
      body: _slide0Body,
    ),
    OnboardingSlide(
      assetPath: 'assets/onboarding/slide_1_pact.svg',
      title: _slide1Title,
      body: _slide1Body,
    ),
    OnboardingSlide(
      assetPath: 'assets/onboarding/slide_2_reminder.svg',
      title: _slide2Title,
      body: _slide2Body,
    ),
    OnboardingSlide(
      assetPath: 'assets/onboarding/slide_3_progress.svg',
      title: _slide3Title,
      body: _slide3Body,
    ),
  ];
}

String _slide0Title(AppLocalizations l10n) => l10n.onboardingSlide0Title;
String _slide0Body(AppLocalizations l10n) => l10n.onboardingSlide0Body;
String _slide1Title(AppLocalizations l10n) => l10n.onboardingSlide1Title;
String _slide1Body(AppLocalizations l10n) => l10n.onboardingSlide1Body;
String _slide2Title(AppLocalizations l10n) => l10n.onboardingSlide2Title;
String _slide2Body(AppLocalizations l10n) => l10n.onboardingSlide2Body;
String _slide3Title(AppLocalizations l10n) => l10n.onboardingSlide3Title;
String _slide3Body(AppLocalizations l10n) => l10n.onboardingSlide3Body;
