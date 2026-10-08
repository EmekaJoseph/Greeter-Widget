import 'dart:async';
import 'dart:io';

import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import 'avatar.dart';
import 'card_border.dart';
import 'countdown.dart';
import 'greetings.dart';
import 'morning_notification.dart';
import 'my_quotes.dart';
import 'share_card.dart';
import 'special_days.dart';
import 'quotes.dart';
import 'widget_store.dart';

void main() {
  runApp(const GreeterApp());
}

class GreeterApp extends StatelessWidget {
  const GreeterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GREETER',
      theme: ThemeData(
        fontFamily: 'Outfit',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E7A5A),
          brightness: Brightness.dark,
        ),
      ),
      home: const StartPage(),
    );
  }
}

/// Shows setup on first launch, otherwise the home page.
class StartPage extends StatefulWidget {
  const StartPage({super.key});

  @override
  State<StartPage> createState() => _StartPageState();
}

class _StartPageState extends State<StartPage> {
  String? _name;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await HomeWidget.getWidgetData<String>(WidgetKeys.name);
    if (!mounted) return;
    setState(() {
      _name = name;
      _loaded = true;
    });
  }

  Future<void> _saveName(String name) async {
    await HomeWidget.saveWidgetData<String>(WidgetKeys.name, name);
    await refreshWidget();
    if (!mounted) return;
    setState(() => _name = name);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final name = _name;
    if (name == null || name.isEmpty) {
      return SetupPage(onDone: _saveName);
    }
    return HomePage(
      name: name,
      onChangeName: () => setState(() => _name = null),
    );
  }
}

class SetupPage extends StatefulWidget {
  const SetupPage({super.key, required this.onDone});

