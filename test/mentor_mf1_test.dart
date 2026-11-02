import 'package:flutter_test/flutter_test.dart';
import 'package:mindy_flutter/core/network/idempotency.dart';
import 'package:mindy_flutter/core/router/routes.dart';
import 'package:mindy_flutter/core/session/session_controller.dart';
import 'package:mindy_flutter/core/session/session_user.dart';
import 'package:mindy_flutter/core/ui/staff/staff_widgets.dart';
import 'package:mindy_flutter/features/mentor/mentor_utilities.dart';

SessionState signedIn(Role role) => SessionState(
      ready: true,
      user: SessionUser(
        id: '3f2b6d0e-1c2a-4b5c-8d9e-0a1b2c3d4e5f',
        email: 'a@mindy.vn',
        displayName: 'Trần Thị Linh',
        phone: null,
        role: role,
        createdAt: DateTime.utc(2026),
      ),
    );

void main() {
  group('redirectFor - phân luồng theo role', () {
    test('đang kiểm tra phiên -> splash', () {
      expect(redirectFor(const SessionState(), Routes.home), Routes.splash);
      expect(redirectFor(const SessionState(), Routes.splash), isNull);
    });

    test('khách chỉ ở trang guest', () {
      const guest = SessionState(ready: true);
      expect(redirectFor(guest, Routes.login), isNull);
      expect(redirectFor(guest, Routes.register), isNull);
      expect(redirectFor(guest, Routes.mentor), Routes.login);
      expect(redirectFor(guest, Routes.home), Routes.login);
    });

    test('STUDENT vào /home, không vào được khu Mentor', () {
      final s = signedIn(Role.STUDENT);
      expect(redirectFor(s, Routes.login), Routes.home);
      expect(redirectFor(s, Routes.mentor), Routes.home);
      expect(redirectFor(s, Routes.mentorPage('schedule')), Routes.home);
      expect(redirectFor(s, Routes.courses), isNull);
    });

    test('MENTOR chỉ ở khu /mentor', () {
      final s = signedIn(Role.MENTOR);
      expect(redirectFor(s, Routes.login), Routes.mentor);
      expect(redirectFor(s, Routes.home), Routes.mentor);
      expect(redirectFor(s, Routes.courses), Routes.mentor);
      expect(redirectFor(s, Routes.mentor), isNull);
      expect(redirectFor(s, Routes.mentorUtilities), isNull);
      expect(redirectFor(s, Routes.mentorPage('schedule')), isNull);
    });

    test('MANAGER/ADMIN (chưa có app) -> welcome', () {
      expect(redirectFor(signedIn(Role.MANAGER), Routes.mentor), Routes.welcome);
      expect(redirectFor(signedIn(Role.ADMIN), Routes.welcome), isNull);
    });
  });

  group('Tiện ích Mentor', () {
    test('không còn "Mở chương"', () {
      expect(MentorUtil.values.map((u) => u.name), isNot(contains('release')));
    });

    test('mentor chỉ dạy thay không thấy tiện ích của lớp chính', () {
      expect(isUtilVisible(MentorUtil.schedule, substituteOnly: true), isTrue);
      expect(isUtilVisible(MentorUtil.substitute, substituteOnly: true), isTrue);
      expect(isUtilVisible(MentorUtil.classes, substituteOnly: true), isFalse);
      expect(isUtilVisible(MentorUtil.upload, substituteOnly: true), isFalse);
      expect(displayFavorites(const [], substituteOnly: true), [MentorUtil.schedule]);
    });

    test('yêu thích: 3 cố định, tối đa 6, không bỏ được tiện ích chính', () {
      expect(displayFavorites(const [], substituteOnly: false), fixedFavorites);

      var (list, err) = toggleFavorite(const [], MentorUtil.classes);
      expect(err, 'mentor.home.fixed');

      (list, err) = toggleFavorite(const [], MentorUtil.students);
      expect(list, [MentorUtil.students]);
      (list, err) = toggleFavorite(list, MentorUtil.upload);
      (list, err) = toggleFavorite(list, MentorUtil.attendance);
      expect(list.length, 3); // + 3 cố định = 6
      (list, err) = toggleFavorite(list, MentorUtil.substitute);
      expect(err, 'mentor.home.maxFav');
      expect(list.length, 3);

      (list, err) = toggleFavorite(list, MentorUtil.upload);
      expect(list, [MentorUtil.students, MentorUtil.attendance]);
    });
  });

  test('IdempotentCall: key giữ nguyên khi retry, khác nhau giữa các thao tác', () {
    final a = IdempotentCall({'expectedVersion': 3});
    final b = IdempotentCall({'expectedVersion': 3});
    expect(a.headers['Idempotency-Key'], a.key);
    expect(a.key, isNot(b.key));
    expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(a.key), isTrue);
  });

  test('InitialsAvatar.initials', () {
    expect(InitialsAvatar.initials('Trần Thị Linh'), 'TL');
    expect(InitialsAvatar.initials('linh'), 'L');
    expect(InitialsAvatar.initials('  '), '?');
  });
}
