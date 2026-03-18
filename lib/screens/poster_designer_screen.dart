import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../models/competition_model.dart';
import '../models/match_model.dart';
import '../services/firestore_service.dart';
import '../utils/share_util.dart';
import '../constants/app_constants.dart';
import '../widgets/team_logo.dart';
import '../widgets/loading_spinner.dart';

class PosterDesignerScreen extends StatefulWidget {
  final CompetitionModel competition;
  final MatchModel? initialMatch;

  final bool isResultMode;

  const PosterDesignerScreen({
    super.key,
    required this.competition,
    this.initialMatch,
    this.isResultMode = false,
  });

  @override
  State<PosterDesignerScreen> createState() => _PosterDesignerScreenState();
}

class _PosterDesignerScreenState extends State<PosterDesignerScreen> {
  final GlobalKey _posterKey = GlobalKey();
  final ImagePicker _picker = ImagePicker();

  MatchModel? _selectedMatch;

  // Titles and Toggles
  String _titleTop = 'WINNIKO PRESENTS';
  String _titleMiddle = 'MATCH DAY';
  String _titleBottom = 'SEASON-5';

  String _team1Name = '';
  String _team2Name = '';
  String _posterDate = '';
  String _posterVenue = 'LOCATION';

  bool _showTitleTop = true;
  bool _showTitleMiddle = true;
  bool _showTitleBottom = true;
  bool _showWatermark = true;
  bool _useDualLineTeams = false;
  bool _stretchFooterLogos = false;

  String _team1Prefix = '';
  String _team2Prefix = '';

  String _team1Score = '';
  String _team2Score = '';
  String _matchResult = '';
  String _matchTiedText = '';

  // Font Decoration for Main Heading
  double _titleMiddleFontSize = 44.0;
  bool _titleMiddleItalic = false;
  bool _titleMiddleStroke = false;

  // Controllers for smooth typing
  late TextEditingController _titleTopController;
  late TextEditingController _titleMiddleController;
  late TextEditingController _titleBottomController;
  late TextEditingController _venueController;
  late TextEditingController _dateController;
  late TextEditingController _team1Controller;
  late TextEditingController _team2Controller;
  late TextEditingController _team1PrefixController;
  late TextEditingController _team2PrefixController;

  // Customization
  Color _backgroundColor = const Color(0xFF001F3F);
  Color _accentColor = AppColors.accentGreen;

  dynamic _watermarkLogo;
  final List<dynamic> _footerLogos = [];

  bool _isGenerating = false;
  double _layoutShift = 0.0;
  bool _isFullView = false;
  io.File? _customBgImage;
  String? _selectedBgPreset;
  late bool _isResultMode;

  final List<String> _bgPresets = [
    'assets/images/posters/poster_bg_1.jpg',
    'assets/images/posters/poster_bg_2.jpg',
    'assets/images/posters/poster_bg_3.jpg',
    'assets/images/posters/poster_bg_4.jpg',
    'assets/images/posters/poster_bg_5.jpg',
    'assets/images/posters/poster_bg_6.jpg',
    'assets/images/posters/poster_bg_7.jpg',
    'assets/images/posters/poster_bg_8.jpg',
    'assets/images/posters/poster_bg_9.jpg',
    'assets/images/posters/poster_bg_10.jpg',
    'assets/images/posters/poster_bg_11.jpg',
    'assets/images/posters/poster_bg_12.jpg',
    'assets/images/posters/poster_bg_13.jpg',
    'assets/images/posters/poster_bg_14.jpg',
    'assets/images/posters/poster_bg_15.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _isResultMode = widget.isResultMode;
    _selectedMatch = widget.initialMatch;
    _titleTop = 'WINNIKO PRESENTS';
    _titleMiddle = widget.competition.name.toUpperCase();
    _titleBottom = 'SEASON-5';

    _titleTopController = TextEditingController(text: _titleTop);
    _titleMiddleController = TextEditingController(text: _titleMiddle);
    _titleBottomController = TextEditingController(text: _titleBottom);
    _venueController = TextEditingController(text: _posterVenue);
    _dateController = TextEditingController(text: _posterDate);
    _team1Controller = TextEditingController(text: _team1Name);
    _team2Controller = TextEditingController(text: _team2Name);
    _team1PrefixController = TextEditingController(text: _team1Prefix);
    _team2PrefixController = TextEditingController(text: _team2Prefix);

    if (_selectedMatch != null) {
      _updateDetailsFromMatch(_selectedMatch!);
    }
  }

  @override
  void dispose() {
    _titleTopController.dispose();
    _titleMiddleController.dispose();
    _titleBottomController.dispose();
    _venueController.dispose();
    _dateController.dispose();
    _team1Controller.dispose();
    _team2Controller.dispose();
    _team1PrefixController.dispose();
    _team2PrefixController.dispose();
    super.dispose();
  }