  final Future<void> Function(String name) onDone;

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final _controller = TextEditingController();
  bool _saving = false;

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty || _saving) return;
    setState(() => _saving = true);
    await widget.onDone(name);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Welcome to GREETER', style: textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text('What should we call you?', style: textTheme.bodyLarge),
              const SizedBox(height: 24),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Your name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _controller.text.trim().isEmpty || _saving
                    ? null
                    : _submit,
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.name, required this.onChangeName});

  final String name;
  final VoidCallback onChangeName;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _focusController = TextEditingController();
  WidgetAppearance _look = WidgetAppearance.defaults;
  int _shuffle = 0;
  String? _avatarPath;
  GreetingStyle _greetingStyle = GreetingStyle.defaultStyle;
  final _focusNode = FocusNode();
  final _focusFieldKey = GlobalKey();
  StreamSubscription<Uri?>? _widgetClicks;
  String? _focusSavedDay;
  bool _focusEdited = false;
  bool _showFocus = defaultShowFocus;
  String? _birthday;
  String? _specialQuoteHiddenDay;
  bool _autoNight = false;
  Countdown? _countdown;
  CardBorder _border = CardBorder.defaults;
  MyQuotes _myQuotes = const MyQuotes();
  NotificationSettings _notify = const NotificationSettings();

  /// The focus as the widget shows it: only a focus saved for today counts.
  String get _previewFocus {
    final text = _focusController.text.trim();
    final isToday = _focusSavedDay == focusDayKey(DateTime.now());
    return isToday || _focusEdited ? text : '';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_openedFromWidget);
    _widgetClicks = HomeWidget.widgetClicked.listen(_openedFromWidget);
  }

  void _openedFromWidget(Uri? uri) {
    if (uri?.host != focusLaunchUri.host) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final field = _focusFieldKey.currentContext;
      if (field == null || !mounted) return;
      Scrollable.ensureVisible(
        field,
        alignment: 0.3,
        duration: const Duration(milliseconds: 300),
      );
      _focusNode.requestFocus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Tapping the quote on the widget changes it while the app is in the background.
    if (state == AppLifecycleState.resumed) _reloadShuffle();
  }

  Future<void> _reloadShuffle() async {
    final shuffle = await HomeWidget.getWidgetData<int>(
      WidgetKeys.quoteShuffle,
    );
    final hiddenDay = await HomeWidget.getWidgetData<String>(
      WidgetKeys.specialQuoteHiddenDay,
    );
    if (!mounted) return;
    setState(() {
      _shuffle = shuffle ?? 0;
      _specialQuoteHiddenDay = hiddenDay;
    });
  }

  /// The quote the widget shows: a special day's quote until it's tapped
  /// away, otherwise one of the normal quotes.
  String? _shownQuote(DateTime now) {
    final special = specialDayFor(now, _birthday);
    if (special != null && _specialQuoteHiddenDay != focusDayKey(now)) {
      return special.quote;
    }
    return currentQuote(_myQuotes.active, _shuffle, now);
  }

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final current = _birthday;
    final picked = await showDatePicker(
      context: context,
      helpText: 'Your birthday',
      firstDate: DateTime(1900),
      lastDate: now,
      initialDate: current == null
          ? DateTime(now.year - 25, now.month, now.day)
          : DateTime(
              2000,
              int.parse(current.substring(0, 2)),
              int.parse(current.substring(3)),
            ),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked == null) return;
    await _setBirthday(monthDayKey(picked));
  }

  Future<void> _setBirthday(String? monthDay) async {
    setState(() => _birthday = monthDay);
    await HomeWidget.saveWidgetData<String>(WidgetKeys.birthday, monthDay);
    await saveSpecialDaysForWidget(monthDay);
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  }

  Future<void> _editCountdown() async {
    final result = await showDialog<Countdown>(
      context: context,
      builder: (context) => _CountdownDialog(initial: _countdown),
    );
    if (result == null) return;
    setState(() => _countdown = result);
    await result.save();
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  }

  String _countdownSubtitle() {
    final countdown = _countdown;
    if (countdown == null) return 'Count down the days to an event';
    final status = countdownStatus(countdown.date, DateTime.now());
    final when = longMonthDay(monthDayKey(countdown.date));
    return status == null
        ? '${countdown.name} · $when (passed, hidden on the widget)'
        : '${countdown.name} · $when · $status';
  }

  Future<void> _clearCountdown() async {
    setState(() => _countdown = null);
    await Countdown.clear();
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  }

  Future<void> _setAutoNight(bool on) async {
    setState(() => _autoNight = on);
    await HomeWidget.saveWidgetData<bool>(WidgetKeys.autoNight, on);
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  }

  Future<void> _load() async {
    final focus = await HomeWidget.getWidgetData<String>(WidgetKeys.focus);
    final shuffle = await HomeWidget.getWidgetData<int>(
      WidgetKeys.quoteShuffle,
    );
    final style = await HomeWidget.getWidgetData<String>(
      WidgetKeys.greetingStyle,
    );
    final focusDay = await HomeWidget.getWidgetData<String>(
      WidgetKeys.focusDay,
    );
    final showFocus = await HomeWidget.getWidgetData<bool>(
      WidgetKeys.showFocus,
    );
    final birthday = await HomeWidget.getWidgetData<String>(
      WidgetKeys.birthday,
    );
    final hiddenDay = await HomeWidget.getWidgetData<String>(
      WidgetKeys.specialQuoteHiddenDay,
    );
    final countdown = await Countdown.load();
    final border = await CardBorder.load();
    final autoNight = await HomeWidget.getWidgetData<bool>(
      WidgetKeys.autoNight,
    );
    final look = await WidgetAppearance.load();
    final myQuotes = await MyQuotes.load();
    final notify = await NotificationSettings.load();
    final avatarPath = await loadAvatarPath();
    if (!mounted) return;
    setState(() {
      _birthday = birthday;
      _specialQuoteHiddenDay = hiddenDay;
      _autoNight = autoNight ?? false;
      _countdown = countdown;
      _border = border;
      _myQuotes = myQuotes;
      _notify = notify;
      _focusController.text = focus ?? '';
      _focusSavedDay = focusDay;
      _showFocus = showFocus ?? defaultShowFocus;
      _shuffle = shuffle ?? 0;
      _greetingStyle = GreetingStyle.fromStored(style);
      _look = look;
      _avatarPath = avatarPath;
    });

    await saveQuotesForWidget(myQuotes);
    await saveGreetingsForWidget();
    await saveSpecialDaysForWidget(birthday);
    await saveNightThemeForWidget();
    await refreshWidget();
    await rescheduleNotification();
  }

  Future<void> _setGreetingStyle(GreetingStyle style) async {
    setState(() => _greetingStyle = style);
    await HomeWidget.saveWidgetData<String>(
      WidgetKeys.greetingStyle,
      style.storedValue,
    );
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  }

  Future<void> _changeAvatar() async {
    final path = await pickAvatar();
    if (path == null) return;
    setState(() => _avatarPath = path);
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  }

  Future<void> _removeAvatar() async {
    await removeAvatar();
    setState(() => _avatarPath = null);
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  }

  Future<void> _setShowFocus(bool show) async {
    setState(() => _showFocus = show);
    await HomeWidget.saveWidgetData<bool>(WidgetKeys.showFocus, show);
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  }

  Future<void> _saveFocus() async {
    FocusScope.of(context).unfocus();
    final day = focusDayKey(DateTime.now());
    await HomeWidget.saveWidgetData<String>(
      WidgetKeys.focus,
      _focusController.text.trim(),
    );
    await HomeWidget.saveWidgetData<String>(WidgetKeys.focusDay, day);
    setState(() {
      _focusSavedDay = day;
      _focusEdited = false;
    });
    await HomeWidget.updateWidget(androidName: androidWidgetName);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Focus updated')));
  }

  Future<void> _nextQuote() async {
    final now = DateTime.now();
    if (specialDayFor(now, _birthday) != null &&
        _specialQuoteHiddenDay != focusDayKey(now)) {
      // Leave the special day's quote for the normal ones.
      final today = focusDayKey(now);
      setState(() => _specialQuoteHiddenDay = today);
      await HomeWidget.saveWidgetData<String>(
        WidgetKeys.specialQuoteHiddenDay,
        today,
      );
      await HomeWidget.updateWidget(androidName: androidWidgetName);
      return;
    }
    final quotes = _myQuotes.active;
    final shown = currentQuote(quotes, _shuffle, now);
    var next = _shuffle + 1;
    while (quotes.length > 1 &&
        currentQuote(quotes, next, now) == shown &&
        next < _shuffle + 20) {
      next++;
    }
    setState(() => _shuffle = next);
    await HomeWidget.saveWidgetData<int>(WidgetKeys.quoteShuffle, _shuffle);
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  }

  void _openMyQuotes() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            MyQuotesPage(initial: _myQuotes, onChanged: _setMyQuotes),
      ),
    );
  }

  Future<void> _setMyQuotes(MyQuotes mine) async {
    setState(() => _myQuotes = mine);
    await mine.save();
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  }

  Future<void> _setNotify(bool on) async {
    if (on && !await requestNotificationPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Allow notifications for GREETER to get your daily greeting.',
          ),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: openNotificationSettings,
          ),
        ),
      );
      return;
    }
    final notify = _notify.copyWith(on: on);
    setState(() => _notify = notify);
    await notify.save();
  }

  Future<void> _pickNotifyTime() async {
    final picked = await showTimePicker(
      context: context,
      helpText: 'Notification time',
      initialTime: _notify.time,
    );
    if (picked == null) return;
    final notify = _notify.copyWith(time: picked);
    setState(() => _notify = notify);
    await notify.save();
  }

  String _myQuotesSubtitle() {
    final count = _myQuotes.quotes.length;
    if (count == 0) return 'Add your own quotes to the mix';
    final quotes = count == 1 ? '1 quote' : '$count quotes';
    return _myQuotes.onlyMine ? '$quotes · showing only yours' : quotes;
  }

  Future<void> _applyLook(WidgetAppearance look) async {
    setState(() => _look = look);
    await look.save();
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  }

  /// Updates the preview at once; [save] writes to the widget (skipped while a
  /// slider is still being dragged).
  Future<void> _applyBorder(CardBorder border, {bool save = true}) async {
    setState(() => _border = border);
    if (!save) return;
    await border.save(_look.accentColor);
    await HomeWidget.updateWidget(androidName: androidWidgetName);
  }

  Future<void> _addWidget() async {
    final supported = await HomeWidget.isRequestPinWidgetSupported() ?? false;
    if (supported) {
      await HomeWidget.requestPinWidget(androidName: androidWidgetName);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Long-press your home screen, tap Widgets, and pick GREETER.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _widgetClicks?.cancel();
    _focusNode.dispose();
    _focusController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('GREETER')),
      // The preview stays pinned above the settings so changes show while adjusting.
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _preview(),
                const SizedBox(height: 6),
                Text(
                  'Widget preview',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _settings(context, textTheme)),
        ],
      ),
    );
  }

  Widget _preview() {
    return
    // A colourful backdrop stands in for the wallpaper so transparency is visible.
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF4FC3F7), Color(0xFFBA68C8), Color(0xFFFFB74D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: GreeterCard(
        name: widget.name,
        quote: _shownQuote(DateTime.now()),
        focus: _previewFocus,
        showFocus: _showFocus,
        look: effectiveLook(_look, DateTime.now(), autoNight: _autoNight),
        avatarPath: _avatarPath,
        greetingStyle: _greetingStyle,
        specialDay: specialDayFor(DateTime.now(), _birthday),
        countdown: _countdown,
        border: _border,
      ),
    );
  }

  /// Thin line between settings.
  static const _divider = Divider(height: 16, thickness: 0.5);

  Widget _settings(BuildContext context, TextTheme textTheme) {
    return ListView(
      // Extra bottom space so the last buttons clear the navigation bar.
      padding: EdgeInsets.fromLTRB(
        24,
        12,
        24,
        48 + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              onPressed: _nextQuote,
              icon: const Icon(Icons.format_quote),
              label: const Text('New quote'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () {
                final now = DateTime.now();
                final quote = _shownQuote(now);
                if (quote == null) return;
                showShareQuoteSheet(
                  context,
                  quote: quote,
                  look: effectiveLook(_look, now, autoNight: _autoNight),
                );
              },
              icon: const Icon(Icons.share_outlined),
              label: const Text('Share quote'),
            ),
          ],
        ),
        _divider,
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: _openMyQuotes,
          leading: const Icon(Icons.edit_note),
          title: const Text('My quotes'),
          subtitle: Text(_myQuotesSubtitle()),
          trailing: const Icon(Icons.chevron_right),
        ),
        _divider,
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: _editCountdown,
          leading: const Icon(Icons.event_outlined),
          title: const Text('Countdown'),
          subtitle: Text(_countdownSubtitle()),
          trailing: _countdown == null
              ? null
              : IconButton(
                  tooltip: 'Remove countdown',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _clearCountdown,
                ),
        ),
        _divider,
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text("Show Today's focus"),
          subtitle: const Text('Resets every morning at 5:00'),
          value: _showFocus,
          onChanged: _setShowFocus,
        ),
        if (_showFocus) ...[
          const SizedBox(height: 8),
          TextField(
            key: _focusFieldKey,
            controller: _focusController,
            focusNode: _focusNode,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            maxLength: 60,
            onChanged: (_) => setState(() => _focusEdited = true),
            onSubmitted: (_) => _saveFocus(),
            decoration: InputDecoration(
              labelText: "Today's focus",
              helperText: _focusSavedDay == focusDayKey(DateTime.now())
                  ? 'Saved for ${shortDate(DateTime.now())}'
                  : 'Not set for today yet. Tap ✓ to save it.',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Save focus',
                icon: const Icon(Icons.check),
                onPressed: _saveFocus,
              ),
            ),
          ),
        ],
        _divider,
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('Daily notification'),
          subtitle: Text(
            _notify.on
                ? 'Your greeting and quote at ${_notify.time.format(context)}'
                : 'Get your greeting and quote as a notification',
          ),
          value: _notify.on,
          onChanged: _setNotify,
        ),
        if (_notify.on)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.schedule),
            title: const Text('Notification time'),
            subtitle: Text(_notify.time.format(context)),
            onTap: _pickNotifyTime,
          ),
        _divider,
        const SizedBox(height: 16),
        Text('Appearance', style: textTheme.titleLarge),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pidgin greetings'),
          subtitle: Text(
            _greetingStyle == GreetingStyle.pidgin
                ? '"Good morning o," "How work dey go," and more'
                : '"Good morning," "Rise and shine," and more',
          ),
          value: _greetingStyle == GreetingStyle.pidgin,
          onChanged: (on) => _setGreetingStyle(
            on ? GreetingStyle.pidgin : GreetingStyle.english,
          ),
        ),
        _divider,
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: _pickBirthday,
          leading: const Icon(Icons.cake_outlined),
          title: const Text('Birthday'),
          subtitle: Text(
            _birthday == null
                ? 'Get a birthday greeting on your day'
                : longMonthDay(_birthday!),
          ),
          trailing: _birthday == null
              ? null
              : IconButton(
                  tooltip: 'Remove birthday',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _setBirthday(null),
                ),
        ),
        _divider,
        ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: _changeAvatar,
          leading: Avatar(
            path: _avatarPath,
            accent: _look.accentColor,
            size: 44,
          ),
          title: const Text('Profile picture'),
          subtitle: Text(
            _avatarPath == null ? 'Tap to choose a photo' : 'Tap to change',
          ),
          trailing: _avatarPath == null
              ? null
              : IconButton(
                  tooltip: 'Remove picture',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _removeAvatar,
                ),
        ),
        _divider,
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Night theme in the evening'),
          subtitle: Text(
            'Switches to Night from $nightStartHour:00 to '
            '$morningStartHour:00',
          ),
          value: _autoNight,
          onChanged: _setAutoNight,
        ),
        _divider,
        Text('Theme', style: textTheme.titleSmall),
        const SizedBox(height: 12),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: themePresets.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final preset = themePresets[i];
              return _PresetTile(
                preset: preset,
                selected: preset.look.looksLike(_look),
                onTap: () => _applyLook(preset.look),
              );
            },
          ),
        ),
        _divider,
        Text(
          'Fine-tune',
          style: textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        _ColorSetting(
          label: 'Background color',
          suggestions: cardColorChoices,
          color: _look.cardColor,
          onChanged: (c) => _applyLook(_look.copyWith(cardColor: c)),
        ),
        _divider,
        Text(
          'Background opacity: ${_look.opacityPercent}%',
          style: textTheme.titleSmall,
        ),
        Slider(
          value: _look.opacityPercent.toDouble(),
          max: 100,
          divisions: 20,
          label: '${_look.opacityPercent}%',
          onChanged: (value) => setState(
            () => _look = _look.copyWith(opacityPercent: value.round()),
          ),
          onChangeEnd: (_) => _applyLook(_look),
        ),
        _divider,
        _ColorSetting(
          label: 'Text color',
          suggestions: textColorChoices,
          color: _look.textColor,
          onChanged: (c) => _applyLook(_look.copyWith(textColor: c)),
        ),
        _divider,
        _ColorSetting(
          label: 'Accent color (quote and label)',
          suggestions: accentColorChoices,
          color: _look.accentColor,
          onChanged: (c) => _applyLook(_look.copyWith(accentColor: c)),
        ),
        _divider,
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Gradient border'),
          subtitle: const Text('A thin shiny edge around the card'),
          value: _border.enabled,
          onChanged: (on) => _applyBorder(_border.copyWith(enabled: on)),
        ),
        if (_border.enabled) ...[
          Text('Border width: ${_border.widthDp}', style: textTheme.titleSmall),
          Slider(
            value: _border.widthDp.toDouble(),
            min: CardBorder.minWidthDp.toDouble(),
            max: CardBorder.maxWidthDp.toDouble(),
            divisions: CardBorder.maxWidthDp - CardBorder.minWidthDp,
            label: '${_border.widthDp}',
            onChanged: (v) =>
                _applyBorder(_border.copyWith(widthDp: v.round()), save: false),
            onChangeEnd: (_) => _applyBorder(_border),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final style in BorderStyleOption.values)
                ChoiceChip(
                  avatar: _GradientDot(
                    colors: _border
                        .copyWith(style: style)
                        .colors(_look.accentColor),
                  ),
                  label: Text(style.label),
                  selected: _border.style == style,
                  onSelected: (_) =>
                      _applyBorder(_border.copyWith(style: style)),
                ),
            ],
          ),
          if (_border.style == BorderStyleOption.custom) ...[
            const SizedBox(height: 8),
            _ColorSetting(
              label: 'Border start color',
              suggestions: accentColorChoices,
              color: _border.customStart,
              onChanged: (c) => _applyBorder(_border.copyWith(customStart: c)),
            ),
            _ColorSetting(
              label: 'Border end color',
              suggestions: accentColorChoices,
              color: _border.customEnd,
              onChanged: (c) => _applyBorder(_border.copyWith(customEnd: c)),
            ),
          ],
        ],
        const SizedBox(height: 32),
        FilledButton.icon(
          onPressed: _addWidget,
          icon: const Icon(Icons.widgets_outlined),
          label: const Text('Add widget to home screen'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: widget.onChangeName,
          icon: const Icon(Icons.edit),
          label: const Text('Change name'),
        ),
        const SizedBox(height: 32),
        Text(
          'Designed by Proffictech (+2348139590011)',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Mirrors res/layout/greeter_widget.xml.
class GreeterCard extends StatelessWidget {
  const GreeterCard({
    super.key,
    required this.name,
    required this.quote,
    required this.focus,
    required this.look,
    this.avatarPath,
    this.greetingStyle = GreetingStyle.defaultStyle,
    this.showFocus = defaultShowFocus,
    this.specialDay,
    this.countdown,
    this.border = CardBorder.defaults,
  });

  final String name;
  final String? quote;

  /// Empty when no focus is set for today, which shows [focusPrompt].
  final String focus;
  final WidgetAppearance look;
  final String? avatarPath;
  final GreetingStyle greetingStyle;
  final bool showFocus;

  /// Replaces the usual greeting on a birthday or holiday.
  final SpecialDay? specialDay;
  final Countdown? countdown;
  final CardBorder border;

  static const double radius = 28;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: border.enabled
          ? GradientBorderPainter(
              colors: border.colors(look.accentColor),
              widthDp: border.widthDp,
              radius: radius,
            )
          : null,
      child: _card(),
    );
  }

  Widget _card() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: look.cardColor.withValues(alpha: look.opacityPercent / 100),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: _text(),
    );
  }

  Widget _text() {
    final quote = this.quote;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    specialDay?.greeting(greetingStyle) ??
                        greetingLine(DateTime.now(), greetingStyle),
                    style: TextStyle(color: look.textColor, fontSize: 20),
                  ),
                  // Shrinks a long name to one line, like GreeterWidget.kt does.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      name.toUpperCase(),
                      maxLines: 1,
                      style: TextStyle(
                        color: look.textColor,
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Avatar(path: avatarPath, accent: look.accentColor, size: 48),
          ],
        ),
        if (quote != null) ...[
          const SizedBox(height: 6),
          Text(
            '"$quote"',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: look.accentColor,
              fontSize: 17,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        ?_countdownRow(),
        if (showFocus) ...[
          const SizedBox(height: 14),
          Divider(
            height: 1,
            thickness: 1,
            color: look.textColor.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                focusLabel,
                style: TextStyle(color: look.accentColor, fontSize: 13),
              ),
              const Spacer(),
              Text(
                shortDate(DateTime.now()),
                style: TextStyle(
                  color: look.textColor.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            focus.isEmpty ? focusPrompt : focus,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: focus.isEmpty
                  ? look.textColor.withValues(alpha: 0.6)
                  : look.textColor,
              fontSize: 17,
            ),
          ),
        ],
      ],
    );
  }
}

