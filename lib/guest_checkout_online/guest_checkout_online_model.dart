import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'guest_checkout_online_widget.dart' show GuestCheckoutOnlineWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class GuestCheckoutOnlineModel
    extends FlutterFlowModel<GuestCheckoutOnlineWidget> {
  ///  Local state fields for this page.

  String? customerName = '';

  String? customerPhone = '';

  String? customerEmail = '';

  String? productType = 'paper';

  bool? wantsFilm = false;

  bool? submitting = false;

  bool? submitUncertain = false;

  String? deliveryType = 'pickup';

  String? deliveryAddress = '';

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
