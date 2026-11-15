import 'package:flutter/material.dart';

/// Shared visual states for nickname and email availability fields.
enum AvailabilityInputState { neutral, checking, available, invalid }

const availabilitySuccessColor = Color(0xFF25815F);
const availabilityFailureColor = Color(0xFFBF4B45);
const availabilityNeutralColor = Color(0xFF6C7E74);
const _neutralBorderColor = Color(0xFFD6DFD8);
const _focusedNeutralBorderColor = Color(0xFFA7B8AD);

OutlineInputBorder _inputBorder(Color color, double width) =>
    OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );

/// Every border state is explicit so focus and form validation do not replace
/// a completed availability result with the theme's default outline.
InputDecoration availabilityInputDecoration({
  required String labelText,
  required AvailabilityInputState state,
  String? hintText,
  String? helperText,
  required String checkingSemanticLabel,
  required String successSemanticLabel,
  required String failureSemanticLabel,
}) {
  final succeeded = state == AvailabilityInputState.available;
  final failed = state == AvailabilityInputState.invalid;
  final color = succeeded
      ? availabilitySuccessColor
      : failed
      ? availabilityFailureColor
      : _neutralBorderColor;
  final focusedColor = succeeded || failed ? color : _focusedNeutralBorderColor;
  final borderWidth = succeeded || failed ? 1.5 : 1.0;
  final focusedWidth = succeeded || failed ? 2.0 : 1.5;
  final labelColor = succeeded
      ? availabilitySuccessColor
      : failed
      ? availabilityFailureColor
      : availabilityNeutralColor;
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    helperText: helperText,
    alignLabelWithHint: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    filled: true,
    fillColor: succeeded
        ? const Color(0xFFF2F8F3)
        : failed
        ? const Color(0xFFFFF5F3)
        : Colors.white,
    labelStyle: TextStyle(color: labelColor),
    floatingLabelStyle: TextStyle(color: labelColor),
    helperStyle: const TextStyle(color: availabilityNeutralColor),
    errorStyle: const TextStyle(color: availabilityFailureColor),
    border: _inputBorder(color, borderWidth),
    enabledBorder: _inputBorder(color, borderWidth),
    focusedBorder: _inputBorder(focusedColor, focusedWidth),
    disabledBorder: _inputBorder(color, borderWidth),
    errorBorder: _inputBorder(availabilityFailureColor, 1.5),
    focusedErrorBorder: _inputBorder(availabilityFailureColor, 2),
    suffixIcon: state == AvailabilityInputState.checking
        ? Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: availabilityNeutralColor,
                semanticsLabel: checkingSemanticLabel,
              ),
            ),
          )
        : succeeded
        ? Icon(
            Icons.check_circle_rounded,
            color: availabilitySuccessColor,
            semanticLabel: successSemanticLabel,
          )
        : failed
        ? Icon(
            Icons.error_outline_rounded,
            color: availabilityFailureColor,
            semanticLabel: failureSemanticLabel,
          )
        : null,
  );
}
