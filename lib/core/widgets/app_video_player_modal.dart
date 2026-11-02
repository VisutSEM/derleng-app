import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../utils/media_launcher.dart';
import '../utils/ui.dart';

/// Immersive, modern in-app video player modal.
///
/// Supports both network URLs (e.g. cloud storage .mp4) and local file paths
/// (e.g. videos picked from gallery or device storage) with playback controls,
/// scrubbing, volume toggle, and external browser fallback.
class AppVideoPlayerModal extends StatefulWidget {
  const AppVideoPlayerModal({
    super.key,
    required this.videoUrl,
    this.title,
    this.authorName,
  });

  final String videoUrl;
  final String? title;
  final String? authorName;

  /// Convenience launcher that displays the modal with smooth transition.
  static Future<void> show(
    BuildContext context, {
    required String videoUrl,
    String? title,
    String? authorName,
  }) {
    if (videoUrl.trim().isEmpty) {
      showAppSnackBar(context, 'No video available for this post.', isError: true);
      return Future.value();
    }

    return showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close video',
      barrierColor: Colors.black.withValues(alpha: 0.94),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, anim1, anim2) {
        return AppVideoPlayerModal(
          videoUrl: videoUrl,
          title: title,
          authorName: authorName,
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<AppVideoPlayerModal> createState() => _AppVideoPlayerModalState();
}

class _AppVideoPlayerModalState extends State<AppVideoPlayerModal> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _showControls = true;
  bool _isMuted = false;
  Timer? _hideControlsTimer;

  bool get _isNetwork =>
      widget.videoUrl.startsWith('http://') ||
      widget.videoUrl.startsWith('https://');

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final rawUrl = widget.videoUrl.trim();
    if (rawUrl.isEmpty) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Video URL is empty.';
      });
      return;
    }

    try {
      if (_isNetwork || kIsWeb) {
        final uri = Uri.parse(rawUrl);
        _controller = VideoPlayerController.networkUrl(uri);
      } else {
        final file = File(rawUrl);
        if (!file.existsSync()) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Local video file does not exist on device.';
          });
          return;
        }
        _controller = VideoPlayerController.file(file);
      }

      await _controller!.initialize();
      _controller!.addListener(_onControllerUpdate);
      _controller!.setLooping(true);
      await _controller!.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _scheduleHideControls();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Could not load video: $e';
        });
      }
    }
  }

  void _onControllerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    if (_controller != null && _controller!.value.isPlaying) {
      _hideControlsTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && _controller!.value.isPlaying) {
          setState(() => _showControls = false);
        }
      });
    }
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
      setState(() => _showControls = true);
      _hideControlsTimer?.cancel();
    } else {
      _controller!.play();
      setState(() => _showControls = true);
      _scheduleHideControls();
    }
  }

  void _toggleMute() {
    if (_controller == null) return;
    setState(() {
      _isMuted = !_isMuted;
      _controller!.setVolume(_isMuted ? 0.0 : 1.0);
    });
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video Center Content or Loading/Error State
            Center(
              child: _buildVideoContent(theme),
            ),

            // Top Bar with Dismiss and Info
            Positioned(
              top: 10,
              left: 16,
              right: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showControls ? 1.0 : 0.0,
                child: Row(
                  children: [
                    _CircleIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.title != null)
                            Text(
                              widget.title!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          if (widget.authorName != null)
                            Text(
                              'Story by ${widget.authorName!}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black87,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (_isNetwork)
                      _CircleIconButton(
                        icon: Icons.open_in_new_rounded,
                        tooltip: 'Open in browser',
                        onPressed: () {
                          launchMediaUrlSafely(context, widget.videoUrl);
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Bottom Controls Bar
            if (_isInitialized && _controller != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _showControls ? 1.0 : 0.0,
                  child: _buildBottomControls(theme),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoContent(ThemeData theme) {
    if (_hasError) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.75),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFF43F5E),
              size: 48,
            ),
            const SizedBox(height: 14),
            const Text(
              'Could not play video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_isNetwork)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      launchMediaUrlSafely(context, widget.videoUrl);
                    },
                    icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                    label: const Text('Open in Browser'),
                  ),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            color: theme.colorScheme.primary,
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading video...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    final isPlaying = _controller!.value.isPlaying;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() {
          _showControls = !_showControls;
        });
        if (_showControls && isPlaying) {
          _scheduleHideControls();
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: AspectRatio(
              aspectRatio: _controller!.value.aspectRatio > 0
                  ? _controller!.value.aspectRatio
                  : (16 / 9),
              child: VideoPlayer(_controller!),
            ),
          ),

          // Central Play/Pause indicator overlay
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: (!_showControls && isPlaying) ? 0.0 : 0.95,
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  size: 44,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls(ThemeData theme) {
    final position = _controller!.value.position;
    final duration = _controller!.value.duration;
    final posMs = position.inMilliseconds.toDouble();
    final durMs = duration.inMilliseconds.toDouble();
    final currentSliderVal = durMs > 0 ? posMs.clamp(0.0, durMs) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scrub Slider
          Row(
            children: [
              Text(
                _formatDuration(position),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: theme.colorScheme.primary,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    trackHeight: 3,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 12),
                  ),
                  child: Slider(
                    value: currentSliderVal,
                    min: 0.0,
                    max: durMs > 0 ? durMs : 1.0,
                    onChanged: (val) {
                      _controller!.seekTo(Duration(milliseconds: val.toInt()));
                      _scheduleHideControls();
                    },
                  ),
                ),
              ),
              Text(
                _formatDuration(duration),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 11,
                ),
              ),
            ],
          ),

          // Play / Pause / Replay / Mute Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    iconSize: 26,
                    color: Colors.white,
                    onPressed: _togglePlayPause,
                    icon: Icon(
                      _controller!.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                  IconButton(
                    iconSize: 20,
                    color: Colors.white70,
                    tooltip: 'Rewind 5s',
                    onPressed: () {
                      final target = position - const Duration(seconds: 5);
                      _controller!.seekTo(
                        target < Duration.zero ? Duration.zero : target,
                      );
                      _scheduleHideControls();
                    },
                    icon: const Icon(Icons.replay_5_rounded),
                  ),
                ],
              ),
              IconButton(
                iconSize: 22,
                color: Colors.white,
                tooltip: _isMuted ? 'Unmute' : 'Mute',
                onPressed: _toggleMute,
                icon: Icon(
                  _isMuted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      shape: const CircleBorder(),
      child: IconButton(
        iconSize: 22,
        color: Colors.white,
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
    );
  }
}
