import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/ff_builtin_enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'team_operations_online_widget.dart' show TeamOperationsOnlineWidget;
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class TeamOperationsOnlineModel
    extends FlutterFlowModel<TeamOperationsOnlineWidget> {
  ///  Local state fields for this page.

  String? email = '';

  String? password = '';

  String? staffToken = '';

  String? staffName = '';

  bool? authenticated = false;

  List<Studio59StaffEventStruct> events = [];
  void addToEvents(Studio59StaffEventStruct item) => events.add(item);
  void removeFromEvents(Studio59StaffEventStruct item) => events.remove(item);
  void removeAtIndexFromEvents(int index) => events.removeAt(index);
  void insertAtIndexInEvents(int index, Studio59StaffEventStruct item) =>
      events.insert(index, item);
  void updateEventsAtIndex(
          int index, Function(Studio59StaffEventStruct) updateFn) =>
      events[index] = updateFn(events[index]);

  List<Studio59StaffOrderStruct> orders = [];
  void addToOrders(Studio59StaffOrderStruct item) => orders.add(item);
  void removeFromOrders(Studio59StaffOrderStruct item) => orders.remove(item);
  void removeAtIndexFromOrders(int index) => orders.removeAt(index);
  void insertAtIndexInOrders(int index, Studio59StaffOrderStruct item) =>
      orders.insert(index, item);
  void updateOrdersAtIndex(
          int index, Function(Studio59StaffOrderStruct) updateFn) =>
      orders[index] = updateFn(orders[index]);

  int? activeEventId = 0;

  int? selectedOrderId = 0;

  Studio59StaffOrderStruct? orderDetails;
  void updateOrderDetailsStruct(Function(Studio59StaffOrderStruct) updateFn) {
    updateFn(orderDetails ??= Studio59StaffOrderStruct());
  }

  bool? busy = false;

  Studio59StaffOrderDetailsStruct? orderDetailsFull;
  void updateOrderDetailsFullStruct(
      Function(Studio59StaffOrderDetailsStruct) updateFn) {
    updateFn(orderDetailsFull ??= Studio59StaffOrderDetailsStruct());
  }

  String? cashReceivedText = '';

  String? cashReceivedDecimal = '0.00';

  String? cashChangeDecimal = '0.00';

  String? cashDueDecimal = '0.00';

  bool? cashChangeGiven = false;

  bool? paymentSubmitting = false;

  bool? paymentUncertain = false;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - readStudio59StaffToken] action in TeamOperationsOnline widget.
  String? restoredStaffTokenOnline;
  // Stores action output result for [Custom Action - authenticateStudio59StaffWithNullableToken] action in TeamOperationsOnline widget.
  Studio59StaffAuthResultStruct? restoredTeamAuth;
  // Stores action output result for [Custom Action - deleteStudio59StaffToken] action in TeamOperationsOnline widget.
  bool? deleteStudio59StaffTokenResult;
  // State field(s) for staffEmail widget.
  FocusNode? staffEmailFocusNode;
  TextEditingController? staffEmailTextController;
  String? Function(BuildContext, String?)? staffEmailTextControllerValidator;
  // State field(s) for staffPassword widget.
  FocusNode? staffPasswordFocusNode;
  TextEditingController? staffPasswordTextController;
  String? Function(BuildContext, String?)? staffPasswordTextControllerValidator;
  // Stores action output result for [Custom Action - authenticateStudio59StaffWithNullableToken] action in Button widget.
  Studio59StaffAuthResultStruct? teamUsernameAuth;
  // Stores action output result for [Custom Action - storeStudio59StaffToken] action in Button widget.
  bool? storedUsernameAuthToken;
  // Stores action output result for [Backend Call - API (Studio59StaffLogoutTyped)] action in Button widget.
  ApiCallResponse? teamLogoutResult;
  // Stores action output result for [Custom Action - deleteStudio59StaffToken] action in Button widget.
  bool? deleteStudio59StaffTokenResult2;
  // Stores action output result for [Backend Call - API (Studio59EventOrdersTyped)] action in Button widget.
  ApiCallResponse? eventOrdersForPhotographer;
  // Stores action output result for [Backend Call - API (Studio59OrderDetailsTyped)] action in Button widget.
  ApiCallResponse? photographerOrderDetails;
  // Stores action output result for [Backend Call - API (Studio59OrderDetailsRaw)] action in Button widget.
  ApiCallResponse? selectedPhotographerOrderDetails;
  // Stores action output result for [Backend Call - API (Studio59OrderDetailsRaw)] action in Button widget.
  ApiCallResponse? selectedPhotographerOrderDetails2;
  // State field(s) for cashReceivedAmount widget.
  FocusNode? cashReceivedAmountFocusNode1;
  TextEditingController? cashReceivedAmountTextController1;
  String? Function(BuildContext, String?)?
      cashReceivedAmountTextController1Validator;
  // State field(s) for Checkbox widget.
  bool? checkboxValue1;
  // State field(s) for cashReceivedAmount widget.
  FocusNode? cashReceivedAmountFocusNode2;
  TextEditingController? cashReceivedAmountTextController2;
  String? Function(BuildContext, String?)?
      cashReceivedAmountTextController2Validator;
  // State field(s) for Checkbox widget.
  bool? checkboxValue2;
  // Stores action output result for [Custom Action - postStudio59MarkPaidWithCashNullableSafe] action in Button widget.
  Studio59MarkPaidResultStruct? photographerMarkPaidResult;
  // Stores action output result for [Backend Call - API (Studio59OrderDetailsRaw)] action in Button widget.
  ApiCallResponse? reloadedPhotographerOrderAfterPayment;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    staffEmailFocusNode?.dispose();
    staffEmailTextController?.dispose();

    staffPasswordFocusNode?.dispose();
    staffPasswordTextController?.dispose();

    cashReceivedAmountFocusNode1?.dispose();
    cashReceivedAmountTextController1?.dispose();

    cashReceivedAmountFocusNode2?.dispose();
    cashReceivedAmountTextController2?.dispose();
  }
}
