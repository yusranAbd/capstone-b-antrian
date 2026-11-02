import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';

import 'routing/app_router.dart';

import 'admin_ui.dart';
import 'api.dart';
import 'user_profile.dart';
import 'doctor_visual.dart';
import 'mobile_ui.dart';
import 'login_ui.dart';
import 'patient_design.dart';
import 'staff_v4.dart';
import 'queueb_palette.dart';
import 'queueb_feedback.dart';

class QueueBApp extends StatefulWidget {
  const QueueBApp({super.key, required this.api});
  final QueueApi api;
  @override
  State<QueueBApp> createState() => _QueueBAppState();
}

class _QueueBAppState extends State<QueueBApp> {
  late AppRouting routing = AppRouting(widget.api);
  @override
  void didUpdateWidget(covariant QueueBApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api) {
      routing.dispose();
      routing = AppRouting(widget.api);
    }
  }

  @override
  void dispose() {
    routing.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    routerConfig: routing.router,
    builder: (context, child) => QueueBFeedbackHost(
      navigatorKey: routing.rootKey,
      session: routing.refresh,
      sessionKey: () => routing.refresh.scopeKey,
      navigation: routing.router.routeInformationProvider,
      locationKey: () =>
          routing.router.routeInformationProvider.value.uri.toString(),
      child: child ?? const SizedBox.shrink(),
    ),
    title: 'QueueB Hospital',
    debugShowCheckedModeBanner: false,
    locale: const Locale('id'),
    supportedLocales: const [Locale('id'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: QueueBPalette.primary,
      ).copyWith(primary: QueueBPalette.primary, secondary: QueueBPalette.cyan),
      scaffoldBackgroundColor: QueueBPalette.background,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      cardTheme: const CardThemeData(elevation: 0, color: Colors.white),
    ),
  );
}

PreferredSizeWidget portalHeader(
  BuildContext context,
  QueueApi api,
  VoidCallback openProfile, {
  VoidCallback? onActivity,
  Widget? staffContext,
}) {
  final role = api.user?['peran'];
  if (role == 'PETUGAS') {
    return StaffToolbar(
      selection: staffContext ?? const SizedBox(),
      avatar: AccountAvatar(api: api, radius: 18),
      name: (api.user?['nama'] ?? 'Petugas').toString(),
      onProfile: openProfile,
    );
  }
  if (role == 'DOKTER') {
    return DoctorToolbar(
      avatar: AccountAvatar(api: api, radius: 18),
      name: (api.user?['nama'] ?? 'Dokter').toString(),
      onProfile: openProfile,
    );
  }
  return AppBar(
    automaticallyImplyLeading: role != 'USER',
    toolbarHeight: role == 'USER'
        ? 48
        : role == 'ADMIN'
        ? 52
        : role == 'DOKTER'
        ? 64
        : role == 'PETUGAS'
        ? 60
        : null,
    title: role == 'USER'
        ? null
        : staffContext != null && MediaQuery.sizeOf(context).width >= 700
        ? Row(
            children: [
              const Flexible(child: QueueBBrand(compact: true)),
              Expanded(flex: 3, child: staffContext),
            ],
          )
        : const QueueBBrand(compact: true),
    actions: [
      if (role == 'USER')
        IconButton(
          tooltip: 'Aktivitas tiket',
          onPressed: onActivity,
          icon: const Icon(Icons.notifications_none_rounded),
        ),

      if (role != 'USER' && role != 'ADMIN')
        IconButton(
          tooltip: 'Profil akun',
          icon: role == 'DOKTER'
              ? const Icon(Icons.person_outline_rounded)
              : ExcludeSemantics(child: AccountAvatar(api: api, radius: 16)),
          onPressed: openProfile,
        ),
      if (role != 'USER')
        IconButton(
          tooltip: 'Keluar akun',
          icon: const Icon(Icons.logout),
          onPressed: () async {
            try {
              await api.logout();
            } catch (_) {
              /* Session gate reports cleanup failures and server confirmation. */
            }
          },
        ),
    ],
  );
}

class PortalFrame extends StatelessWidget {
  const PortalFrame({
    super.key,
    required this.api,
    required this.role,
    required this.child,
  });
  final QueueApi api;
  final String role;
  final Widget child;
  @override
  Widget build(BuildContext context) => Theme(
    data: role == 'ADMIN'
        ? AdminStyle.theme
        : role == 'DOKTER'
        ? DoctorStyle.theme
        : role == 'USER'
        ? PatientDesign.theme
        : QueueBStyle.theme,
    child: Builder(
      builder: (context) => Scaffold(
        appBar: role == 'USER' || role == 'PETUGAS'
            ? null
            : portalHeader(
                context,
                api,
                () => context.go(
                  '${role == 'ADMIN' ? '/admin' : '/doctor'}/profile',
                ),
              ),
        body: SafeArea(top: false, child: child),
      ),
    ),
  );
}

