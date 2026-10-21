import '/components/filter_chip/filter_chip_widget.dart';
import '/components/photo_card/photo_card_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'photo_catalogue_widget.dart' show PhotoCatalogueWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class PhotoCatalogueModel extends FlutterFlowModel<PhotoCatalogueWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for FilterChip.
  late FilterChipModel filterChipModel1;
  // Model for FilterChip.
  late FilterChipModel filterChipModel2;
  // Model for FilterChip.
  late FilterChipModel filterChipModel3;
  // Model for FilterChip.
  late FilterChipModel filterChipModel4;
  // Model for PhotoCard.
  late PhotoCardModel photoCardModel1;
  // Model for PhotoCard.
  late PhotoCardModel photoCardModel2;
  // Model for PhotoCard.
  late PhotoCardModel photoCardModel3;
  // Model for PhotoCard.
  late PhotoCardModel photoCardModel4;
  // Model for PhotoCard.
  late PhotoCardModel photoCardModel5;
  // Model for PhotoCard.
  late PhotoCardModel photoCardModel6;
  // Model for PhotoCard.
  late PhotoCardModel photoCardModel7;
  // Model for PhotoCard.
  late PhotoCardModel photoCardModel8;
  // Model for PhotoCard.
  late PhotoCardModel photoCardModel9;
  // Model for PhotoCard.
  late PhotoCardModel photoCardModel10;
  // Model for PhotoCard.
  late PhotoCardModel photoCardModel11;
  // Model for PhotoCard.
  late PhotoCardModel photoCardModel12;

  @override
  void initState(BuildContext context) {
    filterChipModel1 = createModel(context, () => FilterChipModel());
    filterChipModel2 = createModel(context, () => FilterChipModel());
    filterChipModel3 = createModel(context, () => FilterChipModel());
    filterChipModel4 = createModel(context, () => FilterChipModel());
    photoCardModel1 = createModel(context, () => PhotoCardModel());
    photoCardModel2 = createModel(context, () => PhotoCardModel());
    photoCardModel3 = createModel(context, () => PhotoCardModel());
    photoCardModel4 = createModel(context, () => PhotoCardModel());
    photoCardModel5 = createModel(context, () => PhotoCardModel());
    photoCardModel6 = createModel(context, () => PhotoCardModel());
    photoCardModel7 = createModel(context, () => PhotoCardModel());
    photoCardModel8 = createModel(context, () => PhotoCardModel());
    photoCardModel9 = createModel(context, () => PhotoCardModel());
    photoCardModel10 = createModel(context, () => PhotoCardModel());
    photoCardModel11 = createModel(context, () => PhotoCardModel());
    photoCardModel12 = createModel(context, () => PhotoCardModel());
  }

  @override
  void dispose() {
    filterChipModel1.dispose();
    filterChipModel2.dispose();
    filterChipModel3.dispose();
    filterChipModel4.dispose();
    photoCardModel1.dispose();
    photoCardModel2.dispose();
    photoCardModel3.dispose();
    photoCardModel4.dispose();
    photoCardModel5.dispose();
    photoCardModel6.dispose();
    photoCardModel7.dispose();
    photoCardModel8.dispose();
    photoCardModel9.dispose();
    photoCardModel10.dispose();
    photoCardModel11.dispose();
    photoCardModel12.dispose();
  }
}
