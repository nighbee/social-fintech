import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/service/injectable/injectable_service.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/features/map/domain/requests/map_create_task_request.dart';
import 'package:app/src/features/map/presentation/bloc/map_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Assets.icons.silverCoin.svg(width: 24, height: 24),
                const Gap(4),
                Text(
                  '27',
                  style: TextStyles.titleTag.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
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
                              child: SfSliderTheme(
                                data: const SfSliderThemeData(
                                  activeTrackHeight: 2,
                                  inactiveTrackHeight: 2,
                                  thumbRadius: 9,
                                  overlayRadius: 0,
                                  activeDividerRadius: 9,
                                  inactiveDividerRadius: 9,
                                  activeDividerColor: Colors.white,
                                  inactiveDividerColor: Color(0xFF7A7A7A),
                                  // thumbColor: AppColors.whiteBackground,
                                ),
                                child: SfSlider(
                                  min: 1.0,
                                  max: 3.0,
                                  value: _reward,
                                  stepSize: 1.0,
                                  interval: 1.0,
                                  showDividers: true,
                                  showLabels: true,
                                  activeColor: Colors.white,
                                  inactiveColor: Color(0xFF7A7A7A),
                                  thumbShape: _ContainerThumbShape(),
                                  dividerShape: _ContainerDividerShape(),
                                  onChanged: (dynamic value) {
                                    setState(() => _reward = value as double);
                                  },
                                ),
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
                                  activeColor: Colors.white,
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
                          final heroesCount =
                              int.tryParse(_heroesController.text) ?? 1;
                          _mapBloc.add(MapEvent.createTask(
                            MapCreateTaskRequest(
                              title: _titleController.text,
                              description: _descriptionController.text,
                              heroesCount: heroesCount,
                              reward: _reward.toInt(),
                              latitude: widget.latitude,
                              longitude: widget.longitude,
                              autoShutdown: _autoShutdown,
                            ),
                          ));
                        }
                      },
                      borderRadius: 8,
                      backgroundColor:
                          isCreating ? Colors.white24 : Colors.white,
                      textStyle: TextStyles.bodyLarge.copyWith(
                        color: Colors.black,
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

class _ContainerThumbShape extends SfThumbShape {
  const _ContainerThumbShape({
    this.width = 18,
    this.height = 18,
    this.borderRadius = 6,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Size getPreferredSize(SfSliderThemeData themeData) {
    return Size(width, height);
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
    final rect = Rect.fromCenter(
      center: thumbCenter,
      width: width,
      height: height,
    );
    final rRect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );

    final fillPaint = Paint()..color = const Color(0xFFF8F8F8);
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x33000000);

    canvas.drawRRect(rRect, fillPaint);
    canvas.drawRRect(rRect, borderPaint);
  }
}

class _ContainerDividerShape extends SfDividerShape {
  const _ContainerDividerShape({
    this.width = 18,
    this.height = 18,
    this.borderRadius = 6,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Size getPreferredSize(SfSliderThemeData themeData, {bool? isActive}) {
    return Size(width, height);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center,
    Offset? thumbCenter,
    Offset? startThumbCenter,
    Offset? endThumbCenter, {
    required RenderBox parentBox,
    required SfSliderThemeData themeData,
    SfRangeValues? currentValues,
    dynamic currentValue,
    required Paint? paint,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
  }) {
    final bool isActive =
        thumbCenter == null ? false : center.dx <= thumbCenter.dx;
    final Color fillColor =
        isActive ? const Color(0xFFF8F8F8) : const Color(0xFF8A8A8A);

    final rect = Rect.fromCenter(
      center: center,
      width: width,
      height: height,
    );
    final rRect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final fillPaint = Paint()..color = fillColor;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0x33000000);

    context.canvas.drawRRect(rRect, fillPaint);
    context.canvas.drawRRect(rRect, borderPaint);
  }
}
