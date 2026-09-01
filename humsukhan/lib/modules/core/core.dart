/// Shared application infrastructure.
///
/// Core owns cross-cutting concerns only: navigation, localization, theme,
/// shared models, shared widgets, and reusable platform/service adapters.
/// Feature-specific business logic should stay inside its module.
export '../../navigation/app_router.dart';
export '../../l10n/app_strings.dart';
export '../../theme/app_theme.dart';
