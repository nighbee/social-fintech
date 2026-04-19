import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/utils/helpers/date_picker_helper.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:app/src/core/widgets/particle_animation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({
    this.email,
    this.password,
    this.phoneNumber,
    this.firebaseIdToken,
    super.key,
  });

  final String? email;
  final String? password;
  final String? phoneNumber;
  final String? firebaseIdToken;

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  DateTime? _selectedDate;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await DatePickerHelper.pickBirthDate(
      context,
      initialDate: _selectedDate,
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateOfBirthController.text = DatePickerHelper.formatUsShort(picked);
      });
      _formKey.currentState?.validate();
    }
  }

  String? _requiredValidator(String? value) {
    if ((value?.trim() ?? '').isEmpty) return 'Please fill this field';
    return null;
  }

  String? _dateValidator(String? value) {
    if (_selectedDate == null) return 'Please select date of birth';
    return null;
  }

  void _continueToReferral() {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;

    final dateStr =
        '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

    context.pushNamed(
      RouteNames.referal,
      extra: {
        'email': widget.email,
        'password': widget.password,
        'phoneNumber': widget.phoneNumber,
        'firebaseIdToken': widget.firebaseIdToken,
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'dateOfBirth': dateStr,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.theme.mainBackground,
      appBar: const CustomAppBar(
        title: 'Info',
        backgroundColor: Colors.transparent,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ParticleAnimation(
                particleCount: 25,
                particleColors: const [Color(0xFFFFFFFF)],
                minSize: 4.0,
                maxSize: 8.0,
                minDistanceBetweenParticles: 70.0,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Gap(40),
                    Text('Legal Name', style: TextStyles.titleBig),
                    Gap(16),
                    CustomTextField(
                      controller: _firstNameController,
                      labelText: 'First name',
                      hintText: 'First name',
                      validator: _requiredValidator,
                    ),
                    Gap(16),
                    CustomTextField(
                      controller: _lastNameController,
                      labelText: 'Last name',
                      hintText: 'Last name',
                      validator: _requiredValidator,
                    ),
                    Gap(40),
                    Text('Date of birth', style: TextStyles.titleBig),
                    Gap(16),
                    CustomTextField(
                      controller: _dateOfBirthController,
                      labelText: 'Date of birth',
                      hintText: 'MM/DD/YY',
                      readOnly: true,
                      onTap: _selectDate,
                      validator: _dateValidator,
                      suffixIcon: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Assets.icons.calendar.svg(
                          width: 20,
                          height: 20,
                          colorFilter: const ColorFilter.mode(
                            AppColors.colorffffffff,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    Gap(40),
                    CustomButton(text: 'Next', onTap: _continueToReferral),
                    Gap(20),
                    SizedBox(
                      height: MediaQuery.of(context).viewInsets.bottom + 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
