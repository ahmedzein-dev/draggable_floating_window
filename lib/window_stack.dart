/// Desktop-style windowing inside a single Flutter view.
///
/// Floating windows that drag, resize, minimize to a dock and maximize; stay
/// ordered by priority; carry their own stacks of modal dialogs; and keep
/// keyboard focus where the user left it.
///
/// Start with [WindowStack] and [WindowStackController].
library;

export 'src/core.dart'
    show
        MinimizedWindowBuilder,
        WindowCloseRequestCallback,
        WindowDragArea,
        WindowEntry,
        WindowStack,
        WindowStackController,
        WindowTitleBarBuilder,
        showWindowDialog;
export 'src/intents.dart';
export 'src/theme/window_stack_labels.dart';
export 'src/theme/window_stack_theme.dart';
export 'src/widgets/minimized_window_bar.dart';
export 'src/widgets/window_controls.dart';
export 'src/widgets/window_title_bar.dart';
export 'src/window_mode.dart';
export 'src/window_placement.dart';
export 'src/window_priority.dart';
