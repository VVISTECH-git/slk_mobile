import 'dart:convert';

import 'package:flutter/material.dart';

/// Opens a full-screen, swipeable, pinch-to-zoom viewer for a set of base64
/// photos, starting at [initialIndex]. [heroPrefix] must match the Hero tags
/// used on the thumbnails (tag = `heroPrefix` + index) for the fly animation.
void openPhotoViewer(
  BuildContext context, {
  required List<String> images,
  required int initialIndex,
  String title = '',
  String heroPrefix = '',
}) {
  Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => PhotoViewer(
      images: images,
      initialIndex: initialIndex,
      title: title,
      heroPrefix: heroPrefix,
    ),
  ));
}

class PhotoViewer extends StatefulWidget {
  const PhotoViewer({
    super.key,
    required this.images,
    required this.initialIndex,
    this.title = '',
    this.heroPrefix = '',
  });
  final List<String> images;
  final int initialIndex;
  final String title;
  final String heroPrefix;

  @override
  State<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<PhotoViewer> {
  late final PageController _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.images.length;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.title.isEmpty ? 'Photo ${_index + 1} of $count' : '${widget.title} · ${_index + 1}/$count',
        ),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: count,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) {
          final image = Image.memory(base64Decode(widget.images[i]), fit: BoxFit.contain);
          return InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Center(
              child: widget.heroPrefix.isEmpty
                  ? image
                  : Hero(tag: '${widget.heroPrefix}$i', child: image),
            ),
          );
        },
      ),
    );
  }
}
