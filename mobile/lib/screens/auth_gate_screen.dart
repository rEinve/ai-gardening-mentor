import 'package:flutter/material.dart';

import '../data/offline_garden_store.dart';
import '../widgets/brand_logo.dart';

/// Login / Create Account gate placed in front of all personal garden services.
/// Supports Email/Password Sign-In, Create Account, and Google Sign-In
/// (free pilot trial — no payment required yet).
class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key, required this.store});

  final OfflineGardenStore store;

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _isCreateMode = true;
  bool _submitting = false;
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitEmailAuth() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final displayName = _nameCtrl.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorText = 'Please enter a valid email address.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorText = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      await widget.store.signInWithEmail(
        email: email,
        password: password,
        displayName: _isCreateMode ? (displayName.isEmpty ? email.split('@').first : displayName) : null,
        createAccount: _isCreateMode,
      );
    } catch (err) {
      if (mounted) {
        setState(() => _errorText = err.toString());
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitGoogleAuth() async {
    setState(() {
      _submitting = true;
      _errorText = null;
    });
    try {
      await widget.store.signInWithGoogle();
    } catch (err) {
      if (mounted) {
        setState(() => _errorText = err.toString());
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandLogo(size: 64)),
                  const SizedBox(height: 12),
                  Text(
                    'AI Gardening Mentor',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Free Pilot Trial • Private Crop Planner, Diagnosis & Mentor for Tanzania',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 24),

                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Create Account')),
                      ButtonSegment(value: false, label: Text('Log In')),
                    ],
                    selected: {_isCreateMode},
                    onSelectionChanged: (sel) => setState(() {
                      _isCreateMode = sel.first;
                      _errorText = null;
                    }),
                  ),
                  const SizedBox(height: 16),

                  if (_errorText != null) ...[
                    Card(
                      color: cs.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(_errorText!, style: TextStyle(color: cs.onErrorContainer)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (_isCreateMode) ...[
                    TextField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Your Name',
                        hintText: 'e.g., Mama Neema',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      hintText: 'you@example.com',
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submitEmailAuth(),
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      hintText: 'At least 6 characters',
                      prefixIcon: Icon(Icons.lock_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  FilledButton(
                    onPressed: _submitting ? null : _submitEmailAuth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        _submitting
                            ? 'Please wait...'
                            : (_isCreateMode ? 'Create Free Account' : 'Log In to My Farm'),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('or'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: _submitting ? null : _submitGoogleAuth,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text('Continue with Google'),
                    ),
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'All farm schedules, plant photos, and supplier/buyer contacts are private to your account. No payment required during pilot testing.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
