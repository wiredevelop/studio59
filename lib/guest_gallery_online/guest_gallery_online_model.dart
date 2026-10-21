import '/backend/schema/structs/index.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import 'guest_gallery_online_widget.dart' show GuestGalleryOnlineWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class GuestGalleryOnlineModel
    extends FlutterFlowModel<GuestGalleryOnlineWidget> {
  ///  Local state fields for this page.

  List<Studio59GalleryPhotoStruct> photos = [];
  void addToPhotos(Studio59GalleryPhotoStruct item) => photos.add(item);
  void removeFromPhotos(Studio59GalleryPhotoStruct item) => photos.remove(item);
  void removeAtIndexFromPhotos(int index) => photos.removeAt(index);
  void insertAtIndexInPhotos(int index, Studio59GalleryPhotoStruct item) =>
      photos.insert(index, item);
  void updatePhotosAtIndex(
          int index, Function(Studio59GalleryPhotoStruct) updateFn) =>
      photos[index] = updateFn(photos[index]);

  int? page = 1;

  int? lastPage = 1;

  bool? loading = true;

  String? errorMessage = '';

  Studio59GalleryPhotoStruct? selectedPhoto;
  void updateSelectedPhotoStruct(
      Function(Studio59GalleryPhotoStruct) updateFn) {
    updateFn(selectedPhoto ??= Studio59GalleryPhotoStruct());
  }

  bool? isPhotoModalOpen = false;

  bool? showEmpty = false;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - fetchStudio59GuestGalleryWithNullableToken] action in GuestGalleryOnline widget.
  Studio59GalleryFetchResultStruct? guestGalleryInitialLoad;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}
