import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'status_badge64303d10_model.dart';
export 'status_badge64303d10_model.dart';

class StatusBadge64303d10Widget extends StatefulWidget {
  const StatusBadge64303d10Widget({
    super.key,
    String? status,
  }) : this.status = status ?? 'pago';

  final String status;

  @override
  State<StatusBadge64303d10Widget> createState() =>
      _StatusBadge64303d10WidgetState();
}

class _StatusBadge64303d10WidgetState extends State<StatusBadge64303d10Widget> {
  late StatusBadge64303d10Model _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => StatusBadge64303d10Model());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: valueOrDefault<Color>(
          valueOrDefault<String>(
                    widget!.status,
                    'pago',
                  ) ==
                  'pendente'
              ? FlutterFlowTheme.of(context).error15
              : FlutterFlowTheme.of(context).success15,
          FlutterFlowTheme.of(context).success15,
        ),
        borderRadius: BorderRadius.circular(8.0),
        shape: BoxShape.rectangle,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16.0, 4.0, 16.0, 4.0),
        child: Container(
          child: Text(
            valueOrDefault<String>(
              widget!.status,
              'pago',
            ),
            style: FlutterFlowTheme.of(context).labelSmall.override(
                  font: GoogleFonts.montserrat(
                    fontWeight: FontWeight.bold,
                    fontStyle:
                        FlutterFlowTheme.of(context).labelSmall.fontStyle,
                  ),
                  color: valueOrDefault<Color>(
                    valueOrDefault<String>(
                              widget!.status,
                              'pago',
                            ) ==
                            'pendente'
                        ? FlutterFlowTheme.of(context).error
                        : FlutterFlowTheme.of(context).success,
                    FlutterFlowTheme.of(context).success,
                  ),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.bold,
                  fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
                  lineHeight: 1.2,
                ),
          ),
        ),
      ),
    );
  }
}
