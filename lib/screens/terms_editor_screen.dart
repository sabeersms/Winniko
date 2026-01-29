import 'package:flutter/material.dart';
import 'package:translator/translator.dart';
import '../widgets/loading_spinner.dart';
import '../constants/app_constants.dart';

class TermsEditorScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? initialTerms;
  final String? initialLanguage;

  const TermsEditorScreen({super.key, this.initialTerms, this.initialLanguage});

  @override
  State<TermsEditorScreen> createState() => _TermsEditorScreenState();
}

class _TermsEditorScreenState extends State<TermsEditorScreen> {
  late List<Map<String, dynamic>> _terms;
  final GoogleTranslator _translator = GoogleTranslator();

  String _currentLanguage = 'en';
  bool _isTranslating = false;
  Map<int, Map<String, String>> _translatedCache = {};

  final Map<String, String> _languages = {
    'en': 'English',
    'hi': 'Hindi',
    'ml': 'Malayalam',
    'ta': 'Tamil',
    'te': 'Telugu',
    'kn': 'Kannada',
    'mr': 'Marathi',
    'bn': 'Bengali',
    'gu': 'Gujarati',
    'pa': 'Punjabi',
    'ur': 'Urdu',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialLanguage != null) {
      _currentLanguage = widget.initialLanguage!;
    }

    if (widget.initialTerms != null && widget.initialTerms!.isNotEmpty) {
      _terms = List<Map<String, dynamic>>.from(
        widget.initialTerms!.map((e) => Map<String, dynamic>.from(e)),
      );
    } else {
      _terms = _getDefaultTerms();
    }

