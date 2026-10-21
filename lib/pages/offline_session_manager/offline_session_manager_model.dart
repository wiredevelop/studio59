import '/components/activity_log/activity_log_widget.dart';
import '/components/button/button_widget.dart';
import '/components/device_status/device_status_widget.dart';
import '/components/section_header2/section_header2_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'offline_session_manager_widget.dart' show OfflineSessionManagerWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class OfflineSessionManagerModel
    extends FlutterFlowModel<OfflineSessionManagerWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for SectionHeader.
  late SectionHeader2Model sectionHeaderModel1;
  // Model for TextField.
  late TextFieldModel textFieldModel1;
  // Model for TextField.
  late TextFieldModel textFieldModel2;
  // Model for Button.
  late ButtonModel buttonModel1;
  // Model for SectionHeader.
  late SectionHeader2Model sectionHeaderModel2;
  // Model for SectionHeader.
  late SectionHeader2Model sectionHeaderModel3;
  // Model for DeviceStatus.
  late DeviceStatusModel deviceStatusModel1;
  // Model for DeviceStatus.
  late DeviceStatusModel deviceStatusModel2;
  // Model for DeviceStatus.
  late DeviceStatusModel deviceStatusModel3;
  // Model for SectionHeader.
  late SectionHeader2Model sectionHeaderModel4;
  // Model for ActivityLog.
  late ActivityLogModel activityLogModel1;
  // Model for ActivityLog.
  late ActivityLogModel activityLogModel2;
  // Model for ActivityLog.
  late ActivityLogModel activityLogModel3;
  // Model for Button.
  late ButtonModel buttonModel2;
  // Model for Button.
  late ButtonModel buttonModel3;

  @override
  void initState(BuildContext context) {
    sectionHeaderModel1 = createModel(context, () => SectionHeader2Model());
    textFieldModel1 = createModel(context, () => TextFieldModel());
    textFieldModel2 = createModel(context, () => TextFieldModel());
    buttonModel1 = createModel(context, () => ButtonModel());
    sectionHeaderModel2 = createModel(context, () => SectionHeader2Model());
    sectionHeaderModel3 = createModel(context, () => SectionHeader2Model());
    deviceStatusModel1 = createModel(context, () => DeviceStatusModel());
    deviceStatusModel2 = createModel(context, () => DeviceStatusModel());
    deviceStatusModel3 = createModel(context, () => DeviceStatusModel());
    sectionHeaderModel4 = createModel(context, () => SectionHeader2Model());
    activityLogModel1 = createModel(context, () => ActivityLogModel());
    activityLogModel2 = createModel(context, () => ActivityLogModel());
    activityLogModel3 = createModel(context, () => ActivityLogModel());
    buttonModel2 = createModel(context, () => ButtonModel());
    buttonModel3 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    sectionHeaderModel1.dispose();
    textFieldModel1.dispose();
    textFieldModel2.dispose();
    buttonModel1.dispose();
    sectionHeaderModel2.dispose();
    sectionHeaderModel3.dispose();
    deviceStatusModel1.dispose();
    deviceStatusModel2.dispose();
    deviceStatusModel3.dispose();
    sectionHeaderModel4.dispose();
    activityLogModel1.dispose();
    activityLogModel2.dispose();
    activityLogModel3.dispose();
    buttonModel2.dispose();
    buttonModel3.dispose();
  }
}