  void _updateDetailsFromMatch(MatchModel match) {
    _posterDate = DateFormat(
      'EEEE, MMM d • h:mm a',
    ).format(match.scheduledTime);
    _posterVenue = (match.location != null && match.location!.isNotEmpty)
        ? match.location!
        : 'LOCATION';
    _team1Name = match.team1Name;
    _team2Name = match.team2Name;

    if (widget.competition.sport == AppConstants.sportCricket) {
      _team1Score = match.actualScore?['t1Runs'] != null
          ? '${match.actualScore!['t1Runs']}/${match.actualScore!['t1Wickets'] ?? 0}'
          : '';
      _team2Score = match.actualScore?['t2Runs'] != null
          ? '${match.actualScore!['t2Runs']}/${match.actualScore!['t2Wickets'] ?? 0}'
          : '';
    } else {
      _team1Score = match.actualScore?['team1']?.toString() ?? '';
      _team2Score = match.actualScore?['team2']?.toString() ?? '';
    }

    String? rawWinnerId = match.winnerId;
    if ((rawWinnerId == null || rawWinnerId.isEmpty) &&
        match.actualScore != null) {
      rawWinnerId = match.actualScore!['winnerId']?.toString();
    }

    // Determine if scores are equal or it's a tie-breaker situation
    bool isScoreEqual = false;
    if (match.actualScore != null) {
      if (widget.competition.sport == AppConstants.sportCricket) {
        int t1r =
            int.tryParse(match.actualScore!['t1Runs']?.toString() ?? '0') ?? 0;
        int t2r =
            int.tryParse(match.actualScore!['t2Runs']?.toString() ?? '0') ?? 0;
        isScoreEqual = (t1r == t2r && t1r > 0);
      } else {
        int s1 =
            int.tryParse(match.actualScore!['team1']?.toString() ?? '0') ?? 0;
        int s2 =
            int.tryParse(match.actualScore!['team2']?.toString() ?? '0') ?? 0;
        isScoreEqual = (s1 == s2);
      }
    }

    String? tbwId = match.actualScore?['tieBreakerWinnerId']?.toString();
    if (tbwId == null || tbwId.isEmpty) {
      tbwId = match.actualScore?['superOverWinnerId']?.toString();
    }
    if (tbwId == null || tbwId.isEmpty) {
      tbwId = match.actualScore?['shootoutWinnerId']?.toString();
    }
    if (tbwId == null || tbwId.isEmpty) {
      tbwId = match.actualScore?['tie_breaker_winner_id']?.toString();
    }

    // Capture specific tie-breaker winner if it exists from dedicated fields
    bool hasSpecialTBW = (tbwId != null && tbwId.isNotEmpty && tbwId != 'tied' && tbwId != 'draw' && tbwId != 'no_result');

    if (hasSpecialTBW) {
      isScoreEqual = true;
    }
    
    // Also treat 'tied' / 'draw' winner status as an equal score branch
    if (rawWinnerId == 'tied' || rawWinnerId == 'draw') {
      isScoreEqual = true;
    }

    if (isScoreEqual && (tbwId == null || tbwId.isEmpty || tbwId == 'tied' || tbwId == 'draw')) {
      // backup check: only if scores are equal, we check if winnerId is a team (legacy/custom tie-breaker storage)
      if (rawWinnerId != null &&
          rawWinnerId != 'tied' &&
          rawWinnerId != 'no_result' &&
          rawWinnerId != 'draw') {
        tbwId = rawWinnerId;
      }
    }
    String? resolveWinnerName(String? wId) {
      if (wId == null || (wId.trim().isEmpty)) return wId;
      if (wId == 'no_result') return wId;
      
      String cleanWId = wId.trim().toLowerCase();
      bool isGenericTie = (cleanWId == 'tied' || cleanWId == 'draw');
      // Handle cases where the ID might have a suffix like " WON S/O"
      if (cleanWId.contains(' ')) {
        cleanWId = cleanWId.split(' ')[0];
      }
      
      String cleanT1Id = match.team1Id.trim().toLowerCase();
      String cleanT2Id = match.team2Id.trim().toLowerCase();
      
      // Normalize all strings for comparison
      String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      
      final nWId = norm(cleanWId);
      final nT1Id = norm(cleanT1Id);
      final nT2Id = norm(cleanT2Id);
      final nT1Name = norm(_team1Name);
      final nT2Name = norm(_team2Name);
      final nMatchT1Name = norm(match.team1Name);
      final nMatchT2Name = norm(match.team2Name);

      // --- STAGE 1: Direct Matching ---
      // 1. Precise or fuzzy ID match
      if (nWId == nT1Id || (nT1Id.length > 5 && nWId.contains(nT1Id)) || (nWId.length > 5 && nT1Id.contains(nWId))) return _team1Name;
      if (nWId == nT2Id || (nT2Id.length > 5 && nWId.contains(nT2Id)) || (nWId.length > 5 && nT2Id.contains(nWId))) return _team2Name;

      // 2. Name-based match (sometimes ID is a slug/name)
      if (nWId == nT1Name || (nT1Name.length > 3 && (nWId.contains(nT1Name) || nT1Name.contains(nWId)))) return _team1Name;
      if (nWId == nT2Name || (nT2Name.length > 3 && (nWId.contains(nT2Name) || nT2Name.contains(nWId)))) return _team2Name;
      if (nWId == nMatchT1Name || (nMatchT1Name.length > 3 && (nWId.contains(nMatchT1Name) || nMatchT1Name.contains(nWId)))) return _team1Name;
      if (nWId == nMatchT2Name || (nMatchT2Name.length > 3 && (nWId.contains(nMatchT2Name) || nMatchT2Name.contains(nWId)))) return _team2Name;

      // --- STAGE 2: Metadata Check (skip if value is 'tied'/'draw') ---
      if (match.actualScore != null) {
        final wn = match.actualScore!['winnerName']?.toString();
        if (wn != null && wn.toLowerCase() != 'tied' && wn.toLowerCase() != 'draw') return wn;
        final wn2 = match.actualScore!['winner_name']?.toString();
        if (wn2 != null && wn2.toLowerCase() != 'tied' && wn2.toLowerCase() != 'draw') return wn2;
      }

      // --- STAGE 3: Cross-Reference with Root Winner ---
      // If wId is a UUID that doesn't match team IDs, check if match.winnerId resolves better
      final rwId = match.winnerId?.trim().toLowerCase();
      if (rwId != null && rwId != 'tied' && rwId != 'draw' && rwId != cleanWId) {
        final nrwId = norm(rwId);
        if (nrwId == nT1Id || (nT1Id.length > 5 && (nrwId.contains(nT1Id) || nT1Id.contains(nrwId)))) return _team1Name;
        if (nrwId == nT2Id || (nT2Id.length > 5 && (nrwId.contains(nT2Id) || nT2Id.contains(nrwId)))) return _team2Name;
        if (nrwId == nT1Name || nrwId == nMatchT1Name) return _team1Name;
        if (nrwId == nT2Name || nrwId == nMatchT2Name) return _team2Name;
      }

      // --- STAGE 4: Score Inference (Highest Reliability for Finished Matches) ---
      if (match.actualScore != null) {
        if (widget.competition.sport == AppConstants.sportCricket) {
          final t1Runs = int.tryParse(match.actualScore!['t1Runs']?.toString() ?? '0') ?? 0;
          final t2Runs = int.tryParse(match.actualScore!['t2Runs']?.toString() ?? '0') ?? 0;
          if (t1Runs != t2Runs && t1Runs > 0 && t2Runs > 0) {
            return t1Runs > t2Runs ? _team1Name : _team2Name;
          }
        } else {
          final s1 = int.tryParse(match.actualScore!['team1']?.toString() ?? '0') ?? 0;
          final s2 = int.tryParse(match.actualScore!['team2']?.toString() ?? '0') ?? 0;
          if (s1 != s2 && (s1 > 0 || s2 > 0)) {
            return s1 > s2 ? _team1Name : _team2Name;
          }
        }
      }

      // --- STAGE 5: Result Text Search (Final Effort for Official Matches) ---
      final resTextRaw = match.actualScore?['result']?.toString().toLowerCase() ?? 
                      match.actualScore?['status']?.toString().toLowerCase() ?? '';
      if (resTextRaw.isNotEmpty && (resTextRaw.contains('won') || resTextRaw.contains('win') || resTextRaw.contains('winner'))) {
        final nRes = norm(resTextRaw);
        if (nRes.contains(nT1Name) || (nT1Name.length > 3 && nRes.contains(nT1Name))) return _team1Name;
        if (nRes.contains(nT2Name) || (nT2Name.length > 3 && nRes.contains(nT2Name))) return _team2Name;
        if (nRes.contains(nMatchT1Name) || (nMatchT1Name.length > 3 && nRes.contains(nMatchT1Name))) return _team1Name;
        if (nRes.contains(nMatchT2Name) || (nMatchT2Name.length > 3 && nRes.contains(nMatchT2Name))) return _team2Name;
      }

      if (isGenericTie) return cleanWId; // Fallback to "tied"/"draw" if result text search failed

      // 6. Final fallback: If it's a long UUID and we still can't match it,
      // map it to Team 1 to avoid a code, but this is a last resort.
      if (wId.contains('-')) return _team1Name;

      return wId;
    }


    if (rawWinnerId != null && rawWinnerId.isNotEmpty) {
      if (rawWinnerId == 'no_result') {
        _matchResult = "NO RESULT";
        _matchTiedText = '';
      } else if (isScoreEqual) {
        // Scores are equal - show MATCH TIED in center area
        _matchTiedText = (widget.competition.sport.toLowerCase().contains('cricket')) ? 'MATCH TIED' : 'DRAW';

        // Check for tie-breaker winner for the bottom pill
        final String winnerNameOrId = tbwId ?? rawWinnerId;
        String? winnerName = resolveWinnerName(winnerNameOrId);
        
        // Also try direct ID matching as fallback
        if (winnerName == null || winnerName == 'tied' || winnerName == 'draw' || winnerName == 'no_result') {
          if (winnerNameOrId == match.team1Id || winnerNameOrId.toLowerCase() == match.team1Id.toLowerCase()) {
            winnerName = _team1Name;
          } else if (winnerNameOrId == match.team2Id || winnerNameOrId.toLowerCase() == match.team2Id.toLowerCase()) {
            winnerName = _team2Name;
          }
        }
        
        if (winnerName != null && winnerName != 'tied' && winnerName != 'draw' && winnerName != 'no_result') {
          final String tieBreakerSuffix = widget.competition.sport.toLowerCase().contains('football') ? 'P/K' : 'S/O';
          _matchResult = "$winnerName WON BY $tieBreakerSuffix".toUpperCase();
        } else {
          _matchResult = ''; // No winner to show in bottom pill
        }
      } else if (rawWinnerId == 'tied') {
        _matchTiedText = 'MATCH TIED';
        _matchResult = '';
      } else if (rawWinnerId == 'draw') {
        _matchTiedText = 'DRAW';
        _matchResult = '';
      } else {
        _matchTiedText = '';
        String winnerName = resolveWinnerName(rawWinnerId) ?? rawWinnerId;

        _matchResult = "$winnerName WON".toUpperCase();

        final scoreData = match.actualScore;
        if (scoreData != null &&
            widget.competition.sport == AppConstants.sportCricket) {
          String type = scoreData['marginType']?.toString().toLowerCase() ?? '';
          String val = scoreData['marginValue']?.toString() ?? '';

          if (type == 'runs') {
            final t1r =
                int.tryParse(scoreData['t1Runs']?.toString() ?? '0') ?? 0;
            final t2r =
                int.tryParse(scoreData['t2Runs']?.toString() ?? '0') ?? 0;
            final diff = (t1r - t2r).abs();
            final marginVal = (val.isNotEmpty && val != '?')
                ? val
                : diff.toString();
            if (marginVal != '0') {
              String runText = (marginVal == '1') ? "RUN" : "RUNS";
              _matchResult = "$winnerName WON BY $marginVal $runText".toUpperCase();
            }
          } else if (type == 'wickets' || type == 'wicket') {
            final t1w =
                int.tryParse(scoreData['t1Wickets']?.toString() ?? '0') ?? 0;
            final t2w =
                int.tryParse(scoreData['t2Wickets']?.toString() ?? '0') ?? 0;
            final winnerWkts = (rawWinnerId == match.team1Id) ? t1w : t2w;
            final wLeft = (10 - winnerWkts).clamp(0, 10);
            final marginVal = (val.isNotEmpty && val != '?')
                ? val
                : wLeft.toString();
            if (marginVal != '0') {
              String wicketText = (marginVal == '1') ? "WICKET" : "WICKETS";
              _matchResult = "$winnerName WON BY $marginVal $wicketText"
                  .toUpperCase();
            }
          } else if (type.isNotEmpty && val.isNotEmpty && val != '?') {
            _matchResult = "$winnerName WON BY $val ${type.toUpperCase()}"
                .toUpperCase();
          }
        }
      }
    } else {
      _matchResult = "";
      _matchTiedText = '';
    }

    _titleBottom = 'SEASON-5';

    // Update controllers to match new data
    _titleBottomController.text = _titleBottom;
    _venueController.text = _posterVenue;
    _dateController.text = _posterDate;
    _team1Controller.text = _team1Name;
    _team2Controller.text = _team2Name;
  }

