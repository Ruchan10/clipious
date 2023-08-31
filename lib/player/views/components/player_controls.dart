import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:invidious/main.dart';
import 'package:invidious/player/models/mediaEvent.dart';
import 'package:invidious/player/states/interfaces/media_player.dart';
import 'package:invidious/player/states/player.dart';

import '../../../utils.dart';
import '../../states/audio_player.dart';
import '../../states/player_controls.dart';
import '../../states/video_player.dart';

class PlayerControls extends StatelessWidget {
  final MediaPlayerCubit? mediaPlayerCubit;

  const PlayerControls({super.key, this.mediaPlayerCubit});

  showPlaybackSpeedSelection(BuildContext context, MediaPlayerCubit player) {
    Navigator.of(context).pop();
    showModalBottomSheet(
      isScrollControlled: true,
      showDragHandle: true,
      context: context,
      builder: (context) {
        const double minValue = 0.1, maxValue = 6;
        return StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                min: minValue,
                max: maxValue,
                divisions: maxValue ~/ minValue - 1,
                value: player.getSpeed(),
                label: '${player.getSpeed().toStringAsFixed(2)}x',
                onChanged: (value) => setState(() => player.setSpeed(value)),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(onPressed: () => setState(() => player.setSpeed(max(minValue, player.getSpeed() - minValue))), icon: const Icon(Icons.remove)),
                  SizedBox(
                      width: 50,
                      child: Text(
                        '${player.getSpeed().toStringAsFixed(2)}x',
                        textAlign: TextAlign.center,
                      )),
                  IconButton(onPressed: () => setState(() => player.setSpeed(min(maxValue, player.getSpeed() + minValue))), icon: const Icon(Icons.add)),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  showPlayerTrackSelection(BuildContext context, PlayerControlsState _, {required List<String> tracks, required int selected, required Function(int index) onSelected}) {
    List<ListTile> widgets = [];

    for (int i = 0; i < tracks.length; i++) {
      widgets.add(ListTile(
          onTap: () {
            Navigator.of(context).pop();
            onSelected(i);
          },
          leading: selected == i ? const Icon(Icons.check) : const SizedBox.shrink(),
          title: Text(tracks[i])));
    }

    showModalBottomSheet(
      showDragHandle: true,
      isScrollControlled: true,
      context: context,
      builder: (context) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widgets,
          ),
        );
      },
    );
  }

