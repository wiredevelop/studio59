import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'studio59_dashboard_online_model.dart';
export 'studio59_dashboard_online_model.dart';

/// Painel autenticado com dados e secções permitidas pela API Studio 59.
class Studio59DashboardOnlineWidget extends StatefulWidget {
  const Studio59DashboardOnlineWidget({super.key});

  static String routeName = 'Studio59DashboardOnline';
  static String routePath = '/studio59-dashboard';

  @override
  State<Studio59DashboardOnlineWidget> createState() =>
      _Studio59DashboardOnlineWidgetState();
}

class _Studio59DashboardOnlineWidgetState
    extends State<Studio59DashboardOnlineWidget> {
  late Studio59DashboardOnlineModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Studio59DashboardOnlineModel());
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        body: SafeArea(
          top: true,
          child: Container(
            child: custom_widgets.Studio59StaffHub(),
          ),
        ),
      ),
    );
  }
}
