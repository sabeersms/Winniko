import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_constants.dart';
import '../models/participant_model.dart';
import '../services/firestore_service.dart';
import 'competition_detail_screen.dart'; // To navigate after joining
import '../widgets/loading_spinner.dart';
import 'terms_and_conditions_screen.dart';

class JoinCompetitionScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userPhone;
  final String? userPhotoUrl;

  const JoinCompetitionScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userPhone,
    this.userPhotoUrl,
  });

  @override
  State<JoinCompetitionScreen> createState() => _JoinCompetitionScreenState();
}

class _JoinCompetitionScreenState extends State<JoinCompetitionScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final firestore = Provider.of<FirestoreService>(context, listen: false);

    // DEBUG DIALOG: Confirm method start
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Debug: Step 1'),
        content: Text(
          'Join Process Started. Code: ${_codeController.text.trim()}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Code must be 6 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch Competition by Code first
      final competition = await firestore.getCompetitionByJoinCode(code);

      if (competition == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Debug: Error'),
            content: const Text('Competition NOT found for this code.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        setState(() => _errorMessage = 'Invalid Code. Competition not found.');
        return;
      }

      if (!mounted) return;

      // DEBUG DIALOG: Show fetched T&C
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Debug: Step 2'),
          content: Text(
            'Competition Found!\nName: ${competition.name}\nT&C Length: ${competition.termsAndConditions?.length ?? 0}\nT&C Content: "${competition.termsAndConditions}"',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      final participant = ParticipantModel(
        userId: widget.userId,
        userName: widget.userName,
        phoneNumber: widget.userPhone,
        photoUrl: widget.userPhotoUrl,
        competitionId: competition.id,
        joinedAt: DateTime.now(),
      );

      // 2. Check for Terms and Conditions
      if (competition.termsAndConditions != null &&
          competition.termsAndConditions!.isNotEmpty) {
        if (!mounted) return;
        setState(() => _isLoading = false);

        // Navigate to T&C Screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TermsAndConditionsScreen(
              competition: competition,
              participant: participant,
            ),
          ),
        );
        return;
      }

      // DEBUG DIALOG: Going to join directly
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Debug: Step 3'),
          content: const Text('No T&C found. Joining directly...'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );

      // 3. If no T&C, join directly
      final competitionId = await firestore.joinCompetitionByCode(
        code,
        participant,
      );

      if (competitionId == null) {
        setState(
          () => _errorMessage = 'Competition not found or error joining.',
        );
        return;
      }

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CompetitionDetailScreen(competitionId: competitionId),
        ),
      );
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Debug: Exception'),
            content: Text(e.toString()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      setState(
        () => _errorMessage = e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(title: const Text('Join Competition')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.group_add,
                size: 80,
                color: AppColors.accentGreen,
              ),
              const SizedBox(height: 32),
              const Text(
                'Enter Join Code',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ask the organizer for the 6-digit code',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _codeController,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  counterText: "",
                  filled: true,
                  fillColor: AppColors.cardBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  hintText: 'CODE',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: AppColors.error),
                ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _join,
                  child: _isLoading
                      ? const LoadingSpinner(
                          size: 24,
                          color: AppColors.textPrimary,
                        )
                      : const Text('Join Now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
