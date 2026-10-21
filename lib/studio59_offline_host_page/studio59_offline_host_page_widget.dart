import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'studio59_offline_host_page_model.dart';
export 'studio59_offline_host_page_model.dart';

/// Criação e gestão da sessão offline no computador anfitrião.
class Studio59OfflineHostPageWidget extends StatefulWidget {
  const Studio59OfflineHostPageWidget({super.key});

  static String routeName = 'Studio59OfflineHostPage';
  static String routePath = '/offline-host';

  @override
  State<Studio59OfflineHostPageWidget> createState() =>
      _Studio59OfflineHostPageWidgetState();
}

class _Studio59OfflineHostPageWidgetState
    extends State<Studio59OfflineHostPageWidget> {
  late Studio59OfflineHostPageModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => Studio59OfflineHostPageModel());
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
            child: custom_widgets.Studio59OfflineSession(),
          ),
        ),
      ),
    );
  }
}
