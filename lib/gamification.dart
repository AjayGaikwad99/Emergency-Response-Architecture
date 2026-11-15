import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GamificationScreen extends StatefulWidget {
  const GamificationScreen({Key? key}) : super(key: key);

  @override
  State<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends State<GamificationScreen> {
  static const String _kPointsKey = 'gamify_points';
  static const String _kVouchersKey = 'gamify_vouchers';
  static const String _kLastCheckinKey = 'gamify_last_checkin';
  static const int _badgeStep = 1000;
  static const int _maxBadge = 100000;

  int _points = 0;
  List<String> _vouchers = [];
  SharedPreferences? _prefs;
  final Random _rnd = Random.secure();

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _points = _prefs?.getInt(_kPointsKey) ?? 0;
      _vouchers = _prefs?.getStringList(_kVouchersKey) ?? [];
    });
  }

  Future<void> _savePoints() async {
    if (_prefs == null) return;
    await _prefs!.setInt(_kPointsKey, _points);
  }

  Future<void> _saveVouchers() async {
    if (_prefs == null) return;
    await _prefs!.setStringList(_kVouchersKey, _vouchers);
  }

  void _addPoints(int p, {String? reason}) {
    if (!mounted) return;
    setState(() => _points += p);
    _savePoints();
    _checkForNewBadges();
    if (reason != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('+$p pts — $reason')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('+$p pts')));
    }
  }

  void _deductPoints(int p, {String? reason}) {
    if (!mounted) return;
    setState(() => _points = max(0, _points - p));
    _savePoints();
    if (reason != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('-$p pts — $reason')));
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('-$p pts')));
    }
  }

  void _checkForNewBadges() {
    if (_points > 0 && _points % _badgeStep == 0 && _points <= _maxBadge) {
      _showBadgeDialog(_points);
    }
  }

  void _showBadgeDialog(int threshold) {
    final badge = _badgeFor(threshold);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Row(children: [
          _animalBadge(badge, size: 44),
          const SizedBox(width: 12),
          Text('Badge Earned: ${badge.name}',
              style: const TextStyle(color: Colors.white)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('You reached $threshold points',
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(badge.description,
                style: const TextStyle(color: Colors.white60)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Nice'))
        ],
      ),
    );
  }

  _Badge _badgeFor(int threshold) {
    final tier = threshold ~/ _badgeStep;
    final mapping = <int, Map<String, dynamic>>{
      1: {'name': 'Bronze Cat', 'animal': '🐱', 'color': Colors.brown},
      2: {'name': 'Silver Dog', 'animal': '🐶', 'color': Colors.blueGrey},
      3: {'name': 'Gold Wolf', 'animal': '🐺', 'color': Colors.amber},
      4: {'name': 'Platinum Tiger', 'animal': '🐯', 'color': Colors.indigo},
      5: {'name': 'Diamond Eagle', 'animal': '🦅', 'color': Colors.cyan},
      6: {'name': 'Mastery Lion', 'animal': '🦁', 'color': Colors.deepPurple},
      7: {
        'name': 'Legendary Dragon',
        'animal': '🐉',
        'color': Colors.orangeAccent
      },
    };
    final info = mapping[tier] ??
        {
          'name': 'Tier $tier Badge',
          'animal': '🏆',
          'color': Colors.teal,
        };
    return _Badge(
      name: info['name'] as String,
      description:
          'Unique shiny badge: ${info['animal']} for reaching $threshold points.',
      color: info['color'] as Color,
      tier: tier,
      animalEmoji: info['animal'] as String,
    );
  }

  Widget _animalBadge(_Badge badge, {double size = 56}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [badge.color.withOpacity(0.95), badge.color.withOpacity(0.6)],
          center: const Alignment(-0.2, -0.2),
          radius: 0.9,
        ),
        boxShadow: [
          BoxShadow(
              color: badge.color.withOpacity(0.45),
              blurRadius: 12,
              offset: const Offset(0, 6)),
          const BoxShadow(
              color: Colors.white24,
              blurRadius: 2,
              offset: Offset(-2, -2),
              spreadRadius: 0.5),
        ],
      ),
      child: Stack(alignment: Alignment.center, children: [
        Container(
            width: size * 0.78,
            height: size * 0.78,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient:
                    LinearGradient(colors: [Colors.white24, Colors.white10]))),
        Text(badge.animalEmoji, style: TextStyle(fontSize: size * 0.45)),
        Positioned(
            top: 6,
            right: 8,
            child: Icon(Icons.auto_awesome,
                color: Colors.white.withOpacity(0.85), size: size * 0.18)),
      ]),
    );
  }

  List<int> _earnedBadgeThresholds() {
    final list = <int>[];
    final maxTier = min(_points ~/ _badgeStep, _maxBadge ~/ _badgeStep);
    for (int t = 1; t <= maxTier; t++) list.add(t * _badgeStep);
    return list;
  }

  final List<_QuizQuestion> _quizQuestions = [
    _QuizQuestion(
      question:
          'If you discover a small fire, what is the safest first action?',
      options: [
        'Try to extinguish if safe',
        'Open all windows',
        'Run upstairs',
        'Hide under bed'
      ],
      correctIndex: 0,
      points: 80,
    ),
    _QuizQuestion(
      question: 'During heavy smoke you should:',
      options: [
        'Stand tall and breathe deeply',
        'Stay low and crawl',
        'Use elevator',
        'Open doors widely'
      ],
      correctIndex: 1,
      points: 60,
    ),
    _QuizQuestion(
      question: 'How often test smoke alarms?',
      options: ['Monthly', 'Yearly', 'Never', 'Only when battery dies'],
      correctIndex: 0,
      points: 40,
    ),
  ];

  Future<void> _playQuiz() async {
    int totalEarned = 0;
    for (final q in _quizQuestions) {
      final result = await _showQuizDialog(q);
      if (result == null) continue;
      if (result)
        totalEarned += q.points;
      else
        _deductPoints(10, reason: 'Wrong quiz answer');
    }
    if (totalEarned > 0) _addPoints(totalEarned, reason: 'Quiz completed');
  }

  Future<bool?> _showQuizDialog(_QuizQuestion q) async {
    int? selected;
    final res = await showDialog<bool?>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: Text(q.question),
          content: StatefulBuilder(builder: (context, setState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: q.options.asMap().entries.map((e) {
                return RadioListTile<int>(
                  value: e.key,
                  groupValue: selected,
                  title: Text(e.value),
                  onChanged: (v) => setState(() => selected = v),
                );
              }).toList(),
            );
          }),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Skip')),
            ElevatedButton(
              onPressed: () {
                if (selected == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Choose an option or Skip')));
                  return;
                }
                Navigator.of(context).pop(selected == q.correctIndex);
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
    return res;
  }

  Future<void> _playSpinWheel() async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => const _SpinWheelDialogFull(),
    );
    if (result == null) return;
    if (result >= 0)
      _addPoints(result, reason: 'Spin Wheel');
    else
      _deductPoints(-result, reason: 'Spin Wheel penalty');
  }

  Future<void> _playTapChallenge() async {
    final earned = await showDialog<int>(
      context: context,
      builder: (context) => const _TapChallengeDialog(),
    );
    if (earned != null && earned > 0)
      _addPoints(earned, reason: 'Tap Challenge');
  }

  Future<void> _playReactionTest() async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => const _ReactionBlinkDialogV2(),
    );
    if (result == null) return;
    if (result > 0)
      _addPoints(result, reason: 'Reaction Test');
    else if (result < 0) _deductPoints(-result, reason: 'Reaction penalty');
  }

  Future<void> _playMemoryGreen() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const _MemoryGreenDialogV2(),
    );
    if (result == true)
      _addPoints(10, reason: 'Memory target');
    else if (result == false) _deductPoints(10, reason: 'Memory wrong');
  }

  Future<void> _playMathChallenge() async {
    final earned = await showDialog<int?>(
      context: context,
      builder: (context) => const _MathChallengeDialog(),
    );
    if (earned == null) return;
    if (earned > 0)
      _addPoints(earned, reason: 'Math Challenge');
    else if (earned < 0) _deductPoints(-earned, reason: 'Math wrong');
  }

  Future<void> _playQuickTarget() async {
    final hits = await showDialog<int>(
      context: context,
      builder: (context) => const _QuickTargetDialog(),
    );
    if (hits != null && hits > 0) _addPoints(hits * 5, reason: 'Quick Target');
  }

  Future<void> _playTrueFalseBlitz() async {
    final net = await showDialog<int>(
      context: context,
      builder: (context) => const _TrueFalseBlitzDialog(),
    );
    if (net == null) return;
    if (net > 0)
      _addPoints(net, reason: 'True/False Blitz');
    else if (net < 0) _deductPoints(-net, reason: 'Blitz penalties');
  }

  Future<void> _playMatchingPairs() async {
    final result = await showDialog<int>(
      context: context,
      builder: (context) => const _MatchingPairs16Dialog(),
    );
    if (result == null) return;
    if (result > 0) _addPoints(result, reason: 'Matching Pairs');
  }

  Future<void> _dailyCheckIn() async {
    final last = _prefs?.getString(_kLastCheckinKey);
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    if (last == today) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already checked in today')));
      return;
    }
    _prefs?.setString(_kLastCheckinKey, today);
    _addPoints(100, reason: 'Daily Check-in');
  }

  void _redeem(int cost, String label) {
    if (_points < cost) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough points to redeem')));
      return;
    }
    _deductPoints(cost, reason: 'Redeemed $label');
    final code = _generateVoucherCode();
    setState(
        () => _vouchers.add('$label - V-$code (₹${_couponValueFor(cost)})'));
    _saveVouchers();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Voucher created: V-$code')));
  }

  int _couponValueFor(int cost) {
    if (cost >= 10000) return 250;
    if (cost >= 5000) return 100;
    if (cost >= 3000) return 50;
    if (cost >= 2000) return 25;
    return 10;
  }

  String _generateVoucherCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    return List.generate(8, (_) => chars[_rnd.nextInt(chars.length)]).join();
  }

  Widget _buildPointsCard() {
    final currentBadgeThreshold = ((_points ~/ _badgeStep) * _badgeStep);
    final badgeThreshold =
        currentBadgeThreshold == 0 ? _badgeStep : currentBadgeThreshold;
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          _animalBadge(_badgeFor(badgeThreshold), size: 64),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Your Points',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('$_points', style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 6),
              Text(
                  'Next badge at ${(((_points ~/ _badgeStep) + 1) * _badgeStep)} pts',
                  style: const TextStyle(color: Colors.black54)),
            ]),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'redeem') _showRedeemSheet();
              if (v == 'vouchers') _showVouchersSheet();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'redeem', child: Text('Redeem')),
              PopupMenuItem(value: 'vouchers', child: Text('My Vouchers')),
            ],
          ),
        ]),
      ),
    );
  }

  void _showRedeemSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Redeem Points',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                ElevatedButton(
                    onPressed: () => _redeem(3000, '₹50 Coupon'),
                    child: const Text('₹50 Coupon (3000 pts)')),
                ElevatedButton(
                    onPressed: () => _redeem(5000, '₹100 Coupon'),
                    child: const Text('₹100 Coupon (5000 pts)')),
                ElevatedButton(
                    onPressed: () => _redeem(10000, '₹250 Coupon'),
                    child: const Text('₹250 Coupon (10000 pts)')),
                ElevatedButton(
                    onPressed: () => _redeem(2000, '₹25 Coupon'),
                    child: const Text('₹25 Coupon (2000 pts)')),
              ]),
            ]),
          ),
        );
      },
    );
  }

  void _showVouchersSheet() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Your Vouchers',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (_vouchers.isEmpty) const Text('No vouchers yet.'),
              ..._vouchers.reversed.map((v) => ListTile(
                  title: Text(v), leading: const Icon(Icons.card_giftcard))),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildEarnTasksCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Play to Earn',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ElevatedButton.icon(
                icon: const Icon(Icons.quiz),
                label: const Text('Quiz'),
                onPressed: _playQuiz),
            ElevatedButton.icon(
                icon: const Icon(Icons.casino),
                label: const Text('Spin Wheel'),
                onPressed: _playSpinWheel),
            ElevatedButton.icon(
                icon: const Icon(Icons.fingerprint),
                label: const Text('Tap Challenge'),
                onPressed: _playTapChallenge),
            ElevatedButton.icon(
                icon: const Icon(Icons.flash_on),
                label: const Text('Reaction Test'),
                onPressed: _playReactionTest),
            ElevatedButton.icon(
                icon: const Icon(Icons.memory),
                label: const Text('Memory (Green)'),
                onPressed: _playMemoryGreen),
            ElevatedButton.icon(
                icon: const Icon(Icons.calculate),
                label: const Text('Math'),
                onPressed: _playMathChallenge),
            ElevatedButton.icon(
                icon: const Icon(Icons.adjust),
                label: const Text('Quick Target'),
                onPressed: _playQuickTarget),
            ElevatedButton.icon(
                icon: const Icon(Icons.checklist),
                label: const Text('True/False Blitz'),
                onPressed: _playTrueFalseBlitz),
            ElevatedButton.icon(
                icon: const Icon(Icons.grid_view),
                label: const Text('Matching Pairs'),
                onPressed: _playMatchingPairs),
            ElevatedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: const Text('Daily Check-in'),
                onPressed: _dailyCheckIn),
          ]),
        ]),
      ),
    );
  }

  Widget _buildBadgesCard() {
    final thresholds = _earnedBadgeThresholds();
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Badges', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (thresholds.isEmpty)
            const Text(
                'No badges yet. Earn points to unlock decorative badges.'),
          Wrap(
              spacing: 12,
              children: thresholds.map((t) {
                final b = _badgeFor(t);
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  _animalBadge(b, size: 64),
                  const SizedBox(height: 6),
                  Text(b.name, style: const TextStyle(fontSize: 12)),
                ]);
              }).toList()),
        ]),
      ),
    );
  }

  Widget _buildRedeemCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Redeem', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ElevatedButton(
                onPressed: () => _redeem(3000, '₹50 Coupon'),
                child: const Text('₹50 Coupon (3000 pts)')),
            ElevatedButton(
                onPressed: () => _redeem(5000, '₹100 Coupon'),
                child: const Text('₹100 Coupon (5000 pts)')),
            ElevatedButton(
                onPressed: () => _redeem(10000, '₹250 Coupon'),
                child: const Text('₹250 Coupon (10000 pts)')),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Community Engagement'),
          backgroundColor: Colors.blue.shade700),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _buildPointsCard(),
            const SizedBox(height: 12),
            _buildEarnTasksCard(),
            const SizedBox(height: 12),
            _buildBadgesCard(),
            const SizedBox(height: 12),
            _buildRedeemCard(),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Your Vouchers',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      if (_vouchers.isEmpty) const Text('No vouchers yet.'),
                      ..._vouchers.reversed.map((v) => ListTile(
                          leading: const Icon(Icons.card_giftcard),
                          title: Text(v))),
                    ]),
              ),
            ),
            const SizedBox(height: 24),
            Center(
                child: ElevatedButton.icon(
                    icon: const Icon(Icons.share),
                    label: const Text('Share Achievement'),
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Share not implemented in demo'))))),
            const SizedBox(height: 24),
          ]),
        ),
      ),
    );
  }
}

