import '/components/button/button_widget.dart';
import '/components/progress_stat/progress_stat_widget.dart';
import '/components/sync_item/sync_item_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'data_sync_screen_widget.dart' show DataSyncScreenWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';

class DataSyncScreenModel extends FlutterFlowModel<DataSyncScreenWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for ProgressStat.
  late ProgressStatModel progressStatModel1;
  // Model for ProgressStat.
  late ProgressStatModel progressStatModel2;
  // Model for ProgressStat.
  late ProgressStatModel progressStatModel3;
  // Model for Button.
  late ButtonModel buttonModel1;
  // Model for SyncItem.
  late SyncItemModel syncItemModel1;
  // Model for SyncItem.
  late SyncItemModel syncItemModel2;
  // Model for SyncItem.
  late SyncItemModel syncItemModel3;
  // Model for Button.
  late ButtonModel buttonModel2;

  @override
  void initState(BuildContext context) {
    progressStatModel1 = createModel(context, () => ProgressStatModel());
    progressStatModel2 = createModel(context, () => ProgressStatModel());
    progressStatModel3 = createModel(context, () => ProgressStatModel());
    buttonModel1 = createModel(context, () => ButtonModel());
    syncItemModel1 = createModel(context, () => SyncItemModel());
    syncItemModel2 = createModel(context, () => SyncItemModel());
    syncItemModel3 = createModel(context, () => SyncItemModel());
    buttonModel2 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    progressStatModel1.dispose();
    progressStatModel2.dispose();
    progressStatModel3.dispose();
    buttonModel1.dispose();
    syncItemModel1.dispose();
    syncItemModel2.dispose();
    syncItemModel3.dispose();
    buttonModel2.dispose();
  }
}
