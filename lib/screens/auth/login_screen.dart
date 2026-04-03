import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/gradient_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isLogin = true;
  String? _error;

  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Animation<double> _fade(double begin, double end) =>
      CurvedAnimation(
        parent: _animController,
        curve: Interval(begin, end, curve: Curves.easeOut),
      );

  Animation<Offset> _slide(double begin, double end) =>
      Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(
          parent: _animController,
          curve: Interval(begin, end, curve: Curves.easeOutCubic),
        ),
      );

  Future<void> _signInWithEmail() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Email dan password harus diisi');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      if (_isLogin) {
        await authService.signInWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await authService.registerWithEmail(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkBgGradient
              : AppColors.lightBgGradient,
        ),
        child: Stack(
          children: [
            // Decorative circles
            Positioned(
              top: -80,
              right: -60,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withAlpha(20),
                ),
              ),
            ),
            Positioned(
              bottom: -40,
              left: -80,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryLight.withAlpha(15),
                ),
              ),
            ),

            // Content
            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      FadeTransition(
                        opacity: _fade(0.0, 0.3),
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.5, end: 1.0).animate(
                            CurvedAnimation(
                              parent: _animController,
                              curve: const Interval(0.0, 0.3,
                                  curve: Curves.easeOutBack),
                            ),
                          ),
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withAlpha(100),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.account_balance_wallet,
                                color: Colors.white, size: 36),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Title
                      FadeTransition(
                        opacity: _fade(0.15, 0.4),
                        child: SlideTransition(
                          position: _slide(0.15, 0.4),
                          child: Text(
                            'Money Management',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      FadeTransition(
                        opacity: _fade(0.25, 0.5),
                        child: SlideTransition(
                          position: _slide(0.25, 0.5),
                          child: Text(
                            'Kelola keuangan keluarga dengan mudah',
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Email
                      FadeTransition(
                        opacity: _fade(0.35, 0.6),
                        child: SlideTransition(
                          position: _slide(0.35, 0.6),
                          child: TextField(
                            controller: _emailController,
                            decoration: const InputDecoration(
                              hintText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Password
                      FadeTransition(
                        opacity: _fade(0.45, 0.7),
                        child: SlideTransition(
                          position: _slide(0.45, 0.7),
                          child: TextField(
                            controller: _passwordController,
                            decoration: const InputDecoration(
                              hintText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                            obscureText: true,
                          ),
                        ),
                      ),

                      // Error
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style:
                              const TextStyle(color: AppColors.expense, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 28),

                      // Button
                      FadeTransition(
                        opacity: _fade(0.55, 0.8),
                        child: SlideTransition(
                          position: _slide(0.55, 0.8),
                          child: GradientButton(
                            text: _isLogin ? 'Masuk' : 'Daftar',
                            isLoading: _isLoading,
                            onPressed: _signInWithEmail,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Toggle
                      FadeTransition(
                        opacity: _fade(0.65, 0.9),
                        child: GestureDetector(
                          onTap: () => setState(() => _isLogin = !_isLogin),
                          child: AnimatedCrossFade(
                            duration: const Duration(milliseconds: 250),
                            crossFadeState: _isLogin
                                ? CrossFadeState.showFirst
                                : CrossFadeState.showSecond,
                            firstChild: Text(
                              'Belum punya akun? Daftar',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            secondChild: Text(
                              'Sudah punya akun? Masuk',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