/// Authentication boundary only; dashboards keep their existing UI.
class SessionGate extends StatelessWidget {
  const SessionGate({super.key, required this.api});
  final QueueApi api;
  @override
  Widget build(BuildContext context) {
    final waiting = [
      SessionPhase.restoring,
      SessionPhase.signingOut,
    ].contains(api.sessionPhase);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (waiting) const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    waiting
                        ? api.sessionPhase == SessionPhase.signingOut
                              ? 'Menutup sesi…'
                              : 'Memulihkan sesi…'
                        : api.sessionPhase == SessionPhase.storageError
                        ? 'Penyimpanan sesi belum tersedia'
                        : 'Koneksi sesi belum tersedia',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  if (api.sessionMessage != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        api.sessionMessage!,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (!waiting) ...[
                    FilledButton(
                      onPressed: () async {
                        try {
                          await api.restoreSession();
                        } catch (_) {}
                      },
                      child: const Text('Coba lagi'),
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          await api.logout();
                        } catch (_) {}
                      },
                      child: const Text('Hapus sesi & kembali ke login'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.api,
    required this.onDisplay,
    this.notice,
    this.registration,
    this.onRegistrationChanged,
  });
  final QueueApi api;
  final VoidCallback onDisplay;
  final String? notice;
  final bool? registration;
  final ValueChanged<bool>? onRegistrationChanged;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  bool _register = false, busy = false, obscure = true;
  bool get register => widget.registration ?? _register;
  void changeRegistration(bool value) {
    if (widget.onRegistrationChanged case final callback?) {
      callback(value);
    } else {
      _register = value;
    }
  }

  String? error, message;
  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      if (register) {
        await widget.api.register(name.text, email.text, password.text);
        if (mounted) {
          setState(() {
            changeRegistration(false);
            message = 'Akun pasien dibuat. Silakan masuk.';
          });
        }
      } else {
        await widget.api.login(email.text, password.text);
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: PatientDesign.theme,
    child: Builder(
      builder: (context) => Scaffold(
        backgroundColor: LoginStyle.paper,
        body: SafeArea(
          child: LoginLayout(child: Builder(builder: _loginCard)),
        ),
      ),
    ),
  );

  Widget _loginCard(BuildContext context) {
    final compact = LoginStyle.compact(context);
    Widget notice(String text, {bool isError = false, bool success = false}) =>
        MobileNotice(text, error: isError, success: success, popup: true);
    return LoginFormCard(
      child: AutofillGroup(
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Center(child: QueueBBrand(compact: true)),
              SizedBox(height: compact ? 16 : 24),
              Text(
                register ? 'Daftar' : 'Masuk',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: compact ? 25 : 30,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: PatientDesign.ink,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                register
                    ? 'Daftar akun pasien'
                    : 'Akses sistem antrean rumah sakit',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: PatientDesign.muted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              SizedBox(height: compact ? 20 : 26),
              if (widget.notice != null) notice(widget.notice!),
              if (error != null) notice(error!, isError: true),
              if (message != null) notice(message!, success: true),
              if (register) ...[
                TextFormField(
                  key: const ValueKey('login-name'),
                  controller: name,
                  enabled: !busy,
                  style: LoginStyle.inputText,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: const InputDecoration(
                    labelText: 'Nama lengkap',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) =>
                      v == null || v.trim().length < 3 || v.length > 150
                      ? 'Nama 3–150 karakter.'
                      : null,
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                key: const ValueKey('login-email'),
                controller: email,
                enabled: !busy,
                style: LoginStyle.inputText,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.username],
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  hintText: 'nama@email.com',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator: (v) =>
                    v == null ||
                        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(v.trim())
                    ? 'Masukkan email yang valid.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                key: const ValueKey('login-password'),
                controller: password,
                enabled: !busy,
                style: LoginStyle.inputText,
                obscureText: obscure,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.done,
                autofillHints: [
                  register ? AutofillHints.newPassword : AutofillHints.password,
                ],
                decoration: InputDecoration(
                  labelText: 'Kata sandi',
                  hintText: 'Masukkan kata sandi',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    tooltip: obscure
                        ? 'Tampilkan kata sandi'
                        : 'Sembunyikan kata sandi',
                    onPressed: busy
                        ? null
                        : () => setState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                onFieldSubmitted: (_) => submit(),
                validator: (v) => v == null || v.isEmpty
                    ? 'Kata sandi wajib diisi.'
                    : register && (v.length < 8 || v.length > 72)
                    ? 'Kata sandi 8–72 karakter.'
                    : null,
              ),
              SizedBox(height: compact ? 18 : 22),
              FilledButton(
                onPressed: busy ? null : submit,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (busy) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        busy
                            ? 'Memproses…'
                            : register
                            ? 'Daftar pasien'
                            : 'Masuk',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: compact ? 12 : 18),
                child: const Row(
                  children: [
                    Expanded(child: Divider(color: LoginStyle.rule)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Text(
                        'atau',
                        style: TextStyle(
                          color: PatientDesign.muted,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: LoginStyle.rule)),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : widget.onDisplay,
                icon: const Icon(Icons.desktop_windows_outlined, size: 20),
                label: const Text(
                  'Masuk ke Public Display',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: busy
                    ? null
                    : () => setState(() {
                        changeRegistration(!register);
                        error = null;
                        message = null;
                      }),
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(color: PatientDesign.muted),
                    children: [
                      TextSpan(
                        text: register
                            ? 'Sudah punya akun?  '
                            : 'Pasien baru?  ',
                      ),
                      TextSpan(
                        text: register ? 'Masuk' : 'Daftar',
                        style: const TextStyle(
                          color: PatientDesign.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
