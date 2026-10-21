import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'guest_gallery_online_model.dart';
export 'guest_gallery_online_model.dart';

/// Catálogo público paginado usando previews reais do evento.
class GuestGalleryOnlineWidget extends StatefulWidget {
  const GuestGalleryOnlineWidget({super.key});

  static String routeName = 'GuestGalleryOnline';
  static String routePath = '/guest-gallery-online';

  @override
  State<GuestGalleryOnlineWidget> createState() =>
      _GuestGalleryOnlineWidgetState();
}

class _GuestGalleryOnlineWidgetState extends State<GuestGalleryOnlineWidget> {
  late GuestGalleryOnlineModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GuestGalleryOnlineModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.guestGalleryInitialLoad =
          await actions.fetchStudio59GuestGalleryWithNullableToken(
        functions.studio59IntAsJson(FFAppState().guestEvent.id),
        functions.studio59StringAsJson(FFAppState().guestSessionToken),
        1,
      );
      if (_model.guestGalleryInitialLoad?.success == true) {
        _model.photos = _model.guestGalleryInitialLoad!.data
            .toList()
            .cast<Studio59GalleryPhotoStruct>();
        safeSetState(() {});
        _model.page = _model.guestGalleryInitialLoad?.currentPage;
        safeSetState(() {});
        _model.lastPage = _model.guestGalleryInitialLoad?.lastPage;
        safeSetState(() {});
        _model.showEmpty = _model.guestGalleryInitialLoad?.total == 0;
        safeSetState(() {});
        _model.errorMessage = '';
        safeSetState(() {});
      } else {
        _model.errorMessage = _model.guestGalleryInitialLoad?.message;
        safeSetState(() {});
      }

      _model.loading = false;
      safeSetState(() {});
    });
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

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
            'Galeria',
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
          child: Container(
            child: custom_widgets.Studio59GuestGallery(),
          ),
        ),
      ),
    );
  }
}
