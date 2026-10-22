import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'team_operations_online_model.dart';
export 'team_operations_online_model.dart';

/// Sessão autenticada da equipa, eventos atribuídos e tickets do fotógrafo.
class TeamOperationsOnlineWidget extends StatefulWidget {
  const TeamOperationsOnlineWidget({super.key});

  static String routeName = 'TeamOperationsOnline';
  static String routePath = '/team-operations-online';

  @override
  State<TeamOperationsOnlineWidget> createState() =>
      _TeamOperationsOnlineWidgetState();
}

class _TeamOperationsOnlineWidgetState
    extends State<TeamOperationsOnlineWidget> {
  late TeamOperationsOnlineModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TeamOperationsOnlineModel());
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
            child: custom_widgets.Studio59StaffLogin(),
          ),
        ),
      ),
    );
  }
}
