import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'studio59_sync_online_model.dart';
export 'studio59_sync_online_model.dart';

/// Sincronização autenticada de sessão offline com o serviço online.
class Studio59SyncOnlineWidget extends StatefulWidget {
  const Studio59SyncOnlineWidget({super.key});

  static String routeName = 'Studio59SyncOnline';
  static String routePath = '/studio59-sync';

  @override
  State<Studio59SyncOnlineWidget> createState() =>
      _Studio59SyncOnlineWidgetState();
}

class _Studio59SyncOnlineWidgetState extends State<Studio59SyncOnlineWidget> {
  late Studio59SyncOnlineModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Studio59SyncOnlineModel());
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
            child: custom_widgets.Studio59SyncPanel(),
          ),
        ),
      ),
    );
  }
}
