import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'sync_item_model.dart';
export 'sync_item_model.dart';

class SyncItemWidget extends StatefulWidget {
  const SyncItemWidget({
    super.key,
    String? count,
    this.icon,
    String? subtitle,
    String? time,
    String? title,
    String? status,
  })  : this.count = count ?? '42 ficheiros',
        this.subtitle = subtitle ?? 'Upload de ficheiros RAW/JPG',
        this.time = time ?? 'A iniciar...',
        this.title = title ?? 'Galeria de Fotos',
        this.status = status ?? 'syncing';

  final String count;
  final Widget? icon;
  final String subtitle;
  final String time;
  final String title;
  final String status;

  @override
  State<SyncItemWidget> createState() => _SyncItemWidgetState();
}

class _SyncItemWidgetState extends State<SyncItemWidget> {
  late SyncItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SyncItemModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 16.0),
      child: Container(
        child: Container(
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(12.0),
            shape: BoxShape.rectangle,
            border: Border.all(
              color: FlutterFlowTheme.of(context).alternate,
              width: 1.0,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Container(
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48.0,
                    height: 48.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).primaryBackground,
                      borderRadius: BorderRadius.circular(8.0),
                      shape: BoxShape.rectangle,
                    ),
                    alignment: AlignmentDirectional(0.0, 0.0),
                    child: widget!.icon!,
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          valueOrDefault<String>(
                            widget!.title,
                            'Galeria de Fotos',
                          ),
                          style: FlutterFlowTheme.of(context)
                              .titleMedium
                              .override(
                                font: GoogleFonts.montserrat(
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleMedium
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w600,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .fontStyle,
                                lineHeight: 1.45,
                              ),
                        ),
                        Text(
                          valueOrDefault<String>(
                            widget!.subtitle,
                            'Upload de ficheiros RAW/JPG',
                          ),
                          style: FlutterFlowTheme.of(context)
                              .bodySmall
                              .override(
                                font: GoogleFonts.montserrat(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodySmall
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .fontStyle,
                                lineHeight: 1.4,
                              ),
                        ),
                      ].divide(SizedBox(height: 4.0)),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: valueOrDefault<Color>(
                            valueOrDefault<String>(
                                      widget!.status,
                                      'syncing',
                                    ) ==
                                    'error'
                                ? Color(0xFFFFEBEE)
                                : Color(0xFFFCE4EC),
                            Color(0xFFFCE4EC),
                          ),
                          borderRadius: BorderRadius.circular(9999.0),
                          shape: BoxShape.rectangle,
                        ),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              10.0, 4.0, 10.0, 4.0),
                          child: Container(
                            child: Row(
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
                                        valueOrDefault<String>(
                                                  widget!.status,
                                                  'syncing',
                                                ) ==
                                                'error'
                                            ? true
                                            : false,
                                        false,
                                      ))
                                        Icon(
                                          Icons.error_outline_rounded,
                                          color: valueOrDefault<Color>(
                                            valueOrDefault<String>(
                                                      widget!.status,
                                                      'syncing',
                                                    ) ==
                                                    'error'
                                                ? FlutterFlowTheme.of(context)
                                                    .error
                                                : FlutterFlowTheme.of(context)
                                                    .primary,
                                            FlutterFlowTheme.of(context)
                                                .primary,
                                          ),
                                          size: 14.0,
                                        ),
                                      if (valueOrDefault<bool>(
                                        valueOrDefault<String>(
                                                  widget!.status,
                                                  'syncing',
                                                ) ==
                                                'error'
                                            ? false
                                            : true,
                                        true,
                                      ))
                                        Icon(
                                          Icons.sync_rounded,
                                          color: valueOrDefault<Color>(
                                            valueOrDefault<String>(
                                                      widget!.status,
                                                      'syncing',
                                                    ) ==
                                                    'error'
                                                ? FlutterFlowTheme.of(context)
                                                    .error
                                                : FlutterFlowTheme.of(context)
                                                    .primary,
                                            FlutterFlowTheme.of(context)
                                                .primary,
                                          ),
                                          size: 14.0,
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  valueOrDefault<String>(
                                    valueOrDefault<String>(
                                              widget!.status,
                                              'syncing',
                                            ) ==
                                            'error'
                                        ? 'Erro'
                                        : 'A sincronizar',
                                    'A sincronizar',
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .override(
                                        font: GoogleFonts.montserrat(
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelSmall
                                                  .fontStyle,
                                        ),
                                        color: valueOrDefault<Color>(
                                          valueOrDefault<String>(
                                                    widget!.status,
                                                    'syncing',
                                                  ) ==
                                                  'error'
                                              ? FlutterFlowTheme.of(context)
                                                  .error
                                              : FlutterFlowTheme.of(context)
                                                  .primary,
                                          FlutterFlowTheme.of(context).primary,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelSmall
                                            .fontStyle,
                                        lineHeight: 1.2,
                                      ),
                                ),
                              ].divide(SizedBox(width: 4.0)),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        valueOrDefault<String>(
                          widget!.count,
                          '42 ficheiros',
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
                              color: FlutterFlowTheme.of(context).accent3,
                              letterSpacing: 0.0,
                              fontWeight: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .fontStyle,
                              lineHeight: 1.2,
                            ),
                      ),
                      Text(
                        valueOrDefault<String>(
                          widget!.time,
                          'A iniciar...',
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
                              color: FlutterFlowTheme.of(context).accent3,
                              letterSpacing: 0.0,
                              fontWeight: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .labelSmall
                                  .fontStyle,
                              lineHeight: 1.2,
                            ),
                      ),
                    ].divide(SizedBox(height: 4.0)),
                  ),
                ].divide(SizedBox(width: 16.0)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
