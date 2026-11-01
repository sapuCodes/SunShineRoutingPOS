import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/app_theme.dart';
import '../../../core/providers/app_providers.dart';
import '../application/auth_providers.dart';
import '../domain/auth_form_validation.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String? _error;
  bool _busy = false;

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .signIn(email: _email.trim(), password: _password);
      if (mounted) {
        context.go('/workspace-loading');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => _AuthPage(
    title: 'Sign in',
    subtitle: 'Sign in to continue to your workspace.',
    children: [
      const _AuthStatusMessage(),
      Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              key: const Key('sign-in-email'),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email'),
              validator: AuthFormValidation.email,
              onChanged: (value) => _email = value,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('sign-in-password'),
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Password'),
              validator: AuthFormValidation.signInPassword,
              onChanged: (value) => _password = value,
            ),
            const SizedBox(height: 12),
            if (_error != null) _AuthErrorMessage(_error!),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _signIn,
                child: Text(_busy ? 'Signing in…' : 'Sign in'),
              ),
            ),
          ],
        ),
      ),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: () => context.go('/forgot-password'),
          child: const Text('Forgot password?'),
        ),
      ),
      TextButton(
        onPressed: () => context.go('/register'),
        child: const Text('Create an account'),
      ),
    ],
  );
}

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  String _displayName = '';
  String _email = '';
  String _password = '';
  String? _error;
  bool _busy = false;

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).register(
        email: _email.trim(),
        password: _password,
        displayName: _displayName.trim(),
      );
      if (mounted) {
        context.go(
          '/verify-email?email=${Uri.encodeQueryComponent(_email.trim())}',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => _AuthPage(
    title: 'Create account',
    subtitle: 'Verify your email before entering a workspace.',
    children: [
      const _AuthStatusMessage(),
      Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              key: const Key('registration-name'),
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Display name'),
              validator: AuthFormValidation.displayName,
              onChanged: (value) => _displayName = value,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('registration-email'),
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: AuthFormValidation.email,
              onChanged: (value) => _email = value,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('registration-password'),
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                helperText: 'Use at least 8 characters.',
              ),
              validator: AuthFormValidation.password,
              onChanged: (value) => _password = value,
            ),
            const SizedBox(height: 12),
            if (_error != null) _AuthErrorMessage(_error!),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _register,
                child: Text(_busy ? 'Creating account…' : 'Register'),
              ),
            ),
          ],
        ),
      ),
      TextButton(
        onPressed: () => context.go('/sign-in'),
        child: const Text('Back to sign in'),
      ),
    ],
  );
}

class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _code = '';
  String? _error;
  String? _notice;
  bool _busy = false;
  bool _emailInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_emailInitialized) {
      _email =
          GoRouterState.of(context).uri.queryParameters['email'] ?? '';
      _emailInitialized = true;
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .verifyEmail(email: _email.trim(), code: _code.trim());
      if (mounted) {
        context.go('/workspace-loading');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .resendVerificationCode(email: _email.trim());
      if (mounted) {
        setState(() => _notice = 'A new verification code was requested.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialEmail = GoRouterState.of(context).uri.queryParameters['email'];
    return _AuthPage(
      title: 'Verify your email',
      subtitle: 'Enter the 6-digit code sent to your email address.',
      children: [
        const _AuthStatusMessage(),
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                key: const Key('verification-email'),
                initialValue: initialEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: AuthFormValidation.email,
                onChanged: (value) => _email = value,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('verification-code'),
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Verification code',
                  counterText: '',
                ),
                validator: AuthFormValidation.verificationCode,
                onChanged: (value) => _code = value,
              ),
              if (_error != null) _AuthErrorMessage(_error!),
              if (_notice != null) _AuthNotice(_notice!),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _verify,
                  child: Text(_busy ? 'Verifying…' : 'Verify email'),
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: _busy ? null : _resend,
          child: const Text('Resend code'),
        ),
        TextButton(
          onPressed: () => context.go('/sign-in'),
          child: const Text('Back to sign in'),
        ),
      ],
    );
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _code = '';
  String _newPassword = '';
  String? _error;
  String? _notice;
  bool _codeSent = false;
  bool _busy = false;

  Future<void> _sendCode() async {
    if (AuthFormValidation.email(_email) != null) {
      setState(() => _error = AuthFormValidation.email(_email));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .requestPasswordReset(email: _email.trim());
      if (mounted) {
        setState(() {
          _codeSent = true;
          _notice = 'Check your email for the password reset code.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _completeReset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).completePasswordReset(
        email: _email.trim(),
        code: _code.trim(),
        newPassword: _newPassword,
      );
      if (mounted) {
        context.go('/workspace-loading');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => _AuthPage(
    title: 'Reset password',
    subtitle: 'Request a code, then choose a new password.',
    children: [
      const _AuthStatusMessage(),
      Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              key: const Key('reset-email'),
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: AuthFormValidation.email,
              onChanged: (value) => _email = value,
            ),
            if (_codeSent) ...[
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('reset-code'),
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Reset code',
                  counterText: '',
                ),
                validator: AuthFormValidation.verificationCode,
                onChanged: (value) => _code = value,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('reset-new-password'),
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: AuthFormValidation.password,
                onChanged: (value) => _newPassword = value,
              ),
            ],
            const SizedBox(height: 12),
            if (_error != null) _AuthErrorMessage(_error!),
            if (_notice != null) _AuthNotice(_notice!),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : _codeSent
                    ? _completeReset
                    : _sendCode,
                child: Text(
                  _busy
                      ? 'Please wait…'
                      : _codeSent
                      ? 'Update password'
                      : 'Send reset code',
                ),
              ),
            ),
          ],
        ),
      ),
      TextButton(
        onPressed: () => context.go('/sign-in'),
        child: const Text('Back to sign in'),
      ),
    ],
  );
}

class _AuthPage extends StatelessWidget {
  const _AuthPage({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sun Shine POS')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              color: AppColors.steel900,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(subtitle),
                      const SizedBox(height: 20),
                      ...children,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthStatusMessage extends ConsumerWidget {
  const _AuthStatusMessage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final error = ref.watch(supabaseStartupErrorProvider);
    final client = ref.watch(supabaseClientProvider);
    final config = ref.watch(appConfigProvider);
    final authState = ref.watch(authControllerProvider);
    if (error != null) {
      return _AuthErrorMessage(
        'Local Supabase could not be initialized: $error',
      );
    }
    if (!config.hasSupabaseConfiguration || client == null) {
      return const _AuthNotice(
        'Local Supabase is not configured. Copy '
        'local_config.example.json to local_config.json and add the local '
        'publishable key. Hosted Supabase URLs are rejected.',
      );
    }
    if (authState.hasError) {
      return _AuthErrorMessage(
        'Authentication state could not be restored: '
        '${authState.error}',
      );
    }
    return const SizedBox.shrink();
  }
}

class _AuthErrorMessage extends StatelessWidget {
  const _AuthErrorMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    ),
  );
}

class _AuthNotice extends StatelessWidget {
  const _AuthNotice(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      message,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: AppColors.steel700),
    ),
  );
}