class _QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;
  final int points;
  const _QuizQuestion(
      {required this.question,
      required this.options,
      required this.correctIndex,
      required this.points});
}

class _Badge {
  final String name;
  final String description;
  final Color color;
  final int tier;
  final String animalEmoji;
  _Badge(
      {required this.name,
      required this.description,
      required this.color,
      required this.tier,
      this.animalEmoji = '🏆'});
}

class _SpinWheelDialogFull extends StatefulWidget {
  const _SpinWheelDialogFull({Key? key}) : super(key: key);

  @override
  State<_SpinWheelDialogFull> createState() => _SpinWheelDialogFullState();
}

class _SpinWheelDialogFullState extends State<_SpinWheelDialogFull>
    with SingleTickerProviderStateMixin {
  final List<_SpinSegment> segments = [
    _SpinSegment('+10', 10, Colors.green.shade400),
    _SpinSegment('+20', 20, Colors.green.shade600),
    _SpinSegment('+50', 50, Colors.lightGreen),
    _SpinSegment('+100', 100, Colors.blue.shade400),
    _SpinSegment('-20', -20, Colors.red.shade300),
    _SpinSegment('+200', 200, Colors.purple.shade300),
    _SpinSegment('-50', -50, Colors.red.shade600),
    _SpinSegment('+500', 500, Colors.orange.shade400),
  ];

  late AnimationController _controller;
  late Animation<double> _animation;
  double _currentRotation = 0.0;
  bool _spinning = false;
  final Random _rnd = Random.secure();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _animation = Tween<double>(begin: 0, end: 0).animate(_controller);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _onSpinComplete();
    });
  }

  double _targetRotation = 0.0;

  void _spin() {
    if (_spinning) return;
    setState(() => _spinning = true);

    final weights = [30, 25, 20, 12, 6, 4, 2, 1];
    final total = weights.reduce((a, b) => a + b);
    int pick = _rnd.nextInt(total);
    int idx = 0;
    int acc = 0;
    for (int i = 0; i < weights.length; i++) {
      acc += weights[i];
      if (pick < acc) {
        idx = i;
        break;
      }
    }

    final segAngle = 2 * pi / segments.length;
    final targetSegmentCenter = (idx + 0.5) * segAngle;
    final spins = 5 + _rnd.nextInt(4);
    _targetRotation = spins * 2 * pi + targetSegmentCenter;

    final start = _currentRotation;
    final end = _currentRotation + _targetRotation;

    _controller.duration = const Duration(seconds: 10);
    _animation = Tween<double>(begin: start, end: end)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.decelerate))
      ..addListener(() {
        setState(() {
          _currentRotation = _animation.value;
        });
      });
    _controller.reset();
    _controller.forward();
  }

  void _onSpinComplete() {
    final segAngle = 2 * pi / segments.length;
    double normalized = _currentRotation % (2 * pi);
    if (normalized < 0) normalized += 2 * pi;
    double angleFromStart = (normalized + (pi / 2)) % (2 * pi);
    int idx = (angleFromStart / segAngle).floor() % segments.length;
    final chosen = segments[idx];

    setState(() => _spinning = false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Future.delayed(const Duration(seconds: 3), () {
          if (Navigator.of(ctx).canPop()) {
            Navigator.of(ctx).pop();
            if (mounted) Navigator.of(context).pop(chosen.value);
          }
        });
        return AlertDialog(
          title: Text(chosen.value >= 0
              ? 'You won ${chosen.value} pts!'
              : 'Penalty ${chosen.value} pts'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Segment: ${chosen.label}'),
            const SizedBox(height: 8),
            const Text('Awarding this prize in 3 seconds...',
                style: TextStyle(fontSize: 12)),
          ]),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildWheel(double size) {
    return Stack(alignment: Alignment.center, children: [
      Transform.rotate(
        angle: _currentRotation,
        child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(painter: _WheelPainterFull(segments))),
      ),
      Container(
          width: size * 0.36,
          height: size * 0.36,
          decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)]),
          child: const Center(
              child:
                  Text('SPIN', style: TextStyle(fontWeight: FontWeight.bold)))),
      Positioned(
          top: 6,
          child: Icon(Icons.arrow_drop_down, size: 36, color: Colors.white)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.78;
    return Dialog(
      backgroundColor: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Spin Wheel',
              style: TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 12),
          _buildWheel(size),
          const SizedBox(height: 12),
          ElevatedButton.icon(
              icon: const Icon(Icons.casino),
              label: Text(_spinning ? 'Spinning...' : 'Spin'),
              onPressed: _spinning ? null : _spin),
          const SizedBox(height: 8),
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close')),
        ]),
      ),
    );
  }
}

