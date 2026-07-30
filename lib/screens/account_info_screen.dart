import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/user_session.dart';

/// 계정 정보 화면 — 로그인된 사용자 정보를 보여준다.
///
/// TODO(실서버 연동): 지금은 로그인 시 저장해둔 UserSession 값만 보여줌.
/// 나중에 실제 계정 정보 수정 API가 생기면 이 화면에서 바로 수정 요청을 보내면 됨
/// (서버 쪽은 이미 GET /api/users/me, DELETE /api/users/me가 준비돼 있음 — AuthService 참고).
class AccountInfoScreen extends StatelessWidget {
  const AccountInfoScreen({super.key});

  String _providerLabel(String? provider) {
    switch (provider) {
      case 'google':
        return 'Google 계정으로 로그인';
      case 'kakao':
        return '카카오 계정으로 로그인';
      default:
        return '로그인 정보 없음 (게스트 상태)';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        title: Text('계정 정보', style: TextStyle(color: kFg)),
        iconTheme: IconThemeData(color: kFg),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ValueListenableBuilder(
        valueListenable: UserSession.current,
        builder: (context, user, _) {
          final name = user?.nickname ?? '진유하';
          final email = user?.email ?? 'yuha@univ.ac.kr';
          final provider = user?.provider;

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 88,
                          height: 88,
                          decoration: BoxDecoration(
                            color: kPrimary.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.person, color: kPrimary, size: 40),
                        ),
                        const SizedBox(height: 12),
                        Text(name,
                            style: TextStyle(color: kFg, fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(_providerLabel(provider),
                            style: TextStyle(color: kMuted, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  _infoGroup([
                    _infoRow('이름', name),
                    _infoRow('이메일', email),
                    _infoRow('로그인 방식', provider == null ? '-' : _providerLabel(provider)),
                  ]),
                  const SizedBox(height: 20),
                  Text(
                    '이름/이메일 변경 기능은 준비 중이에요. 카카오·구글 계정 정보를 기준으로 자동으로 채워져요.',
                    style: TextStyle(color: kMuted, fontSize: 12, height: 1.5),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _infoGroup(List<Widget> items) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: List.generate(items.length, (i) => Column(
          children: [
            items[i],
            if (i < items.length - 1)
              Divider(height: 1, color: kBorder, indent: 16, endIndent: 16),
          ],
        )),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(color: kMuted, fontSize: 14)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(color: kFg, fontSize: 14, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