extension on GreeterCard {
  /// Divider plus "Lagos trip ... 12 days to go"; null when there's nothing
  /// to count down to. Mirrors the countdown row in GreeterWidget.kt.
  Widget? _countdownRow() {
    final countdown = this.countdown;
    if (countdown == null) return null;
    final status = countdownStatus(countdown.date, DateTime.now());
    if (status == null) return null;
    return Column(
      children: [
        const SizedBox(height: 14),
        Divider(
          height: 1,
          thickness: 1,
          color: look.textColor.withValues(alpha: 0.25),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                countdown.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: look.textColor, fontSize: 16),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              status,
              style: TextStyle(
                color: look.accentColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CountdownDialog extends StatefulWidget {
  const _CountdownDialog({this.initial});

  final Countdown? initial;

  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late DateTime? _date = widget.initial?.date;

  bool get _valid => _name.text.trim().isNotEmpty && _date != null;

  Future<void> _pickDate() async {
    final today = focusDate(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      helpText: 'Event date',
      firstDate: today,
      lastDate: DateTime(today.year + 10),
      initialDate: _date != null && !_date!.isBefore(today) ? _date : today,
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final date = _date;
    return AlertDialog(
      title: const Text('Countdown'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            autofocus: widget.initial == null,
            maxLength: Countdown.maxNameLength,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'What are you counting down to?',
              hintText: 'Lagos trip',
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(
              date == null ? 'Pick a date' : longMonthDay(monthDayKey(date)),
            ),
            subtitle: date == null ? null : Text('${date.year}'),
            onTap: _pickDate,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _valid
              ? () => Navigator.of(
                  context,
                ).pop(Countdown(name: _name.text.trim(), date: _date!))
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Round profile picture, or a person placeholder when none is set.
/// Mirrors avatarBitmap() in GreeterWidget.kt.
class Avatar extends StatelessWidget {
  const Avatar({
    super.key,
    required this.path,
    required this.accent,
    required this.size,
  });

  final String? path;
  final Color accent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = this.path;
    if (path != null) {
      return ClipOval(
        child: Image.file(
          File(path),
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.2),
      ),
      child: Icon(Icons.person, color: accent, size: size * 0.7),
    );
  }
}

/// A small card drawn in a theme's own colors.
class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final ThemePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final look = preset.look;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 72,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? scheme.primary : scheme.outlineVariant,
                width: selected ? 3 : 1,
              ),
              // Same stand-in wallpaper as the preview, so see-through themes read as such.
              gradient: const LinearGradient(
                colors: [Color(0xFF4FC3F7), Color(0xFFBA68C8)],
              ),
            ),
            child: Container(
              margin: const EdgeInsets.all(3),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: look.cardColor.withValues(
                  alpha: look.opacityPercent / 100,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Text(
                    'Aa',
                    style: TextStyle(
                      color: look.textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: look.accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(preset.name, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

/// A small circle filled with a border style's gradient.
class _GradientDot extends StatelessWidget {
  const _GradientDot({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

/// A row showing the current color; tapping it opens a full color picker.
class _ColorSetting extends StatelessWidget {
  const _ColorSetting({
    required this.label,
    required this.suggestions,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final List<Color> suggestions;
  final Color color;
  final ValueChanged<Color> onChanged;

  Future<void> _pick(BuildContext context) async {
    final picked = await showColorPickerDialog(
      context,
      color,
      title: Text(label, style: Theme.of(context).textTheme.titleLarge),
      pickersEnabled: const {
        ColorPickerType.wheel: true,
        ColorPickerType.custom: true,
        ColorPickerType.primary: true,
        ColorPickerType.accent: false,
      },
      pickerTypeLabels: const {
        ColorPickerType.wheel: 'Any color',
        ColorPickerType.custom: 'Suggested',
        ColorPickerType.primary: 'Palette',
      },
      customColorSwatchesAndNames: {
        for (final c in suggestions) ColorTools.createPrimarySwatch(c): '',
      },
      enableShadesSelection: true,
      showColorCode: true,
      colorCodeHasColor: true,
      copyPasteBehavior: const ColorPickerCopyPasteBehavior(
        longPressMenu: true,
      ),
      actionButtons: const ColorPickerActionButtons(
        okButton: true,
        closeButton: true,
        dialogActionButtons: false,
      ),
      constraints: const BoxConstraints(minWidth: 320, maxWidth: 320),
    );
    if (colorToRgb(picked) != colorToRgb(color)) {
      onChanged(picked.withValues(alpha: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hex = colorToRgb(color).toRadixString(16).padLeft(6, '0');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => _pick(context),
      title: Text(label),
      subtitle: Text('#${hex.toUpperCase()}'),
      trailing: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.outline),
        ),
        child: Icon(
          Icons.colorize,
          size: 20,
          color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
        ),
      ),
    );
  }
}