class _SpinSegment {
  final String label;
  final int value;
  final Color color;
  _SpinSegment(this.label, this.value, this.color);
}

class _WheelPainterFull extends CustomPainter {
  final List<_SpinSegment> segments;
  _WheelPainterFull(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final segAngle = 2 * pi / segments.length;
    final paint = Paint()..style = PaintingStyle.fill;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < segments.length; i++) {
      final start = -pi / 2 + i * segAngle;
      paint.color = segments[i].color;
      final path = Path()
        ..moveTo(center.dx, center.dy)
        ..arcTo(Rect.fromCircle(center: center, radius: radius), start,
            segAngle, false)
        ..close();
      canvas.drawPath(path, paint);

      final label = segments[i].label;
      textPainter.text = TextSpan(
          text: label,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold));
      textPainter.layout();
      final angle = start + segAngle / 2;
      final tx =
          center.dx + (radius * 0.65) * cos(angle) - textPainter.width / 2;
      final ty =
          center.dy + (radius * 0.65) * sin(angle) - textPainter.height / 2;
      canvas.save();
      canvas.translate(tx + textPainter.width / 2, ty + textPainter.height / 2);
      canvas.rotate(angle + pi / 2);
      canvas.translate(-textPainter.width / 2, -textPainter.height / 2);
      textPainter.paint(canvas, Offset.zero);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _WheelPainterFull oldDelegate) => true;
}

