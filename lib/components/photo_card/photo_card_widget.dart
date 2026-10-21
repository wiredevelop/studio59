import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'photo_card_model.dart';
export 'photo_card_model.dart';

class PhotoCardWidget extends StatefulWidget {
  const PhotoCardWidget({
    super.key,
    String? desc,
    bool? selected,
  })  : this.desc = desc ??
            'https://dimg.dreamflow.cloud/v1/image/wedding%20couple%20walking%20in%20garden',
        this.selected = selected ?? false;

  final String desc;
  final bool selected;

  @override
  State<PhotoCardWidget> createState() => _PhotoCardWidgetState();
}

class _PhotoCardWidgetState extends State<PhotoCardWidget> {
  late PhotoCardModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PhotoCardModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8.0),
      child: Container(
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(8.0),
          shape: BoxShape.rectangle,
          border: Border.all(
            color: valueOrDefault<Color>(
              valueOrDefault<bool>(
                widget!.selected,
                false,
              )
                  ? FlutterFlowTheme.of(context).primary
                  : Colors.transparent,
              Colors.transparent,
            ),
            width: valueOrDefault<double>(
              valueOrDefault<bool>(
                widget!.selected,
                false,
              )
                  ? 2.0
                  : 2.0,
              2.0,
            ),
          ),
        ),
        child: Stack(
          alignment: AlignmentDirectional(-1.0, -1.0),
          children: [
            CachedNetworkImage(
              fadeInDuration: Duration(milliseconds: 0),
              fadeOutDuration: Duration(milliseconds: 0),
              imageUrl: valueOrDefault<String>(
                widget!.desc,
                'https://dimg.dreamflow.cloud/v1/image/wedding%20couple%20walking%20in%20garden',
              ),
              height: 160.0,
              fit: BoxFit.cover,
              alignment: Alignment(0.0, 0.0),
            ),
            Align(
              alignment: AlignmentDirectional(1.0, -1.0),
              child: Container(
                child: Padding(
                  padding: EdgeInsets.all(4.0),
                  child: Container(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4.0),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: 4.0,
                          sigmaY: 4.0,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context).fullContrast40,
                            borderRadius: BorderRadius.circular(4.0),
                            shape: BoxShape.rectangle,
                          ),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                4.0, 2.0, 4.0, 2.0),
                            child: Container(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.water_drop_rounded,
                                    color:
                                        FlutterFlowTheme.of(context).onPrimary,
                                    size: 10.0,
                                  ),
                                  Text(
                                    'S59',
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          font: GoogleFonts.montserrat(
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .onPrimary,
                                          fontSize: 10.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.bold,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                          lineHeight: 1.5,
                                        ),
                                  ),
                                ].divide(SizedBox(width: 4.0)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (valueOrDefault<bool>(
              widget!.selected,
              false,
            ))
              Align(
                alignment: AlignmentDirectional(1.0, 1.0),
                child: Container(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Container(
                      child: Container(
                        width: 28.0,
                        height: 28.0,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).primary,
                          borderRadius: BorderRadius.circular(9999.0),
                          shape: BoxShape.rectangle,
                        ),
                        alignment: AlignmentDirectional(0.0, 0.0),
                        child: Icon(
                          Icons.check_rounded,
                          color: FlutterFlowTheme.of(context).onPrimary,
                          size: 18.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
