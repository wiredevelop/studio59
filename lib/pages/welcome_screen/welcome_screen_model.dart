import '/backend/schema/structs/index.dart';
import '/components/button/button_widget.dart';
import '/components/keypad_button/keypad_button_widget.dart';
import '/components/pin_digit/pin_digit_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'welcome_screen_widget.dart' show WelcomeScreenWidget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class WelcomeScreenModel extends FlutterFlowModel<WelcomeScreenWidget> {
  ///  Local state fields for this page.

  bool? showKeypad = false;

  String? selectedPinSlot = '1';

  String? pinDigit1 = '';

  String? pinDigit2 = '';

  String? pinDigit3 = '';

  String? pinDigit4 = '';

  bool? pinRequestInFlight = false;

  int? teamLogoTapCount = 0;

  bool? qrRequestInFlight = false;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - readStudio59StaffToken] action in Image widget.
  String? welcomeStaffTokenForDashboard;
  // Model for Button.
  late ButtonModel buttonModel;
  var guestQrScan = '';
  // Stores action output result for [Custom Action - enterStudio59GuestSessionSafely] action in Button widget.
  Studio59GuestSessionResultStruct? guestQrEntry;
  // Model for PinDigit.
  late PinDigitModel pinDigitModel1;
  // Model for PinDigit.
  late PinDigitModel pinDigitModel2;
  // Model for PinDigit.
  late PinDigitModel pinDigitModel3;
  // Model for PinDigit.
  late PinDigitModel pinDigitModel4;
  // Model for KeypadButton.
  late KeypadButtonModel keypadButtonModel1;
  // Stores action output result for [Custom Action - enterStudio59GuestSessionSafely] action in KeypadButton widget.
  Studio59GuestSessionResultStruct? guestPinEntry1;
  // Model for KeypadButton.
  late KeypadButtonModel keypadButtonModel2;
  // Stores action output result for [Custom Action - enterStudio59GuestSessionSafely] action in KeypadButton widget.
  Studio59GuestSessionResultStruct? guestPinEntry2;
  // Model for KeypadButton.
  late KeypadButtonModel keypadButtonModel3;
  // Stores action output result for [Custom Action - enterStudio59GuestSessionSafely] action in KeypadButton widget.
  Studio59GuestSessionResultStruct? guestPinEntry3;
  // Model for KeypadButton.
  late KeypadButtonModel keypadButtonModel4;
  // Stores action output result for [Custom Action - enterStudio59GuestSessionSafely] action in KeypadButton widget.
  Studio59GuestSessionResultStruct? guestPinEntry4;
  // Model for KeypadButton.
  late KeypadButtonModel keypadButtonModel5;
  // Stores action output result for [Custom Action - enterStudio59GuestSessionSafely] action in KeypadButton widget.
  Studio59GuestSessionResultStruct? guestPinEntry5;
  // Model for KeypadButton.
  late KeypadButtonModel keypadButtonModel6;
  // Stores action output result for [Custom Action - enterStudio59GuestSessionSafely] action in KeypadButton widget.
  Studio59GuestSessionResultStruct? guestPinEntry6;
  // Model for KeypadButton.
  late KeypadButtonModel keypadButtonModel7;
  // Stores action output result for [Custom Action - enterStudio59GuestSessionSafely] action in KeypadButton widget.
  Studio59GuestSessionResultStruct? guestPinEntry7;
  // Model for KeypadButton.
  late KeypadButtonModel keypadButtonModel8;
  // Stores action output result for [Custom Action - enterStudio59GuestSessionSafely] action in KeypadButton widget.
  Studio59GuestSessionResultStruct? guestPinEntry8;
  // Model for KeypadButton.
  late KeypadButtonModel keypadButtonModel9;
  // Stores action output result for [Custom Action - enterStudio59GuestSessionSafely] action in KeypadButton widget.
  Studio59GuestSessionResultStruct? guestPinEntry9;
  // Model for KeypadButton.
  late KeypadButtonModel keypadButtonModel10;
  // Stores action output result for [Custom Action - enterStudio59GuestSessionSafely] action in KeypadButton widget.
  Studio59GuestSessionResultStruct? guestPinEntry0;

  @override
  void initState(BuildContext context) {
    buttonModel = createModel(context, () => ButtonModel());
    pinDigitModel1 = createModel(context, () => PinDigitModel());
    pinDigitModel2 = createModel(context, () => PinDigitModel());
    pinDigitModel3 = createModel(context, () => PinDigitModel());
    pinDigitModel4 = createModel(context, () => PinDigitModel());
    keypadButtonModel1 = createModel(context, () => KeypadButtonModel());
    keypadButtonModel2 = createModel(context, () => KeypadButtonModel());
    keypadButtonModel3 = createModel(context, () => KeypadButtonModel());
    keypadButtonModel4 = createModel(context, () => KeypadButtonModel());
    keypadButtonModel5 = createModel(context, () => KeypadButtonModel());
    keypadButtonModel6 = createModel(context, () => KeypadButtonModel());
    keypadButtonModel7 = createModel(context, () => KeypadButtonModel());
    keypadButtonModel8 = createModel(context, () => KeypadButtonModel());
    keypadButtonModel9 = createModel(context, () => KeypadButtonModel());
    keypadButtonModel10 = createModel(context, () => KeypadButtonModel());
  }

  @override
  void dispose() {
    buttonModel.dispose();
    pinDigitModel1.dispose();
    pinDigitModel2.dispose();
    pinDigitModel3.dispose();
    pinDigitModel4.dispose();
    keypadButtonModel1.dispose();
    keypadButtonModel2.dispose();
    keypadButtonModel3.dispose();
    keypadButtonModel4.dispose();
    keypadButtonModel5.dispose();
    keypadButtonModel6.dispose();
    keypadButtonModel7.dispose();
    keypadButtonModel8.dispose();
    keypadButtonModel9.dispose();
    keypadButtonModel10.dispose();
  }
}