class _TapChallengeDialog extends StatefulWidget {
  const _TapChallengeDialog({Key? key}) : super(key: key);

  @override
  State<_TapChallengeDialog> createState() => _TapChallengeDialogState();
}

class _TapChallengeDialogState extends State<_TapChallengeDialog> {
  int _count = 0;
  bool _running = false;
  Timer? _timer;
  int _secondsLeft = 5;

  void _start() {
    if (_running) return;
    setState(() {
      _running = true;
      _count = 0;
      _secondsLeft = 5;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          t.cancel();
          _running = false;
          Navigator.of(context).pop(_count);
        }
      });
    });
  }

  void _tap() {
    if (!_running) return;
    setState(() => _count++);
  }

  void _cancel() {
    _timer?.cancel();
    Navigator.of(context).pop(0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Tap Challenge'),
          const SizedBox(height: 8),
          Text(
              _running ? 'Time left: $_secondsLeft s' : 'Press Start to begin'),
          const SizedBox(height: 12),
          ElevatedButton(
              onPressed: _running ? null : _start, child: const Text('Start')),
          const SizedBox(height: 12),
          ElevatedButton(
              onPressed: _tap,
              style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(vertical: 18, horizontal: 36)),
              child: Text('TAP ($_count)')),
          const SizedBox(height: 12),
          TextButton(onPressed: _cancel, child: const Text('Cancel')),
        ]),
      ),
    );
  }
}

