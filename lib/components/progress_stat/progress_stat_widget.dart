import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'progress_stat_model.dart';
export 'progress_stat_model.dart';

class ProgressStatWidget extends StatefulWidget {
  const ProgressStatWidget({
    super.key,
    String? label,
    String? value,
  })  : this.label = label ?? 'Fotos',
        this.value = value ?? '142 / 184';

  final String label;
  final String value;

  @override
  State<ProgressStatWidget> createState() => _ProgressStatWidgetState();
}

class _ProgressStatWidgetState extends State<ProgressStatWidget> {
  late ProgressStatModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProgressStatModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          valueOrDefault<String>(
            widget!.label,
            'Fotos',
          ),
          style: FlutterFlowTheme.of(context).labelSmall.override(
                font: GoogleFonts.montserrat(
                  fontWeight:
                      FlutterFlowTheme.of(context).labelSmall.fontWeight,
                  fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
                ),
                color: FlutterFlowTheme.of(context).secondaryText,
                letterSpacing: 0.0,
                fontWeight: FlutterFlowTheme.of(context).labelSmall.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
                lineHeight: 1.2,
              ),
        ),
        Text(
          valueOrDefault<String>(
            widget!.value,
            '142 / 184',
          ),
          style: FlutterFlowTheme.of(context).titleMedium.override(
                font: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
                ),
                color: FlutterFlowTheme.of(context).primaryText,
                letterSpacing: 0.0,
                fontWeight: FontWeight.bold,
                fontStyle: FlutterFlowTheme.of(context).titleMedium.fontStyle,
                lineHeight: 1.45,
              ),
        ),
      ].divide(SizedBox(height: 4.0)),
    );
  }
}
