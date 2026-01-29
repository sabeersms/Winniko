import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/app_constants.dart';
import 'loading_spinner.dart';

class TeamLogo extends StatelessWidget {
  final String? url;
  final String teamName;
  final double size;
  final Color? fallbackColor;
  final Color? backgroundColor;

  const TeamLogo({
    super.key,
    required this.url,
    required this.teamName,
    this.size = 40,
    this.fallbackColor,
    this.backgroundColor,
  });

  String _convertWikimediaUrl(String url) {
    if (!url.contains('upload.wikimedia.org') || !url.endsWith('.svg')) {
      return url;
    }
    try {
      String newUrl = url;
      if (newUrl.contains('/wikipedia/commons/')) {
        newUrl = newUrl.replaceFirst(
          '/wikipedia/commons/',
          '/wikipedia/commons/thumb/',
        );
      } else if (newUrl.contains('/wikipedia/en/')) {
        newUrl = newUrl.replaceFirst('/wikipedia/en/', '/wikipedia/en/thumb/');
      } else {
        return url;
      }
      final uri = Uri.parse(url);
      final filename = uri.pathSegments.last;
      return '$newUrl/200px-$filename.png';
    } catch (e) {
      return url;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUrl = (url != null && url!.isNotEmpty)
        ? _convertWikimediaUrl(url!)
        : null;
    final isSvg =
        effectiveUrl != null && effectiveUrl.toLowerCase().endsWith('.svg');

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(4),
          child: _buildContent(effectiveUrl, isSvg),
        ),
      ),
    );
  }

  Widget _buildContent(String? imageUrl, bool isSvg) {
    if (imageUrl == null) {
      return _buildFallback();
    }

    if (isSvg) {
      return SvgPicture.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.contain,
        headers: const {'User-Agent': 'WinnikoApp/1.0'},
        placeholderBuilder: (_) => _buildPlaceholder(),
      );
    } // Removed redundant caching for non-svgs here since SvgPicture.network handles SVGs and CachedNetworkImage handles others.

    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      fit: BoxFit.contain,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildFallback(),
      memCacheWidth: (size * 3).toInt(), // Tiny memory optimization
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: SizedBox(
        width: size / 2,
        height: size / 2,
        child: LoadingSpinner(size: size / 2, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fallbackColor ?? AppColors.primaryGreen,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        teamName.isNotEmpty ? teamName[0].toUpperCase() : '?',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.4,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
