import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/tokens.dart';
import '../state/auth_provider.dart';
import '../state/store_provider.dart';

void showAuthModal(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? AppColorsDark.bgPrimary
        : AppColors.bgPrimary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: AuthModalContent(ref: ref),
    ),
  );
}

void showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Account'),
      content: const Text(
        'This will permanently delete your account and all associated data. '
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            final auth = ref.read(authServiceProvider);
            final store = ref.read(storeServiceProvider);
            final error = await auth.deleteAccount();
            if (error != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error: $error')),
              );
            } else {
              await store.clearAll();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account deleted')),
                );
              }
            }
          },
          child: Text(
            'Delete',
            style: TextStyle(color: AppColors.conditionPoor),
          ),
        ),
      ],
    ),
  );
}

class AuthModalContent extends StatefulWidget {
  final WidgetRef ref;
  const AuthModalContent({super.key, required this.ref});

  @override
  State<AuthModalContent> createState() => _AuthModalContentState();
}

class _AuthModalContentState extends State<AuthModalContent> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password are required');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = widget.ref.read(authServiceProvider);
    final result = _isSignUp
        ? await auth.signUp(email, password)
        : await auth.signIn(email, password);

    if (!mounted) return;

    if (result.error != null) {
      setState(() {
        _loading = false;
        _error = result.error;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = widget.ref.read(authServiceProvider);
    final error = await auth.signInWithGoogle();

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = widget.ref.read(authServiceProvider);
    final error = await auth.signInWithApple();

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _loading = false;
        _error = error;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColorsDark.textPrimary : AppColors.textPrimary;
    final subColor =
        isDark ? AppColorsDark.textSecondary : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: AppSpacing.s4),
            decoration: BoxDecoration(
              color: subColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            _isSignUp ? 'Create Account' : 'Sign In',
            style: TextStyle(
              fontSize: AppTypography.textBase,
              fontWeight: AppTypography.weightSemibold,
              color: textColor,
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          TextField(
            controller: _passwordController,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.s2),
            Text(
              _error!,
              style: TextStyle(
                fontSize: AppTypography.textXs,
                color: AppColors.conditionPoor,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.s4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_isSignUp ? 'Create Account' : 'Sign In'),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          if (widget.ref.read(authServiceProvider).isAppleSignInAvailable)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s2),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _signInWithApple,
                  icon: const Icon(Icons.apple, size: 20),
                  label: const Text('Continue with Apple'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    foregroundColor: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black
                        : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _loading ? null : _signInWithGoogle,
              icon: const Icon(Icons.g_mobiledata, size: 24),
              label: const Text('Continue with Google'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s3),
          TextButton(
            onPressed: () => setState(() {
              _isSignUp = !_isSignUp;
              _error = null;
            }),
            child: Text(
              _isSignUp
                  ? 'Already have an account? Sign In'
                  : "Don't have an account? Sign Up",
              style: TextStyle(
                fontSize: AppTypography.textSm,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s4),
        ],
      ),
    );
  }
}
