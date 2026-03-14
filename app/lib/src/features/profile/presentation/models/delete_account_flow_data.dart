class DeleteAccountFlowData {
  const DeleteAccountFlowData({
    required this.verificationMethod,
    required this.displayName,
    required this.avatarUrl,
    required this.email,
    required this.phoneNumber,
    this.selectedReason = '',
  });

  static const String emailMethod = 'email';
  static const String phoneMethod = 'phone';
  static const String defaultPhoneNumber = '787777065068';

  final String verificationMethod;
  final String displayName;
  final String avatarUrl;
  final String email;
  final String phoneNumber;
  final String selectedReason;

  bool get usesPhoneVerification => verificationMethod == phoneMethod;

  String get resolvedVerificationMethod =>
      usesPhoneVerification ? phoneMethod : emailMethod;

  String get resolvedPhoneNumber {
    final trimmedPhoneNumber = phoneNumber.trim();
    if (trimmedPhoneNumber.isEmpty) {
      return defaultPhoneNumber;
    }
    return trimmedPhoneNumber;
  }

  String get resolvedDisplayName {
    final trimmedDisplayName = displayName.trim();
    if (trimmedDisplayName.isEmpty) {
      return 'BrightBund user';
    }
    return trimmedDisplayName;
  }

  factory DeleteAccountFlowData.fromExtra(Object? extra) {
    final map = extra as Map<String, dynamic>?;
    final verificationMethod =
        (map?['verificationMethod'] as String?)?.trim() ?? emailMethod;

    return DeleteAccountFlowData(
      verificationMethod: verificationMethod == phoneMethod
          ? phoneMethod
          : emailMethod,
      displayName: (map?['displayName'] as String?)?.trim() ?? '',
      avatarUrl: (map?['avatarUrl'] as String?)?.trim() ?? '',
      email: (map?['email'] as String?)?.trim() ?? '',
      phoneNumber: (map?['phoneNumber'] as String?)?.trim() ?? '',
      selectedReason: (map?['selectedReason'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toExtra() {
    return <String, dynamic>{
      'verificationMethod': resolvedVerificationMethod,
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'email': email,
      'phoneNumber': resolvedPhoneNumber,
      'selectedReason': selectedReason,
    };
  }

  DeleteAccountFlowData copyWith({
    String? verificationMethod,
    String? displayName,
    String? avatarUrl,
    String? email,
    String? phoneNumber,
    String? selectedReason,
  }) {
    return DeleteAccountFlowData(
      verificationMethod:
          verificationMethod ?? resolvedVerificationMethod,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? resolvedPhoneNumber,
      selectedReason: selectedReason ?? this.selectedReason,
    );
  }
}
