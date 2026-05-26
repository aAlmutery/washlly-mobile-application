---
name: project-design-system
description: Full design-system token layer built for Washlly — file locations, color palette, spacing scale, and StatusBadge widget
metadata:
  type: project
---

A complete Material 3 design-system token layer was introduced in May 2026. All files are in `lib/theme/`:

- `app_colors.dart` — `abstract final class AppColors` with `const Color` values. Primary = `Color(0xFF1565C0)`. Status colors: `statusPending` (orange), `statusConfirmed` (green), `statusCompleted` (primary blue), `statusCancelled` (grey), `statusPendingCustomer` (deep purple).
- `app_text_styles.dart` — `abstract final class AppTextStyles` with named `const TextStyle` constants at the scale: displayLarge(32), headlineMedium(24), titleLarge(20), titleMedium(18), bodyLarge(16), bodyMedium(14), bodySmall(13), labelLarge(14,w600), labelSmall(12).
- `app_spacing.dart` — `abstract final class AppSpacing` with `xs=4, sm=8, md=16, lg=24, xl=32, xxl=48` and radii `radiusSm=8, radiusMd=12, radiusLg=16, radiusXl=24, radiusFull=100`.
- `app_theme.dart` — `abstract final class AppTheme` with `light()` and `dark()` factory methods returning full `ThemeData`. Wire in `main.dart` as `theme: AppTheme.light(), darkTheme: AppTheme.dark()`.

Reusable widget: `lib/widgets/status_badge.dart` — `StatusBadge(status: string, label: string?)` renders a pill badge. Replaces all duplicated status `Container` builds in booking cards.

**Why:** Consolidate all ad-hoc `Colors.blue.shade800`, inline `TextStyle(fontSize: X)`, and duplicated status badge patterns into a single token layer.

**How to apply:** Always import from `theme/` rather than hardcoding `Colors.*` or inline `TextStyle`. Use `StatusBadge` in every booking list. Never re-introduce `Colors.blue.shade800` — use `AppColors.primary`.
