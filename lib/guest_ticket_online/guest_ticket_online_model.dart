import '/backend/api_requests/api_calls.dart';
import '/backend/schema/structs/index.dart';
import '/flutter_flow/ff_builtin_enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'guest_ticket_online_widget.dart' show GuestTicketOnlineWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class GuestTicketOnlineModel extends FlutterFlowModel<GuestTicketOnlineWidget> {
  ///  Local state fields for this page.

  String? serverDeliveryType = '';

  dynamic serverShippingFee;

  bool? shippingLookupFailed = false;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - API (Studio59PublicOrderByCode)] action in GuestTicketOnline widget.
  ApiCallResponse? guestOrderDeliveryDetails;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
