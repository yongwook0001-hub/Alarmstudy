import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../services/stats_service.dart';

/// 오답노트 독립 화면 - GET /api/wrong-answers 전체를 정렬 토글 + 무한스크롤로 노출한다.
/// (기존에는 AiSummaryScreen 안에 자료 1개로 필터링된 최대 5개만 파묻혀 있었음)
class WrongAnswerScreen extends StatefulWidget {
  const WrongAnswerScreen({super.key});

  @override
  State<WrongAnswerScreen> createState() => _WrongAnswerScreenState();
}

class _WrongAnswerScreenState extends State<WrongAnswerScreen> {
  static const _pageSize = 20;

  final _scrollController = ScrollController();
  final List<WrongAnswerItem> _items = [];
  String _sort = 'recent';
  int _page = 1;
  int _total = 0;
  bool _loadingMore = false;
  bool _initialLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || _initialLoading) return;
    if (_items.length >= _total) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  Future<void> _loadFirstPage() async {
    final requestedSort = _sort;
    setState(() {
      _initialLoading = true;
      _error = null;
    });
    try {
      final result = await StatsService.wrongAnswersPage(sort: requestedSort, page: 1, size: _pageSize);
      // 응답이 도착하는 사이 사용자가 정렬을 다시 바꿨으면 이 결과는 버린다 (낡은 응답이
      // 최신 정렬 위에 잘못 덮어써지는 걸 방지).
      if (!mounted || _sort != requestedSort) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _total = result.total;
        _page = 1;
      });
    } catch (_) {
      if (mounted && _sort == requestedSort) setState(() => _error = '오답노트를 불러오지 못했어요.');
    } finally {
      if (mounted && _sort == requestedSort) setState(() => _initialLoading = false);
    }
  }

  Future<void> _loadNextPage() async {
    final requestedSort = _sort;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final result = await StatsService.wrongAnswersPage(sort: requestedSort, page: nextPage, size: _pageSize);
      if (!mounted || _sort != requestedSort) return;
      setState(() {
        _items.addAll(result.items);
        _total = result.total;
        _page = nextPage;
      });
    } catch (_) {
      // 다음 페이지 실패는 조용히 무시 - 다시 스크롤하면 같은 위치에서 재시도된다.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _changeSort(String sort) {
    if (_sort == sort) return;
    setState(() => _sort = sort);
    _loadFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        elevation: 0,
        foregroundColor: kFg,
        title: Text('오답노트', style: TextStyle(color: kFg, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              child: Row(
                children: [
                  _sortChip('최신순', 'recent'),
                  const SizedBox(width: 8),
                  _sortChip('자주 틀림순', 'most_wrong'),
                ],
              ),
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _sortChip(String label, String value) {
    final selected = _sort == value;
    return GestureDetector(
      onTap: () => _changeSort(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? kPrimary : kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? kPrimary : kBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : kMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: TextStyle(color: kMuted, fontSize: 13)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _loadFirstPage,
                child: Text('다시 시도', style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Text('오답이 없어요. 완벽해요!', style: TextStyle(color: kMuted, fontSize: 14)),
      );
    }
    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(20),
      itemCount: _items.length + (_items.length < _total ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        if (i >= _items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return _wrongAnswerCard(_items[i]);
      },
    );
  }

  Widget _wrongAnswerCard(WrongAnswerItem item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: kPrimary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(item.topic, style: TextStyle(color: kPrimaryLight, fontSize: 11)),
              ),
              const Spacer(),
              Text('${item.wrongCount}번 틀림',
                  style: TextStyle(color: kRed, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Text(item.content, style: TextStyle(color: kFg, fontSize: 14, height: 1.5)),
          const SizedBox(height: 8),
          Text('정답: ${item.choices[item.correctAnswer]}',
              style: TextStyle(color: kMuted, fontSize: 12.5, fontWeight: FontWeight.w600)),
          if (item.explanation != null) ...[
            const SizedBox(height: 4),
            Text(item.explanation!, style: TextStyle(color: kMuted, fontSize: 12, height: 1.4)),
          ],
        ],
      ),
    );
  }
}