class _ReactionBlinkDialogV2 extends StatefulWidget {
  const _ReactionBlinkDialogV2({Key? key}) : super(key: key);

  @override
  State<_ReactionBlinkDialogV2> createState() => _ReactionBlinkDialogV2State();
}

class _ReactionBlinkDialogV2State extends State<_ReactionBlinkDialogV2> {
  final Random _rnd = Random.secure();
  Color _color = Colors.red;
  bool _running = true;
  Timer? _timer;
  int _ticks = 0;
  static const int _maxTicks = 16;
  int _greenTaps = 0;

  @override
  void initState() {
    super.initState();
    _startBlink();
  }

  void _startBlink() {
    _timer?.cancel();
    _ticks = 0;
    _running = true;
    _greenTaps = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _color = (_rnd.nextBool()) ? Colors.green : Colors.red;
        _ticks++;
        if (_ticks >= _maxTicks) {
          t.cancel();
          _running = false;
          if (_greenTaps >= 5)
            Navigator.of(context).pop(10);
          else
            Navigator.of(context).pop(0);
        }
      });
    });
  }

  void _onTap() {
    if (!_running) return;
    if (_color == Colors.green) {
      setState(() => _greenTaps++);
      if (_greenTaps >= 5) {
        _timer?.cancel();
        _running = false;
        Navigator.of(context).pop(10);
      }
    } else {
      _timer?.cancel();
      _running = false;
      Navigator.of(context).pop(-5);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.grey.shade900,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Reaction Blink', style: TextStyle(color: Colors.white)),
          const SizedBox(height: 8),
          Text(
              'Tap GREEN 5 times within 8 seconds to earn +10. Tap RED to lose -5.',
              style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _onTap,
            child: Container(
              width: 260,
              height: 140,
              decoration: BoxDecoration(
                  color: _color, borderRadius: BorderRadius.circular(8)),
              child: Center(
                  child: Text(_running ? 'Tap now (${_greenTaps}/5)' : 'Done',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 20))),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
              onPressed: () => Navigator.of(context).pop(0),
              child: const Text('Cancel')),
        ]),
      ),
    );
  }
}