    // Auto-translate if initial language is not English
    if (_currentLanguage != 'en') {
      // Post-frame to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _translateTerms(_currentLanguage);
      });
    }
  }

  Future<void> _translateTerms(String targetLang) async {
    if (targetLang == 'en') {
      setState(() {
        _currentLanguage = 'en';
        _translatedCache.clear();
      });
      return;
    }

    setState(() {
      _isTranslating = true;
      _currentLanguage = targetLang;
    });

    try {
      final newCache = <int, Map<String, String>>{};

      // Translate all terms
      for (int i = 0; i < _terms.length; i++) {
        final title = _terms[i]['title'] as String;
        final content = _terms[i]['content'] as String;

        final transTitle = await _translator.translate(title, to: targetLang);
        final transContent = await _translator.translate(
          content,
          to: targetLang,
        );

        newCache[i] = {'title': transTitle.text, 'content': transContent.text};
      }

      if (mounted) {
        setState(() {
          _translatedCache = newCache;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isTranslating = false;
          _currentLanguage = 'en'; // Revert on failure
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Translation failed')));
      }
    }
  }

  List<Map<String, dynamic>> _getDefaultTerms() {
    return [
      {
        'title': 'No Purchase Necessary',
        'content':
            'No purchase or payment of any kind is necessary to enter or win this contest. A purchase will not increase your chances of winning.',
        'isVisible': true,
      },
      {
        'title': 'Sponsorship Disclaimer',
        'content':
            'This contest is organized solely by the competition creator. Apple Inc., Google LLC, and their affiliates are strictly NOT sponsors of, and are in no way involved with, this contest or promotion.',
        'isVisible': true,
      },
      {
        'title': 'Point Logic',
        'content':
            '''Points will be awarded based on the accuracy of predictions as follows:

• Football:
  - Predicting the correct Match Result (Winner or Draw): 3 Points
  - Predicting the Correct Scoreline (in addition to the result): 2 Bonus Points

• Cricket:
  - Predicting the Match Winner: 3 Points
  - Predicting the Correct Winning Margin (Runs or Wickets): 2 Bonus Points
  - Predicting a Draw/Tie correctly: 5 Points (Full points: 3+2)''',
        'isVisible': true,
      },
      {
        'title': 'Identity Verification',
        'content':
            'Participants must register using their legal name and a valid mobile number. The use of fake identities, aliases, or incorrect details is strictly prohibited and will result in immediate disqualification.',
        'isVisible': true,
      },
      {
        'title': 'Proof of Identity',
        'content':
            'The organizers reserve the right to request official government-issued ID proof from shortlisted or winning participants. Failure to provide valid identification upon request will lead to forfeiture of the prize.',
        'isVisible': true,
      },
      {
        'title': 'Eligibility',
        'content':
            'Void where prohibited by law. Participants must be of legal age in their jurisdiction of residence to enter.',
        'isVisible': true,
      },
      {
        'title': 'Event Modifications',
        'content':
            'As this contest may be linked to specific events, the organizers reserve the right to modify, postpone, or cancel the contest rules or the contest itself in the event of changes, delays, or cancellation of the underlying event.',
        'isVisible': true,
      },

      {
        'title': 'Final Authority',
        'content':
            'The decision of the organizers shall be final and binding in all matters related to the contest.',
        'isVisible': true,
      },
    ];
  }

  void _addRule() {
    // allow adding in current language
    _editRule(index: -1, initialTitle: '', initialContent: '');
  }

  void _editRule({
    required int index,
    required String initialTitle,
    required String initialContent,
  }) {
    // Removed forced switch to English

    final titleController = TextEditingController(text: initialTitle);
    final contentController = TextEditingController(text: initialContent);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          index == -1 ? 'Add Rule' : 'Edit Rule',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.accentGreen),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                style: const TextStyle(color: AppColors.textPrimary),
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: AppColors.accentGreen),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (titleController.text.trim().isEmpty) return;

              final newRule = {
                'title': titleController.text.trim(),
                'content': contentController.text.trim(),
                'isVisible': true,
              };

              setState(() {
                if (index == -1) {
                  _terms.add(newRule);
                } else {
                  _terms[index] = {
                    ..._terms[index],
                    'title': newRule['title'],
                    'content': newRule['content'],
                  };
                  // Clear cache for this item so it displays the new (edited) text
                  _translatedCache.remove(index);
                }
              });
              Navigator.pop(context);
            },
            child: const Text(
              'Save',
              style: TextStyle(color: AppColors.accentGreen),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleVisibility(int index) {
    setState(() {
      final item = _terms[index];
      item['isVisible'] = !(item['isVisible'] as bool);
    });
  }

  void _saveAndExit() {
    // Ensure Hidden terms are at the bottom before saving
    final active = _terms.where((t) => t['isVisible'] == true).toList();
    final hidden = _terms.where((t) => t['isVisible'] == false).toList();

    final result = {
      'terms': [...active, ...hidden],
      'language': _currentLanguage,
    };

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    // Separate active and hidden for display
    final activeTerms = _terms
        .asMap()
        .entries
        .where((e) => e.value['isVisible'] == true)
        .toList();
    final hiddenTerms = _terms
        .asMap()
        .entries
        .where((e) => e.value['isVisible'] == false)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        title: const Text('Edit Terms & Conditions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _saveAndExit,
            tooltip: 'Save',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addRule,
        backgroundColor: AppColors.accentGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _isTranslating
          ? const Center(child: LoadingSpinner())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active Terms Section
                  if (activeTerms.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Active Rules',
                            style: TextStyle(
                              color: AppColors.accentGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _currentLanguage,
                              dropdownColor: AppColors.cardBackground,
                              icon: const Icon(
                                Icons.translate,
                                color: AppColors.accentGreen,
                              ),
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                              ),
                              items: _languages.entries.map((e) {
                                return DropdownMenuItem(
                                  value: e.key,
                                  child: Text(e.value),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) _translateTerms(val);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: activeTerms.length,
                      onReorder: (oldIndex, newIndex) {
                        if (oldIndex < newIndex) newIndex -= 1;
                        setState(() {
                          final activeList = _terms
                              .where((t) => t['isVisible'] == true)
                              .toList();
                          final hiddenList = _terms
                              .where((t) => t['isVisible'] == false)
                              .toList();

                          final item = activeList.removeAt(oldIndex);
                          activeList.insert(newIndex, item);

                          _terms = [...activeList, ...hiddenList];
                        });
                      },
                      itemBuilder: (context, index) {
                        final entry = activeTerms[index];
                        final realIndex = entry.key;
                        final rule = entry.value;

                        // Display Translated Text if available, else original
                        final displayTitle =
                            (_currentLanguage != 'en' &&
                                _translatedCache.containsKey(realIndex))
                            ? _translatedCache[realIndex]!['title']!
                            : rule['title'] as String;

                        final displayContent =
                            (_currentLanguage != 'en' &&
                                _translatedCache.containsKey(realIndex))
                            ? _translatedCache[realIndex]!['content']!
                            : rule['content'] as String;

                        return Card(
                          key: ValueKey('active_${rule['title']}_$realIndex'),
                          color: AppColors.cardBackground,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${index + 1}. $displayTitle',
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.visibility,
                                            color: AppColors.accentGreen,
                                          ),
                                          onPressed: () =>
                                              _toggleVisibility(realIndex),
                                          tooltip: 'Hide Rule',
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: AppColors.textPrimary,
                                          ),
                                          onPressed: () => _editRule(
                                            index: realIndex,
                                            initialTitle: displayTitle,
                                            initialContent: displayContent,
                                          ),
                                        ),
                                        // Delete button removed
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(color: AppColors.textSecondary),
                                Text(
                                  displayContent,
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],

                  // Hidden Terms Section
                  if (hiddenTerms.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 32, 16, 8),
                      child: Text(
                        'Hidden Rules',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    ...hiddenTerms.map((entry) {
                      final realIndex = entry.key;
                      final rule = entry.value;

                      // Display Translated Text if available
                      final displayTitle =
                          (_currentLanguage != 'en' &&
                              _translatedCache.containsKey(realIndex))
                          ? _translatedCache[realIndex]!['title']!
                          : rule['title'] as String;

                      return Card(
                        key: ValueKey('hidden_${rule['title']}_$realIndex'),
                        color: AppColors.cardBackground.withValues(alpha: 0.5),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: ListTile(
                          title: Text(
                            displayTitle,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.visibility_off,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () => _toggleVisibility(realIndex),
                                tooltip: 'Show Rule',
                              ),
                              // Delete button removed
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
    );
  }
}
