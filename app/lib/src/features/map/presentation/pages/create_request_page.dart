import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/silver_balance_chip.dart';
import 'package:app/src/features/map/domain/requests/map_create_task_request.dart';
import 'package:app/src/features/map/presentation/bloc/map_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';

class CreateRequestPage extends StatefulWidget {
  const CreateRequestPage({
    required this.latitude,
    required this.longitude,
    super.key,
  });

  final double latitude;
  final double longitude;

  @override
  State<CreateRequestPage> createState() => _CreateRequestPageState();
}

class _CreateRequestPageState extends State<CreateRequestPage> {
  late final MapBloc _mapBloc;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _heroesController =
      TextEditingController(text: '1');

  double _reward = 2;
  bool _autoShutdown = false;

  @override
  void initState() {
    super.initState();
    _mapBloc = getIt<MapBloc>();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _heroesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121418),
      appBar: CustomAppBar(
        title: "Create a request",
        actions: [
          const SilverBalanceChip.live(),
          const Gap(15),
        ],
      ),
      body: BlocListener<MapBloc, MapState>(
        bloc: _mapBloc,
        listenWhen: (previous, current) {
          final wasCreating = previous.maybeWhen(
            loaded: (viewModel) => viewModel.isCreatingTask,
            orElse: () => false,
          );
          final isCreating = current.maybeWhen(
            loaded: (viewModel) => viewModel.isCreatingTask,
            orElse: () => false,
          );
          // Navigate only once on successful create flow completion edge.
          return wasCreating && !isCreating;
        },
        listener: (context, state) {
          state.maybeWhen(
            loadingError: (message) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: Colors.red,
                ),
              );
            },
            loaded: (_) {
              if (!context.mounted) {
                return;
              }
              context.pushReplacement(RoutePaths.mapCreateRequestPublished);
            },
            orElse: () {},
          );
        },
        child: BlocBuilder<MapBloc, MapState>(
          bloc: _mapBloc,
          builder: (context, state) {
            final isCreating = state.maybeWhen(
              loaded: (viewModel) => viewModel.isCreatingTask,
              orElse: () => false,
            );

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _RequestField(
                              label: 'Title',
                              hint: 'Enter a short request title',
                              controller: _titleController,
                              maxLength: 80,
                            ),
                            const SizedBox(height: 12),
                            _RequestField(
                              label: 'Description',
                              hint: 'Describe your request in detail',
                              controller: _descriptionController,
                              maxLines: 6,
                              maxLength: 500,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Number of heroes',
                              style: TextStyles.bodyMain
                                  .copyWith(color: Colors.white70),
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 44,
                              child: TextField(
                                controller: _heroesController,
                                keyboardType: TextInputType.number,
                                inputFormatters: <TextInputFormatter>[
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(2),
                                ],
                                style: TextStyles.bodyLarge
                                    .copyWith(color: Colors.white),
                                textAlign: TextAlign.center,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF121418),
                                  contentPadding:
                                      const EdgeInsets.symmetric(vertical: 8),
                                  isDense: true,
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color:
                                          Colors.white.withValues(alpha: 0.14),
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide:
                                        const BorderSide(color: Colors.white54),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Text(
                                  'Reward',
                                  style: TextStyles.bodyMain
                                      .copyWith(color: Colors.white70),
                                ),
                                Gap(6),
                                Assets.icons.silverCoin.svg(),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 35,
                                vertical: 15,
                              ),
                              child: _RewardSlider(
                                value: _reward,
                                onChanged: (value) {
                                  setState(() => _reward = value);
                                },
                              ),
                            ),
                            Text(
                              'Heroes will be reserved and cannot be edited after publishing',
                              style: TextStyles.bodyMain.copyWith(
                                color: Colors.white38,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Automatic shutdown',
                                        style: TextStyles.bodyLarge.copyWith(
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'The request will be disabled after 24 hours.',
                                        style: TextStyles.bodyMain.copyWith(
                                          color: Colors.white38,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _autoShutdown,
                                  activeThumbColor: Colors.white,
                                  inactiveThumbColor: Colors.white70,
                                  inactiveTrackColor: Colors.white24,
                                  onChanged: (value) {
                                    setState(() => _autoShutdown = value);
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CustomButton(
                      text: isCreating ? 'Creating...' : 'Create',
                      onTap: () {
                        if (!isCreating) {
                          final title = _titleController.text.trim();
                          final description = _descriptionController.text.trim();
                          final rawHeroes =
                              int.tryParse(_heroesController.text.trim()) ?? 0;
                          final heroesCount = rawHeroes.clamp(1, 20);
                          final reward = _reward.round().clamp(1, 3);

                          if (rawHeroes < 1 || rawHeroes > 20) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Number of heroes must be between 1 and 20.'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          _mapBloc.add(MapEvent.createTask(
                            MapCreateTaskRequest(
                              title: title,
                              description: description,
                              heroesCount: heroesCount,
                              reward: reward,
                              latitude: widget.latitude,
                              longitude: widget.longitude,
                              autoShutdown: _autoShutdown,
                            ),
                          ));
                        }
                      },
                      borderRadius: 8,
                      backgroundColor:
                          isCreating ? const Color(0xFF848B99) : const Color(0xFFB0B7C5),
                      textStyle: TextStyles.bodyLarge.copyWith(
                        color: const Color(0xFF12161F),
                        fontWeight: FontWeight.w600,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RequestField extends StatelessWidget {
  const _RequestField({
    required this.label,
    required this.hint,
    required this.controller,
    this.maxLines = 1,
    this.maxLength,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final int maxLines;
  final int? maxLength;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyles.bodyMain.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          minLines: maxLines,
          maxLines: maxLines,
          maxLength: maxLength,
          buildCounter: (
            BuildContext context, {
            required int currentLength,
            required bool isFocused,
            required int? maxLength,
          }) {
            if (maxLength == null) {
              return null;
            }
            return Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$currentLength/$maxLength',
                style: TextStyles.bodyMain.copyWith(
                  color: Colors.white38,
                  fontSize: 12,
                ),
              ),
            );
          },
          style: TextStyles.bodyMain.copyWith(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyles.bodyMain.copyWith(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF121418),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 10,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.14)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Colors.white54),
            ),
          ),
        ),
      ],
    );
  }
}