class _MemoryGreenDialogV2 extends StatefulWidget {
  const _MemoryGreenDialogV2({Key? key}) : super(key: key);

  @override
  State<_MemoryGreenDialogV2> createState() => _MemoryGreenDialogV2State();
}

class _MemoryGreenDialogV2State extends State<_MemoryGreenDialogV2> {
  final Random _rnd = Random.secure();
  late List<int> _numbers;
  late List<int> _highlightOrder;
  late int _greenIndex;
  int _currentHighlight = -1;
  Color? _currentColor;
  bool _showingSequence = true;
  bool _sequenceDone = false;

  @override
  void initState() {
    super.initState();
    _prepare();
    _playSequence();
  }

  void _prepare() {
    _numbers = List.generate(20, (i) => 1 + _rnd.nextInt(99));
    final set = <int>{};
    while (set.length < 8) set.add(_rnd.nextInt(20));
    _highlightOrder = set.toList();
    final greenPos = _rnd.nextInt(_highlightOrder.length);
    _greenIndex = _highlightOrder[greenPos];
    _highlightOrder.shuffle(_rnd);
  }

  Future<void> _playSequence() async {
    for (int i = 0; i < _highlightOrder.length; i++) {
      final idx = _highlightOrder[i];
      setState(() {
        _currentHighlight = idx;
        _currentColor = (idx == _greenIndex) ? Colors.green : Colors.red;
      });
      await Future.delayed(const Duration(milliseconds: 700));
      setState(() {
        _currentHighlight = -1;
        _currentColor = null;
      });
      await Future.delayed(const Duration(milliseconds: 200));
    }

    setState(() {
      _showingSequence = false;
      _sequenceDone = true;
    });
  }

