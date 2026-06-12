import 'package:app/src/features/profile/data/models/interaction_settings_dto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('active feed limit remains current while another limit is pending', () {
    final dto = FeedSettingsDto.fromJson({
      'current_mins': 20,
      'pending_mins': 60,
      'pending_apply_at': '2026-06-13T10:00:00Z',
    });

    expect(effectiveFeedLimitMins(dto), 20);
    expect(dto.pendingMins, 60);
    expect(dto.pendingApplyAt, DateTime.utc(2026, 6, 13, 10));
  });
}
