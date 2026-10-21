import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'admin_stat_card_model.dart';
export 'admin_stat_card_model.dart';

class AdminStatCardWidget extends StatefulWidget {
  const AdminStatCardWidget({
    super.key,
    Color? color,
    this.icon,
    String? label,
    String? trendText,
    String? value,
    bool? trendUp,
  })  : this.color = color ?? const Color(0x00000000),
        this.label = label ?? 'Vendas Hoje',
        this.trendText = trendText ?? '+12%',
        this.value = value ?? '€1.240',
        this.trendUp = trendUp ?? true;

  final Color color;
  final Widget? icon;
  final String label;
  final String trendText;
  final String value;
  final bool trendUp;

  @override
  State<AdminStatCardWidget> createState() => _AdminStatCardWidgetState();
}

class _AdminStatCardWidgetState extends State<AdminStatCardWidget> {
  late AdminStatCardModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AdminStatCardModel());
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
        color: FlutterFlowTheme.of(context).secondaryBackground,
        borderRadius: BorderRadius.circular(12.0),
        shape: BoxShape.rectangle,
      ),
      child: Padding(
        padding: EdgeInsets.all(24.0),
        child: Container(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    flex: 1,
                    child: Text(
                      valueOrDefault<String>(
                        widget!.label,
                        'Vendas Hoje',
                      ),
                      maxLines: 1,
                      style: FlutterFlowTheme.of(context).labelMedium.override(
                            font: GoogleFonts.montserrat(
                              fontWeight: FlutterFlowTheme.of(context)
                                  .labelMedium
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .labelMedium
                                  .fontStyle,
                            ),
                            color: FlutterFlowTheme.of(context).secondaryText,
                            letterSpacing: 0.0,
                            fontWeight: FlutterFlowTheme.of(context)
                                .labelMedium
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .labelMedium
                                .fontStyle,
                            lineHeight: 1.3,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  widget!.icon!,
                ],
              ),
              Text(
                valueOrDefault<String>(
                  widget!.value,
                  '€1.240',
                ),
                style: FlutterFlowTheme.of(context).titleLarge.override(
                      font: GoogleFonts.montserrat(
                        fontWeight: FontWeight.bold,
                        fontStyle:
                            FlutterFlowTheme.of(context).titleLarge.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).primaryText,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.bold,
                      fontStyle:
                          FlutterFlowTheme.of(context).titleLarge.fontStyle,
                      lineHeight: 1.4,
                    ),
              ),
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 14.0,
                    height: 14.0,
                    child: Stack(
                      alignment: AlignmentDirectional(0.0, 0.0),
                      children: [
                        if (valueOrDefault<bool>(
                          valueOrDefault<bool>(
                            widget!.trendUp,
                            true,
                          )
                              ? true
                              : false,
                          true,
                        ))
                          Icon(
                            Icons.trending_up_rounded,
                            color: valueOrDefault<Color>(
                              valueOrDefault<bool>(
                                widget!.trendUp,
                                true,
                              )
                                  ? FlutterFlowTheme.of(context).success
                                  : FlutterFlowTheme.of(context).error,
                              FlutterFlowTheme.of(context).success,
                            ),
                            size: 14.0,
                          ),
                        if (valueOrDefault<bool>(
                          valueOrDefault<bool>(
                            widget!.trendUp,
                            true,
                          )
                              ? false
                              : true,
                          false,
                        ))
                          Icon(
                            Icons.trending_down_rounded,
                            color: valueOrDefault<Color>(
                              valueOrDefault<bool>(
                                widget!.trendUp,
                                true,
                              )
                                  ? FlutterFlowTheme.of(context).success
                                  : FlutterFlowTheme.of(context).error,
                              FlutterFlowTheme.of(context).success,
                            ),
                            size: 14.0,
                          ),
                      ],
                    ),
                  ),
                  Text(
                    valueOrDefault<String>(
                      widget!.trendText,
                      '+12%',
                    ),
                    style: FlutterFlowTheme.of(context).labelSmall.override(
                          font: GoogleFonts.montserrat(
                            fontWeight: FlutterFlowTheme.of(context)
                                .labelSmall
                                .fontWeight,
                            fontStyle: FlutterFlowTheme.of(context)
                                .labelSmall
                                .fontStyle,
                          ),
                          color: valueOrDefault<Color>(
                            valueOrDefault<bool>(
                              widget!.trendUp,
                              true,
                            )
                                ? FlutterFlowTheme.of(context).success
                                : FlutterFlowTheme.of(context).error,
                            FlutterFlowTheme.of(context).success,
                          ),
                          letterSpacing: 0.0,
                          fontWeight: FlutterFlowTheme.of(context)
                              .labelSmall
                              .fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).labelSmall.fontStyle,
                          lineHeight: 1.2,
                        ),
                  ),
                ].divide(SizedBox(width: 4.0)),
              ),
            ].divide(SizedBox(height: 4.0)),
          ),
        ),
      ),
    );
  }
}
