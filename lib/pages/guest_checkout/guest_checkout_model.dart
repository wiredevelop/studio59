import '/components/button/button_widget.dart';
import '/components/cart_item/cart_item_widget.dart';
import '/components/delivery_option/delivery_option_widget.dart';
import '/components/section_header/section_header_widget.dart';
import '/components/switch_component/switch_component_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'guest_checkout_widget.dart' show GuestCheckoutWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class GuestCheckoutModel extends FlutterFlowModel<GuestCheckoutWidget> {
  ///  State fields for stateful widgets in this page.

  // Model for SectionHeader.
  late SectionHeaderModel sectionHeaderModel1;
  // Model for CartItem.
  late CartItemModel cartItemModel1;
  // Model for CartItem.
  late CartItemModel cartItemModel2;
  // Model for CartItem.
  late CartItemModel cartItemModel3;
  // Model for SectionHeader.
  late SectionHeaderModel sectionHeaderModel2;
  // Model for DeliveryOption.
  late DeliveryOptionModel deliveryOptionModel1;
  // Model for DeliveryOption.
  late DeliveryOptionModel deliveryOptionModel2;
  // Model for DeliveryOption.
  late DeliveryOptionModel deliveryOptionModel3;
  // Model for SectionHeader.
  late SectionHeaderModel sectionHeaderModel3;
  // Model for TextField.
  late TextFieldModel textFieldModel1;
  // Model for TextField.
  late TextFieldModel textFieldModel2;
  // Model for TextField.
  late TextFieldModel textFieldModel3;
  // Model for Button.
  late ButtonModel buttonModel1;
  // Model for Switch.
  late SwitchComponentModel switchModel;
  // Model for Button.
  late ButtonModel buttonModel2;

  @override
  void initState(BuildContext context) {
    sectionHeaderModel1 = createModel(context, () => SectionHeaderModel());
    cartItemModel1 = createModel(context, () => CartItemModel());
    cartItemModel2 = createModel(context, () => CartItemModel());
    cartItemModel3 = createModel(context, () => CartItemModel());
    sectionHeaderModel2 = createModel(context, () => SectionHeaderModel());
    deliveryOptionModel1 = createModel(context, () => DeliveryOptionModel());
    deliveryOptionModel2 = createModel(context, () => DeliveryOptionModel());
    deliveryOptionModel3 = createModel(context, () => DeliveryOptionModel());
    sectionHeaderModel3 = createModel(context, () => SectionHeaderModel());
    textFieldModel1 = createModel(context, () => TextFieldModel());
    textFieldModel2 = createModel(context, () => TextFieldModel());
    textFieldModel3 = createModel(context, () => TextFieldModel());
    buttonModel1 = createModel(context, () => ButtonModel());
    switchModel = createModel(context, () => SwitchComponentModel());
    buttonModel2 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    sectionHeaderModel1.dispose();
    cartItemModel1.dispose();
    cartItemModel2.dispose();
    cartItemModel3.dispose();
    sectionHeaderModel2.dispose();
    deliveryOptionModel1.dispose();
    deliveryOptionModel2.dispose();
    deliveryOptionModel3.dispose();
    sectionHeaderModel3.dispose();
    textFieldModel1.dispose();
    textFieldModel2.dispose();
    textFieldModel3.dispose();
    buttonModel1.dispose();
    switchModel.dispose();
    buttonModel2.dispose();
  }
}
