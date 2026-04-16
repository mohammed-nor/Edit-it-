import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:share_plus/share_plus.dart';
import '../services/audio_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioPlayer _player = AudioPlayer();
  final AudioService _audioService = AudioService();
  
  String? _selectedFilePath;
  String? _fileName;
  Duration _totalDuration = Duration.zero;
  
  double _startValue = 0.0;
  double _endValue = 1.0;
  double _speedValue = 1.0;
  
  bool _isProcessing = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
        });
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFilePath = result.files.single.path;
        _fileName = result.files.single.name;
        _startValue = 0.0;
        _endValue = 1.0;
      });

      await _player.setFilePath(_selectedFilePath!);
      _totalDuration = _player.duration ?? Duration.zero;
      setState(() {});
    }
  }

  Future<void> _processAndExport() async {
    if (_selectedFilePath == null) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final startSec = _startValue * _totalDuration.inMilliseconds / 1000;
      final endSec = _endValue * _totalDuration.inMilliseconds / 1000;
      
      final String extension = _fileName!.split('.').last;
      
      final String? outputPath = await _audioService.processAudio(
        inputPath: _selectedFilePath!,
        startSeconds: startSec,
        endSeconds: endSec,
        speed: _speedValue,
        format: extension,
      );

      if (outputPath != null) {
        await Share.shareXFiles([XFile(outputPath)], text: 'Check out my edited audio!');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to process audio')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EDIT IT'),
        centerTitle: true,
      ),
      body: Container(
        padding: const EdgeInsets.all(24.0),
        child: _selectedFilePath == null ? _buildImportState() : _buildEditState(),
      ),
    );
  }

  Widget _buildImportState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.audio_file_rounded,
              size: 80,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Start your project',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Import an audio file to begin editing',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: 48),
          ElevatedButton.icon(
            onPressed: _pickAudio,
            icon: const Icon(Icons.add_rounded),
            label: const Text('IMPORT AUDIO'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPlayerCard(),
        const SizedBox(height: 32),
        Text(
          'Trim Duration',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        RangeSlider(
          values: RangeValues(_startValue, _endValue),
          onChanged: (values) {
             setState(() {
               _startValue = values.start;
               _endValue = values.end;
             });
          },
          min: 0.0,
          max: 1.0,
          activeColor: Theme.of(context).colorScheme.primary,
          inactiveColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(_totalDuration * _startValue)),
            Text(_formatDuration(_totalDuration * _endValue)),
          ],
        ),
        const SizedBox(height: 32),
        Text(
          'Playback Speed: ${_speedValue.toStringAsFixed(2)}x',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Slider(
          value: _speedValue,
          onChanged: (val) {
            setState(() {
              _speedValue = val;
            });
          },
          min: 0.5,
          max: 2.0,
          divisions: 15, // 0.1 increments
          label: '${_speedValue.toStringAsFixed(1)}x',
        ),
        const Spacer(),
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildPlayerCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.music_note_rounded, color: Colors.white70),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fileName ?? 'Unknown File',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      _formatDuration(_totalDuration),
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedFilePath = null;
                    _player.stop();
                  });
                },
                icon: const Icon(Icons.close_rounded, color: Colors.white38),
              ),
            ],
          ),
          const SizedBox(height: 24),
          StreamBuilder<Duration>(
            stream: _player.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              return ProgressBar(
                progress: position,
                total: _totalDuration,
                onSeek: (duration) {
                  _player.seek(duration);
                },
                barHeight: 8,
                baseBarColor: Colors.white10,
                progressBarColor: Theme.of(context).colorScheme.primary,
                thumbColor: Theme.of(context).colorScheme.primary,
                timeLabelTextStyle: const TextStyle(color: Colors.white54),
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               IconButton(
                 iconSize: 48,
                 onPressed: () {
                   if (_isPlaying) {
                     _player.pause();
                   } else {
                     _player.play();
                   }
                 },
                 icon: Icon(
                   _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                   color: Theme.of(context).colorScheme.primary,
                 ),
               ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _processAndExport,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 18),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
          shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
        ),
        child: _isProcessing
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text(
                'PROCESS & EXPORT',
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }
}
