import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'pos_localizations.dart';
import 'pos_repository.dart';

const _brand = Color(0xFF2A4B6E);
const _brandDeep = Color(0xFF1A2F47);
const _brandWash = Color(0xFFE6EBF0);
const _paper = Color(0xFFF3EDE0);
const _surfaceLight = Color(0xFFFBF8F0);
const _accent = Color(0xFFC9442E);
const _ink = Color(0xFF2B2622);
const _line = Color(0xFFDDD2BE);
const _categories = ['すべて', '食品', '飲料', '日用品', 'その他'];
const _currency = '¥';

List<String> _categoryList(Iterable<PosProduct> products) {
  final custom = <String>{
    for (final product in products)
      if (!_categories.contains(product.category) &&
          product.category.trim().isNotEmpty)
        product.category,
  }.toList()..sort();
  return [
    ..._categories.take(_categories.length - 1),
    ...custom,
    _categories.last,
  ];
}

const _desktopBreakpoint = 480.0;

int _dashboardColumnCount(double width) => switch (width) {
  >= 1100 => 4,
  >= 760 => 3,
  _ => 2,
};

String formatYen(int amount) {
  final digits = amount.abs().toString();
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = end - 3 < 0 ? 0 : end - 3;
    groups.insert(0, digits.substring(start, end));
  }
  return '${amount < 0 ? '-' : ''}$_currency${groups.join(',')}';
}

class PosApp extends StatefulWidget {
  const PosApp({
    super.key,
    this.auth,
    this.firestore,
    this.initialLocale = const Locale('ja'),
  });

  final Locale initialLocale;
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;

  @override
  State<PosApp> createState() => _PosAppState();
}

class _PosAppState extends State<PosApp> {
  ThemeMode _themeMode = ThemeMode.light;
  late Locale _locale = widget.initialLocale;
  bool _guestBrowsing = false;

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colors = ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: brightness,
      primary: _brand,
      secondary: _accent,
      surface: dark ? const Color(0xFF1D2530) : _surfaceLight,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colors,
      scaffoldBackgroundColor: dark ? const Color(0xFF141A22) : _paper,
      fontFamily: 'Roboto',
      fontFamilyFallback: const ['Noto Sans JP', 'Hiragino Sans', 'Yu Gothic'],
      dividerColor: dark ? const Color(0xFF38424F) : _line,
      textTheme: Typography.material2021().black.apply(
        bodyColor: dark ? colors.onSurface : _ink,
        displayColor: dark ? colors.onSurface : _ink,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? const Color(0xFF141A22) : _paper,
        foregroundColor: dark ? colors.onSurface : _brandDeep,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
        toolbarHeight: 68,
        shape: Border(
          bottom: BorderSide(color: dark ? const Color(0xFF38424F) : _line),
        ),
        titleTextStyle: TextStyle(
          fontFamilyFallback: const [
            'Yu Mincho',
            'Hiragino Mincho ProN',
            'Noto Serif JP',
          ],
          letterSpacing: 1.2,
          color: dark ? colors.onSurface : _brandDeep,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? const Color(0xFF18202A) : _surfaceLight,
        indicatorColor: dark ? const Color(0xFF2B3F58) : _brandWash,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(7),
        ),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 76,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            fontSize: 10,
            letterSpacing: 0.2,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          );
        }),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF222B37) : const Color(0xFFEFE8D8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: const BorderSide(color: _brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(7),
          borderSide: BorderSide(color: colors.error.withValues(alpha: 0.65)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 16,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark
            ? const Color(0xFF222B37)
            : const Color(0xFFEFE8D8),
        selectedColor: dark ? const Color(0xFF2B3F58) : _brandWash,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: TextStyle(
          color: dark ? colors.onSurface : _brandDeep,
          fontWeight: FontWeight.w700,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _brand,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _brandDeep,
          minimumSize: const Size(48, 48),
          side: BorderSide(color: dark ? const Color(0xFF566274) : _line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: dark ? const Color(0xFF38424F) : _line),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: dark ? const Color(0xFF1D2530) : _surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = PosRepository(
      widget.auth ?? FirebaseAuth.instance,
      widget.firestore ?? FirebaseFirestore.instance,
    );
    return MaterialApp(
      title: localizePosText(_locale, 'MORI デイリーマーケット'),
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: const [Locale('ja'), Locale('en'), Locale('my')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: _themeMode,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(media.textScaler.scale(1) * 0.88),
          ),
          child: child!,
        );
      },
      home: _AuthGate(
        repository: repository,
        themeMode: _themeMode,
        locale: _locale,
        onLocaleChanged: (locale) => setState(() => _locale = locale),
        onThemeChanged: (mode) => setState(() => _themeMode = mode),
        guestBrowsing: _guestBrowsing,
        onBrowseAsGuest: () => setState(() => _guestBrowsing = true),
        onGuestOrderComplete: () => setState(() => _guestBrowsing = false),
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate({
    required this.repository,
    required this.themeMode,
    required this.locale,
    required this.onLocaleChanged,
    required this.onThemeChanged,
    required this.guestBrowsing,
    required this.onBrowseAsGuest,
    required this.onGuestOrderComplete,
  });

  final PosRepository repository;
  final ThemeMode themeMode;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<ThemeMode> onThemeChanged;
  final bool guestBrowsing;
  final VoidCallback onBrowseAsGuest;
  final VoidCallback onGuestOrderComplete;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: repository.authChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.hasError) {
          return _ErrorPage(
            title: context.posText('ログイン状態を確認できません'),
            message: _readableError(authSnapshot.error!, context),
          );
        }
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingPage();
        }
        final user = authSnapshot.data;
        if (guestBrowsing) {
          return _GuestBrowsePage(
            repository: repository,
            locale: locale,
            onLocaleChanged: onLocaleChanged,
            onGuestOrderComplete: onGuestOrderComplete,
          );
        }
        if (user == null) {
          return _AuthPage(
            repository: repository,
            locale: locale,
            onLocaleChanged: onLocaleChanged,
            onBrowseAsGuest: onBrowseAsGuest,
          );
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: repository.profileChanges(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.hasError) {
              return _ErrorPage(
                title: context.posText('店舗データに接続できません'),
                message: _readableError(profileSnapshot.error!, context),
              );
            }
            if (!profileSnapshot.hasData) return const _LoadingPage();
            final document = profileSnapshot.data!;
            if (!document.exists) {
              return _ProfileRecoveryPage(
                user: user,
                repository: repository,
                locale: locale,
                onLocaleChanged: onLocaleChanged,
              );
            }
            final data = document.data();
            if (data == null) {
              return _ErrorPage(
                title: context.posText('アカウント情報を読み込めません'),
                message: context.posText('ユーザー情報の形式を確認してください。'),
              );
            }
            final profile = PosProfile.fromDocument(user.uid, data, user.email);
            return _PosShell(
              repository: repository,
              profile: profile,
              themeMode: themeMode,
              locale: locale,
              onLocaleChanged: onLocaleChanged,
              onThemeChanged: onThemeChanged,
            );
          },
        );
      },
    );
  }
}

class _GuestBrowsePage extends StatelessWidget {
  const _GuestBrowsePage({
    required this.repository,
    required this.locale,
    required this.onLocaleChanged,
    required this.onGuestOrderComplete,
  });

  final PosRepository repository;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final VoidCallback onGuestOrderComplete;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _brand,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.forest_rounded,
                color: Color(0xFFF4D19A),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.posText('商品を見る')),
                Text(
                  'MORI  /  DAILY MARKET',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.15,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: _LanguageSelector(
                locale: locale,
                onChanged: onLocaleChanged,
              ),
            ),
          ),
        ],
      ),
      body: _CashierPage(
        key: const ValueKey('guest-cashier'),
        repository: repository,
        profile: null,
        onGuestOrderComplete: onGuestOrderComplete,
        locale: locale,
        onLocaleChanged: onLocaleChanged,
      ),
    );
  }
}

String _readableError(Object error, BuildContext context) {
  if (error is FirebaseException) {
    return '${error.message ?? error.code}\n\n${context.posText('Firebase ConsoleでAuthenticationとCloud Firestoreの設定を確認してください。')}';
  }
  return error.toString();
}