  showOptionMenu(BuildContext context, PlayerControlsState controls) {
    late MediaPlayerCubit pc;
    var player = context.read<PlayerCubit>();
    if (mediaPlayerCubit != null) {
      pc = mediaPlayerCubit!;
    } else if (player.state.isAudio) {
      pc = context.read<AudioPlayerCubit>();
    } else {
      pc = context.read<VideoPlayerCubit>();
    }
    var locals = AppLocalizations.of(context)!;
    var videoTracks = pc.getVideoTracks();
    var audioTracks = pc.getAudioTracks();
    var subtitles = pc.getSubtitles();

    showModalBottomSheet(
      isScrollControlled: true,
      showDragHandle: true,
      context: context,
      builder: (ctx) {
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                onTap: () => showPlaybackSpeedSelection(context, pc),
                leading: const Icon(Icons.speed),
                title: Text(locals.playbackSpeed),
              ),
              if (subtitles.isNotEmpty)
                ListTile(
                  onTap: () {
                    Navigator.of(context).pop();
                    showPlayerTrackSelection(
                      context,
                      controls,
                      tracks: subtitles,
                      selected: pc.selectedSubtitle(),
                      onSelected: pc.selectSubtitle,
                    );
                  },
                  leading: const Icon(Icons.subtitles),
                  title: Text(locals.subtitles),
                ),
              if (videoTracks.isNotEmpty)
                ListTile(
                  onTap: () {
                    Navigator.of(context).pop();
                    showPlayerTrackSelection(
                      context,
                      controls,
                      tracks: videoTracks,
                      selected: pc.selectedVideoTrack(),
                      onSelected: pc.selectVideoTrack,
                    );
                  },
                  leading: const Icon(Icons.hd),
                  title: Text(locals.quality),
                ),
              if (audioTracks.isNotEmpty)
                ListTile(
                  onTap: () {
                    Navigator.of(context).pop();
                    showPlayerTrackSelection(
                      context,
                      controls,
                      tracks: audioTracks,
                      selected: pc.selectedAudioTrack(),
                      onSelected: pc.selectAudioTrack,
                    );
                  },
                  leading: const Icon(Icons.music_note),
                  title: Text(locals.audio),
                ),
              if (pc.hasDashToggle() && !(player.state.currentlyPlaying?.liveNow ?? false))
                ListTile(
                  onTap: () {
                    Navigator.of(context).pop();
                    pc.toggleDash();
                  },
                  leading: Icon(
                    Icons.stream,
                    color: pc.isUsingDash() ? Colors.green : null,
                  ),
                  title: Text(locals.useDash),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    var player = context.read<PlayerCubit>();
    return Theme(
      data: ThemeData(useMaterial3: true, colorScheme: darkColorScheme, progressIndicatorTheme: ProgressIndicatorThemeData(circularTrackColor: darkColorScheme.secondaryContainer.withOpacity(0.8))),
      child: BlocProvider(
        create: (context) => PlayerControlsCubit(PlayerControlsState(), player),
        child: BlocBuilder<PlayerControlsCubit, PlayerControlsState>(
          builder: (context, _) {
            bool isMini = context.select((PlayerCubit cubit) => cubit.state.isMini);
            bool hasQueue = context.select((PlayerCubit cubit) => cubit.state.hasQueue);
            bool isPip = context.select((PlayerCubit cubit) => cubit.state.isPip);
            String videoTitle = context.select((PlayerCubit cubit) => cubit.state.currentlyPlaying?.title ?? cubit.state.offlineCurrentlyPlaying?.title ?? '');

/*
            late MediaPlayerCubit pc;
            if (mediaPlayerCubit != null) {
              pc = mediaPlayerCubit!;
            } else if (player.state.isAudio) {
              pc = context.read<AudioPlayerCubit>();
            } else {
              pc = context.read<VideoPlayerCubit>();
            }
*/
            // PlayerState mpc = player.state;
            var event = _.event;
            var cubit = context.read<PlayerControlsCubit>();
            return BlocListener<PlayerCubit, PlayerState>(
              listenWhen: (previous, current) => previous.mediaEvent != current.mediaEvent,
              listener: (BuildContext context, state) {
                cubit.onStreamEvent(state.mediaEvent);
              },
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _.displayControls ? cubit.hideControls : cubit.showControls,
                onVerticalDragEnd: _.fullScreenState == FullScreenState.fullScreen ? null : player.videoDraggedEnd,
                onVerticalDragUpdate: _.fullScreenState == FullScreenState.fullScreen ? null : player.videoDragged,
                onVerticalDragStart: _.fullScreenState == FullScreenState.fullScreen ? null : player.videoDragStarted,
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      if (_.errored)
                        Container(
                          color: Colors.black.withOpacity(0.8),
                          child: const Center(
                            child: Icon(Icons.error),
                          ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        top: 0,
                        child: isMini || isPip
                            ? const SizedBox.shrink()
                            : _.displayControls
                                ? Container(
                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(0), color: Colors.black.withOpacity(0.4)),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (_.fullScreenState == FullScreenState.fullScreen)
                                              Expanded(
                                                  child: Padding(
                                                padding: const EdgeInsets.only(left: 8.0),
                                                child: Text(
                                                  videoTitle,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              )),
                                            if (_.supportsPip) IconButton(onPressed: () => player.enterPip(), icon: const Icon(Icons.picture_in_picture)),
                                            IconButton(onPressed: () => showOptionMenu(context, _), icon: const Icon(Icons.more_vert))
                                          ],
                                        ),
                                        Expanded(child: Container()),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            _.muted
                                                ? IconButton(onPressed: () => player.setMuted(false), icon: const Icon(Icons.volume_off))
                                                : IconButton(onPressed: () => player.setMuted(true), icon: const Icon(Icons.volume_up)),
                                            switch (_.fullScreenState) {
                                              FullScreenState.fullScreen => IconButton(onPressed: () => player.setFullScreen(FullScreenState.notFullScreen), icon: const Icon(Icons.fullscreen_exit)),
                                              FullScreenState.notFullScreen => IconButton(onPressed: () => player.setFullScreen(FullScreenState.fullScreen), icon: const Icon(Icons.fullscreen)),
                                              _ => const SizedBox.shrink()
                                            }
                                          ],
                                        ),
                                        if (!(player.state.currentlyPlaying?.liveNow ?? false))
                                          Padding(
                                            padding: const EdgeInsets.only(top: 0.0, right: 8),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: SizedBox(
                                                    height: 25,
                                                    child: Slider(
                                                      min: 0,
                                                      value: min(_.position.inMilliseconds.toDouble(), _.duration.inMilliseconds.toDouble()),
                                                      max: _.duration.inMilliseconds.toDouble(),
                                                      secondaryTrackValue: min(_.buffer.inMilliseconds.toDouble() , _.duration.inMilliseconds.toDouble()),
                                                      onChangeEnd: cubit.onScrubbed,
                                                      onChanged: cubit.onScrubDrag,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '${prettyDuration(_.position)} / ${prettyDuration(_.duration)}',
                                                  style: textTheme.bodySmall?.copyWith(color: Colors.white),
                                                ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.expand(),
                      ),
                      if (!isMini && !isPip && _.displayControls)
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (hasQueue)
                                IconButton(
                                    onPressed: () {
                                      player.playPrevious();
                                      cubit.removeError();
                                    },
                                    icon: const Icon(
                                      Icons.skip_previous,
                                      size: 20,
                                    )),
                              IconButton(
                                  onPressed: () => player.rewind(),
                                  icon: const Icon(
                                    Icons.fast_rewind,
                                    size: 30,
                                  )),
                              IconButton(
                                onPressed: () => player.state.isPlaying ? player.pause() : player.play(),
                                icon: Icon(player.state.isPlaying ? Icons.pause : Icons.play_arrow, size: 55),
                              ),
                              IconButton(
                                  onPressed: () => player.fastForward(),
                                  icon: const Icon(
                                    Icons.fast_forward,
                                    size: 30,
                                  )),
                              if (hasQueue)
                                IconButton(
                                    onPressed: () {
                                      player.playNext();
                                      cubit.removeError();
                                    },
                                    icon: const Icon(
                                      Icons.skip_next,
                                      size: 20,
                                    )),
                            ],
                          ),
                        ),
                      if (event.state == MediaState.buffering)
                        const Center(
                          child: FractionallySizedBox(
                            heightFactor: 0.3,
                            child: AspectRatio(
                                aspectRatio: 1,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                )),
                          ),
                        )
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
