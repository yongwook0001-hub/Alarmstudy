import 'package:flutter/material.dart';
import 'theme_controller.dart';

// ── 다크 팔레트 ──────────────────────────────────────────────
const _darkBg = Color(0xFF181329);
const _darkFg = Color(0xFFF5F3FF);
const _darkMuted = Color(0xFFA79FC4);
const _darkCard = Color(0xFF241D40);
const _darkBorder = Color(0xFF3A3160);
const _darkLogoBg = Color(0xFFFFFFFF);
const _darkOnboardCard = Color(0xFF2D2557);

// ── 라이트 팔레트 ─────────────────────────────────────────────
const _lightBg = Color(0xFFFFFFFF);
const _lightFg = Color(0xFF1A1A1A);
const _lightMuted = Color(0xFF8E8E93);
const _lightCard = Color(0xFFF7F7F9);
const _lightBorder = Color(0xFFE5E5EA);
const _lightLogoBg = Color(0xFFEDEFFD);
const _lightOnboardCard = Color(0xFFEDEFFD);

// 브랜드/시맨틱 컬러는 모드와 무관하게 동일하게 유지
const _primary = Color(0xFF8C7EE8);
const _primaryLight = Color(0xFFA79AF0);
const _accent = Color(0xFFFF6B6B);
const _green = Color(0xFF4ECDC4);
const _red = Color(0xFFFF4757);
const _badgePurple = Color(0xFF8C7EE8);
const _badgeOrange = Color(0xFFFF9F5A);

bool get _dark => ThemeController.isDark.value;

// ── 공개 접근자 (기존 코드에서 kBg, kFg 등으로 그대로 사용) ──────
// 주의: const가 아닌 getter이므로, 이 값들을 참조하는 위젯 생성자 앞에는
// const를 붙일 수 없다 (라이트/다크 전환 시 값이 바뀌어야 하기 때문).
Color get kBg => _dark ? _darkBg : _lightBg;
Color get kFg => _dark ? _darkFg : _lightFg;
Color get kMuted => _dark ? _darkMuted : _lightMuted;
Color get kCard => _dark ? _darkCard : _lightCard;
Color get kBorder => _dark ? _darkBorder : _lightBorder;
Color get kLogoBg => _dark ? _darkLogoBg : _lightLogoBg;
Color get kOnboardCard => _dark ? _darkOnboardCard : _lightOnboardCard;

Color get kPrimary => _primary;
Color get kPrimaryLight => _primaryLight;
Color get kAccent => _accent;
Color get kGreen => _green;
Color get kRed => _red;
Color get kBadgePurple => _badgePurple;
Color get kBadgeOrange => _badgeOrange;
