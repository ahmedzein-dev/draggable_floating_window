import 'package:flutter/material.dart';
import 'package:window_stack/window_stack.dart';

/// Toggles the enclosing window between [WindowPriority.high] ("keep on
/// top") and [WindowPriority.normal]. Used as a title bar action.
class KeepOnTopButton extends StatelessWidget {
  const KeepOnTopButton({super.key});

  @override
  Widget build(BuildContext context) {
    final WindowEntry window = WindowEntry.of(context);
    return ListenableBuilder(
      listenable: window,
      builder: (BuildContext context, Widget? child) {
        final bool onTop = window.priority > WindowPriority.normal;
        return IconButton(
          iconSize: 16,
          visualDensity: VisualDensity.compact,
          tooltip: onTop ? 'Stop keeping on top' : 'Keep on top',
          isSelected: onTop,
          icon: const Icon(Icons.push_pin_outlined),
          selectedIcon: const Icon(Icons.push_pin),
          onPressed: () => window.priority =
              onTop ? WindowPriority.normal : WindowPriority.high,
        );
      },
    );
  }
}

/// A four-function calculator, opened with `WindowPriority.high` so it
/// floats above the other windows.
class CalculatorWindow extends StatefulWidget {
  const CalculatorWindow({super.key});

  @override
  State<CalculatorWindow> createState() => _CalculatorWindowState();
}

class _CalculatorWindowState extends State<CalculatorWindow> {
  String _display = '0';
  double? _stored;
  String? _operator;
  bool _startNew = true;

  void _digit(String digit) {
    setState(() {
      if (_startNew || _display == '0' || _display == 'Error') {
        _display = digit == '.' ? '0.' : (digit == '00' ? '0' : digit);
        _startNew = false;
      } else if (digit != '.' || !_display.contains('.')) {
        _display += digit;
      }
    });
  }

  void _operation(String operator) {
    setState(() {
      _evaluate();
      _stored = double.tryParse(_display);
      _operator = operator;
      _startNew = true;
    });
  }

  void _equals() => setState(() {
        _evaluate();
        _operator = null;
        _stored = null;
        _startNew = true;
      });

  void _negate() => setState(() {
        final double? value = double.tryParse(_display);
        if (value != null && value != 0) {
          _display = _format(-value);
        }
      });

  void _percent() => setState(() {
        final double? value = double.tryParse(_display);
        if (value != null) {
          _display = _format(value / 100);
          _startNew = true;
        }
      });

  void _clear() => setState(() {
        _display = '0';
        _stored = null;
        _operator = null;
        _startNew = true;
      });

  void _evaluate() {
    final double? left = _stored;
    final double? right = double.tryParse(_display);
    if (left == null || right == null || _operator == null || _startNew) {
      return;
    }
    final double result = switch (_operator) {
      '+' => left + right,
      '−' => left - right,
      '×' => left * right,
      '÷' => right == 0 ? double.nan : left / right,
      _ => right,
    };
    _display = result.isNaN ? 'Error' : _format(result);
  }

  static String _format(double value) {
    if (value == value.roundToDouble() && value.abs() < 1e15) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(6).replaceFirst(RegExp(r'\.?0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    Widget key(
      String label, {
      VoidCallback? onPressed,
      Color? background,
      Color? foreground,
    }) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: background ?? colors.surfaceContainerHighest,
            foregroundColor: foreground ?? colors.onSurface,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(fontSize: 18),
          ),
          onPressed: onPressed ?? () => _digit(label),
          child: Text(label),
        ),
      );
    }

    Widget operatorKey(String label) => key(
          label,
          onPressed: () => _operation(label),
          background: _operator == label && _startNew
              ? colors.primary
              : colors.primaryContainer,
          foreground: _operator == label && _startNew
              ? colors.onPrimary
              : colors.onPrimaryContainer,
        );

    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Container(
            height: 64,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(10),
            ),
            child: FittedBox(
              child: Text(
                _display,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Column(
              children: <Widget>[
                for (final List<Widget> row in <List<Widget>>[
                  <Widget>[
                    key('C', onPressed: _clear, foreground: colors.error),
                    key('±', onPressed: _negate),
                    key('%', onPressed: _percent),
                    operatorKey('÷'),
                  ],
                  <Widget>[key('7'), key('8'), key('9'), operatorKey('×')],
                  <Widget>[key('4'), key('5'), key('6'), operatorKey('−')],
                  <Widget>[key('1'), key('2'), key('3'), operatorKey('+')],
                  <Widget>[
                    key('0'),
                    key('00', onPressed: () => _digit('00')),
                    key('.'),
                    key(
                      '=',
                      onPressed: _equals,
                      background: colors.primary,
                      foreground: colors.onPrimary,
                    ),
                  ],
                ])
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (final Widget button in row)
                          Expanded(child: button),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