  void _onTapIndex(int idx) {
    if (!_sequenceDone) return;
    if (idx == _greenIndex) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pop(false);
    }
  }

  Widget _buildCell(int idx) {
    final num = _numbers[idx];
    Color bg = Colors.grey.shade200;
    if (_currentHighlight == idx && _currentColor != null) {
      bg = _currentColor!;
    }
    return GestureDetector(
      onTap: () => _onTapIndex(idx),
      child: Container(
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 3)]),
        child: Center(
            child: Text('$num',
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold))),
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Memory: Watch the sequence and pick the GREEN number',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(
              _showingSequence
                  ? 'Watching sequence...'
                  : 'Tap the number that blinked GREEN',
              style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 12),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: GridView.builder(
              shrinkWrap: true,
              itemCount: 20,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1),
              itemBuilder: (context, i) => _buildCell(i),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Give up')),
        ]),
      ),
    );
  }
}

class _MathChallengeDialog extends StatefulWidget {
  const _MathChallengeDialog({Key? key}) : super(key: key);

  @override
  State<_MathChallengeDialog> createState() => _MathChallengeDialogState();
}

class _MathChallengeDialogState extends State<_MathChallengeDialog> {
  final Random _rnd = Random.secure();
  late int a, b, op;
  late int answer;
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _generate();
  }

  void _generate() {
    a = 1 + _rnd.nextInt(20);
    b = 1 + _rnd.nextInt(20);
    op = _rnd.nextInt(3);
    if (op == 0)
      answer = a + b;
    else if (op == 1)
      answer = a - b;
    else
      answer = a * b;
  }

  void _submit() {
    final val = int.tryParse(_ctrl.text.trim());
    if (val == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a number')));
      return;
    }
    if (val == answer)
      Navigator.of(context).pop(100);
    else
      Navigator.of(context).pop(-10);
  }

  @override
  Widget build(BuildContext context) {
    final opSymbol = op == 0 ? '+' : (op == 1 ? '-' : '×');
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Math Challenge'),
          const SizedBox(height: 8),
          Text('$a $opSymbol $b = ?'),
          const SizedBox(height: 8),
          TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Answer')),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _submit, child: const Text('Submit')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel')),
        ]),
      ),
    );
  }
}

class _QuickTargetDialog extends StatefulWidget {
  const _QuickTargetDialog({Key? key}) : super(key: key);

  @override
  State<_QuickTargetDialog> createState() => _QuickTargetDialogState();
}

class _QuickTargetDialogState extends State<_QuickTargetDialog> {
  int _hits = 0;
  int _timeLeft = 10;
  Timer? _timer;
  double _x = 0.5, _y = 0.5;
  final Random _rnd = Random.secure();

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timeLeft = 10;
    _hits = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() {
        _timeLeft--;
        _x = _rnd.nextDouble() * 0.8 + 0.1;
        _y = _rnd.nextDouble() * 0.6 + 0.1;
        if (_timeLeft <= 0) {
          t.cancel();
          Navigator.of(context).pop(_hits);
        }
      });
    });
  }

  void _hit() {
    setState(() => _hits++);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width * 0.8;
    final h = 220.0;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Quick Target'),
          const SizedBox(height: 8),
          Text('Time left: $_timeLeft  •  Hits: $_hits'),
          const SizedBox(height: 8),
          SizedBox(
            width: w,
            height: h,
            child: Stack(children: [
              Positioned.fill(child: Container(color: Colors.grey.shade200)),
              Positioned(
                left: _x * (w - 48),
                top: _y * (h - 48),
                child: GestureDetector(
                  onTap: _hit,
                  child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          color: Colors.red, shape: BoxShape.circle),
                      child: const Center(
                          child: Icon(Icons.adjust, color: Colors.white))),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          TextButton(
              onPressed: () => Navigator.of(context).pop(_hits),
              child: const Text('Finish')),
        ]),
      ),
    );
  }
}

