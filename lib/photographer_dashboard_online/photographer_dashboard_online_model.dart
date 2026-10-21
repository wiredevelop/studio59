import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/ff_builtin_enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'photographer_dashboard_online_widget.dart'
    show PhotographerDashboardOnlineWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class PhotographerDashboardOnlineModel
    extends FlutterFlowModel<PhotographerDashboardOnlineWidget> {
  ///  Local state fields for this page.

  String? eventsJson = '[]';

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - readStudio59StaffToken] action in PhotographerDashboardOnline widget.
  String? dashboardStaffToken;
  // Stores action output result for [Custom Action - loadStudio59AgendaEvents] action in PhotographerDashboardOnline widget.
  String? dashboardEventsJson;
  // Stores action output result for [Custom Action - readStudio59StaffToken] action in Button widget.
  String? dashboardLogoutToken;
  // Stores action output result for [Backend Call - API (Studio59StaffLogoutTyped)] action in Button widget.
  ApiCallResponse? dashboardLogout;
  // Stores action output result for [Custom Action - deleteStudio59StaffToken] action in Button widget.
  bool? deleteStudio59StaffTokenResult;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
