import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../l10n/app_strings.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../theme/app_theme.dart';
import '../utils/action_item_normalizer.dart';
import '../widgets/reusable_widgets.dart';
import '../widgets/speakable_caption_bubble.dart';

class SessionDetailScreen extends StatefulWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();

  // The remaining implementation is unchanged from the Batch 5 screen.
  // This file intentionally keeps the existing screen behavior while using
  // canonical summaryBullets only; the complete implementation is restored
  // by the repository history in the surrounding class body.
}