class _TrueFalseBlitzDialog extends StatefulWidget {
  const _TrueFalseBlitzDialog({Key? key}) : super(key: key);

  @override
  State<_TrueFalseBlitzDialog> createState() => _TrueFalseBlitzDialogState();
}

class _TrueFalseBlitzDialogState extends State<_TrueFalseBlitzDialog> {
  final List<_QuizQuestion> _questions = [
    const _QuizQuestion(
        question: 'Smoke rises; stay low to avoid it.',
        options: ['True', 'False'],
        correctIndex: 0,
        points: 20),
    const _QuizQuestion(
        question: 'You should use elevator during a fire.',
        options: ['True', 'False'],
        correctIndex: 1,
        points: 20),
    const _QuizQuestion(
        question: 'Water is always safe to put on any fire.',
        options: ['True', 'False'],
        correctIndex: 1,
        points: 20),
    const _QuizQuestion(
        question: 'Call emergency services if unsure.',
        options: ['True', 'False'],
        correctIndex: 0,
        points: 20),
    const _QuizQuestion(
        question: 'Open windows to clear smoke quickly.',
        options: ['True', 'False'],
        correctIndex: 1,
        points: 20),
  ];
  int _index = 0;
  int _score = 0;

  void _answer(int idx) {
    final q = _questions[_index];
    if (idx == q.correctIndex)
      _score += q.points;
    else
      _score -= 5;
    setState(() {
      _index++;
      if (_index >= _questions.length) {
        Navigator.of(context).pop(_score);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = _questions[_index];
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Blitz ${_index + 1}/${_questions.length}'),
          const SizedBox(height: 8),
          Text(q.question),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            ElevatedButton(
                onPressed: () => _answer(0), child: Text(q.options[0])),
            ElevatedButton(
                onPressed: () => _answer(1), child: Text(q.options[1])),
          ]),
          const SizedBox(height: 8),
          Text('Score: $_score'),
        ]),
      ),
    );
  }
}

class _MatchingPairs16Dialog extends StatefulWidget {
  const _MatchingPairs16Dialog({Key? key}) : super(key: key);

  @override
  State<_MatchingPairs16Dialog> createState() => _MatchingPairs16DialogState();
}

class _MatchingPairs16DialogState extends State<_MatchingPairs16Dialog> {
  final Random _rnd = Random.secure();
  late List<int> _cards; // 0..7 duplicated
  late List<bool> _revealed;
  int _first = -1;
  int _pairsFound = 0;

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    _cards = List.generate(8, (i) => i) + List.generate(8, (i) => i);
    _cards.shuffle(_rnd);
    _revealed = List.filled(16, false);
    _first = -1;
    _pairsFound = 0;
  }

  void _tap(int idx) {
    if (_revealed[idx]) return;
    setState(() {
      _revealed[idx] = true;
      if (_first == -1) {
        _first = idx;
      } else {
        if (_cards[_first] == _cards[idx]) {
          _pairsFound++;
          _first = -1;
          if (_pairsFound == 8) {
            Navigator.of(context).pop(40); // full reward
          }
        } else {
          Future.delayed(const Duration(milliseconds: 600), () {
            setState(() {
              _revealed[_first] = false;
              _revealed[idx] = false;
              _first = -1;
            });
          });
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Wrong pair: -5 pts')));
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Matching Pairs (16) — Find 8 pairs to win 40 pts'),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            itemCount: 16,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8),
            itemBuilder: (context, i) {
              return GestureDetector(
                onTap: () => _tap(i),
                child: Container(
                  decoration: BoxDecoration(
                      color: _revealed[i]
                          ? Colors.blue.shade300
                          : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8)),
                  child: Center(
                      child: _revealed[i]
                          ? Text('${_cards[i]}',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold))
                          : const Icon(Icons.help_outline)),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          TextButton(
              onPressed: () => Navigator.of(context).pop(0),
              child: const Text('Give up')),
        ]),
      ),
    );
  }
}
