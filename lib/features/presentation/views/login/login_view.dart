import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/service/dependency_injection.dart';
import '../../../../utils/app_theme.dart';
import '../../../../utils/navigation_routes.dart';
import '../../../data/data_sources/local_data_sources.dart';
import '../../cubit/login/login_cubit.dart';
import '../../cubit/login/login_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final FocusNode _userFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();
  bool _obscurePass = true;
  bool _rememberMe = false;
  late String branchName = "";
  final LocalDataSource _localDataSource = sl<LocalDataSource>();
  static const _keyEmail = 'remembered_email';
  static const _keyPass = 'remembered_pass';
  static const _keyRemember = 'remember_me';

  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
    _loadRememberedCredentials();
    getBranchName();
  }

  Future<void> _loadRememberedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final remembered = prefs.getBool(_keyRemember) ?? false;
    if (remembered) {
      setState(() {
        _rememberMe = true;
        _userController.text = prefs.getString(_keyEmail) ?? '';
        _passController.text = prefs.getString(_keyPass) ?? '';
      });
    }
  }

  Future<void> _saveOrClearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setBool(_keyRemember, true);
      await prefs.setString(_keyEmail, _userController.text.trim());
      await prefs.setString(_keyPass, _passController.text);
    } else {
      await prefs.remove(_keyRemember);
      await prefs.remove(_keyEmail);
      await prefs.remove(_keyPass);
    }
  }

  /// Persists the token so the user stays logged in across app restarts.
  Future<void> _persistToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  @override
  void dispose() {
    _animController.dispose();
    _userController.dispose();
    _passController.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> getBranchName() async {
    branchName = await _localDataSource.getBranch();
    if (mounted) setState(() {});
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgBase,
      body: BlocConsumer<LoginCubit, LoginState>(
        listener: (context, state) async {
          if (state is LoginFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.message)),
                  ],
                ),
                backgroundColor: AppTheme.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
          if (state is LoginSuccess) {
            // Persist the token so the user stays logged in across restarts
            await _persistToken(state.token);
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, Routes.kMainPosScreen);
            }
          }
        },
        builder: (context, state) {
          final isLoading = state is LoginLoading || state is LoginSyncing;

          return Stack(
            children: [
              // Ambient background glow
              Positioned(
                top: -80,
                right: -80,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.gold.withValues(alpha: 0.12),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -80,
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.green.withValues(alpha: 0.06),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Main content
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Logo
                              Center(
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    gradient: AppTheme.goldGradient,
                                    borderRadius: BorderRadius.circular(22),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppTheme.gold
                                            .withValues(alpha: 0.35),
                                        blurRadius: 24,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.restaurant_menu_rounded,
                                    color: AppTheme.textOnGold,
                                    size: 36,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              const Text(
                                'Sample Restaurant',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${branchName.isNotEmpty ? branchName : ''} · POS System',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                ),
                              ),

                              const SizedBox(height: 48),

                              // Card container
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: AppTheme.bgCard,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppTheme.bgBorder),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.stretch,
                                  children: [
                                    const Text(
                                      'Sign In',
                                      style: TextStyle(
                                        color: AppTheme.textPrimary,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Enter your credentials to continue',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 24),

                                    // Email field
                                    _buildLabel('Email Address'),
                                    const SizedBox(height: 8),
                                    _buildTextField(
                                      controller: _userController,
                                      focusNode: _userFocus,
                                      hint: 'name@restaurant.com',
                                      keyboardType: TextInputType.emailAddress,
                                      prefixIcon: Icons.email_outlined,
                                      textInputAction: TextInputAction.next,
                                      onSubmitted: (_) =>
                                          _passFocus.requestFocus(),
                                    ),
                                    const SizedBox(height: 20),

                                    // Password field
                                    _buildLabel('Password'),
                                    const SizedBox(height: 8),
                                    _buildTextField(
                                      controller: _passController,
                                      focusNode: _passFocus,
                                      hint: '••••••••',
                                      obscure: _obscurePass,
                                      prefixIcon: Icons.lock_outline_rounded,
                                      textInputAction: TextInputAction.done,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePass
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: AppTheme.textHint,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(
                                                () => _obscurePass = !_obscurePass),
                                      ),
                                      onSubmitted: (_) =>
                                          _handleLogin(context),
                                    ),

                                    const SizedBox(height: 16),

                                    // Remember Me
                                    GestureDetector(
                                      onTap: () => setState(
                                              () => _rememberMe = !_rememberMe),
                                      behavior: HitTestBehavior.opaque,
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: Checkbox(
                                              value: _rememberMe,
                                              onChanged: (val) => setState(
                                                      () => _rememberMe =
                                                      val ?? false),
                                              activeColor: AppTheme.gold,
                                              checkColor: AppTheme.textOnGold,
                                              side: const BorderSide(
                                                  color: AppTheme.textHint,
                                                  width: 1.5),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                BorderRadius.circular(4),
                                              ),
                                              materialTapTargetSize:
                                              MaterialTapTargetSize
                                                  .shrinkWrap,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          const Text(
                                            'Remember me',
                                            style: TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    const SizedBox(height: 28),

                                    // Sign in button
                                    AnimatedContainer(
                                      duration:
                                      const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        gradient: isLoading
                                            ? null
                                            : AppTheme.goldGradient,
                                        color: isLoading
                                            ? AppTheme.bgCardElevated
                                            : null,
                                        borderRadius:
                                        BorderRadius.circular(14),
                                        boxShadow: isLoading
                                            ? []
                                            : [
                                          BoxShadow(
                                            color: AppTheme.gold
                                                .withValues(alpha: 0.4),
                                            blurRadius: 16,
                                            offset:
                                            const Offset(0, 6),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton(
                                        onPressed: isLoading
                                            ? null
                                            : () => _handleLogin(context),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          disabledBackgroundColor:
                                          Colors.transparent,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                            BorderRadius.circular(14),
                                          ),
                                        ),
                                        child: isLoading
                                            ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child:
                                          CircularProgressIndicator(
                                            color: AppTheme.gold,
                                            strokeWidth: 2,
                                          ),
                                        )
                                            : const Text(
                                          'SIGN IN',
                                          style: TextStyle(
                                            color: AppTheme.textOnGold,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData prefixIcon,
    TextInputType? keyboardType,
    bool obscure = false,
    TextInputAction? textInputAction,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppTheme.textHint, fontSize: 14),
        filled: true,
        fillColor: AppTheme.bgCardElevated,
        prefixIcon: Icon(prefixIcon, color: AppTheme.textHint, size: 20),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.bgBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.bgBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }

  void _handleLogin(BuildContext context) {
    FocusScope.of(context).unfocus();
    _saveOrClearCredentials();
    context.read<LoginCubit>().login(
      _userController.text.trim(),
      _passController.text,
    );
  }
}