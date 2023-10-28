library cached_network_avif_image;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class CachedNetworkAvifImage extends AvifImage {
  CachedNetworkAvifImage(
    String url, {
    super.key,
    double scale = 1.0,
    super.width,
    super.height,
    super.color,
    super.opacity,
    super.colorBlendMode,
    super.fit,
    super.alignment = Alignment.center,
    super.repeat = ImageRepeat.noRepeat,
    super.centerSlice,
    super.matchTextDirection = false,
    super.isAntiAlias = false,
    super.filterQuality = FilterQuality.low,
    super.cacheWidth,
    super.cacheHeight,
    int? overrideDurationMs = -1,
    super.errorBuilder,
    super.semanticLabel,
    super.excludeFromSemantics = false,
    super.gaplessPlayback = false,
    super.frameBuilder,
    super.loadingBuilder,
    Map<String, String>? headers,
  }) : super(
          image: CachedNetworkAvifImageProvider(
            url,
            scale: scale,
            overrideDurationMs: overrideDurationMs,
            headers: headers,
          ),
        );
}

class CachedNetworkAvifImageProvider extends NetworkAvifImage {
  CachedNetworkAvifImageProvider(
    super.url, {
    super.scale = 1.0,
    super.overrideDurationMs = -1,
    super.headers,
  });

  @override
  ImageStreamCompleter loadImage(
      NetworkAvifImage key, ImageDecoderCallback decode) {
    final StreamController<ImageChunkEvent> chunkEvents =
        StreamController<ImageChunkEvent>();

    return AvifImageStreamCompleter(
      key: key,
      codec: _loadAsync(
        key,
        decode,
        chunkEvents,
      ),
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        ErrorDescription('Url: $url'),
      ],
      chunkEvents: chunkEvents.stream,
    );
  }

  Future<AvifCodec> _loadAsync(
    NetworkAvifImage key,
    ImageDecoderCallback decode,
    StreamController<ImageChunkEvent> chunkEvents,
  ) async {
    assert(key == this);

    final stream = DefaultCacheManager().getImageFile(
      url,
      headers: headers,
      withProgress: true,
    );

    await for (final event in stream) {
      if (event is DownloadProgress) {
        chunkEvents.add(
          ImageChunkEvent(
            cumulativeBytesLoaded: event.downloaded,
            expectedTotalBytes: event.totalSize,
          ),
        );
      }
      if (event is FileInfo) {
        final file = event.file;
        final bytes = await file.readAsBytes();

        if (bytes.lengthInBytes == 0) {
          PaintingBinding.instance.imageCache.evict(key);
          throw StateError('$url is empty and cannot be loaded as an image.');
        }

        final fType = _isAvifFile(bytes.sublist(0, 16));
        if (fType == _FileType.unknown) {
          throw StateError('$url is not an avif file.');
        }

        final codec = fType == _FileType.avif
            ? SingleFrameAvifCodec(bytes: bytes)
            : MultiFrameAvifCodec(
                key: hashCode,
                avifBytes: bytes,
                overrideDurationMs: overrideDurationMs,
              );
        await codec.ready();

        return codec;
      }
    }

    throw StateError('Could not load $url.');
  }
}

enum _FileType { avif, avis, unknown }

_FileType _isAvifFile(Uint8List bytes) {
  if (_isSubset(bytes, [102, 116, 121, 112, 97, 118, 105, 102])) {
    return _FileType.avif;
  }

  if (_isSubset(bytes, [102, 116, 121, 112, 97, 118, 105, 115])) {
    return _FileType.avis;
  }

  return _FileType.unknown;
}

bool _isSubset(List arr1, List arr2) {
  int i = 0, j = 0;
  for (i = 0; i < arr1.length - arr2.length + 1; i++) {
    for (j = 0; j < arr2.length; j++) {
      if (arr1[i + j] != arr2[j]) break;
    }

    if (j == arr2.length) return true;
  }

  return false;
}
