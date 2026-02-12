import 'package:app/gen/assets.gen.dart';
import 'package:app/src/core/router/router.dart';
import 'package:app/src/core/theme/theme.dart';
import 'package:app/src/core/widgets/custom_app_bar.dart';
import 'package:app/src/core/widgets/custom_button.dart';
import 'package:app/src/core/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class InfoPage extends StatefulWidget {
  const InfoPage({super.key});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();
  DateTime? _selectedDate;
  String? _email;
  String? _password;
  String? _phoneNumber;
  String? _firebaseIdToken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final extra = GoRouterState.of(context).extra as Map<String, dynamic>?;
      if (extra != null) {
        setState(() {
          _email = extra['email'] as String?;
          _password = extra['password'] as String?;
          _phoneNumber = extra['phoneNumber'] as String?;
          _firebaseIdToken = extra['firebaseIdToken'] as String?;
        });
      }
    });
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.dark(
              primary: AppColors.blueText1,
              onPrimary: AppColors.whiteBackground,
              surface: AppColors.mainBackground,
              onSurface: AppColors.whiteBackground,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        final month = picked.month.toString().padLeft(2, '0');
        final day = picked.day.toString().padLeft(2, '0');
        final year = picked.year.toString().substring(2);
        _dateOfBirthController.text = '$month/$day/$year';
      });
    }
  }

  void _continueToReferral() {
    if (_firstNameController.text.isEmpty || _lastNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date of birth')),
      );
      return;
    }

    // Format date as YYYY-MM-DD
    final dateStr =
        '${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}';

    // Navigate to referral page with all collected data
    context.pushNamed(
      RouteNames.referal,
      extra: {
        'email': _email,
        'password': _password,
        'phoneNumber': _phoneNumber,
        'firebaseIdToken': _firebaseIdToken,
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
      appBar: const CustomAppBar(title: 'Info'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Gap(40),
              Text("Legal Name", style: TextStyles.titleBig),
              Gap(16),
              CustomTextField(
                controller: _firstNameController,
                labelText: "First name",
                hintText: "First name",
              ),
              Gap(16),
              CustomTextField(
                controller: _lastNameController,
                labelText: "Last name",
                hintText: "Last name",
              ),
              Gap(40),
              Text("Date of birth", style: TextStyles.titleBig),
              Gap(16),
              CustomTextField(
                controller: _dateOfBirthController,
                labelText: "Date of birth",
                hintText: "MM/DD/YY",
                readOnly: true,
                onTap: () => _selectDate(context),
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Assets.icons.calendar.svg(
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                      AppColors.whiteBackground,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ),
              Gap(40),
              CustomButton(text: "Next", onTap: _continueToReferral),
              Gap(20),
              SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
            ],
          ),
        ),
      ),
    );
  }
}