  @override
  Widget build(BuildContext context) {
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Poster Designer'),
        actions: [
          IconButton(
            icon: Icon(_isFullView ? Icons.edit : Icons.fullscreen),
            tooltip: _isFullView ? 'Edit' : 'Full Preview',
            onPressed: () => setState(() => _isFullView = !_isFullView),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Preview Area
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black12,
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: GestureDetector(
                    onVerticalDragUpdate: (details) {
                      setState(() {
                        // Downward drag (positive delta) moves content down
                        _layoutShift =
                            (_layoutShift + (details.primaryDelta! / 300))
                                .clamp(0.0, 1.0);
                      });
                    },
                    child: RepaintBoundary(
                      key: _posterKey,
                      child: _buildPosterPreview(),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 2. Controls Area
          if (!_isFullView)
            Expanded(
              flex: 2,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: DefaultTabController(
                  length: 3,
                  child: Column(
                    children: [
                      const TabBar(
                        indicatorColor: AppColors.accentGreen,
                        labelColor: AppColors.accentGreen,
                        unselectedLabelColor: AppColors.textSecondary,
                        tabs: [
                          Tab(text: 'Match'),
                          Tab(text: 'Style'),
                          Tab(text: 'Logos'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildMatchSettings(firestore),
                            _buildStyleSettings(),
                            _buildLogoSettings(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: ElevatedButton.icon(
            onPressed: _selectedMatch == null || _isGenerating
                ? null
                : _exportPoster,
            icon: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.download),
            label: Text(
              _isGenerating ? 'Generating...' : 'Save & Share Poster',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGreen,
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPosterPreview() {
    if (_selectedMatch == null) {
      return Container(
        width: 320,
        height: 400,
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: const Center(
          child: Text(
            'Select a match to preview',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }

    // Pro Cinematic Template enforce 5:7
    return AspectRatio(
      aspectRatio: 5 / 7,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(
            12,
          ), // Reduced for more "full" feel
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Stack(
          children: [
            // 1. Background Layer (Image or Gradient)
            if (_customBgImage != null || _selectedBgPreset != null)
              Positioned.fill(
                child: _customBgImage != null
                    ? Image.file(_customBgImage!, fit: BoxFit.cover)
                    : _selectedBgPreset!.startsWith('assets/')
                    ? Image.asset(_selectedBgPreset!, fit: BoxFit.cover)
                    : Image.network(_selectedBgPreset!, fit: BoxFit.cover),
              ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.3),
                      _backgroundColor.withOpacity(0.4),
                      _backgroundColor.withOpacity(0.9),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Main Content
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 4.0,
                vertical: 20.0,
              ), // Minimized horizontal padding
              child: Center(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 500, // Matches 5:7 ratio with height 700
                    height: 700,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 12),
                        if (_showWatermark) _buildPosterHeader(),

                        // 1. Dynamic Top Spacer
                        Spacer(flex: (_layoutShift * 100).toInt() + 1),

                        // 2. MAIN MATTER BLOCK
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Multi-Row Cinematic Heading
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (_showTitleTop)
                                  Stack(
                                    children: [
                                      Text(
                                        _titleTop.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 5,
                                          foreground: Paint()
                                            ..style = PaintingStyle.stroke
                                            ..strokeWidth = 3
                                            ..color = Colors.black,
                                        ),
                                      ),
                                      Text(
                                        _titleTop.toUpperCase(),
                                        style: TextStyle(
                                          color: _accentColor,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 5,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (_showTitleMiddle)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        if (_titleMiddleStroke)
                                          Text(
                                            _titleMiddle.toUpperCase(),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: _titleMiddleFontSize,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 2,
                                              height: 1,
                                              fontStyle: _titleMiddleItalic
                                                  ? FontStyle.italic
                                                  : FontStyle.normal,
                                              foreground: Paint()
                                                ..style = PaintingStyle.stroke
                                                ..strokeWidth = 6
                                                ..color = _accentColor,
                                            ),
                                          ),
                                        Text(
                                          _titleMiddle.toUpperCase(),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: _titleMiddleFontSize,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2,
                                            height: 1,
                                            fontStyle: _titleMiddleItalic
                                                ? FontStyle.italic
                                                : FontStyle.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (_showTitleBottom)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _accentColor.withOpacity(0.9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      _titleBottom.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 4,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Team Logos
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildTeamPedestal(
                                      _selectedMatch!.team1LogoUrl,
                                      _team1Name,
                                    ),
                                    if (_isResultMode &&
                                        widget.competition.sport ==
                                            AppConstants.sportCricket &&
                                        _team1Score.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        _team1Score,
                                        style: TextStyle(
                                          color: _accentColor,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Text(
                                          _posterDate.contains('•')
                                              ? _posterDate
                                                    .split('•')[0]
                                                    .trim()
                                                    .toUpperCase()
                                              : _posterDate.toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2,
                                            foreground: Paint()
                                              ..style = PaintingStyle.stroke
                                              ..strokeWidth = 3
                                              ..color = Colors.black,
                                          ),
                                        ),
                                        Text(
                                          _posterDate.contains('•')
                                              ? _posterDate
                                                    .split('•')[0]
                                                    .trim()
                                                    .toUpperCase()
                                              : _posterDate.toUpperCase(),
                                          style: TextStyle(
                                            color: _accentColor,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Text(
                                          _posterDate.contains('•')
                                              ? _posterDate
                                                    .split('•')[1]
                                                    .trim()
                                                    .toUpperCase()
                                              : 'LIVE',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1,
                                            foreground: Paint()
                                              ..style = PaintingStyle.stroke
                                              ..strokeWidth = 4
                                              ..color = Colors.black,
                                          ),
                                        ),
                                        Text(
                                          _posterDate.contains('•')
                                              ? _posterDate
                                                    .split('•')[1]
                                                    .trim()
                                                    .toUpperCase()
                                              : 'LIVE',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                    // Show MATCH TIED under date/time
                                    if (_isResultMode && _matchTiedText.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          _matchTiedText.toUpperCase(),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildTeamPedestal(
                                      _selectedMatch!.team2LogoUrl,
                                      _team2Name,
                                    ),
                                    if (_isResultMode &&
                                        widget.competition.sport ==
                                            AppConstants.sportCricket &&
                                        _team2Score.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        _team2Score,
                                        style: TextStyle(
                                          color: _accentColor,
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            // Scoreboard
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  height: 64,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: _accentColor.withOpacity(0.6),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: _accentColor.withOpacity(0.2),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(11),
                                    child: Stack(
                                      children: [
                                        Positioned.fill(
                                          child: Opacity(
                                            opacity: 0.15,
                                            child: CustomPaint(
                                              painter: DiagonalStripesPainter(),
                                            ),
                                          ),
                                        ),
                                        Positioned.fill(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.white.withOpacity(
                                                    0.12,
                                                  ),
                                                  Colors.transparent,
                                                  Colors.black.withOpacity(0.3),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Flexible(
                                                    child:
                                                        _buildTeamNameDisplay(
                                                          _team1Prefix,
                                                          _team1Name,
                                                          fontSize: 18,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            ClipPath(
                                              clipper: PrismClipper(),
                                              child: Container(
                                                width: 110,
                                                height: double.infinity,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                    colors: [
                                                      _accentColor,
                                                      _accentColor.withOpacity(
                                                        0.8,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                alignment: Alignment.center,
                                                child: Text(
                                                  _isResultMode &&
                                                          widget
                                                                  .competition
                                                                  .sport !=
                                                              AppConstants
                                                                  .sportCricket &&
                                                          _team1Score
                                                              .isNotEmpty &&
                                                          _team2Score.isNotEmpty
                                                      ? '$_team1Score - $_team2Score'
                                                      : 'VS',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.w900,
                                                    fontStyle: FontStyle.italic,
                                                    letterSpacing: -1.0,
                                                    shadows: [
                                                      Shadow(
                                                        color: Colors.black45,
                                                        offset: Offset(2, 2),
                                                        blurRadius: 4,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Flexible(
                                                    child:
                                                        _buildTeamNameDisplay(
                                                          _team2Prefix,
                                                          _team2Name,
                                                          fontSize: 18,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_isResultMode &&
                                    _matchResult.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _accentColor,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: _accentColor.withOpacity(0.3),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      _matchResult,
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Venue
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: _accentColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 4),
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Text(
                                      _posterVenue.toUpperCase(),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2.0,
                                        fontSize: 18,
                                        foreground: Paint()
                                          ..style = PaintingStyle.stroke
                                          ..strokeWidth = 3
                                          ..color = Colors.black,
                                      ),
                                    ),
                                    Text(
                                      _posterVenue.toUpperCase(),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2.0,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),

                        // 3. Dynamic Bottom Spacer
                        Spacer(flex: ((1.0 - _layoutShift) * 100).toInt() + 1),

                        // Footer
                        _buildPosterFooterLogos(),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamNameDisplay(
    String prefix,
    String name, {
    double fontSize = 14,
  }) {
    if (!_useDualLineTeams || prefix.isEmpty) {
      return Text(
        name.toUpperCase(),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          prefix.toUpperCase(),
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: fontSize * 0.65,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        Text(
          name.toUpperCase(),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize - 1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _buildTeamPedestal(String? logoUrl, String name) {
    return Container(
      width: 80, // Reduced from 100
      height: 80, // Reduced from 100
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _accentColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.4),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: TeamLogo(url: logoUrl, teamName: name, size: 70),
      ),
    );
  }

  Widget _buildPosterHeader() {
    if (_watermarkLogo != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _watermarkLogo is io.File
            ? Image.file(_watermarkLogo as io.File, height: 60)
            : Image.asset('assets/images/app_logo.png', height: 60),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset('assets/images/app_logo.png', height: 60),
    );
  }

  Widget _buildPosterFooterLogos() {
    if (_footerLogos.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sports_soccer, color: Colors.white38, size: 14),
            SizedBox(width: 8),
            Text(
              'POWERED BY WINNIKO',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      );
    }

    final count = _footerLogos.length;
    // Adaptive sizing: More generous sizes

    return LayoutBuilder(
      builder: (context, constraints) {
        // Unified horizontal box for maximum comfort in a single row
        return Container(
          width: double.infinity,
          height: 85, // Fixed high-impact height for horizontal view
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (count == 1) const Spacer(flex: 1),
              ..._footerLogos.map((logo) {
                return Expanded(
                  flex: (count == 1) ? 2 : 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Center(
                      child: logo is io.File
                          ? Image.file(
                              logo,
                              fit: _stretchFooterLogos
                                  ? BoxFit.fill
                                  : BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            )
                          : const Icon(
                              Icons.image,
                              color: Colors.white24,
                              size: 30,
                            ),
                    ),
                  ),
                );
              }).toList(),
              if (count == 1) const Spacer(flex: 1),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMatchSettings(FirestoreService firestore) {
    return StreamBuilder<List<MatchModel>>(
      stream: firestore.getMatches(widget.competition.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: LoadingSpinner());
        final matches = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Choose Match',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: matches.length,
                itemBuilder: (context, index) {
                  final match = matches[index];
                  final isSelected = _selectedMatch?.id == match.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedMatch = match;
                        _updateDetailsFromMatch(match);
                      });
                    },
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accentGreen.withOpacity(0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.accentGreen
                              : Colors.white10,
                        ),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${match.team1Name} vs ${match.team2Name}',
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM d').format(match.scheduledTime),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _buildHeadingInput(
              'Heading (Top Row)',
              _titleTopController,
              (v) => _titleTop = v,
              _showTitleTop,
              (v) => _showTitleTop = v!,
            ),
            const SizedBox(height: 12),
            _buildHeadingInput(
              'Heading (Main Row)',
              _titleMiddleController,
              (v) => _titleMiddle = v,
              _showTitleMiddle,
              (v) => _showTitleMiddle = v!,
            ),
            const SizedBox(height: 12),
            _buildHeadingInput(
              'Heading (Bottom Row)',
              _titleBottomController,
              (v) => _titleBottom = v,
              _showTitleBottom,
              (v) => _showTitleBottom = v!,
            ),
            const SizedBox(height: 16),
            _buildSectionTitle('Main Heading Style'),
            Row(
              children: [
                const Text(
                  'Size',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                Expanded(
                  child: Slider(
                    value: _titleMiddleFontSize,
                    min: 20,
                    max: 80,
                    activeColor: _accentColor,
                    onChanged: (v) => setState(() => _titleMiddleFontSize = v),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                FilterChip(
                  label: const Text('Italic'),
                  selected: _titleMiddleItalic,
                  onSelected: (v) => setState(() => _titleMiddleItalic = v),
                  selectedColor: _accentColor.withOpacity(0.3),
                  checkmarkColor: _accentColor,
                ),
                FilterChip(
                  label: const Text('Accent Stroke'),
                  selected: _titleMiddleStroke,
                  onSelected: (v) => setState(() => _titleMiddleStroke = v),
                  selectedColor: _accentColor.withOpacity(0.3),
                  checkmarkColor: _accentColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _venueController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Location / Venue'),
              onChanged: (v) => setState(() => _posterVenue = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dateController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Date & Time Text'),
              onChanged: (v) => setState(() => _posterDate = v),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Dual-Line Team Names',
                style: TextStyle(color: Colors.white, fontSize: 13),
              ),
              subtitle: const Text(
                'Top small font, bottom big font',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
              value: _useDualLineTeams,
              onChanged: (v) => setState(() => _useDualLineTeams = v),
              activeColor: AppColors.accentGreen,
            ),
            if (_useDualLineTeams) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _team1PrefixController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Team 1 Prefix',
                      ),
                      onChanged: (v) => setState(() => _team1Prefix = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _team2PrefixController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Team 2 Prefix',
                      ),
                      onChanged: (v) => setState(() => _team2Prefix = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _team1Controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Team 1 Name'),
                    onChanged: (v) => setState(() => _team1Name = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _team2Controller,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: 'Team 2 Name'),
                    onChanged: (v) => setState(() => _team2Name = v),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStyleSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Poster Type'),
        Row(
          children: [
            _buildTypeOption('Match Poster', false),
            const SizedBox(width: 12),
            _buildTypeOption('Result Poster', true),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Background Layout'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Custom Upload
              GestureDetector(
                onTap: () async {
                  final XFile? img = await _picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (img != null) {
                    setState(() {
                      _customBgImage = io.File(img.path);
                      _selectedBgPreset = null;
                    });
                  }
                },
                child: Container(
                  width: 60,
                  height: 60,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(Icons.add_a_photo, color: Colors.white70),
                ),
              ),
              // Clear BG
              _buildColorOption(
                null,
                _selectedBgPreset == null && _customBgImage == null,
                onTap: () => setState(() {
                  _selectedBgPreset = null;
                  _customBgImage = null;
                }),
                child: const Icon(Icons.block, color: Colors.white, size: 16),
              ),
              // Presets
              ..._bgPresets.map((url) {
                final isSelected = _selectedBgPreset == url;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedBgPreset = url;
                    _customBgImage = null;
                  }),
                  child: Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(color: AppColors.accentGreen, width: 2)
                          : null,
                      image: DecorationImage(
                        image: url.startsWith('assets/')
                            ? AssetImage(url) as ImageProvider
                            : NetworkImage(url),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Primary Theme Color'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildColorOption(
                const Color(0xFF001F3F),
                _backgroundColor == const Color(0xFF001F3F),
              ),
              _buildColorOption(
                const Color(0xFF1B5E20),
                _backgroundColor == const Color(0xFF1B5E20),
              ),
              _buildColorOption(
                const Color(0xFF85144b),
                _backgroundColor == const Color(0xFF85144b),
              ),
              _buildColorOption(
                const Color(0xFF111111),
                _backgroundColor == const Color(0xFF111111),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Accent Color'),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildColorOption(
                AppColors.accentGreen,
                _accentColor == AppColors.accentGreen,
                onTap: () =>
                    setState(() => _accentColor = AppColors.accentGreen),
              ),
              _buildColorOption(
                Colors.amber,
                _accentColor == Colors.amber,
                onTap: () => setState(() => _accentColor = Colors.amber),
              ),
              _buildColorOption(
                Colors.blueAccent,
                _accentColor == Colors.blueAccent,
                onTap: () => setState(() => _accentColor = Colors.blueAccent),
              ),
              _buildColorOption(
                const Color(0xFFFF5252), // Crimson Red
                _accentColor == const Color(0xFFFF5252),
                onTap: () =>
                    setState(() => _accentColor = const Color(0xFFFF5252)),
              ),
              _buildColorOption(
                const Color(0xFF00E5FF), // Electric Cyan
                _accentColor == const Color(0xFF00E5FF),
                onTap: () =>
                    setState(() => _accentColor = const Color(0xFF00E5FF)),
              ),
              _buildColorOption(
                const Color(0xFFFFAB40), // Deep Orange
                _accentColor == const Color(0xFFFFAB40),
                onTap: () =>
                    setState(() => _accentColor = const Color(0xFFFFAB40)),
              ),
              _buildColorOption(
                const Color(0xFFE040FB), // Neon Purple
                _accentColor == const Color(0xFFE040FB),
                onTap: () =>
                    setState(() => _accentColor = const Color(0xFFE040FB)),
              ),
              _buildColorOption(
                const Color(0xFFE0E0E0), // Ice Silver
                _accentColor == const Color(0xFFE0E0E0),
                onTap: () =>
                    setState(() => _accentColor = const Color(0xFFE0E0E0)),
              ),
              _buildColorOption(
                const Color(0xFFFF4081), // Hot Pink
                _accentColor == const Color(0xFFFF4081),
                onTap: () =>
                    setState(() => _accentColor = const Color(0xFFFF4081)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildSectionTitle('Content Position'),
        Row(
          children: [
            const Icon(
              Icons.vertical_align_top,
              color: Colors.white38,
              size: 20,
            ),
            Expanded(
              child: Slider(
                value: _layoutShift,
                onChanged: (v) => setState(() => _layoutShift = v),
                activeColor: _accentColor,
                inactiveColor: Colors.white10,
              ),
            ),
            const Icon(
              Icons.vertical_align_bottom,
              color: Colors.white38,
              size: 20,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeadingInput(
    String label,
    TextEditingController controller,
    Function(String) onTyped,
    bool visible,
    Function(bool?) onToggle,
  ) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            style: TextStyle(color: visible ? Colors.white : Colors.white24),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: TextStyle(
                color: visible ? AppColors.accentGreen : Colors.white24,
              ),
            ),
            enabled: visible,
            onChanged: (v) => setState(() => onTyped(v)),
          ),
        ),
        Checkbox(
          value: visible,
          onChanged: (v) => setState(() => onToggle(v)),
          activeColor: AppColors.accentGreen,
        ),
      ],
    );
  }

  Widget _buildTypeOption(String label, bool value) {
    final isSelected = _isResultMode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isResultMode = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.accentGreen.withOpacity(0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.accentGreen : Colors.white10,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.accentGreen : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildColorOption(
    Color? color,
    bool isSelected, {
    VoidCallback? onTap,
    Widget? child,
  }) {
    return GestureDetector(
      onTap: onTap ?? () => setState(() => _backgroundColor = color!),
      child: Container(
        width: 50,
        height: 50,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: color ?? Colors.white10,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white12,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: (color ?? Colors.white).withOpacity(0.3),
                blurRadius: 10,
              ),
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildLogoSettings() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Corner Logo (Watermark)',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            Switch(
              value: _showWatermark,
              onChanged: (v) => setState(() => _showWatermark = v),
              activeColor: AppColors.accentGreen,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            GestureDetector(
              onTap: _pickWatermark,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: _watermarkLogo == null
                    ? const Icon(Icons.add_a_photo, color: Colors.white24)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: _watermarkLogo is io.File
                            ? Image.file(
                                _watermarkLogo as io.File,
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.image),
                      ),
              ),
            ),
            if (_watermarkLogo != null)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () => setState(() => _watermarkLogo = null),
              ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Footer Logos / Sponsors (Max 4)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Equal sized boxes with stretch option',
                  style: TextStyle(color: Colors.white38, fontSize: 10),
                ),
              ],
            ),
            Row(
              children: [
                const Text(
                  'Stretch',
                  style: TextStyle(color: Colors.white54, fontSize: 10),
                ),
                Switch(
                  value: _stretchFooterLogos,
                  onChanged: (v) => setState(() => _stretchFooterLogos = v),
                  activeColor: AppColors.accentGreen,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (int i = 0; i < _footerLogos.length; i++)
              Stack(
                children: [
                  Container(
                    width: 80,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: _footerLogos[i] is io.File
                          ? Image.file(
                              _footerLogos[i] as io.File,
                              fit: _stretchFooterLogos
                                  ? BoxFit.fill
                                  : BoxFit.contain,
                            )
                          : const Icon(Icons.image),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _footerLogos.removeAt(i)),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomLeft: Radius.circular(8),
                          ),
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            if (_footerLogos.length < 4)
              GestureDetector(
                onTap: _pickFooterLogo,
                child: Container(
                  width: 80,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Icon(Icons.add, color: Colors.white24),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickWatermark() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _watermarkLogo = io.File(image.path);
      });
    }
  }

  Future<void> _pickFooterLogo() async {
    final List<XFile> images = await _picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        for (var image in images) {
          if (_footerLogos.length < 4) {
            _footerLogos.add(io.File(image.path));
          }
        }
      });
    }
  }

  Future<void> _exportPoster() async {
    setState(() => _isGenerating = true);
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;

      await ShareUtil.shareWidgetAsImage(
        key: _posterKey,
        fileName:
            'winniko_poster_${_selectedMatch?.matchNumber ?? DateTime.now().millisecondsSinceEpoch}',
        text: 'Join the excitement of ${widget.competition.name} on Winniko!',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}

class DiagonalStripesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..strokeWidth = 2;

    const double gap = 15;
    for (double i = -size.height; i < size.width; i += gap) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class PrismClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.moveTo(size.width * 0.15, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width * 0.85, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
