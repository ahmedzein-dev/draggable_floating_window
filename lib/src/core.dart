// The controller, window entries, dialogs and the WindowStack widget share
// private state, so they live in one library split into parts.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'geometry.dart';
import 'intents.dart';
import 'theme/theme_scope.dart';
import 'theme/window_stack_labels.dart';
import 'theme/window_stack_theme.dart';
import 'widgets/minimized_window_bar.dart';
import 'widgets/window_title_bar.dart';
import 'window_mode.dart';
import 'window_placement.dart';
import 'window_priority.dart';

part 'core/dialogs.dart';
part 'core/show_window_dialog.dart';
part 'core/window_drag_area.dart';
part 'core/window_entry.dart';
part 'core/window_frame.dart';
part 'core/window_stack.dart';
part 'core/window_stack_controller.dart';