class _RewardSlider extends StatelessWidget {
  const _RewardSlider({
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  static const double _stepMin = 1;
  static const double _stepMax = 3;
  static const double _markerSize = 18;
  static const double _trackAreaHeight = 30;
  static const double _labelsAreaHeight = 18;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _trackAreaHeight + _labelsAreaHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final markerRadius = _markerSize / 2;
          final usableWidth = constraints.maxWidth - _markerSize;
          final selectedStep = value.round().clamp(1, 3);

          double centerXForStep(int step) {
            final t = (step - _stepMin) / (_stepMax - _stepMin);
            return markerRadius + (usableWidth * t);
          }

          return Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: _trackAreaHeight,
                child: SfSliderTheme(
                  data: const SfSliderThemeData(
                    activeTrackHeight: 2,
                    inactiveTrackHeight: 2,
                    thumbRadius: 9,
                    overlayRadius: 0,
                  ),
                  child: SfSlider(
                    min: _stepMin,
                    max: _stepMax,
                    value: value,
                    stepSize: 1.0,
                    showDividers: false,
                    showLabels: false,
                    activeColor: Colors.white,
                    inactiveColor: Color(0xFF7A7A7A),
                    thumbShape: _ContainerThumbShape(),
                    onChanged: (dynamic next) {
                      onChanged(next as double);
                    },
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: _trackAreaHeight,
                child: IgnorePointer(
                  child: Stack(
                    children: List.generate(3, (index) {
                      final step = index + 1;
                      final centerX = centerXForStep(step);
                      final isActive = step <= selectedStep;
                      return Positioned(
                        left: centerX - (_markerSize / 2),
                        top: (_trackAreaHeight - _markerSize) / 2,
                        child: _RewardMarker(isActive: isActive),
                      );
                    }),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: _trackAreaHeight,
                height: _labelsAreaHeight,
                child: IgnorePointer(
                  child: Stack(
                    children: List.generate(3, (index) {
                      final step = index + 1;
                      final centerX = centerXForStep(step);
                      return Positioned(
                        left: centerX - 8,
                        top: 0,
                        width: 16,
                        child: Text(
                          '$step',
                          textAlign: TextAlign.center,
                          style: TextStyles.bodyMain.copyWith(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RewardMarker extends StatelessWidget {
  const _RewardMarker({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final outerGradient = isActive
        ? const RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              Color(0xFFF3F3F3),
              Color(0xFFD2D2D2),
              Color(0xFFB0B0B0),
            ],
            stops: [0.0, 0.62, 1.0],
          )
        : const RadialGradient(
            center: Alignment.center,
            radius: 1.0,
            colors: [
              Color(0xFFBDBDBD),
              Color(0xFF9A9A9A),
              Color(0xFF7A7A7A),
            ],
            stops: [0.0, 0.62, 1.0],
          );

    final innerGradient = isActive
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF7F7F7),
              Color(0xFFE7E7E7),
            ],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFD6D6D6),
              Color(0xFFBBBBBB),
            ],
          );

    return SizedBox(
      width: 18,
      height: 18,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: outerGradient,
          border: Border.all(color: const Color(0x66000000), width: 1),
        ),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0x33000000),
                Color(0x00000000),
                Color(0x33000000),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          child: Center(
            child: Container(
              width: 9.5,
              height: 9.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: innerGradient,
                border: Border.all(color: const Color(0x26FFFFFF), width: 1),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ContainerThumbShape extends SfThumbShape {
  const _ContainerThumbShape();

  @override
  Size getPreferredSize(SfSliderThemeData themeData) {
    return const Size(18, 18);
  }

  @override
  void paint(
    PaintingContext context,
    Offset thumbCenter, {
    required RenderBox parentBox,
    required RenderBox? child,
    required SfSliderThemeData themeData,
    SfRangeValues? currentValues,
    dynamic currentValue,
    required Paint? paint,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required SfThumb? thumb,
  }) {
    final canvas = context.canvas;
    const radius = 9.0;
    final outerRect = Rect.fromCircle(center: thumbCenter, radius: radius);

    // Metallic outer circle: brighter top/bottom, darker left/right.
    final outerPaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment.center,
        radius: 1.0,
        colors: [
          Color(0xFFF3F3F3),
          Color(0xFFD3D8E2),
          Color(0xFFADB5C4),
        ],
        stops: [0.0, 0.62, 1.0],
      ).createShader(outerRect);
    canvas.drawCircle(thumbCenter, radius, outerPaint);

    final sideShadePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Color(0x33000000),
          Color(0x00000000),
          Color(0x33000000),
        ],
        stops: [0.0, 0.5, 1.0],
      ).createShader(outerRect);
    canvas.drawCircle(thumbCenter, radius, sideShadePaint);

    final outerStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x66000000);
    canvas.drawCircle(thumbCenter, radius, outerStroke);

    // Inner brighter circle.
    final innerRadius = radius * 0.53;
    final innerRect = Rect.fromCircle(center: thumbCenter, radius: innerRadius);
    final innerPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFF7F7F7),
          Color(0xFFDCE2EE),
        ],
      ).createShader(innerRect);
    canvas.drawCircle(thumbCenter, innerRadius, innerPaint);

    final innerStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x26FFFFFF);
    canvas.drawCircle(thumbCenter, innerRadius, innerStroke);
  }
}
