import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'team_operations_online_widget.dart' show TeamOperationsOnlineWidget;
import 'package:flutter/material.dart';
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

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
