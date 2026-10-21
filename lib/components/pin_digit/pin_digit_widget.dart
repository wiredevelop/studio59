import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'pin_digit_model.dart';
export 'pin_digit_model.dart';

class PinDigitWidget extends StatefulWidget {
  const PinDigitWidget({
    super.key,
    String? value,
    bool? filled,
  })  : this.value = value ?? '5',
        this.filled = filled ?? true;

  final String value;
  final bool filled;

  @override
  State<PinDigitWidget> createState() => _PinDigitWidgetState();
}

class _PinDigitWidgetState extends State<PinDigitWidget> {
  late PinDigitModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PinDigitModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64.0,
      height: 72.0,
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
        shape: BoxShape.rectangle,
        border: Border.all(
          color: valueOrDefault<Color>(
            valueOrDefault<bool>(
              widget!.filled,
              true,
            )
                ? FlutterFlowTheme.of(context).primary
                : FlutterFlowTheme.of(context).alternate,
            FlutterFlowTheme.of(context).primary,
          ),
          width: valueOrDefault<double>(
            valueOrDefault<bool>(
              widget!.filled,
              true,
            )
                ? 2.0
                : 2.0,
            2.0,
          ),
        ),
      ),
      alignment: AlignmentDirectional(0.0, 0.0),
      child: Visibility(
        visible: valueOrDefault<bool>(
          widget!.filled,
          true,
        ),
        child: Text(
          valueOrDefault<String>(
            widget!.value,
            '5',
          ),
          style: FlutterFlowTheme.of(context).headlineMedium.override(
                font: GoogleFonts.playfairDisplay(
                  fontWeight:
                      FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
                color: FlutterFlowTheme.of(context).primaryText,
                letterSpacing: 0.0,
                fontWeight:
                    FlutterFlowTheme.of(context).headlineMedium.fontWeight,
                fontStyle:
                    FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                lineHeight: 1.3,
              ),
        ),
      ),
    );
  }
}
