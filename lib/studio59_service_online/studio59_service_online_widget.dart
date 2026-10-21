import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'studio59_service_online_model.dart';
export 'studio59_service_online_model.dart';

/// Ficha real do serviço acessível à equipa autenticada.
class Studio59ServiceOnlineWidget extends StatefulWidget {
  const Studio59ServiceOnlineWidget({
    super.key,
    this.eventId,
  });

  final int? eventId;

  static String routeName = 'Studio59ServiceOnline';
  static String routePath = '/studio59-service';

  @override
  State<Studio59ServiceOnlineWidget> createState() =>
      _Studio59ServiceOnlineWidgetState();
}

class _Studio59ServiceOnlineWidgetState
    extends State<Studio59ServiceOnlineWidget> {
  late Studio59ServiceOnlineModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Studio59ServiceOnlineModel());
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
            child: custom_widgets.Studio59ServiceDetail(
              eventId: widget!.eventId,
            ),
          ),
        ),
      ),
    );
  }
}
