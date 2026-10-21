import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/ff_builtin_enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'photographer_dashboard_online_model.dart';
export 'photographer_dashboard_online_model.dart';

/// Dashboard da equipa com agenda mensal real e acesso aos tickets.
class PhotographerDashboardOnlineWidget extends StatefulWidget {
  const PhotographerDashboardOnlineWidget({super.key});

  static String routeName = 'PhotographerDashboardOnline';
  static String routePath = '/photographer-dashboard';

  @override
  State<PhotographerDashboardOnlineWidget> createState() =>
      _PhotographerDashboardOnlineWidgetState();
}

class _PhotographerDashboardOnlineWidgetState
    extends State<PhotographerDashboardOnlineWidget> {
  late PhotographerDashboardOnlineModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PhotographerDashboardOnlineModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.dashboardStaffToken = await actions.readStudio59StaffToken();
      if (!(_model.dashboardStaffToken == '')) {
        _model.dashboardEventsJson = await actions.loadStudio59AgendaEvents(
          _model.dashboardStaffToken,
        );
        _model.eventsJson = _model.dashboardEventsJson;
        safeSetState(() {});
      }
    });
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
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          automaticallyImplyLeading: true,
          title: Text(
            'Dashboard da equipa',
            style: FlutterFlowTheme.of(context).titleLarge.override(
                  font: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleLarge.fontStyle,
                  ),
                  fontSize: 22.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle: FlutterFlowTheme.of(context).titleLarge.fontStyle,
                ),
          ),
          actions: [],
          centerTitle: true,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: (FFMainAxisAlignment.start).flutterValue,
                crossAxisAlignment: (FFCrossAxisAlignment.center).flutterValue,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    'Agenda dos serviços',
                    style: FlutterFlowTheme.of(context).titleLarge.override(
                          font: GoogleFonts.montserrat(
                            fontWeight: FlutterFlowTheme.of(context)
                                .titleLarge
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .titleLarge
                                .fontStyle,
                          ),
                          letterSpacing: 0.0,
                          fontWeight: FlutterFlowTheme.of(context)
                              .titleLarge
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).titleLarge.fontStyle,
                        ),
                  ),
                  Container(
                    child: custom_widgets.Studio59MonthlyAgenda(
                      eventsJson: _model.eventsJson,
                    ),
                  ),
                  FFButtonWidget(
                    onPressed: () async {
                      context.pushNamed(TeamOperationsOnlineWidget.routeName);
                    },
                    text: 'Tickets e pagamentos',
                    options: FFButtonOptions(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                      iconPadding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                      color: FlutterFlowTheme.of(context).primary,
                      textStyle: TextStyle(
                        color: Colors.white,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  FFButtonWidget(
                    onPressed: () async {
                      _model.dashboardLogoutToken =
                          await actions.readStudio59StaffToken();
                      _model.dashboardLogout =
                          await Studio59StaffLogoutTypedCall.call(
                        token: _model.dashboardLogoutToken,
                      );

                      if ((_model.dashboardLogout?.succeeded ?? true)) {
                        _model.deleteStudio59StaffTokenResult =
                            await actions.deleteStudio59StaffToken();
                        if (Navigator.of(context).canPop()) {
                          context.pop();
                        }
                        context.pushNamed(WelcomeScreenWidget.routeName);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Não foi possível terminar a sessão no servidor.',
                              style: TextStyle(),
                            ),
                            duration: Duration(milliseconds: 4000),
                          ),
                        );
                      }

                      safeSetState(() {});
                    },
                    text: 'Terminar sessão',
                    options: FFButtonOptions(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                      iconPadding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                      color: FlutterFlowTheme.of(context).primary,
                      textStyle: TextStyle(
                        color: Colors.white,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ].divide(SizedBox(height: 14.0)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