String _checkoutErrorMessage(String message, BuildContext context) {
  if (Localizations.localeOf(context).languageCode == 'ja') return message;
  if (message == 'カートに商品がありません。') return context.posText(message);
  if (message == '注文を確定するにはログインしてください。') {
    return context.posText(message);
  }

  for (final suffix in [
    'は現在販売できません。',
    'の価格が更新されました。カートを確認してください。',
    'の在庫が不足しています。',
  ]) {
    if (message.endsWith(suffix)) {
      return '${message.substring(0, message.length - suffix.length)}'
          '${context.posText(suffix)}';
    }
  }
  return message;
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _ErrorPage extends StatelessWidget {
  const _ErrorPage({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, color: _brand, size: 48),
                const SizedBox(height: 18),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileRecoveryPage extends StatefulWidget {
  const _ProfileRecoveryPage({
    required this.user,
    required this.repository,
    required this.locale,
    required this.onLocaleChanged,
  });

  final User user;
  final PosRepository repository;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;

  @override
  State<_ProfileRecoveryPage> createState() => _ProfileRecoveryPageState();
}

class _ProfileRecoveryPageState extends State<_ProfileRecoveryPage> {
  bool _busy = false;
  String? _error;

  Future<void> _createProfile() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.ensureProfile(user: widget.user, name: '');
    } on FirebaseException catch (error) {
      setState(() => _error = _readableError(error, context));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(context.posText('言語')),
                  const SizedBox(width: 8),
                  _LanguageSelector(
                    locale: widget.locale,
                    onChanged: widget.onLocaleChanged,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Icon(
                Icons.person_add_alt_1_rounded,
                size: 42,
                color: _brand,
              ),
              const SizedBox(height: 14),
              Text(
                context.posText('アカウント設定を完了'),
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? context.posText('プロフィールを作成してMORIを利用します。'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : _createProfile,
                child: Text(context.posText(_busy ? '設定中...' : 'プロフィールを作成')),
              ),
              TextButton(
                onPressed: widget.repository.signOut,
                child: Text(context.posText('ログアウト')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthPage extends StatefulWidget {
  const _AuthPage({
    required this.repository,
    required this.locale,
    required this.onLocaleChanged,
    this.onBrowseAsGuest,
    this.onAuthenticated,
  });

  final PosRepository repository;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final VoidCallback? onBrowseAsGuest;
  final VoidCallback? onAuthenticated;

  @override
  State<_AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<_AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _registering = false;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_registering) {
        await widget.repository.register(
          name: _name.text,
          email: _email.text,
          password: _password.text,
        );
      } else {
        await widget.repository.signIn(_email.text, _password.text);
      }
      if (widget.onAuthenticated != null && mounted) {
        widget.onAuthenticated!();
      }
    } on FirebaseAuthException catch (error) {
      setState(() => _error = _authErrorMessage(error, context));
    } on FirebaseException catch (error) {
      setState(() => _error = _readableError(error, context));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _authErrorMessage(FirebaseAuthException error, BuildContext context) {
    return switch (error.code) {
      'email-already-in-use' => context.posText('このメールアドレスはすでに登録されています。'),
      'invalid-email' => context.posText('メールアドレスの形式を確認してください。'),
      'weak-password' => context.posText('パスワードは6文字以上で設定してください。'),
      'user-not-found' ||
      'wrong-password' ||
      'invalid-credential' => context.posText('メールアドレスまたはパスワードを確認してください。'),
      'operation-not-allowed' => context.posText(
        'Firebase Consoleでメールアドレス認証を有効にしてください。',
      ),
      'network-request-failed' => context.posText('ネットワーク接続を確認してください。'),
      _ =>
        error.message ??
            (Localizations.localeOf(context).languageCode == 'en'
                ? '${context.posText('認証に失敗しました（')}${error.code}).'
                : '${context.posText('認証に失敗しました（')}${error.code}${Localizations.localeOf(context).languageCode == 'ja' ? '）。' : '။'}'),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.onAuthenticated == null
          ? null
          : AppBar(title: Text(context.posText('注文にはアカウントが必要です'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(context.posText('言語')),
                        const SizedBox(width: 8),
                        _LanguageSelector(
                          locale: widget.locale,
                          onChanged: widget.onLocaleChanged,
                        ),
                      ],
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Container(
                        height: 112,
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_brandDeep, _brand],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              right: -8,
                              top: -39,
                              child: Icon(
                                Icons.forest_rounded,
                                size: 150,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.forest_rounded,
                                      color: Color(0xFFF4D19A),
                                      size: 22,
                                    ),
                                    const SizedBox(width: 7),
                                    const Text(
                                      'MORI',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 3,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'EST. 2026',
                                      style: TextStyle(
                                        color: Colors.white.withValues(
                                          alpha: 0.68,
                                        ),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  'A LITTLE GOOD,\nEVERY DAY.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.96),
                                    height: 1.05,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      context.posText(
                        _registering ? 'MORIアカウントを作成' : 'MORIにログイン',
                      ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _registering
                          ? context.posText('登録後、管理者がユーザー権限を設定します。')
                          : context.posText('メールアドレスでログインしてください。'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_registering) ...[
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: context.posText('名前'),
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) =>
                            (value == null || value.trim().isEmpty)
                            ? context.posText('名前を入力してください。')
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: context.posText('メールアドレス'),
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? '';
                        if (!email.contains('@') || !email.contains('.')) {
                          return context.posText('有効なメールアドレスを入力してください。');
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: context.posText('パスワード'),
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: context.posText(
                            _obscurePassword ? 'パスワードを表示' : 'パスワードを隠す',
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => (value ?? '').length < 6
                          ? context.posText('パスワードは6文字以上で入力してください。')
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 13),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _brand,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              context.posText(
                                _registering ? 'アカウントを作成' : 'ログイン',
                              ),
                            ),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                              _registering = !_registering;
                              _error = null;
                            }),
                      child: Text(
                        context.posText(
                          _registering
                              ? 'すでにアカウントをお持ちの方：ログイン'
                              : '初めてご利用の方：アカウントを作成',
                        ),
                      ),
                    ),
                    if (widget.onBrowseAsGuest != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        key: const ValueKey('browse-as-guest'),
                        onPressed: _busy ? null : widget.onBrowseAsGuest,
                        icon: const Icon(Icons.storefront_outlined),
                        label: Text(context.posText('アカウントなしで商品を見る')),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({required this.locale, required this.onChanged});

  final Locale locale;
  final ValueChanged<Locale> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<Locale>(
        key: const ValueKey('language-selector'),
        value: locale,
        onChanged: (selected) {
          if (selected != null) onChanged(selected);
        },
        items: const [
          DropdownMenuItem(value: Locale('ja'), child: Text('日本語')),
          DropdownMenuItem(value: Locale('en'), child: Text('English')),
          DropdownMenuItem(value: Locale('my'), child: Text('မြန်မာ')),
        ],
      ),
    );
  }
}

class _PosShell extends StatefulWidget {
  const _PosShell({
    required this.repository,
    required this.profile,
    required this.themeMode,
    required this.locale,
    required this.onLocaleChanged,
    required this.onThemeChanged,
  });

  final PosRepository repository;
  final PosProfile profile;
  final ThemeMode themeMode;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<ThemeMode> onThemeChanged;

  @override
  State<_PosShell> createState() => _PosShellState();
}

class _PosShellState extends State<_PosShell> {
  int _selectedIndex = 0;
  bool _navVisible = true;

  bool _onScroll(UserScrollNotification notification) {
    if (notification.depth != 0) return false;
    final visible = switch (notification.direction) {
      ScrollDirection.reverse => false,
      ScrollDirection.forward => true,
      ScrollDirection.idle => _navVisible,
    };
    if (visible != _navVisible) setState(() => _navVisible = visible);
    return false;
  }

  final Set<String> _knownOrderIds = {};
  final Set<String> _unreadOrderIds = {};
  StreamSubscription<List<PosOrder>>? _ordersSubscription;
  bool _hasReceivedInitialOrders = false;

  @override
  void initState() {
    super.initState();
    _listenForAdminOrders();
  }

  @override
  void didUpdateWidget(covariant _PosShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository ||
        oldWidget.profile.uid != widget.profile.uid ||
        oldWidget.profile.isAdmin != widget.profile.isAdmin) {
      unawaited(_ordersSubscription?.cancel() ?? Future<void>.value());
      _ordersSubscription = null;
      _knownOrderIds.clear();
      _knownStatuses.clear();
      _unreadOrderIds.clear();
      _hasReceivedInitialOrders = false;
      _listenForAdminOrders();
    }
  }

  final Map<String, String> _knownStatuses = {};
  final List<PosOrder> _statusQueue = [];
  bool _statusOpen = false;

  void _listenForUserOrders() {
    _ordersSubscription = widget.repository
        .orders(profile: widget.profile)
        .listen((orders) {
          final first = !_hasReceivedInitialOrders;
          _hasReceivedInitialOrders = true;
          final changed = <PosOrder>[];
          for (final order in orders) {
            final previous = _knownStatuses[order.id];
            if (!first &&
                previous != null &&
                previous != order.status &&
                order.status != 'cancelled') {
              changed.add(order);
            }
            _knownStatuses[order.id] = order.status;
          }
          if (changed.isEmpty || !mounted) return;
          _statusQueue.addAll(changed);
          if (!_statusOpen) unawaited(_drainStatusAlerts());
        }, onError: (Object _) {});
  }

  Future<void> _drainStatusAlerts() async {
    _statusOpen = true;
    while (_statusQueue.isNotEmpty && mounted) {
      final order = _statusQueue.removeAt(0);
      final (icon, color, message) = switch (order.status) {
        'preparing' => (Icons.inventory_2_rounded, _brand, 'ご注文が受け付けられ、準備中です。'),
        'shipped' => (Icons.local_shipping_rounded, _brand, 'ご注文の商品が発送されました。'),
        'rejected' => (
          Icons.block_rounded,
          const Color(0xFFB8372A),
          '申し訳ありません。ご注文は受け付けられませんでした。',
        ),
        _ => (Icons.check_circle_rounded, _brand, 'ご注文が完了しました。'),
      };
      final goToOrders = await _showOrderPopup<bool>(
        // ignore: use_build_context_synchronously
        context,
        child: Builder(
          builder: (dialogContext) => _OrderPopup(
            key: const ValueKey('order-status-dialog'),
            order: order,
            color: color,
            icon: icon,
            title: dialogContext.posText(_orderStatusKey(order.status)),
            message: dialogContext.posText(message),
            showProgress: order.status != 'rejected',
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(dialogContext.posText('閉じる')),
              ),
              FilledButton(
                key: const ValueKey('status-view-orders'),
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(dialogContext.posText('注文を見る')),
              ),
            ],
          ),
        ),
      );
      if (!mounted) break;
      if (goToOrders == true) {
        _statusQueue.clear();
        setState(() => _selectedIndex = 1);
      }
    }
    _statusOpen = false;
  }

  void _listenForAdminOrders() {
    if (!widget.profile.isAdmin) {
      _listenForUserOrders();
      return;
    }
    _ordersSubscription = widget.repository
        .orders(profile: widget.profile)
        .listen(
          (orders) {
            if (!_hasReceivedInitialOrders) {
              _knownOrderIds.addAll(orders.map((order) => order.id));
              _hasReceivedInitialOrders = true;
              return;
            }
            final newOrders = orders
                .where(
                  (order) =>
                      !_knownOrderIds.contains(order.id) &&
                      order.status == 'pending' &&
                      order.userId != widget.profile.uid,
                )
                .toList();
            _knownOrderIds.addAll(orders.map((order) => order.id));
            if (newOrders.isEmpty || !mounted) return;
            setState(() {
              _unreadOrderIds.addAll(newOrders.map((order) => order.id));
            });
            _showNewOrderAlert(newOrders.first);
          },
          onError: (Object error) {
            if (!mounted) return;
            final message = error is FirebaseException
                ? _readableError(error, context)
                : error.toString();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          },
        );
  }

  final List<PosOrder> _alertQueue = [];
  bool _alertOpen = false;

  void _showNewOrderAlert(PosOrder order) {
    _alertQueue.add(order);
    if (!_alertOpen) unawaited(_drainAlerts());
  }

  Future<void> _drainAlerts() async {
    _alertOpen = true;
    while (_alertQueue.isNotEmpty && mounted) {
      final order = _alertQueue.removeAt(0);
      final action = await _showOrderPopup<String>(
        // ignore: use_build_context_synchronously
        context,
        dismissible: false,
        child: Builder(
          builder: (dialogContext) => _OrderPopup(
            key: const ValueKey('new-order-dialog'),
            order: order,
            color: _accent,
            icon: Icons.notifications_active_rounded,
            title: dialogContext.posText('新しい注文'),
            message: dialogContext.posText('新しい注文が入りました。確認してください。'),
            wiggle: true,
            actions: [
              TextButton(
                key: const ValueKey('alert-reject-order'),
                onPressed: () => Navigator.pop(dialogContext, 'reject'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFB8372A),
                ),
                child: Text(dialogContext.posText('注文を拒否する')),
              ),
              TextButton(
                key: const ValueKey('alert-view-order'),
                onPressed: () => Navigator.pop(dialogContext, 'view'),
                child: Text(dialogContext.posText('注文を見る')),
              ),
              FilledButton(
                key: const ValueKey('alert-accept-order'),
                onPressed: () => Navigator.pop(dialogContext, 'accept'),
                child: Text(dialogContext.posText('注文を受け付ける')),
              ),
            ],
          ),
        ),
      );
      if (!mounted) break;
      if (action == 'view') {
        _alertQueue.clear();
        _openAdminOrders();
      } else if (action == 'accept' || action == 'reject') {
        await _resolveOrder(order, accept: action == 'accept');
      }
    }
    _alertOpen = false;
  }

  Future<void> _resolveOrder(PosOrder order, {required bool accept}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (accept) {
        await widget.repository.updateOrderStatus(
          orderId: order.id,
          status: 'preparing',
          profile: widget.profile,
        );
      } else {
        await widget.repository.rejectOrder(
          orderId: order.id,
          profile: widget.profile,
        );
      }
      if (!mounted) return;
      setState(() => _unreadOrderIds.remove(order.id));
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            context.posText(accept ? '注文を受け付け、準備中にしました。' : '注文を拒否し、在庫に戻しました。'),
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(_readableError(error, context))),
        );
      }
    } on StateError catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(context.posText(error.message))),
        );
      }
    }
  }

  void _openAdminOrders() {
    setState(() {
      _selectedIndex = 2;
      _unreadOrderIds.clear();
    });
  }

  @override
  void dispose() {
    unawaited(_ordersSubscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  List<NavigationDestination> _destinations(BuildContext context) =>
      widget.profile.isAdmin
      ? [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded),
            label: context.posText('概要'),
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: context.posText('商品'),
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: context.posText('売上'),
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: context.posText('設定'),
          ),
        ]
      : [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: context.posText('商品を見る'),
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: context.posText('注文履歴'),
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: context.posText('マイページ'),
          ),
        ];

  @override
  Widget build(BuildContext context) {
    final pages = widget.profile.isAdmin
        ? <Widget>[
            _AdminDashboardPage(
              repository: widget.repository,
              profile: widget.profile,
            ),
            _AdminProductsPage(repository: widget.repository),
            _OrdersPage(repository: widget.repository, profile: widget.profile),
            _AccountPage(
              profile: widget.profile,
              repository: widget.repository,
              themeMode: widget.themeMode,
              locale: widget.locale,
              onLocaleChanged: widget.onLocaleChanged,
              onThemeChanged: widget.onThemeChanged,
            ),
          ]
        : <Widget>[
            _CashierPage(
              repository: widget.repository,
              profile: widget.profile,
            ),
            _OrdersPage(repository: widget.repository, profile: widget.profile),
            _AccountPage(
              profile: widget.profile,
              repository: widget.repository,
              themeMode: widget.themeMode,
              locale: widget.locale,
              onLocaleChanged: widget.onLocaleChanged,
              onThemeChanged: widget.onThemeChanged,
            ),
          ];
    final titles = widget.profile.isAdmin
        ? ['管理者ダッシュボード', '商品管理', '売上一覧', '設定']
        : ['商品を見る', '注文履歴', 'マイページ'];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= _desktopBreakpoint;
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _brand,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.forest_rounded,
                    color: Color(0xFFF4D19A),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(context.posText(titles[_selectedIndex])),
                    const SizedBox(height: 1),
                    Text(
                      widget.profile.isAdmin
                          ? 'MORI  /  ADMIN DESK'
                          : 'MORI  /  DAILY MARKET',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.15,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              if (widget.profile.isAdmin)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Center(
                    child: IconButton(
                      key: const ValueKey('admin-order-notifications'),
                      tooltip: context.posText('注文通知'),
                      onPressed: _openAdminOrders,
                      icon: Badge(
                        isLabelVisible: _unreadOrderIds.isNotEmpty,
                        label: Text('${_unreadOrderIds.length}'),
                        child: const Icon(Icons.notifications_outlined),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: CircleAvatar(
                    radius: 17,
                    backgroundColor: _brandWash,
                    child: Text(
                      widget.profile.name.isEmpty
                          ? 'U'
                          : widget.profile.name[0],
                      style: const TextStyle(
                        color: _brand,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (!isDesktop) {
                return NotificationListener<UserScrollNotification>(
                  onNotification: _onScroll,
                  child: IndexedStack(index: _selectedIndex, children: pages),
                );
              }

              final destinations = _railDestinations(context);
              return Row(
                children: [
                  NavigationRail(
                    extended: true,
                    minExtendedWidth: 220,
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) =>
                        setState(() => _selectedIndex = index),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                    leading: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 12, 28),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _brand,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.forest_rounded,
                              color: Color(0xFFF4D19A),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'MORI',
                                style: TextStyle(
                                  color: _brandDeep,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                widget.profile.isAdmin
                                    ? 'ADMIN DESK'
                                    : 'DAILY MARKET',
                                style: const TextStyle(
                                  color: _ink,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    destinations: destinations,
                  ),
                  VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: Theme.of(context).dividerColor,
                  ),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1600),
                        child: IndexedStack(
                          index: _selectedIndex,
                          children: pages,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          bottomNavigationBar: isDesktop
              ? null
              : AnimatedAlign(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  heightFactor: _navVisible ? 1 : 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: _navVisible ? 1 : 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
                        child: Material(
                          key: const ValueKey('floating-nav'),
                          elevation: 10,
                          shadowColor: const Color(0x55000000),
                          borderRadius: BorderRadius.circular(12),
                          clipBehavior: Clip.antiAlias,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF18202A)
                              : Colors.white,
                          child: NavigationBar(
                            height: 68,
                            backgroundColor: Colors.transparent,
                            selectedIndex: _selectedIndex,
                            onDestinationSelected: (index) =>
                                setState(() => _selectedIndex = index),
                            destinations: _destinations(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  List<NavigationRailDestination> _railDestinations(BuildContext context) =>
      widget.profile.isAdmin
      ? [
          NavigationRailDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard_rounded),
            label: Text(context.posText('概要')),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon: const Icon(Icons.inventory_2_rounded),
            label: Text(context.posText('商品')),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long_rounded),
            label: Text(context.posText('売上')),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings_rounded),
            label: Text(context.posText('設定')),
          ),
        ]
      : [
          NavigationRailDestination(
            icon: const Icon(Icons.storefront_outlined),
            selectedIcon: const Icon(Icons.storefront_rounded),
            label: Text(context.posText('商品を見る')),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon: const Icon(Icons.receipt_long_rounded),
            label: Text(context.posText('注文履歴')),
          ),
          NavigationRailDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: Text(context.posText('マイページ')),
          ),
        ];
}

enum _ProductSort { recommended, popular, newest, priceLow, priceHigh, name }

class _CashierPage extends StatefulWidget {
  const _CashierPage({
    required this.repository,
    required this.profile,
    this.onGuestOrderComplete,
    this.locale,
    this.onLocaleChanged,
    super.key,
  });

  final PosRepository repository;
  final PosProfile? profile;
  final VoidCallback? onGuestOrderComplete;
  final Locale? locale;
  final ValueChanged<Locale>? onLocaleChanged;

  @override
  State<_CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<_CashierPage> {
  final _search = TextEditingController();
  String _category = 'すべて';
  final _ProductSort _sort = _ProductSort.recommended;
  final Map<String, int> _cart = {};
  bool _checkingOut = false;
  bool _inStockOnly = false;
  bool _favoritesOnly = false;
  bool _saleOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<PosProduct> _sortedProducts(List<PosProduct> products) {
    final sorted = List<PosProduct>.from(products);
    switch (_sort) {
      case _ProductSort.popular:
        sorted.sort((left, right) => right.soldCount.compareTo(left.soldCount));
      case _ProductSort.newest:
        sorted.sort((left, right) {
          final leftTime =
              left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final rightTime =
              right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return rightTime.compareTo(leftTime);
        });
      case _ProductSort.priceLow:
        sorted.sort((left, right) => left.price.compareTo(right.price));
      case _ProductSort.priceHigh:
        sorted.sort((left, right) => right.price.compareTo(left.price));
      case _ProductSort.name:
        sorted.sort((left, right) => left.name.compareTo(right.name));
      case _ProductSort.recommended:
        sorted.sort((left, right) {
          final leftScore = left.soldCount * 2 + (left.stock > 0 ? 1 : 0);
          final rightScore = right.soldCount * 2 + (right.stock > 0 ? 1 : 0);
          final byScore = rightScore.compareTo(leftScore);
          if (byScore != 0) return byScore;
          final leftTime =
              left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final rightTime =
              right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return rightTime.compareTo(leftTime);
        });
    }
    return sorted;
  }

  int _cartTotal(List<PosProduct> products) {
    return products.fold<int>(
      0,
      (total, product) => total + product.price * (_cart[product.id] ?? 0),
    );
  }

  void _changeQuantity(PosProduct product, int change) {
    setState(() {
      final next = (_cart[product.id] ?? 0) + change;
      if (next <= 0) {
        _cart.remove(product.id);
      } else if (next <= product.stock) {
        _cart[product.id] = next;
      }
    });
  }

  Future<void> _openCart(List<PosProduct> products) async {
    if (_cart.isEmpty) {
      _showNotice(context.posText('商品を選択してください。'));
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => _CartSheet(
        products: products,
        quantities: Map.of(_cart),
        onQuantitiesChanged: (quantities) {
          setState(() {
            _cart
              ..clear()
              ..addAll(quantities);
          });
        },
        onCheckout: (payment, quantities) =>
            _checkout(products, payment, quantities),
      ),
    );
  }

  Future<void> _checkout(
    List<PosProduct> products,
    String paymentMethod,
    Map<String, int> quantities,
  ) async {
    if (_checkingOut) return;
    setState(() => _checkingOut = true);
    try {
      var profile = widget.profile;
      if (profile == null) {
        var user = widget.repository.auth.currentUser;
        if (user == null) {
          final authenticated = await Navigator.of(context).push<bool>(
            MaterialPageRoute<bool>(
              builder: (_) => _AuthPage(
                repository: widget.repository,
                locale: widget.locale ?? const Locale('ja'),
                onLocaleChanged: widget.onLocaleChanged ?? (_) {},
                onAuthenticated: () => Navigator.of(context).pop(true),
              ),
            ),
          );
          if (!mounted || authenticated != true) return;
          user = widget.repository.auth.currentUser;
        }
        if (user == null) {
          throw StateError('注文を確定するにはログインしてください。');
        }
        final profileSnapshot = await widget.repository.firestore
            .collection('users')
            .doc(user.uid)
            .get();
        final profileData = profileSnapshot.data();
        if (profileData == null) {
          throw StateError('アカウント情報を読み込めません');
        }
        profile = PosProfile.fromDocument(user.uid, profileData, user.email);
      }
      final orderId = await widget.repository.checkout(
        profile: profile,
        products: products,
        quantities: Map.of(quantities),
        paymentMethod: paymentMethod,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(_cart.clear);
      _showNotice(
        '${context.posText('注文を受け付けました。確認後に進みます。注文番号：')}${orderId.substring(0, 6)}',
      );
      widget.onGuestOrderComplete?.call();
    } on FirebaseException catch (error) {
      if (mounted) _showNotice(_readableError(error, context));
    } on StateError catch (error) {
      if (mounted) _showNotice(_checkoutErrorMessage(error.message, context));
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  void _showNotice(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PosProduct>>(
      stream: widget.repository.products(
        includeInactive: false,
        publicOnly: widget.profile == null,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _InlineError(
            message: _readableError(snapshot.error!, context),
            onRetry: () => setState(() {}),
          );
        }
        if (!snapshot.hasData) return const _LoadingPage();
        final allProducts = snapshot.data!;
        final filteredProducts = allProducts.where((product) {
          final query = _search.text.trim().toLowerCase();
          final matchesSearch =
              query.isEmpty ||
              product.name.toLowerCase().contains(query) ||
              product.sku.toLowerCase().contains(query);
          final matchesCategory =
              _category == 'すべて' || product.category == _category;
          return matchesSearch &&
              matchesCategory &&
              (!_inStockOnly || product.stock > 0) &&
              (!_saleOnly || product.onSale) &&
              (!_favoritesOnly ||
                  (widget.profile?.favorites.contains(product.id) ?? false));
        }).toList();
        final visibleProducts = _sortedProducts(filteredProducts);
        final showDiscovery =
            _search.text.trim().isEmpty &&
            _category == 'すべて' &&
            !_inStockOnly &&
            !_saleOnly &&
            !_favoritesOnly;
        final saleProducts =
            allProducts
                .where((product) => product.onSale && product.stock > 0)
                .toList()
              ..sort(
                (left, right) =>
                    right.discountPercent.compareTo(left.discountPercent),
              );
        final popularProducts =
            allProducts.where((product) => product.soldCount > 0).toList()
              ..sort(
                (left, right) => right.soldCount.compareTo(left.soldCount),
              );
        final newProducts =
            allProducts.where((product) => product.createdAt != null).toList()
              ..sort(
                (left, right) => right.createdAt!.compareTo(left.createdAt!),
              );
        final showDiscoverySections =
            showDiscovery &&
            (saleProducts.isNotEmpty ||
                popularProducts.isNotEmpty ||
                newProducts.isNotEmpty);
        final screenWidth = MediaQuery.sizeOf(context).width;
        final productCardMaxWidth = screenWidth < 600
            ? 180.0
            : screenWidth < 1100
            ? 260.0
            : 320.0;
        Widget productGrid({required bool nested}) => GridView.builder(
          key: ValueKey(nested ? 'nested-product-grid' : 'product-grid'),
          padding: nested
              ? EdgeInsets.zero
              : const EdgeInsets.fromLTRB(16, 8, 16, 16),
          shrinkWrap: nested,
          physics: nested ? const NeverScrollableScrollPhysics() : null,
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: productCardMaxWidth,
            mainAxisExtent: 226,
            crossAxisSpacing: 11,
            mainAxisSpacing: 11,
          ),
          itemCount: visibleProducts.length,
          itemBuilder: (context, index) {
            final product = visibleProducts[index];
            final quantity = _cart[product.id] ?? 0;
            return _ProductTile(
              product: product,
              repository: widget.repository,
              quantity: quantity,
              onAddToCart: product.stock > quantity
                  ? (amount) => _changeQuantity(product, amount)
                  : null,
              isFavorite: widget.profile?.favorites.contains(product.id),
              onToggleFavorite: widget.profile == null
                  ? null
                  : () => widget.repository.setFavorite(
                      widget.profile!.uid,
                      product.id,
                      !widget.profile!.favorites.contains(product.id),
                    ),
            );
          },
        );
        final categoryOptions = _categoryList(allProducts);
        final controls = Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final searchField = TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: context.posText('商品名・SKUで検索'),
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              );
              final categoryStrip = SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categoryOptions.length + 3,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return FilterChip(
                        key: const ValueKey('filter-in-stock'),
                        label: Text(context.posText('在庫あり')),
                        selected: _inStockOnly,
                        onSelected: (value) =>
                            setState(() => _inStockOnly = value),
                      );
                    }
                    if (index == 1) {
                      return FilterChip(
                        key: const ValueKey('filter-favorites'),
                        avatar: const Icon(Icons.favorite_rounded, size: 16),
                        label: Text(context.posText('お気に入り')),
                        selected: _favoritesOnly,
                        onSelected: widget.profile == null
                            ? null
                            : (value) => setState(() => _favoritesOnly = value),
                      );
                    }
                    if (index == 2) {
                      return FilterChip(
                        key: const ValueKey('filter-sale'),
                        avatar: const Icon(
                          Icons.local_offer_rounded,
                          size: 16,
                          color: _accent,
                        ),
                        label: Text(context.posText('セール')),
                        selected: _saleOnly,
                        onSelected: (value) =>
                            setState(() => _saleOnly = value),
                      );
                    }
                    final category = categoryOptions[index - 3];
                    return ChoiceChip(
                      label: Text(context.posText(category)),
                      selected: category == _category,
                      onSelected: (_) => setState(() => _category = category),
                    );
                  },
                ),
              );
              if (constraints.maxWidth >= 850) {
                return Row(
                  children: [
                    SizedBox(width: 360, child: searchField),
                    const SizedBox(width: 18),
                    Expanded(child: categoryStrip),
                  ],
                );
              }
              return Column(
                children: [
                  Row(children: [Expanded(child: searchField)]),
                  const SizedBox(height: 8),
                  categoryStrip,
                ],
              );
            },
          ),
        );
        final content = allProducts.isEmpty
            ? _EmptyState(
                icon: Icons.inventory_2_outlined,
                title: context.posText('商品はまだありません'),
                message: context.posText('管理者に商品を登録してもらってください。'),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showDiscoverySections) ...[
                    _StorefrontBanner(
                      name: widget.profile?.name ?? '',
                      productCount: allProducts.length,
                      categories: _categoryList(allProducts),
                      onCategory: (category) =>
                          setState(() => _category = category),
                    ),
                    const SizedBox(height: 14),
                    _DiscoveryProductSection(
                      key: const ValueKey('sale-section'),
                      title: 'セール商品',
                      products: saleProducts.take(10).toList(),
                      repository: widget.repository,
                      cart: _cart,
                      onAddToCart: _changeQuantity,
                      onSeeAll: () => setState(() => _saleOnly = true),
                    ),
                    _DiscoveryProductSection(
                      title: 'ベストセラー商品',
                      products: popularProducts.take(8).toList(),
                      repository: widget.repository,
                      cart: _cart,
                      onAddToCart: _changeQuantity,
                    ),
                    if (newProducts.isNotEmpty)
                      _DiscoveryProductSection(
                        title: '新着商品',
                        products: newProducts.take(8).toList(),
                        repository: widget.repository,
                        cart: _cart,
                        onAddToCart: _changeQuantity,
                      ),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.grid_view_rounded,
                          color: _brand,
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.posText('すべての商品'),
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${visibleProducts.length}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (visibleProducts.isEmpty)
                    _EmptyState(
                      icon: Icons.search_rounded,
                      title: context.posText('商品が見つかりません'),
                      message: context.posText('検索条件を変えてもう一度お試しください。'),
                    )
                  else
                    productGrid(nested: true),
                ],
              );
        return Column(
          children: [
            Expanded(
              child: ListView(
                key: const ValueKey('storefront-product-list'),
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  controls,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: content,
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 12,
                      offset: Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${context.posText('カート')} ${_cart.values.fold<int>(0, (quantityTotal, qty) => quantityTotal + qty)}${context.posText('点')}',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            formatYen(_cartTotal(allProducts)),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _checkingOut
                          ? null
                          : () => _openCart(allProducts),
                      style: FilledButton.styleFrom(
                        backgroundColor: _brand,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 13,
                        ),
                      ),
                      icon: const Icon(Icons.shopping_cart_checkout_rounded),
                      label: Text(context.posText('会計へ')),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProductImage extends StatelessWidget {
  const _ProductImage({
    required this.imageUrl,
    required this.category,
    required this.size,
    this.borderRadius = 18,
  });

  final String imageUrl;
  final String category;
  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final tint = _productTint(category);
    if (imageUrl.trim().isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Icon(_productIcon(category), color: tint, size: size * 0.45),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: tint.withValues(alpha: 0.14)),
          child: Icon(_productIcon(category), color: tint, size: size * 0.45),
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.repository,
    required this.quantity,
    required this.onAddToCart,
    this.isFavorite,
    this.onToggleFavorite,
    this.isDiscovery = false,
  });

  final PosProduct product;
  final PosRepository repository;
  final int quantity;
  final ValueChanged<int>? onAddToCart;
  final bool? isFavorite;
  final VoidCallback? onToggleFavorite;
  final bool isDiscovery;

  @override
  Widget build(BuildContext context) {
    final productTint = _productTint(product.category);

    void openDetails() {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => _ProductDetailPage(
            product: product,
            repository: repository,
            isAdmin: false,
            quantityInCart: quantity,
            onAddToCart: onAddToCart == null
                ? null
                : (quantity) => onAddToCart!(quantity),
          ),
        ),
      );
    }

    final soldOut = product.stock == 0;
    final canAdd = onAddToCart != null && !soldOut;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        key: ValueKey(
          'open-product-${isDiscovery ? 'discovery-' : ''}${product.id}',
        ),
        onTap: openDetails,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(color: productTint.withValues(alpha: 0.13)),
                  if (product.imageUrl.trim().isEmpty)
                    Icon(
                      _productIcon(product.category),
                      size: 46,
                      color: productTint.withValues(alpha: 0.75),
                    )
                  else
                    Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Icon(
                        _productIcon(product.category),
                        size: 46,
                        color: productTint.withValues(alpha: 0.75),
                      ),
                    ),
                  if (soldOut)
                    ColoredBox(
                      color: Colors.white.withValues(alpha: 0.6),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            context.posText('売り切れ'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surface.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        context.posText(product.category),
                        style: TextStyle(
                          color: productTint,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (product.onSale)
                    Positioned(
                      left: 8,
                      top: 30,
                      child: Container(
                        key: ValueKey('sale-badge-${product.id}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${product.discountPercent}% OFF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  if (onToggleFavorite != null)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: GestureDetector(
                        key: ValueKey('favorite-${product.id}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: onToggleFavorite,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            isFavorite == true
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 20,
                            color: isFavorite == true ? _accent : _brandDeep,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: IconButton(
                      key: ValueKey(
                        'product-details-${isDiscovery ? 'discovery-' : ''}${product.id}',
                      ),
                      tooltip: context.posText('商品詳細を表示'),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 28,
                        height: 28,
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: scheme.surface.withValues(alpha: 0.9),
                      ),
                      onPressed: openDetails,
                      icon: const Icon(Icons.info_outline_rounded, size: 17),
                    ),
                  ),
                  if (quantity > 0)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: CircleAvatar(
                        radius: 12,
                        backgroundColor: _accent,
                        child: Text(
                          '$quantity',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: _PriceText(product: product, size: 15),
                            ),
                            const SizedBox(width: 6),
                            if (!soldOut)
                              Text(
                                product.stock <= 5
                                    ? context.posText('在庫少')
                                    : '${context.posText('在庫')} ${product.stock}',
                                style: TextStyle(
                                  color: product.stock <= 5
                                      ? _accent
                                      : scheme.onSurfaceVariant,
                                  fontSize: 9,
                                  fontWeight: product.stock <= 5
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: ValueKey('quick-add-${product.id}'),
                    tooltip: context.posText('カートに追加'),
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      backgroundColor: canAdd ? _brand : null,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: canAdd ? () => onAddToCart!(1) : null,
                    icon: const Icon(Icons.add_rounded, size: 20),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _customTints = [
  Color(0xFF7A5C8E),
  Color(0xFF4F7F5A),
  Color(0xFFA3693F),
  Color(0xFF5A6E9E),
  Color(0xFF9A4A62),
];

Color _productTint(String category) => switch (category) {
  '食品' => const Color(0xFFB5573A),
  '飲料' => const Color(0xFF3F6F86),
  '日用品' => const Color(0xFF8A7A55),
  'その他' => _brand,
  _ =>
    _customTints[category.codeUnits.fold<int>(0, (a, b) => a + b) %
        _customTints.length],
};

IconData _productIcon(String category) => switch (category) {
  '食品' => Icons.bakery_dining_rounded,
  '飲料' => Icons.local_cafe_rounded,
  '日用品' => Icons.spa_rounded,
  _ => Icons.inventory_2_rounded,
};

class _StorefrontBanner extends StatelessWidget {
  const _StorefrontBanner({
    required this.name,
    required this.productCount,
    required this.categories,
    required this.onCategory,
  });

  final String name;
  final int productCount;
  final List<String> categories;
  final ValueChanged<String> onCategory;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'おはようございます';
    if (hour < 18) return 'こんにちは';
    return 'こんばんは';
  }

  @override
  Widget build(BuildContext context) {
    final greeting = context.posText(_greeting());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(36),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(36),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(22, 20, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_brandDeep, Color(0xFF35608C), Color(0xFF5B7FA8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -24,
                  top: -30,
                  child: Icon(
                    Icons.forest_rounded,
                    size: 170,
                    color: Colors.white.withValues(alpha: 0.09),
                  ),
                ),
                Positioned(
                  right: 70,
                  bottom: -34,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _accent.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MORI  ·  DAILY MARKET',
                      style: TextStyle(
                        color: const Color(0xFFF4D19A).withValues(alpha: 0.96),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      name.isEmpty ? greeting : '$greeting、$name',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.posText('森から届く、今日のお気に入り。'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$productCount ${context.posText('点の商品')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Builder(
          builder: (context) {
            final names = categories.skip(1).toList();
            Widget tile(String category) => InkWell(
              key: ValueKey('home-category-$category'),
              borderRadius: BorderRadius.circular(8),
              onTap: () => onCategory(category),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _productTint(category).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(_productIcon(category), color: _productTint(category)),
                    const SizedBox(height: 5),
                    Text(
                      context.posText(category),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _productTint(category),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            );
            if (names.length <= 4) {
              return Row(
                children: [
                  for (var i = 0; i < names.length; i++) ...[
                    Expanded(child: tile(names[i])),
                    if (i != names.length - 1) const SizedBox(width: 8),
                  ],
                ],
              );
            }
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final name in names) ...[
                    SizedBox(width: 84, child: tile(name)),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DiscoveryProductSection extends StatelessWidget {
  const _DiscoveryProductSection({
    super.key,
    this.onSeeAll,
    required this.title,
    required this.products,
    required this.repository,
    required this.cart,
    required this.onAddToCart,
  });

  final VoidCallback? onSeeAll;
  final String title;
  final List<PosProduct> products;
  final PosRepository repository;
  final Map<String, int> cart;
  final void Function(PosProduct, int) onAddToCart;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 10),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: _accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 9),
              Text(
                context.posText(title),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              if (onSeeAll != null)
                InkWell(
                  key: const ValueKey('see-all-sale'),
                  onTap: onSeeAll,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: _brand,
                    ),
                  ),
                )
              else
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: _brand,
                ),
            ],
          ),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: products.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final product = products[index];
              final quantity = cart[product.id] ?? 0;
              return SizedBox(
                width: 190,
                child: _ProductTile(
                  product: product,
                  repository: repository,
                  isDiscovery: true,
                  quantity: quantity,
                  onAddToCart: product.stock > quantity
                      ? (amount) => onAddToCart(product, amount)
                      : null,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ProductDetailPage extends StatefulWidget {
  const _ProductDetailPage({
    required this.product,
    required this.repository,
    required this.isAdmin,
    this.quantityInCart = 0,
    this.onAddToCart,
    this.onEdit,
  });

  final PosProduct product;
  final PosRepository repository;
  final bool isAdmin;
  final int quantityInCart;
  final ValueChanged<int>? onAddToCart;
  final VoidCallback? onEdit;

  @override
  State<_ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<_ProductDetailPage> {
  late int _quantityToAdd;

  int get _remainingStock => (widget.product.stock - widget.quantityInCart)
      .clamp(0, widget.product.stock);

  @override
  void initState() {
    super.initState();
    _quantityToAdd = _remainingStock > 0 ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final isAdmin = widget.isAdmin;
    final canAddToCart =
        product.active && _remainingStock > 0 && widget.onAddToCart != null;
    final stockColor = product.stock == 0
        ? const Color(0xFFB8372A)
        : product.stock <= 5
        ? const Color(0xFFE28B18)
        : _brand;
    return Scaffold(
      appBar: AppBar(title: Text(context.posText('商品詳細'))),
      bottomNavigationBar: isAdmin && widget.onEdit != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  key: const ValueKey('edit-product-detail'),
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(context.posText('商品を編集')),
                  style: FilledButton.styleFrom(
                    backgroundColor: _brand,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            )
          : widget.onAddToCart == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton.icon(
                  key: const ValueKey('add-product-detail-to-cart'),
                  onPressed: canAddToCart
                      ? () {
                          Navigator.of(context).pop();
                          widget.onAddToCart!(_quantityToAdd);
                        }
                      : null,
                  icon: const Icon(Icons.add_shopping_cart_rounded),
                  label: Text(context.posText('カートに追加')),
                  style: FilledButton.styleFrom(
                    backgroundColor: _brand,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),
      body: ListView(
        cacheExtent: 3000, // ignore: deprecated_member_use
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 280,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ColoredBox(
                    color: _productTint(
                      product.category,
                    ).withValues(alpha: 0.13),
                  ),
                  if (product.imageUrl.trim().isEmpty)
                    Center(
                      child: Icon(
                        _productIcon(product.category),
                        size: 96,
                        color: _productTint(
                          product.category,
                        ).withValues(alpha: 0.7),
                      ),
                    )
                  else
                    Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Center(
                        child: Icon(
                          _productIcon(product.category),
                          size: 96,
                          color: _productTint(product.category),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        context.posText(product.category),
                        style: TextStyle(
                          color: _productTint(product.category),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (product.stock == 0 || !product.active)
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          context.posText(product.active ? '売り切れ' : '販売停止'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'SKU ${product.sku}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            product.name,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatYen(product.price),
                style: TextStyle(
                  color: product.onSale ? _accent : _brandDeep,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (product.onSale) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    formatYen(product.originalPrice),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    key: const ValueKey('detail-sale-badge'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: _accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${product.discountPercent}% OFF',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  context.posText('税込'),
                  style: const TextStyle(fontSize: 11),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: stockColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 8, color: stockColor),
                    const SizedBox(width: 6),
                    Text(
                      context.posText(
                        product.stock == 0
                            ? '在庫切れ'
                            : product.stock <= 5
                            ? '在庫わずか'
                            : '在庫あり',
                      ),
                      style: TextStyle(
                        color: stockColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 28),
          if (!isAdmin && widget.onAddToCart != null) ...[
            _DashboardPanel(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.posText('追加する数量'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${context.posText('カートに追加可能な在庫')}: $_remainingStock${context.posText('点')}',
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${context.posText('小計')}: ${formatYen(product.price * _quantityToAdd)}',
                          key: const ValueKey('detail-subtotal'),
                          style: const TextStyle(
                            color: _brand,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('decrease-detail-quantity'),
                    tooltip: context.posText('数量を減らす'),
                    onPressed: _quantityToAdd > 1
                        ? () => setState(() => _quantityToAdd--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                  SizedBox(
                    width: 34,
                    child: Text(
                      '$_quantityToAdd',
                      key: const ValueKey('detail-quantity'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('increase-detail-quantity'),
                    tooltip: context.posText('数量を増やす'),
                    onPressed: canAddToCart && _quantityToAdd < _remainingStock
                        ? () => setState(() => _quantityToAdd++)
                        : null,
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          _DashboardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.posText('商品情報'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _OrderInfoRow(
                  label: context.posText('商品コード'),
                  value: product.sku,
                ),
                const SizedBox(height: 12),
                _OrderInfoRow(
                  label: context.posText('カテゴリー'),
                  value: context.posText(product.category),
                ),
                const SizedBox(height: 12),
                _OrderInfoRow(
                  label: context.posText('在庫数'),
                  value: '${product.stock}${context.posText('点')}',
                ),
                const SizedBox(height: 12),
                _OrderInfoRow(
                  label: context.posText('販売状態'),
                  value: context.posText(product.active ? '販売中' : '販売停止'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          _ProductCommentsSection(
            repository: widget.repository,
            product: product,
            locale: Localizations.localeOf(context),
          ),
        ],
      ),
    );
  }
}

class _ProductCommentsSection extends StatefulWidget {
  const _ProductCommentsSection({
    required this.repository,
    required this.product,
    required this.locale,
  });

  final PosRepository repository;
  final PosProduct product;
  final Locale locale;

  @override
  State<_ProductCommentsSection> createState() =>
      _ProductCommentsSectionState();
}

class _ProductCommentsSectionState extends State<_ProductCommentsSection> {
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_submitting) return;
    final text = _commentController.text.trim();
    if (text.isEmpty || text.length > 500) {
      _showMessage(context.posText('コメントは1〜500文字で入力してください。'));
      return;
    }
    if (widget.repository.auth.currentUser == null) {
      final authenticated = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => _AuthPage(
            repository: widget.repository,
            locale: widget.locale,
            onLocaleChanged: (_) {},
            onAuthenticated: () => Navigator.of(context).pop(true),
          ),
        ),
      );
      if (!mounted || authenticated != true) return;
    }
    setState(() => _submitting = true);
    try {
      await widget.repository.addProductComment(
        productId: widget.product.id,
        text: text,
      );
      if (!mounted) return;
      _commentController.clear();
      _showMessage(context.posText('コメントを投稿しました。'));
    } on FirebaseException catch (error) {
      if (mounted) _showMessage(_readableError(error, context));
    } on StateError catch (error) {
      if (mounted) _showMessage(context.posText(error.message));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final signedIn = widget.repository.auth.currentUser != null;
    return _DashboardPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.posText('コメント'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            context.posText('コメントはすべての利用者に公開されます。'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('product-comment-input'),
            controller: _commentController,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: context.posText('コメントを入力'),
              border: const OutlineInputBorder(),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.tonalIcon(
              key: const ValueKey('submit-product-comment'),
              onPressed: _submitting ? null : _submitComment,
              icon: Icon(
                signedIn ? Icons.send_rounded : Icons.login_rounded,
                size: 18,
              ),
              label: Text(context.posText(signedIn ? 'コメントを投稿' : 'ログインしてコメント')),
            ),
          ),
          const Divider(height: 24),
          StreamBuilder<List<PosProductComment>>(
            stream: widget.repository.productComments(widget.product.id),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  _readableError(snapshot.error!, context),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                );
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.data!.isEmpty) {
                return Text(
                  context.posText('コメントはまだありません。'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Column(
                children: [
                  for (final comment in snapshot.data!)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: _brandWash,
                        child: Icon(
                          Icons.person_outline_rounded,
                          color: _brand,
                        ),
                      ),
                      title: Text(
                        comment.authorName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(comment.text),
                      ),
                      trailing: comment.createdAt == null
                          ? null
                          : Text(
                              MaterialLocalizations.of(
                                context,
                              ).formatShortDate(comment.createdAt!),
                              style: TextStyle(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                fontSize: 10,
                              ),
                            ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CartSheet extends StatefulWidget {
  const _CartSheet({
    required this.products,
    required this.quantities,
    required this.onQuantitiesChanged,
    required this.onCheckout,
  });

  final List<PosProduct> products;
  final Map<String, int> quantities;
  final ValueChanged<Map<String, int>> onQuantitiesChanged;
  final void Function(String payment, Map<String, int> quantities) onCheckout;

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  late final Map<String, int> _quantities;
  String _payment = '現金';

  @override
  void initState() {
    super.initState();
    _quantities = Map.of(widget.quantities);
  }

  int get _total => widget.products.fold<int>(
    0,
    (amount, product) =>
        amount + product.price * (_quantities[product.id] ?? 0),
  );

  void _changeQuantity(PosProduct product, int change) {
    setState(() {
      final next = (_quantities[product.id] ?? 0) + change;
      if (next <= 0) {
        _quantities.remove(product.id);
      } else if (next <= product.stock) {
        _quantities[product.id] = next;
      }
      widget.onQuantitiesChanged(Map.of(_quantities));
    });
  }

  void _removeProduct(PosProduct product) {
    setState(() => _quantities.remove(product.id));
    widget.onQuantitiesChanged(Map.of(_quantities));
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.products
        .where((product) => _quantities.containsKey(product.id))
        .toList();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.posText('お会計'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 13),
            if (lines.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: Text(
                    context.posText('カートに商品がありません。'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final product in lines)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  key: ValueKey('remove-cart-${product.id}'),
                                  tooltip: context.posText('商品をカートから削除'),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _removeProduct(product),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Color(0xFFD74747),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  key: ValueKey('decrease-cart-${product.id}'),
                                  tooltip: context.posText('数量を減らす'),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _changeQuantity(product, -1),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text(
                                  '${_quantities[product.id]}${context.posText('点')}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                IconButton(
                                  key: ValueKey('increase-cart-${product.id}'),
                                  tooltip: context.posText('数量を増やす'),
                                  visualDensity: VisualDensity.compact,
                                  onPressed:
                                      _quantities[product.id]! < product.stock
                                      ? () => _changeQuantity(product, 1)
                                      : null,
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  formatYen(
                                    product.price * _quantities[product.id]!,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.posText('合計（税込）'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  formatYen(_total),
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: '現金',
                  icon: Icon(Icons.payments_outlined),
                  label: Text(context.posText('現金')),
                ),
                ButtonSegment(
                  value: 'カード',
                  icon: Icon(Icons.credit_card_outlined),
                  label: Text(context.posText('カード')),
                ),
              ],
              selected: {_payment},
              onSelectionChanged: (selection) =>
                  setState(() => _payment = selection.first),
            ),
            const SizedBox(height: 10),
            Text(
              context.posText('支払い方法を記録します。カード決済端末への接続は含まれません。'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: lines.isEmpty
                    ? null
                    : () => widget.onCheckout(_payment, Map.of(_quantities)),
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: Text(context.posText('注文を確定する')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminDashboardPage extends StatelessWidget {
  const _AdminDashboardPage({required this.repository, required this.profile});

  final PosRepository repository;
  final PosProfile profile;

  Future<void> _rebuildBestSellerCounts(
    BuildContext context, {
    required List<PosOrder> orders,
    required List<PosProduct> products,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.posText('ベストセラーを再集計')),
        content: Text(
          context.posText('過去の完了済み注文から販売数を再集計します。処理中は会計と注文キャンセルを停止してください。'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.posText('キャンセル')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.posText('再集計')),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;

    try {
      final updatedProducts = await repository.rebuildProductSalesCounts(
        profile: profile,
        orders: orders,
        products: products,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.posText('販売数を再集計しました。')} '
            '($updatedProducts${context.posText('点')})',
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_readableError(error, context))));
    } on StateError catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.posText(error.message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PosProduct>>(
      stream: repository.products(includeInactive: true),
      builder: (context, productsSnapshot) {
        if (productsSnapshot.hasError) {
          return _InlineError(
            message: _readableError(productsSnapshot.error!, context),
          );
        }
        if (!productsSnapshot.hasData) return const _LoadingPage();
        final products = productsSnapshot.data!;
        final activeProducts = products
            .where((product) => product.active)
            .length;
        final lowStock = products
            .where((product) => product.active && product.stock <= 5)
            .length;
        return StreamBuilder<List<PosOrder>>(
          stream: repository.orders(
            profile: const PosProfile(
              uid: '',
              name: '',
              email: '',
              role: 'admin',
            ),
          ),
          builder: (context, ordersSnapshot) {
            if (ordersSnapshot.hasError) {
              return _InlineError(
                message: _readableError(ordersSnapshot.error!, context),
              );
            }
            if (!ordersSnapshot.hasData) return const _LoadingPage();
            final orders = ordersSnapshot.data!;
            final today = DateTime.now();
            final todayStart = DateTime(today.year, today.month, today.day);
            final monthStart = DateTime(today.year, today.month);
            final todaysOrders = orders
                .where(
                  (order) =>
                      _countsAsSale(order.status) &&
                      order.createdAt != null &&
                      !order.createdAt!.isBefore(todayStart) &&
                      order.createdAt!.isBefore(
                        todayStart.add(const Duration(days: 1)),
                      ),
                )
                .toList();
            final revenue = todaysOrders.fold<int>(
              0,
              (amount, order) => amount + order.total,
            );
            final monthlyOrders = orders
                .where(
                  (order) =>
                      _countsAsSale(order.status) &&
                      order.createdAt != null &&
                      !order.createdAt!.isBefore(monthStart),
                )
                .toList();
            final monthlyRevenue = monthlyOrders.fold<int>(
              0,
              (amount, order) => amount + order.total,
            );
            final averageOrder = monthlyOrders.isEmpty
                ? 0
                : (monthlyRevenue / monthlyOrders.length).round();
            final soldUnits = monthlyOrders.fold<int>(
              0,
              (total, order) => total + _orderItemCount(order),
            );
            final cashRevenue = todaysOrders
                .where((order) => order.paymentMethod == '現金')
                .fold<int>(0, (total, order) => total + order.total);
            final cardRevenue = todaysOrders
                .where((order) => order.paymentMethod == 'カード')
                .fold<int>(0, (total, order) => total + order.total);
            final dailySales = List.generate(7, (index) {
              final day = DateTime(
                todayStart.year,
                todayStart.month,
                todayStart.day - 6 + index,
              );
              final total = orders
                  .where(
                    (order) =>
                        _countsAsSale(order.status) &&
                        order.createdAt != null &&
                        !order.createdAt!.isBefore(day) &&
                        order.createdAt!.isBefore(
                          day.add(const Duration(days: 1)),
                        ),
                  )
                  .fold<int>(
                    0,
                    (accumulated, order) => accumulated + order.total,
                  );
              return (day: day, total: total);
            });
            final bestSellers =
                products.where((product) => product.soldCount > 0).toList()
                  ..sort(
                    (left, right) => right.soldCount.compareTo(left.soldCount),
                  );
            final lowStockProducts =
                products
                    .where((product) => product.active && product.stock <= 5)
                    .toList()
                  ..sort((left, right) => left.stock.compareTo(right.stock));
            return ListView(
              key: const ValueKey('admin-sales-list'),
              padding: const EdgeInsets.all(16),
              children: [
                _welcomeCard(context),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) => GridView.count(
                    crossAxisCount: _dashboardColumnCount(constraints.maxWidth),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.65,
                    children: [
                      _MetricCard(
                        label: context.posText('本日の売上'),
                        value: formatYen(revenue),
                        icon: Icons.payments_outlined,
                        color: const Color(0xFF1D9B67),
                      ),
                      _MetricCard(
                        label: context.posText('本日の注文'),
                        value: '${todaysOrders.length}${context.posText('件')}',
                        icon: Icons.receipt_long_outlined,
                        color: _brand,
                      ),
                      _MetricCard(
                        label: context.posText('販売中の商品'),
                        value: '$activeProducts${context.posText('点')}',
                        icon: Icons.inventory_2_outlined,
                        color: _accent,
                      ),
                      _MetricCard(
                        label: context.posText('在庫わずか'),
                        value: '$lowStock${context.posText('点')}',
                        icon: Icons.warning_amber_rounded,
                        color: lowStock > 0 ? const Color(0xFFE28B18) : _brand,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: context.posText('今月の売上'),
                        value: formatYen(monthlyRevenue),
                        icon: Icons.calendar_month_outlined,
                        color: _brand,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        label: context.posText('平均客単価'),
                        value: formatYen(averageOrder),
                        icon: Icons.trending_up_rounded,
                        color: const Color(0xFF1D9B67),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                _PageHeading(
                  title: context.posText('過去7日間の売上'),
                  subtitle:
                      '${context.posText('今月の販売点数')}: $soldUnits${context.posText('点')}',
                ),
                const SizedBox(height: 10),
                _DashboardPanel(
                  child: _WeeklySalesChart(
                    sales: dailySales,
                    emptyLabel: context.posText('売上データがありません'),
                  ),
                ),
                const SizedBox(height: 18),
                _PageHeading(
                  title: context.posText('本日の支払い内訳'),
                  subtitle: context.posText('本日の売上'),
                ),
                const SizedBox(height: 10),
                _DashboardPanel(
                  child: Column(
                    children: [
                      _PaymentBreakdownRow(
                        label: context.posText('現金'),
                        amount: cashRevenue,
                        total: revenue,
                        color: const Color(0xFF1D9B67),
                      ),
                      const SizedBox(height: 14),
                      _PaymentBreakdownRow(
                        label: context.posText('カード'),
                        amount: cardRevenue,
                        total: revenue,
                        color: _brand,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _PageHeading(
                  title: context.posText('最も販売された商品'),
                  subtitle: context.posText('累計販売数'),
                ),
                const SizedBox(height: 10),
                _DashboardPanel(
                  child: Column(
                    children: [
                      if (bestSellers.isEmpty)
                        Text(
                          context.posText('販売数がまだありません'),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        )
                      else
                        for (
                          var index = 0;
                          index < bestSellers.length && index < 10;
                          index++
                        )
                          Padding(
                            key: ValueKey(
                              'most-sold-product-${bestSellers[index].id}',
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 13,
                                  backgroundColor: _brandWash,
                                  child: Text(
                                    '${index + 1}',
                                    style: const TextStyle(
                                      color: _brand,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    bestSellers[index].name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${bestSellers[index].soldCount}${context.posText('点')}',
                                  style: const TextStyle(
                                    color: _brand,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          key: const ValueKey('rebuild-best-seller-counts'),
                          onPressed: () => _rebuildBestSellerCounts(
                            context,
                            orders: orders,
                            products: products,
                          ),
                          icon: const Icon(Icons.sync_rounded, size: 18),
                          label: Text(context.posText('ベストセラーを再集計')),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _PageHeading(
                  title: context.posText('在庫アラート'),
                  subtitle: context.posText('在庫わずか'),
                ),
                const SizedBox(height: 10),
                _DashboardPanel(
                  child: lowStockProducts.isEmpty
                      ? Text(
                          context.posText('在庫に注意が必要な商品はありません'),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        )
                      : Column(
                          children: [
                            for (final product in lowStockProducts.take(5))
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      product.stock == 0
                                          ? Icons.error_outline_rounded
                                          : Icons.warning_amber_rounded,
                                      color: product.stock == 0
                                          ? const Color(0xFFD74747)
                                          : const Color(0xFFE28B18),
                                      size: 19,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        product.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${context.posText('在庫')} ${product.stock}${context.posText('点')}',
                                      style: TextStyle(
                                        color: product.stock == 0
                                            ? const Color(0xFFD74747)
                                            : const Color(0xFFE28B18),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 22),
                _PageHeading(
                  title: context.posText('最近の注文'),
                  subtitle: context.posText('注文の記録はFirebaseに保存されます'),
                ),
                const SizedBox(height: 10),
                if (orders.isEmpty)
                  _EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: context.posText('注文はまだありません'),
                    message: context.posText('レジで最初の会計を行うと、ここに表示されます。'),
                  )
                else
                  for (final order in orders.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _OrderCard(
                        order: order,
                        showUser: true,
                        repository: repository,
                        profile: profile,
                      ),
                    ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _welcomeCard(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_brandDeep, Color(0xFF30567F)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -32,
              child: Icon(
                Icons.forest_rounded,
                size: 148,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MORI  /  DAILY STORE REPORT',
                        style: TextStyle(
                          color: const Color(
                            0xFFF4D19A,
                          ).withValues(alpha: 0.96),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 13),
                      Text(
                        context.posText('お店の状況'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        context.posText('今日もお疲れさまです'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4D19A).withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF4D19A).withValues(alpha: 0.24),
                    ),
                  ),
                  child: const Icon(
                    Icons.eco_rounded,
                    color: Color(0xFFF4D19A),
                    size: 29,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

int _orderItemCount(PosOrder order) {
  return order.items.fold<int>(
    0,
    (total, item) => total + ((item['quantity'] as num?)?.toInt() ?? 0),
  );
}

class _DashboardPanel extends StatelessWidget {
  const _DashboardPanel({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: child,
    );
  }
}

class _WeeklySalesChart extends StatelessWidget {
  const _WeeklySalesChart({required this.sales, required this.emptyLabel});

  final List<({DateTime day, int total})> sales;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final maximum = sales.fold<int>(
      0,
      (current, sale) => sale.total > current ? sale.total : current,
    );
    if (maximum == 0) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            emptyLabel,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final sale in sales)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (sale.total > 0)
                      Text(
                        _compactYen(sale.total),
                        maxLines: 1,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 8,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      height: sale.total == 0 ? 3 : 76 * sale.total / maximum,
                      decoration: BoxDecoration(
                        color: sale.total == maximum
                            ? _brand
                            : const Color(0xFF9DB6D0),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${sale.day.month}/${sale.day.day}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _compactYen(int amount) {
    if (amount >= 1000000) return '¥${(amount / 1000000).toStringAsFixed(1)}M';
    if (amount >= 10000) return '¥${(amount / 1000).round()}k';
    return '¥$amount';
  }
}

class _PaymentBreakdownRow extends StatelessWidget {
  const _PaymentBreakdownRow({
    required this.label,
    required this.amount,
    required this.total,
    required this.color,
  });

  final String label;
  final int amount;
  final int total;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final share = total == 0 ? 0.0 : amount / total;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              formatYen(amount),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 8),
            Text(
              '${(share * 100).round()}%',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: LinearProgressIndicator(
            value: share,
            minHeight: 7,
            color: color,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest,
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(height: 7),
          Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeading extends StatelessWidget {
  const _PageHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 4,
              height: 38,
              margin: const EdgeInsets.only(top: 2, right: 10),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AdminProductsPage extends StatefulWidget {
  const _AdminProductsPage({required this.repository});

  final PosRepository repository;

  @override
  State<_AdminProductsPage> createState() => _AdminProductsPageState();
}

class _AdminProductsPageState extends State<_AdminProductsPage> {
  String _query = '';
  String _category = _categories.first;
  String _stockFilter = 'all';
  String _sort = 'name';
  final Set<String> _selected = {};

  Future<void> _bulk(
    BuildContext context,
    List<PosProduct> products,
    PosProduct Function(PosProduct) change,
  ) async {
    final targets = products.where((p) => _selected.contains(p.id)).toList();
    try {
      for (final p in targets) {
        final n = change(p);
        await widget.repository.saveProduct(
          id: p.id,
          name: n.name,
          sku: n.sku,
          category: n.category,
          price: n.regularPrice,
          discountPercent: n.discountPercent,
          stock: n.stock,
          active: n.active,
          imageUrl: n.imageUrl,
        );
      }
      if (mounted) setState(_selected.clear);
    } on FirebaseException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_readableError(error, context))));
      }
    }
  }

  PosProduct _copy(PosProduct p, {int? stock, bool? active, int? discount}) =>
      PosProduct(
        id: p.id,
        name: p.name,
        sku: p.sku,
        category: p.category,
        price: applyDiscount(p.regularPrice, discount ?? p.discountPercent),
        originalPrice: (discount ?? p.discountPercent) > 0 ? p.regularPrice : 0,
        discountPercent: discount ?? p.discountPercent,
        stock: stock ?? p.stock,
        active: active ?? p.active,
        soldCount: p.soldCount,
        createdAt: p.createdAt,
        imageUrl: p.imageUrl,
      );

  Future<void> _duplicate(BuildContext context, PosProduct p) async {
    try {
      await widget.repository.saveProduct(
        name: '${p.name} (copy)',
        sku: '${p.sku}-COPY',
        category: p.category,
        price: p.regularPrice,
        discountPercent: p.discountPercent,
        stock: 0,
        active: false,
        imageUrl: p.imageUrl,
      );
    } on FirebaseException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_readableError(error, context))));
      }
    } on StateError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.posText(error.message))));
      }
    }
  }

  Future<void> _discountOne(BuildContext context, PosProduct p) async {
    final percent = await showDialog<int>(
      context: context,
      builder: (_) => _DiscountDialog(initial: p.discountPercent),
    );
    if (percent == null || !context.mounted) return;
    _selected
      ..clear()
      ..add(p.id);
    await _bulk(context, [p], (x) => _copy(x, discount: percent));
  }

  Future<void> _discountSelected(
    BuildContext context,
    List<PosProduct> products,
  ) async {
    final percent = await showDialog<int>(
      context: context,
      builder: (_) => const _DiscountDialog(initial: 0),
    );
    if (percent == null || !context.mounted) return;
    await _bulk(context, products, (x) => _copy(x, discount: percent));
  }

  Future<void> _toggleOne(BuildContext context, PosProduct p) async {
    _selected
      ..clear()
      ..add(p.id);
    await _bulk(context, [p], (x) => _copy(x, active: !x.active));
  }

  Future<void> _editProduct(BuildContext context, [PosProduct? product]) async {
    final existing = await widget.repository
        .products(includeInactive: true)
        .first;
    if (!context.mounted) return;
    final result = await showDialog<_ProductFormResult>(
      context: context,
      builder: (context) => _ProductEditor(
        product: product,
        repository: widget.repository,
        categories: _categoryList(existing).skip(1).toList(),
      ),
    );
    if (result == null) return;
    try {
      await widget.repository.saveProduct(
        id: product?.id,
        name: result.name,
        sku: result.sku,
        category: result.category,
        price: result.price,
        discountPercent: result.discountPercent,
        stock: result.stock,
        active: result.active,
        imageUrl: result.imageUrl,
      );
    } on FirebaseException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.posText('商品を保存できませんでした：')}${_readableError(error, context)}',
            ),
          ),
        );
      }
    } on StateError catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.posText(error.message))));
      }
    }
  }

  Future<void> _adjustStock(
    BuildContext context,
    PosProduct product,
    int delta,
  ) async {
    final nextStock = (product.stock + delta).clamp(0, 999999);
    try {
      await widget.repository.saveProduct(
        id: product.id,
        name: product.name,
        sku: product.sku,
        category: product.category,
        price: product.regularPrice,
        discountPercent: product.discountPercent,
        stock: nextStock,
        active: product.active,
        imageUrl: product.imageUrl,
      );
    } on FirebaseException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_readableError(error, context))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editProduct(context),
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(context.posText('商品を追加')),
      ),
      body: StreamBuilder<List<PosProduct>>(
        stream: widget.repository.products(includeInactive: true),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _InlineError(
              message: _readableError(snapshot.error!, context),
            );
          }
          if (!snapshot.hasData) return const _LoadingPage();
          final products = snapshot.data!;
          if (products.isEmpty) {
            return _EmptyState(
              icon: Icons.inventory_2_outlined,
              title: context.posText('商品を登録しましょう'),
              message: context.posText('商品名・SKU・税込価格・在庫数を登録すると、レジに表示されます。'),
            );
          }
          final needle = _query.trim().toLowerCase();
          final shown = products.where((p) {
            if (_category != _categories.first && p.category != _category) {
              return false;
            }
            switch (_stockFilter) {
              case 'low':
                if (!(p.stock > 0 && p.stock <= 5)) return false;
              case 'out':
                if (p.stock != 0) return false;
              case 'inactive':
                if (p.active) return false;
              case 'sale':
                if (!p.onSale) return false;
            }
            return needle.isEmpty ||
                p.name.toLowerCase().contains(needle) ||
                p.sku.toLowerCase().contains(needle);
          }).toList();
          shown.sort((a, b) {
            switch (_sort) {
              case 'stock':
                return a.stock.compareTo(b.stock);
              case 'priceHigh':
                return b.price.compareTo(a.price);
              case 'sold':
                return b.soldCount.compareTo(a.soldCount);
              default:
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            }
          });
          final lowCount = products
              .where((p) => p.stock > 0 && p.stock <= 5)
              .length;
          final outCount = products.where((p) => p.stock == 0).length;
          final inactiveCount = products.where((p) => !p.active).length;
          final saleCount = products.where((p) => p.onSale).length;
          final stockValue = products.fold<int>(
            0,
            (total, p) => total + p.price * p.stock,
          );
          Widget filterChip(String key, String label) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: ValueKey('admin-filter-$key'),
              label: Text(label),
              selected: _stockFilter == key,
              onSelected: (_) => setState(() => _stockFilter = key),
            ),
          );
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
            itemCount: shown.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        for (final stat in [
                          ('商品数', '${products.length}'),
                          ('在庫わずか', '$lowCount'),
                          ('在庫なし', '$outCount'),
                          ('在庫金額', formatYen(stockValue)),
                        ])
                          Expanded(
                            child: Card(
                              margin: const EdgeInsets.only(right: 6),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 8,
                                ),
                                child: Column(
                                  children: [
                                    FittedBox(
                                      child: Text(
                                        stat.$2,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    FittedBox(
                                      child: Text(
                                        context.posText(stat.$1),
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_selected.isNotEmpty)
                      Card(
                        color: _brand.withValues(alpha: 0.1),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${_selected.length}${context.posText('件選択中')}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              OutlinedButton(
                                key: const ValueKey('bulk-activate'),
                                onPressed: () => _bulk(
                                  context,
                                  products,
                                  (p) => _copy(p, active: true),
                                ),
                                child: Text(context.posText('販売中にする')),
                              ),
                              OutlinedButton(
                                key: const ValueKey('bulk-deactivate'),
                                onPressed: () => _bulk(
                                  context,
                                  products,
                                  (p) => _copy(p, active: false),
                                ),
                                child: Text(context.posText('販売停止にする')),
                              ),
                              OutlinedButton(
                                key: const ValueKey('bulk-discount'),
                                onPressed: () =>
                                    _discountSelected(context, products),
                                child: Text(context.posText('割引を設定')),
                              ),
                              OutlinedButton(
                                key: const ValueKey('bulk-stock'),
                                onPressed: () => _bulk(
                                  context,
                                  products,
                                  (p) => _copy(p, stock: p.stock + 10),
                                ),
                                child: Text(context.posText('在庫+10')),
                              ),
                              TextButton(
                                onPressed: () => setState(_selected.clear),
                                child: Text(context.posText('選択解除')),
                              ),
                            ],
                          ),
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('admin-product-search'),
                            onChanged: (v) => setState(() => _query = v),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.search_rounded),
                              hintText: context.posText('商品名・SKUで検索'),
                              isDense: true,
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          key: const ValueKey('admin-sort'),
                          tooltip: context.posText('並び替え'),
                          icon: const Icon(Icons.sort_rounded),
                          initialValue: _sort,
                          onSelected: (v) => setState(() => _sort = v),
                          itemBuilder: (_) => [
                            for (final e in const {
                              'name': '名前順',
                              'stock': '在庫の少ない順',
                              'priceHigh': '価格の高い順',
                              'sold': '売れ筋順',
                            }.entries)
                              PopupMenuItem(
                                value: e.key,
                                child: Text(context.posText(e.value)),
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          filterChip('all', context.posText('すべて')),
                          filterChip(
                            'low',
                            '${context.posText('在庫わずか')} $lowCount',
                          ),
                          filterChip(
                            'out',
                            '${context.posText('在庫なし')} $outCount',
                          ),
                          filterChip(
                            'inactive',
                            '${context.posText('販売停止')} $inactiveCount',
                          ),
                          filterChip(
                            'sale',
                            '${context.posText('セール中')} $saleCount',
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ActionChip(
                              key: const ValueKey('admin-select-all'),
                              avatar: const Icon(
                                Icons.select_all_rounded,
                                size: 16,
                              ),
                              label: Text(context.posText('表示中を全選択')),
                              onPressed: () => setState(() {
                                _selected
                                  ..clear()
                                  ..addAll(shown.map((p) => p.id));
                              }),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final c in _categoryList(products))
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(context.posText(c)),
                                selected: _category == c,
                                onSelected: (_) =>
                                    setState(() => _category = c),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (shown.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(context.posText('該当する商品がありません')),
                        ),
                      ),
                  ],
                );
              }
              final product = shown[index - 1];
              final selected = _selected.contains(product.id);
              final scheme = Theme.of(context).colorScheme;
              final statusColor = !product.active
                  ? Colors.grey
                  : product.stock == 0
                  ? const Color(0xFFB8372A)
                  : product.stock <= 5
                  ? const Color(0xFFE28B18)
                  : const Color(0xFF1D9B67);
              void toggleSelect() => setState(() {
                if (!_selected.remove(product.id)) _selected.add(product.id);
              });
              Widget tag(String text, Color color) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
              return Material(
                color: selected ? _brandWash : scheme.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: selected ? _brand : Theme.of(context).dividerColor,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: InkWell(
                  onLongPress: toggleSelect,
                  onTap: _selected.isNotEmpty
                      ? toggleSelect
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => _ProductDetailPage(
                              product: product,
                              repository: widget.repository,
                              isAdmin: true,
                              onEdit: () {
                                Navigator.of(context).pop();
                                _editProduct(context, product);
                              },
                            ),
                          ),
                        ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(width: 5, color: statusColor),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 4, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Opacity(
                                      opacity: product.active ? 1 : 0.5,
                                      child: _ProductImage(
                                        imageUrl: product.imageUrl,
                                        category: product.category,
                                        size: 60,
                                        borderRadius: 6,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'SKU ${product.sku}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: scheme.onSurfaceVariant,
                                              fontSize: 11,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: [
                                              tag(
                                                context.posText(
                                                  product.category,
                                                ),
                                                _productTint(product.category),
                                              ),
                                              if (product.onSale)
                                                tag(
                                                  '-${product.discountPercent}%',
                                                  _accent,
                                                ),
                                              if (!product.active)
                                                tag(
                                                  context.posText('販売停止'),
                                                  Colors.grey,
                                                )
                                              else if (product.stock == 0)
                                                tag(
                                                  context.posText('在庫なし'),
                                                  statusColor,
                                                )
                                              else if (product.stock <= 5)
                                                tag(
                                                  context.posText('在庫わずか'),
                                                  statusColor,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        PopupMenuButton<String>(
                                          key: ValueKey(
                                            'product-menu-${product.id}',
                                          ),
                                          padding: EdgeInsets.zero,
                                          onSelected: (v) {
                                            if (v == 'edit') {
                                              _editProduct(context, product);
                                            }
                                            if (v == 'dup') {
                                              _duplicate(context, product);
                                            }
                                            if (v == 'toggle') {
                                              _toggleOne(context, product);
                                            }
                                            if (v == 'discount') {
                                              _discountOne(context, product);
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            PopupMenuItem(
                                              value: 'edit',
                                              child: Text(
                                                context.posText('編集'),
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'discount',
                                              child: Text(
                                                context.posText('割引を設定'),
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'dup',
                                              child: Text(
                                                context.posText('複製'),
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'toggle',
                                              child: Text(
                                                context.posText(
                                                  product.active
                                                      ? '販売停止にする'
                                                      : '販売中にする',
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _PriceText(
                                        product: product,
                                        size: 18,
                                      ),
                                    ),
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Theme.of(context).dividerColor,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            tooltip: context.posText('在庫を1減らす'),
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () => _adjustStock(
                                              context,
                                              product,
                                              -1,
                                            ),
                                            icon: const Icon(
                                              Icons.remove_rounded,
                                              size: 20,
                                            ),
                                          ),
                                          SizedBox(
                                            width: 36,
                                            child: Text(
                                              '${product.stock}',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: context.posText('在庫を1増やす'),
                                            visualDensity:
                                                VisualDensity.compact,
                                            onPressed: () => _adjustStock(
                                              context,
                                              product,
                                              1,
                                            ),
                                            icon: const Icon(
                                              Icons.add_rounded,
                                              size: 20,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: (product.stock / 50).clamp(0.0, 1.0),
                                    minHeight: 4,
                                    color: statusColor,
                                    backgroundColor: statusColor.withValues(
                                      alpha: 0.14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProductFormResult {
  const _ProductFormResult({
    required this.name,
    required this.sku,
    required this.category,
    required this.price,
    required this.stock,
    required this.active,
    required this.imageUrl,
    this.discountPercent = 0,
  });

  final int discountPercent;
  final String name;
  final String sku;
  final String category;
  final int price;
  final int stock;
  final bool active;
  final String imageUrl;
}

class _ProductEditor extends StatefulWidget {
  const _ProductEditor({
    this.product,
    required this.repository,
    required this.categories,
  });

  final PosProduct? product;
  final List<String> categories;
  final PosRepository repository;

  @override
  State<_ProductEditor> createState() => _ProductEditorState();
}

class _ProductEditorState extends State<_ProductEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _sku;
  late final TextEditingController _price;
  late final TextEditingController _discount;
  late final TextEditingController _stock;
  late final TextEditingController _imageUrl;
  late final TextEditingController _newCategory;
  late String _category;
  late bool _active;
  static const _addCategoryValue = '__add_category__';

  @override
  void initState() {
    super.initState();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _sku = TextEditingController(text: product?.sku ?? '');
    _price = TextEditingController(
      text: product?.regularPrice.toString() ?? '',
    );
    _discount = TextEditingController(
      text: (product?.discountPercent ?? 0).toString(),
    );
    _stock = TextEditingController(text: product?.stock.toString() ?? '');
    _imageUrl = TextEditingController(text: product?.imageUrl ?? '');
    _newCategory = TextEditingController();
    _category = product?.category ?? 'その他';
    _active = product?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _price.dispose();
    _discount.dispose();
    _stock.dispose();
    _imageUrl.dispose();
    _newCategory.dispose();
    super.dispose();
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? context.posText('入力してください。')
      : null;

  String? _nonNegative(String? value) {
    final number = int.tryParse(value ?? '');
    if (number == null || number < 0) {
      return context.posText('0以上の整数を入力してください。');
    }
    return null;
  }

  Future<void> _scanBarcode() async {
    final barcode = await showDialog<String>(
      context: context,
      builder: (context) => const _BarcodeScannerDialog(),
    );
    if (barcode != null && mounted) {
      setState(() => _sku.text = barcode);
    }
  }

  bool get _addingCategory => _category == _addCategoryValue;

  String? _percent(String? value) {
    final number = int.tryParse(value ?? '');
    if (number == null || number < 0 || number > 90) {
      return context.posText('0〜90の整数を入力してください。');
    }
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final category = _addingCategory ? _newCategory.text.trim() : _category;
    Navigator.pop(
      context,
      _ProductFormResult(
        name: _name.text.trim(),
        sku: _sku.text.trim(),
        category: category,
        price: int.parse(_price.text),
        discountPercent: int.parse(_discount.text),
        stock: int.parse(_stock.text),
        active: _active,
        imageUrl: _imageUrl.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.posText(widget.product == null ? '商品を追加' : '商品を編集')),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: context.posText('商品名')),
                validator: _required,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _sku,
                decoration: InputDecoration(
                  labelText: context.posText('SKU / 商品コード'),
                  suffixIcon: IconButton(
                    tooltip: context.posText('バーコードをスキャン'),
                    onPressed: _scanBarcode,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                  ),
                ),
                validator: _required,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: InputDecoration(
                  labelText: context.posText('カテゴリー'),
                ),
                items: [
                  for (final category in {
                    ...widget.categories,
                    if (!_addingCategory) _category,
                  })
                    DropdownMenuItem(
                      value: category,
                      child: Text(context.posText(category)),
                    ),
                  DropdownMenuItem(
                    value: _addCategoryValue,
                    child: Text(context.posText('＋ 新しいカテゴリー')),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              if (_addingCategory) ...[
                const SizedBox(height: 10),
                TextFormField(
                  key: const ValueKey('new-category-field'),
                  controller: _newCategory,
                  maxLength: 20,
                  decoration: InputDecoration(
                    labelText: context.posText('新しいカテゴリー名'),
                  ),
                  validator: (value) {
                    final name = value?.trim() ?? '';
                    if (name.isEmpty || name == 'すべて') {
                      return context.posText('入力してください。');
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 10),
              TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.posText('税込価格（円）'),
                  prefixText: '¥ ',
                ),
                validator: _nonNegative,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const ValueKey('product-discount-field'),
                controller: _discount,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.posText('割引率（0〜90％）'),
                  suffixText: '%',
                  helperText:
                      '${context.posText('販売価格')}: ${formatYen(applyDiscount(int.tryParse(_price.text) ?? 0, (int.tryParse(_discount.text) ?? 0).clamp(0, 90)))}',
                ),
                validator: _percent,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _stock,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: context.posText('在庫数')),
                validator: _nonNegative,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _imageUrl,
                decoration: InputDecoration(
                  labelText: context.posText('商品画像URL'),
                  hintText: 'https://example.com/image.jpg',
                ),
                keyboardType: TextInputType.url,
              ),
              if (_imageUrl.text.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 120,
                    height: 120,
                    child: _ProductImage(
                      imageUrl: _imageUrl.text.trim(),
                      category: _addingCategory ? 'その他' : _category,
                      size: 120,
                      borderRadius: 16,
                    ),
                  ),
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(context.posText('販売中')),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.posText('キャンセル')),
        ),
        FilledButton(onPressed: _save, child: Text(context.posText('保存'))),
      ],
    );
  }
}

class _PriceText extends StatelessWidget {
  const _PriceText({required this.product, required this.size});

  final PosProduct product;
  final double size;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            formatYen(product.price),
            style: TextStyle(
              color: product.onSale ? _accent : _brandDeep,
              fontSize: size,
              fontWeight: FontWeight.w900,
            ),
          ),
          if (product.onSale) ...[
            const SizedBox(width: 5),
            Padding(
              padding: const EdgeInsets.only(bottom: 1),
              child: Text(
                formatYen(product.originalPrice),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: size * .7,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DiscountDialog extends StatefulWidget {
  const _DiscountDialog({required this.initial});

  final int initial;

  @override
  State<_DiscountDialog> createState() => _DiscountDialogState();
}

class _DiscountDialogState extends State<_DiscountDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial > 0 ? '${widget.initial}' : '',
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final number = int.tryParse(_controller.text.trim());
    if (number == null || number < 1 || number > 90) {
      setState(() => _error = context.posText('1〜90の整数を入力してください。'));
      return;
    }
    Navigator.pop(context, number);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.posText('割引を設定')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final value in const [10, 20, 30, 50])
                ActionChip(
                  label: Text('$value%'),
                  onPressed: () => setState(() {
                    _controller.text = '$value';
                    _error = null;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('discount-percent-field'),
            controller: _controller,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: InputDecoration(
              labelText: context.posText('割引率（0〜90％）'),
              suffixText: '%',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.posText('キャンセル')),
        ),
        TextButton(
          key: const ValueKey('discount-remove'),
          onPressed: () => Navigator.pop(context, 0),
          child: Text(context.posText('割引を解除')),
        ),
        FilledButton(
          key: const ValueKey('discount-apply'),
          onPressed: _apply,
          child: Text(context.posText('適用')),
        ),
      ],
    );
  }
}

class _BarcodeScannerDialog extends StatefulWidget {
  const _BarcodeScannerDialog();

  @override
  State<_BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<_BarcodeScannerDialog> {
  bool _detected = false;

  void _onDetect(BarcodeCapture capture) {
    if (_detected) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        _detected = true;
        Navigator.of(context).pop(value);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.posText('バーコードをスキャン')),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      content: SizedBox(
        width: 340,
        height: 340,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: MobileScanner(
            onDetect: _onDetect,
            errorBuilder: (context, error) => ColoredBox(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    context.posText('カメラを起動できませんでした。カメラの権限を確認してください。'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
            overlayBuilder: (context, constraints) => Center(
              child: Container(
                width: constraints.maxWidth * 0.78,
                height: constraints.maxHeight * 0.34,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 3),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.posText('キャンセル')),
        ),
      ],
    );
  }
}

class _OrdersPage extends StatefulWidget {
  const _OrdersPage({required this.repository, required this.profile});

  final PosRepository repository;
  final PosProfile profile;

  @override
  State<_OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<_OrdersPage> {
  final _searchController = TextEditingController();
  String _filter = 'すべて';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PosOrder>>(
      stream: widget.repository.orders(profile: widget.profile),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _InlineError(
            message: _readableError(snapshot.error!, context),
          );
        }
        if (!snapshot.hasData) return const _LoadingPage();
        final orders = snapshot.data!;
        if (orders.isEmpty && !widget.profile.isAdmin) {
          return _EmptyState(
            icon: Icons.receipt_long_outlined,
            title: context.posText('注文履歴はありません'),
            message: context.posText('注文すると、注文履歴がここに表示されます。'),
          );
        }
        if (!widget.profile.isAdmin) {
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 9),
            itemBuilder: (context, index) => _OrderCard(
              order: orders[index],
              showUser: false,
              repository: widget.repository,
              profile: widget.profile,
            ),
          );
        }

        final completedOrders = orders
            .where((order) => _countsAsSale(order.status))
            .toList();
        final unsettledOrders = completedOrders
            .where((order) => !order.paymentSettled)
            .toList();
        final totalSales = completedOrders.fold<int>(
          0,
          (total, order) => total + order.total,
        );
        final unsettledSales = unsettledOrders.fold<int>(
          0,
          (total, order) => total + order.total,
        );
        final soldUnits = completedOrders.fold<int>(
          0,
          (total, order) => total + _orderItemCount(order),
        );
        final query = _searchController.text.trim().toLowerCase();
        final matchingOrders = orders.where((order) {
          final matchesFilter = switch (_filter) {
            '受付待ち' => order.status == 'pending',
            '準備中' => order.status == 'preparing',
            '発送済み' => order.status == 'shipped',
            '拒否済み' => order.status == 'rejected',
            '完了' => _countsAsSale(order.status),
            'キャンセル済み' => order.status == 'cancelled',
            '未精算' => _countsAsSale(order.status) && !order.paymentSettled,
            _ => true,
          };
          final matchesSearch =
              query.isEmpty ||
              order.id.toLowerCase().contains(query) ||
              order.userName.toLowerCase().contains(query) ||
              order.items.any(
                (item) => (item['name'] as String? ?? '')
                    .toLowerCase()
                    .contains(query),
              );
          return matchesFilter && matchesSearch;
        }).toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              context.posText('売上概要'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) => GridView.count(
                key: const ValueKey('sales-summary-grid'),
                crossAxisCount: _dashboardColumnCount(constraints.maxWidth),
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
                childAspectRatio: 1.9,
                children: [
                  _MetricCard(
                    label: context.posText('受注済み注文'),
                    value: '${completedOrders.length}${context.posText('件')}',
                    icon: Icons.receipt_long_outlined,
                    color: _brand,
                  ),
                  _MetricCard(
                    label: context.posText('総売上'),
                    value: formatYen(totalSales),
                    icon: Icons.payments_outlined,
                    color: const Color(0xFF1D9B67),
                  ),
                  _MetricCard(
                    label: context.posText('販売点数'),
                    value: '$soldUnits${context.posText('点')}',
                    icon: Icons.inventory_2_outlined,
                    color: _accent,
                  ),
                  _MetricCard(
                    label:
                        '${context.posText('未精算の注文')} '
                        '(${unsettledOrders.length}${context.posText('件')})',
                    value: formatYen(unsettledSales),
                    icon: Icons.pending_actions_outlined,
                    color: unsettledOrders.isEmpty
                        ? _brand
                        : const Color(0xFFE28B18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              context.posText('注文一覧'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('sales-order-search'),
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: context.posText('注文番号・顧客・商品で検索'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: context.posText('検索をクリア'),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 38,
              child: ListView.separated(
                key: const ValueKey('sales-order-filters'),
                scrollDirection: Axis.horizontal,
                itemCount: 8,
                separatorBuilder: (_, _) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  const filters = [
                    'すべて',
                    '受付待ち',
                    '準備中',
                    '発送済み',
                    '完了',
                    '未精算',
                    '拒否済み',
                    'キャンセル済み',
                  ];
                  final filter = filters[index];
                  return ChoiceChip(
                    label: Text(context.posText(filter)),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (matchingOrders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text(
                    context.posText(
                      orders.isEmpty ? '注文履歴はありません' : '条件に一致する注文はありません',
                    ),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            else
              for (final order in matchingOrders)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _OrderCard(
                    order: order,
                    showUser: true,
                    repository: widget.repository,
                    profile: widget.profile,
                  ),
                ),
          ],
        );
      },
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({
    required this.order,
    required this.showUser,
    required this.repository,
    required this.profile,
  });

  final PosOrder order;
  final bool showUser;
  final PosRepository repository;
  final PosProfile profile;

  @override
  Widget build(BuildContext context) {
    final time = order.createdAt;
    final dateText = time == null
        ? context.posText('日時を確認中')
        : '${time.year}/${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')} '
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    final itemDescription = order.items
        .map((item) => '${item['name']} × ${item['quantity']}')
        .join(
          Localizations.localeOf(context).languageCode == 'en' ? ', ' : '、',
        );
    final statusColor = switch (order.status) {
      'pending' => _accent,
      'rejected' || 'cancelled' => const Color(0xFFB8372A),
      'shipped' => const Color(0xFF526F9C),
      _ => _brand,
    };
    final orderMetadata = [
      dateText,
      context.posText(order.paymentMethod),
      context.posText(_orderStatusKey(order.status)),
      if (showUser && _countsAsSale(order.status))
        context.posText(order.paymentSettled ? '精算済み' : '未精算'),
      if (showUser && order.userName.isNotEmpty) order.userName,
    ].join(' ・ ');
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        key: ValueKey('order-card-${order.id}'),
        borderRadius: BorderRadius.circular(9),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => _OrderDetailPage(
              order: order,
              showUser: showUser,
              repository: repository,
              profile: profile,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  order.status == 'shipped'
                      ? Icons.local_shipping_outlined
                      : order.status == 'rejected' ||
                            order.status == 'cancelled'
                      ? Icons.receipt_long_outlined
                      : Icons.eco_outlined,
                  color: statusColor,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemDescription.isEmpty
                          ? '${context.posText('注文 ')}${order.id.substring(0, 6)}'
                          : itemDescription,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      orderMetadata,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatYen(order.total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrderDetailPage extends StatefulWidget {
  const _OrderDetailPage({
    required this.order,
    required this.showUser,
    required this.repository,
    required this.profile,
  });

  final PosOrder order;
  final bool showUser;
  final PosRepository repository;
  final PosProfile profile;

  @override
  State<_OrderDetailPage> createState() => _OrderDetailPageState();
}

class _OrderDetailPageState extends State<_OrderDetailPage> {
  bool _cancelling = false;
  bool _updatingSettlement = false;
  bool _updatingStatus = false;
  bool _reordering = false;
  late String _status = widget.order.status;
  late bool _paymentSettled = widget.order.paymentSettled;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _orderSubscription;

  @override
  void initState() {
    super.initState();
    _orderSubscription = widget.repository
        .orderChanges(widget.order.id)
        .listen(
          (snapshot) {
            final data = snapshot.data();
            if (!mounted || data == null) return;
            final status = data['status'] as String? ?? _status;
            final paymentSettled =
                data['paymentSettled'] as bool? ?? _paymentSettled;
            if (status == _status && paymentSettled == _paymentSettled) return;
            setState(() {
              _status = status;
              _paymentSettled = paymentSettled;
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            final message = error is FirebaseException
                ? _readableError(error, context)
                : error.toString();
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(message)));
          },
        );
  }

  @override
  void dispose() {
    unawaited(_orderSubscription?.cancel() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final date = order.createdAt;
    final dateText = date == null
        ? context.posText('日時を確認中')
        : '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
              '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return Scaffold(
      appBar: AppBar(title: Text(context.posText('注文詳細'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_brandDeep, _brand],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFFF4D19A),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.posText('レシート'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  formatYen(order.total),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '$dateText  ·  ${context.posText(order.paymentMethod)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _OrderTimeline(status: _status),
          const SizedBox(height: 16),
          _DashboardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.posText('注文情報'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _OrderInfoRow(
                  label: context.posText('注文番号'),
                  value: order.id,
                  selectable: true,
                ),
                const SizedBox(height: 10),
                _OrderInfoRow(label: context.posText('注文日時'), value: dateText),
                const SizedBox(height: 10),
                _OrderInfoRow(
                  label: context.posText('注文状態'),
                  value: context.posText(_orderStatusKey(_status)),
                ),
                const SizedBox(height: 10),
                _OrderInfoRow(
                  label: context.posText('支払い方法'),
                  value: context.posText(order.paymentMethod),
                ),
                const SizedBox(height: 10),
                _OrderInfoRow(
                  label: context.posText('精算状態'),
                  value: context.posText(_paymentSettled ? '精算済み' : '未精算'),
                ),
                if (widget.showUser && order.userName.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _OrderInfoRow(
                    label: context.posText('担当スタッフ'),
                    value: order.userName,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DashboardPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.posText('注文商品'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (order.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(context.posText('商品情報がありません')),
                  )
                else
                  for (final item in order.items) _OrderLineItem(item: item),
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.posText('合計（税込）'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Text(
                      formatYen(order.total),
                      style: const TextStyle(
                        color: _brand,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (widget.showUser && _countsAsSale(_status)) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('toggle-order-settlement'),
                onPressed: _updatingSettlement
                    ? null
                    : _confirmSettlementChange,
                icon: _updatingSettlement
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _paymentSettled
                            ? Icons.undo_rounded
                            : Icons.check_circle_outline_rounded,
                      ),
                label: Text(
                  context.posText(
                    _updatingSettlement
                        ? '更新中...'
                        : _paymentSettled
                        ? '未精算に戻す'
                        : '精算済みにする',
                  ),
                ),
              ),
            ),
          ],
          if (_status == 'pending' && widget.profile.isAdmin) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              key: const ValueKey('accept-order'),
              onPressed: _updatingStatus
                  ? null
                  : () => _updateStatus('preparing'),
              icon: _updatingStatus
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(context.posText('注文を受け付ける')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('reject-order'),
              onPressed: _updatingStatus ? null : _confirmRejection,
              icon: const Icon(Icons.block_outlined),
              label: Text(context.posText('注文を拒否する')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB8372A),
              ),
            ),
          ] else if (_status == 'preparing' && widget.profile.isAdmin) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('ship-order'),
                onPressed: _updatingStatus
                    ? null
                    : () => _updateStatus('shipped'),
                icon: _updatingStatus
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.local_shipping_outlined),
                label: Text(context.posText('発送済みにする')),
              ),
            ),
          ],
          if (_status == 'rejected') ...[
            const SizedBox(height: 16),
            _DashboardPanel(
              child: Text(
                context.posText('注文は拒否され、在庫に戻されました。'),
                style: const TextStyle(
                  color: Color(0xFFB8372A),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          if (_status == 'cancelled') ...[
            const SizedBox(height: 16),
            _DashboardPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.posText('注文はキャンセルされました'),
                    style: const TextStyle(
                      color: Color(0xFFB8372A),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (order.cancelledAt != null) ...[
                    const SizedBox(height: 7),
                    Text(
                      '${context.posText('キャンセル日時')}: ${_formatOrderDate(order.cancelledAt!)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  if (order.cancelledByName.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      '${context.posText('キャンセル担当')}: ${order.cancelledByName}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ] else if ((_status == 'pending' &&
                  order.userId == widget.profile.uid) ||
              (_status == 'completed' && widget.profile.isAdmin)) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('cancel-order'),
                onPressed: _cancelling ? null : _confirmCancellation,
                icon: _cancelling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel_outlined),
                label: Text(
                  context.posText(_cancelling ? 'キャンセル処理中...' : '注文をキャンセル'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB8372A),
                  side: const BorderSide(color: Color(0xFFD8A097)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
          if (!widget.profile.isAdmin &&
              order.userId == widget.profile.uid &&
              order.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('reorder'),
                onPressed: _reordering ? null : _reorder,
                icon: const Icon(Icons.replay_rounded),
                label: Text(context.posText('もう一度注文')),
                style: FilledButton.styleFrom(
                  backgroundColor: _brand,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _reorder() async {
    setState(() => _reordering = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await widget.repository.reorder(
        profile: widget.profile,
        order: widget.order,
        paymentMethod: widget.order.paymentMethod,
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${context.posText('注文を受け付けました。確認後に進みます。注文番号：')}${id.substring(0, 6)}',
          ),
        ),
      );
      Navigator.of(context).pop();
    } on StateError catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(_checkoutErrorMessage(error.message, context)),
          ),
        );
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(_readableError(error, context))),
        );
      }
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  Future<void> _confirmSettlementChange() async {
    final nextSettled = !_paymentSettled;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.posText(nextSettled ? '注文を精算済みにしますか？' : '注文を未精算に戻しますか？'),
        ),
        content: Text(context.posText('この変更は注文の在庫や売上合計には影響しません。')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.posText('キャンセル')),
          ),
          FilledButton(
            key: const ValueKey('confirm-order-settlement'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.posText(nextSettled ? '精算済みにする' : '未精算に戻す')),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;

    setState(() => _updatingSettlement = true);
    try {
      await widget.repository.updateOrderSettlement(
        orderId: widget.order.id,
        settled: nextSettled,
        profile: widget.profile,
      );
      if (!mounted) return;
      setState(() => _paymentSettled = nextSettled);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.posText(nextSettled ? '注文を精算済みにしました。' : '注文を未精算に戻しました。'),
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_readableError(error, context))));
      }
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.posText(error.message))));
      }
    } finally {
      if (mounted) setState(() => _updatingSettlement = false);
    }
  }

  Future<void> _updateStatus(String status) async {
    setState(() => _updatingStatus = true);
    try {
      await widget.repository.updateOrderStatus(
        orderId: widget.order.id,
        status: status,
        profile: widget.profile,
      );
      if (!mounted) return;
      setState(() => _status = status);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.posText(
              status == 'preparing' ? '注文を受け付け、準備中にしました。' : '注文を発送済みにしました。',
            ),
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_readableError(error, context))));
      }
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.posText(error.message))));
      }
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _confirmRejection() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.posText('この注文を拒否しますか？')),
        content: Text(context.posText('注文を拒否すると、予約した商品を在庫に戻します。')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.posText('キャンセル')),
          ),
          FilledButton(
            key: const ValueKey('confirm-reject-order'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB8372A),
            ),
            child: Text(context.posText('注文を拒否する')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _updatingStatus = true);
    try {
      await widget.repository.rejectOrder(
        orderId: widget.order.id,
        profile: widget.profile,
      );
      if (!mounted) return;
      setState(() => _status = 'rejected');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.posText('注文を拒否し、在庫に戻しました。'))),
      );
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_readableError(error, context))));
      }
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.posText(error.message))));
      }
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _confirmCancellation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.posText('注文をキャンセルしますか？')),
        content: Text(
          context.posText(
            '管理者の確認前のみキャンセルできます。キャンセルした注文はお客様の履歴から消え、商品は在庫に戻ります。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.posText('キャンセル')),
          ),
          FilledButton(
            key: const ValueKey('confirm-cancel-order'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB8372A),
            ),
            child: Text(context.posText('注文をキャンセル')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await widget.repository.cancelOrder(
        order: widget.order,
        profile: widget.profile,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.posText('注文をキャンセルし、在庫に戻しました。'))),
      );
      Navigator.of(context).pop();
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_readableError(error, context))));
      }
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.posText(error.message))));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }
}

String _formatOrderDate(DateTime date) =>
    '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')} '
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

bool _countsAsSale(String status) =>
    status == 'preparing' || status == 'shipped' || status == 'completed';

String _orderStatusKey(String status) => switch (status) {
  'pending' => '受付待ち',
  'preparing' => '準備中',
  'shipped' => '発送済み',
  'rejected' => '拒否済み',
  'cancelled' => 'キャンセル済み',
  _ => '完了',
};

Future<T?> _showOrderPopup<T>(
  BuildContext context, {
  required Widget child,
  bool dismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'order',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 480),
    pageBuilder: (_, _, _) => child,
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, .12),
            end: Offset.zero,
          ).animate(curved),
          child: ScaleTransition(
            scale: Tween(begin: .82, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

class _OrderPopup extends StatefulWidget {
  const _OrderPopup({
    super.key,
    required this.order,
    required this.color,
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
    this.wiggle = false,
    this.showProgress = false,
  });

  final PosOrder order;
  final Color color;
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;
  final bool wiggle;
  final bool showProgress;

  @override
  State<_OrderPopup> createState() => _OrderPopupState();
}

class _OrderPopupState extends State<_OrderPopup>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _interval(double begin, double end, [Curve curve = Curves.easeOut]) =>
      Interval(begin, end, curve: curve).transform(_controller.value);

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final scheme = Theme.of(context).colorScheme;
    final shortId = order.id.length >= 6 ? order.id.substring(0, 6) : order.id;
    final itemCount = order.items.fold<int>(
      0,
      (total, item) => total + ((item['quantity'] as num?)?.toInt() ?? 0),
    );
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _header(shortId),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Opacity(
                        opacity: _interval(.15, .35),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: _brandWash,
                              child: Text(
                                order.userName.isEmpty
                                    ? 'U'
                                    : order.userName[0],
                                style: const TextStyle(
                                  color: _brand,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                order.userName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            _popupChip(
                              Icons.payments_outlined,
                              context.posText(order.paymentMethod),
                              scheme,
                            ),
                          ],
                        ),
                      ),
                      if (widget.showProgress) ...[
                        const SizedBox(height: 18),
                        _progress(context, scheme),
                      ],
                      const SizedBox(height: 18),
                      Text(
                        '${context.posText('注文内容')}  ·  $itemCount${context.posText('点')}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (var i = 0; i < order.items.length; i++)
                        _itemRow(order.items[i], i, scheme),
                      const SizedBox(height: 10),
                      _totalRow(context, scheme),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 4,
                  children: widget.actions,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(String shortId) {
    final pop = Curves.elasticOut.transform(
      (_controller.value * 6).clamp(0, 1),
    );
    final tilt = widget.wiggle
        ? math.sin(_controller.value * 70) * .35 * (1 - _controller.value)
        : 0.0;
    final time = widget.order.createdAt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [widget.color, Color.lerp(widget.color, Colors.black, .35)!],
        ),
      ),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: -48,
            right: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: .08),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 130,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_controller.value < .9)
                      for (var i = 0; i < 3; i++)
                        Builder(
                          builder: (context) {
                            final t = (_controller.value * 4 + i / 3) % 1;
                            return Container(
                              width: 60 + 70 * t,
                              height: 60 + 70 * t,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: (1 - t) * .45,
                                  ),
                                  width: 2,
                                ),
                              ),
                            );
                          },
                        ),
                    Transform.rotate(
                      angle: tilt,
                      child: Transform.scale(
                        scale: pop,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: Icon(
                            widget.icon,
                            size: 34,
                            color: widget.color,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Opacity(
                opacity: _interval(.08, .25),
                child: Transform.translate(
                  offset: Offset(0, 10 * (1 - _interval(.08, .25))),
                  child: Column(
                    children: [
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'No. $shortId${time == null ? '' : '  ·  ${_formatOrderDate(time)}'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _popupChip(IconData icon, String label, ColorScheme scheme) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: scheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      );

  Widget _itemRow(Map<String, dynamic> item, int index, ColorScheme scheme) {
    final start = (.2 + index * .06).clamp(0.0, .6);
    final t = _interval(start, start + .2);
    final quantity = (item['quantity'] as num?)?.toInt() ?? 1;
    final unit = (item['unitPrice'] as num?)?.toInt() ?? 0;
    final subtotal = (item['subtotal'] as num?)?.toInt() ?? unit * quantity;
    return Opacity(
      opacity: t,
      child: Transform.translate(
        offset: Offset(24 * (1 - t), 0),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _brandWash,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '×$quantity',
                  style: const TextStyle(
                    color: _brand,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item['name'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (unit > 0)
                      Text(
                        formatYen(unit),
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                formatYen(subtotal),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalRow(BuildContext context, ColorScheme scheme) {
    final count = Curves.easeOut.transform(
      const Interval(.35, .8).transform(_controller.value),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Text(
            context.posText('合計'),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          Text(
            formatYen((widget.order.total * count).round()),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: widget.color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _progress(BuildContext context, ColorScheme scheme) {
    const steps = ['pending', 'preparing', 'shipped', 'completed'];
    final index = math.max(0, steps.indexOf(widget.order.status));
    final p = _interval(.2, .75, Curves.easeInOut) * index;
    Widget node(int i) {
      final done = p >= i - .001;
      final current = i == index && p >= index - .001;
      return Column(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? widget.color : scheme.surfaceContainerHighest,
              boxShadow: current
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: .35),
                        blurRadius: 10,
                        spreadRadius: 3,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              done ? Icons.check_rounded : Icons.circle,
              size: done ? 16 : 6,
              color: done ? Colors.white : scheme.outline,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.posText(_orderStatusKey(steps[i])),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: current ? FontWeight.w900 : FontWeight.w600,
              color: done ? scheme.onSurface : scheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          SizedBox(width: 54, child: node(i)),
          if (i < steps.length - 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Stack(
                  children: [
                    Container(height: 3, color: scheme.surfaceContainerHighest),
                    FractionallySizedBox(
                      widthFactor: (p - i).clamp(0.0, 1.0),
                      child: Container(height: 3, color: widget.color),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _OrderTimeline extends StatelessWidget {
  const _OrderTimeline({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    if (status == 'rejected' || status == 'cancelled') {
      return _DashboardPanel(
        child: Row(
          children: [
            const Icon(Icons.cancel_outlined, color: Colors.redAccent),
            const SizedBox(width: 10),
            Text(
              context.posText(_orderStatusKey(status)),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
    }
    const steps = ['pending', 'preparing', 'shipped'];
    final current = status == 'completed'
        ? steps.length
        : steps.indexOf(status);
    return _DashboardPanel(
      key: const ValueKey('order-timeline'),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Expanded(
              child: Column(
                children: [
                  Icon(
                    i <= current
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: i <= current
                        ? _brand
                        : Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.posText(_orderStatusKey(steps[i])),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: i == current
                          ? FontWeight.w900
                          : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderInfoRow extends StatelessWidget {
  const _OrderInfoRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  final String label;
  final String value;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: selectable
              ? SelectableText(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : Text(
                  value,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
  }
}

class _OrderLineItem extends StatelessWidget {
  const _OrderLineItem({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? '';
    final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
    final subtotal = (item['subtotal'] as num?)?.toInt() ?? 0;
    final unitPrice =
        (item['unitPrice'] as num?)?.toInt() ??
        (quantity == 0 ? 0 : subtotal ~/ quantity);
    final sku = item['sku'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _brandWash,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              color: _brand,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  '${context.posText('数量')}: $quantity × ${formatYen(unitPrice)}${sku.isEmpty ? '' : ' · SKU $sku'}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatYen(subtotal),
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _AccountPage extends StatelessWidget {
  const _AccountPage({
    required this.profile,
    required this.repository,
    required this.themeMode,
    required this.locale,
    required this.onLocaleChanged,
    required this.onThemeChanged,
  });

  final PosProfile profile;
  final PosRepository repository;
  final ThemeMode themeMode;
  final Locale locale;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<ThemeMode> onThemeChanged;

  Future<void> _editContact(BuildContext context) async {
    final phone = TextEditingController(text: profile.phone);
    final address = TextEditingController(text: profile.address);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.posText('お届け先情報')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('contact-address'),
              controller: address,
              maxLength: 200,
              decoration: InputDecoration(
                labelText: dialogContext.posText('住所'),
              ),
            ),
            TextField(
              key: const ValueKey('contact-phone'),
              controller: phone,
              maxLength: 30,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: dialogContext.posText('電話番号'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.posText('キャンセル')),
          ),
          FilledButton(
            key: const ValueKey('contact-save'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.posText('保存')),
          ),
        ],
      ),
    );
    final newPhone = phone.text;
    final newAddress = address.text;
    if (saved == true) {
      await repository.updateContact(profile.uid, newPhone, newAddress);
    }
  }

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: profile.name);
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.posText('名前を変更')),
        content: TextField(
          key: const ValueKey('profile-name-field'),
          controller: controller,
          maxLength: 40,
          autofocus: true,
          decoration: InputDecoration(labelText: dialogContext.posText('名前')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.posText('キャンセル')),
          ),
          FilledButton(
            key: const ValueKey('profile-name-save'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.posText('保存')),
          ),
        ],
      ),
    );
    final name = controller.text.trim();
    if (saved != true || name.isEmpty) return;
    try {
      await repository.updateName(profile.uid, name);
    } on FirebaseException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message ?? '')));
    }
  }

  Future<void> _resetPassword(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final done = context.posText('再設定メールを送信しました');
    try {
      await repository.sendPasswordReset(profile.email);
      messenger.showSnackBar(
        SnackBar(content: Text('$done: ${profile.email}')),
      );
    } on FirebaseException catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(error.message ?? '')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeMode == ThemeMode.dark;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ProfileHero(
          profile: profile,
          repository: repository,
          onEditName: () => _editName(context),
        ),
        if (!profile.isAdmin) ...[
          const SizedBox(height: 14),
          _RecentOrdersGroup(repository: repository, profile: profile),
        ],
        const SizedBox(height: 14),
        _SettingsGroup(
          title: context.posText('マイショッピング'),
          children: [
            ListTile(
              key: const ValueKey('open-favorites'),
              leading: const Icon(Icons.favorite_border_rounded),
              title: Text(context.posText('お気に入り商品')),
              subtitle: Text('${profile.favorites.length}'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      _FavoritesPage(repository: repository, profile: profile),
                ),
              ),
            ),
            ListTile(
              key: const ValueKey('copy-email'),
              leading: const Icon(Icons.copy_rounded),
              title: Text(context.posText('メールアドレスをコピー')),
              subtitle: Text(profile.email),
              onTap: () async {
                final messenger = ScaffoldMessenger.of(context);
                final copied = context.posText('コピーしました');
                await Clipboard.setData(ClipboardData(text: profile.email));
                messenger.showSnackBar(SnackBar(content: Text(copied)));
              },
            ),
            ListTile(
              key: const ValueKey('reset-password'),
              leading: const Icon(Icons.lock_reset_rounded),
              title: Text(context.posText('パスワードを再設定')),
              onTap: () => _resetPassword(context),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SettingsGroup(
          title: context.posText('アプリ設定'),
          children: [
            SwitchListTile(
              value: isDark,
              onChanged: (enabled) =>
                  onThemeChanged(enabled ? ThemeMode.dark : ThemeMode.light),
              secondary: Icon(
                isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              ),
              title: Text(context.posText('ダークモード')),
            ),
            ListTile(
              leading: const Icon(Icons.language_rounded),
              title: Text(context.posText('言語')),
              subtitle: Text(switch (locale.languageCode) {
                'en' => 'English',
                'my' => 'မြန်မာ',
                _ => '日本語',
              }),
              trailing: _LanguageSelector(
                locale: locale,
                onChanged: onLocaleChanged,
              ),
            ),
          ],
        ),
        if (profile.isAdmin) ...[
          const SizedBox(height: 14),
          _SettingsGroup(
            title: context.posText('管理ツール'),
            children: [
              ListTile(
                key: const ValueKey('open-customers'),
                leading: const Icon(Icons.groups_outlined),
                title: Text(context.posText('顧客管理')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => _CustomersPage(
                      repository: repository,
                      currentUid: profile.uid,
                    ),
                  ),
                ),
              ),
              ListTile(
                key: const ValueKey('export-sales-csv'),
                leading: const Icon(Icons.download_outlined),
                title: Text(context.posText('売上CSVをコピー')),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final copiedText = context.posText('CSVをコピーしました');
                  final orders = await repository
                      .orders(profile: profile)
                      .first;
                  await Clipboard.setData(
                    ClipboardData(text: repository.salesCsv(orders)),
                  );
                  messenger.showSnackBar(
                    SnackBar(content: Text('$copiedText (${orders.length})')),
                  );
                },
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        _SettingsGroup(
          title: context.posText('お届け先情報'),
          children: [
            ListTile(
              key: const ValueKey('edit-contact'),
              leading: const Icon(Icons.location_on_outlined),
              title: Text(
                profile.address.isEmpty
                    ? context.posText('住所が未登録です')
                    : profile.address,
              ),
              subtitle: Text(
                profile.phone.isEmpty
                    ? context.posText('電話番号が未登録です')
                    : profile.phone,
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editContact(context),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SettingsGroup(
          title: context.posText('アカウント'),
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: Text(context.posText('アプリについて')),
              subtitle: Text(context.posText('MORI デイリーマーケット ・ Firebase連携')),
            ),
            ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
              ),
              title: Text(
                context.posText('ログアウト'),
                style: const TextStyle(color: Colors.redAccent),
              ),
              onTap: () => repository.signOut(),
            ),
          ],
        ),
      ],
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.repository,
    required this.onEditName,
  });

  final PosProfile profile;
  final PosRepository repository;
  final VoidCallback onEditName;

  static const _tiers = [
    ('レギュラー会員', 0, Icons.spa_rounded),
    ('シルバー会員', 10000, Icons.workspace_premium_outlined),
    ('ゴールド会員', 50000, Icons.workspace_premium_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final name = profile.name.isEmpty ? context.posText('ユーザー') : profile.name;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_brand, _brandDeep],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accent.withValues(alpha: .75),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: _paper,
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(
                          color: _brand,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              IconButton(
                                key: const ValueKey('edit-profile-name'),
                                tooltip: context.posText('名前を変更'),
                                visualDensity: VisualDensity.compact,
                                onPressed: onEditName,
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  size: 16,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            profile.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _RoleBadge(isAdmin: profile.isAdmin),
                ),
                if (!profile.isAdmin) ...[
                  const SizedBox(height: 14),
                  StreamBuilder<List<PosOrder>>(
                    stream: repository.orders(profile: profile),
                    builder: (context, snapshot) {
                      final orders = (snapshot.data ?? const <PosOrder>[]);
                      final spent = orders
                          .where((order) => _countsAsSale(order.status))
                          .fold<int>(0, (total, order) => total + order.total);
                      return _stats(context, orders.length, spent);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stats(BuildContext context, int orderCount, int spent) {
    var tier = 0;
    for (var i = 0; i < _tiers.length; i++) {
      if (spent >= _tiers[i].$2) tier = i;
    }
    final next = tier + 1 < _tiers.length ? _tiers[tier + 1] : null;
    final progress = next == null
        ? 1.0
        : ((spent - _tiers[tier].$2) / (next.$2 - _tiers[tier].$2)).clamp(
            0.0,
            1.0,
          );
    Widget stat(String label, String value) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          ],
        ),
      ),
    );
    return Column(
      children: [
        Row(
          children: [
            stat(context.posText('注文数'), '$orderCount'),
            const SizedBox(width: 8),
            stat(context.posText('累計購入額'), formatYen(spent)),
            const SizedBox(width: 8),
            stat(context.posText('お気に入り'), '${profile.favorites.length}'),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Icon(_tiers[tier].$3, size: 18, color: const Color(0xFFF4D19A)),
            const SizedBox(width: 6),
            Text(
              context.posText(_tiers[tier].$1),
              style: const TextStyle(
                color: Color(0xFFF4D19A),
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              next == null
                  ? context.posText('最高ランクです')
                  : '${context.posText('次のランクまで')} ${formatYen(next.$2 - spent)}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) => ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: Colors.white24,
              valueColor: const AlwaysStoppedAnimation(Color(0xFFF4D19A)),
            ),
          ),
        ),
      ],
    );
  }
}

class _RecentOrdersGroup extends StatelessWidget {
  const _RecentOrdersGroup({required this.repository, required this.profile});

  final PosRepository repository;
  final PosProfile profile;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PosOrder>>(
      stream: repository.orders(profile: profile),
      builder: (context, snapshot) {
        final orders = (snapshot.data ?? const <PosOrder>[]).take(3).toList();
        return _SettingsGroup(
          title: context.posText('最近の注文'),
          children: [
            if (orders.isEmpty)
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(context.posText('注文はまだありません')),
              ),
            for (final order in orders)
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: Text(formatYen(order.total)),
                subtitle: Text(
                  order.createdAt == null
                      ? ''
                      : _formatOrderDate(order.createdAt!),
                ),
                trailing: Text(
                  context.posText(_orderStatusKey(order.status)),
                  style: const TextStyle(
                    color: _brand,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FavoritesPage extends StatefulWidget {
  const _FavoritesPage({required this.repository, required this.profile});

  final PosRepository repository;
  final PosProfile profile;

  @override
  State<_FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<_FavoritesPage> {
  late final Set<String> _ids = widget.profile.favorites.toSet();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.posText('お気に入り商品'))),
      body: StreamBuilder<List<PosProduct>>(
        stream: widget.repository.products(includeInactive: false),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const _LoadingPage();
          final items = snapshot.data!
              .where((product) => _ids.contains(product.id))
              .toList();
          if (items.isEmpty) {
            return Center(child: Text(context.posText('お気に入りはまだありません')));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final product = items[index];
              return _DashboardPanel(
                child: ListTile(
                  key: ValueKey('favorite-${product.id}'),
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: _productTint(
                      product.category,
                    ).withValues(alpha: .15),
                    child: Icon(
                      _productIcon(product.category),
                      color: _productTint(product.category),
                    ),
                  ),
                  title: Text(product.name),
                  subtitle: Text(
                    '${formatYen(product.price)}  ·  ${product.category}',
                  ),
                  trailing: IconButton(
                    key: ValueKey('unfavorite-${product.id}'),
                    icon: const Icon(Icons.favorite_rounded, color: _accent),
                    onPressed: () {
                      setState(() => _ids.remove(product.id));
                      unawaited(
                        widget.repository.setFavorite(
                          widget.profile.uid,
                          product.id,
                          false,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _CustomersPage extends StatelessWidget {
  const _CustomersPage({required this.repository, required this.currentUid});

  final PosRepository repository;
  final String currentUid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.posText('顧客管理'))),
      body: StreamBuilder<List<PosProfile>>(
        stream: repository.customers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _InlineError(
              message: _readableError(snapshot.error!, context),
            );
          }
          if (!snapshot.hasData) return const _LoadingPage();
          final users = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final user = users[index];
              final isSelf = user.uid == currentUid;
              return _DashboardPanel(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(user.name.isEmpty ? user.email : user.name),
                  subtitle: Text(
                    [
                      user.email,
                      if (user.phone.isNotEmpty) user.phone,
                      if (user.address.isNotEmpty) user.address,
                    ].join('\n'),
                  ),
                  isThreeLine: user.phone.isNotEmpty || user.address.isNotEmpty,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _RoleBadge(isAdmin: user.isAdmin),
                      if (!isSelf)
                        IconButton(
                          key: ValueKey('toggle-role-${user.uid}'),
                          tooltip: context.posText(
                            user.isAdmin ? '管理者権限を外す' : '管理者にする',
                          ),
                          icon: Icon(
                            user.isAdmin
                                ? Icons.person_remove_outlined
                                : Icons.admin_panel_settings_outlined,
                          ),
                          onPressed: () => repository.setUserRole(
                            user.uid,
                            user.isAdmin ? 'user' : 'admin',
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.isAdmin});

  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: isAdmin ? const Color(0xFFF6E4D5) : _brandWash,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        context.posText(isAdmin ? '管理者' : 'スタッフ'),
        style: TextStyle(
          color: isAdmin ? const Color(0xFF9C592A) : _brand,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 3),
            child: Text(
              title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(context.posText('再読み込み')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              size: 42,
            ),
            const SizedBox(height: 13),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
