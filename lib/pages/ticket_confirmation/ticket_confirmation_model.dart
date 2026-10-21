import '/components/button/button_widget.dart';
import '/components/info_row/info_row_widget.dart';
import '/components/success_header/success_header_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'ticket_confirmation_widget.dart' show TicketConfirmationWidget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class TicketConfirmationModel
    extends FlutterFlowModel<TicketConfirmationWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for SuccessHeader.
  late SuccessHeaderModel successHeaderModel;
  // Model for InfoRow.
  late InfoRowModel infoRowModel1;
  // Model for InfoRow.
  late InfoRowModel infoRowModel2;
  // Model for InfoRow.
  late InfoRowModel infoRowModel3;
  // Model for InfoRow.
  late InfoRowModel infoRowModel4;
  // Model for Button.
  late ButtonModel buttonModel1;
  // Model for Button.
  late ButtonModel buttonModel2;

  @override
  void initState(BuildContext context) {
    successHeaderModel = createModel(context, () => SuccessHeaderModel());
    infoRowModel1 = createModel(context, () => InfoRowModel());
    infoRowModel2 = createModel(context, () => InfoRowModel());
    infoRowModel3 = createModel(context, () => InfoRowModel());
    infoRowModel4 = createModel(context, () => InfoRowModel());
    buttonModel1 = createModel(context, () => ButtonModel());
    buttonModel2 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    successHeaderModel.dispose();
    infoRowModel1.dispose();
    infoRowModel2.dispose();
    infoRowModel3.dispose();
    infoRowModel4.dispose();
    buttonModel1.dispose();
    buttonModel2.dispose();
  }
}
