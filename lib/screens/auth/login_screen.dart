import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/auth_service.dart';
import '../../widgets/app_widgets.dart';
import '../student/student_home.dart';
import '../vendor/vendor_home.dart';
import '../admin/admin_home.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _authService = AuthService();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _authService.login(_emailCtrl.text, _passCtrl.text);
    setState(() => _loading = false);
    if (!mounted) return;

    if (result['success'] == true) {
      _goToHome(result['role'] as String);
    } else {
      final error = result['error'] as String;
      if (error == AppStrings.vendorRejected) {
        _showRejectedDialog();
      } else {
        setState(() => _error = error);
      }
    }
  }

  void _goToHome(String role) {
    Widget screen;
    if (role == AppStrings.admin) {
      screen = const AdminHome();
    } else if (role == AppStrings.vendor) {
      screen = const VendorHome();
    } else {
      screen = const StudentHome();
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  void _showForgotPasswordDialog() {
    final emailCtrl = TextEditingController(text: _emailCtrl.text);
    String? dialogError;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text(
            'Reset Password',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textWhite,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your email to get a reset link.',
                style: TextStyle(color: AppColors.textGrey),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: AppColors.textWhite),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: const TextStyle(color: AppColors.textGrey),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.green,
                      width: 2,
                    ),
                  ),
                ),
              ),
              if (dialogError != null) ...[
                const SizedBox(height: 8),
                Text(
                  dialogError!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppColors.textGrey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.green,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                if (emailCtrl.text.trim().isEmpty) {
                  setS(() => dialogError = 'Please enter your email.');
                  return;
                }
                final messenger = ScaffoldMessenger.of(context);
                final res = await _authService.sendPasswordReset(
                  emailCtrl.text,
                );
                if (!ctx.mounted) return;
                if (res['success'] == true) {
                  Navigator.pop(ctx);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(AppStrings.resetSent),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  setS(() => dialogError = res['error']);
                }
              },
              child: const Text(
                'Send Link',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRejectedDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Shop Rejected',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textWhite,
          ),
        ),
        content: const Text(
          'Your shop was rejected by admin.\n\nYou can delete this account and apply again.',
          style: TextStyle(color: AppColors.textGrey, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textGrey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ReRegisterScreen(
                    email: _emailCtrl.text,
                    password: _passCtrl.text,
                  ),
                ),
              );
            },
            child: const Text(
              'Delete & Re-Register',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // app icon
                Center(
                  child: Image.asset(
                    'assets/icons/app_icon.png',
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textWhite,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sign in to your account',
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),

                const SizedBox(height: 20),

                AppTextField(
                  label: 'Email',
                  hint: 'Enter your email',
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Please enter your email'
                      : null,
                ),

                const SizedBox(height: 14),

                AppTextField(
                  label: 'Password',
                  hint: 'Enter your password',
                  controller: _passCtrl,
                  isPassword: true,
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Please enter your password'
                      : null,
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _showForgotPasswordDialog,
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(color: AppColors.green, fontSize: 13),
                    ),
                  ),
                ),

                if (_error != null) ...[
                  ErrorBox(message: _error!),
                  const SizedBox(height: 12),
                ],

                AppButton(
                  text: 'Login',
                  onPressed: _login,
                  isLoading: _loading,
                  color: AppColors.green,
                ),

                const SizedBox(height: 24),

                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(color: AppColors.textGrey),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RegisterScreen(),
                          ),
                        ),
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w600,
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
    );
  }
}

// reregister screen for rejected vendors
class ReRegisterScreen extends StatefulWidget {
  final String email;
  final String password;
  const ReRegisterScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<ReRegisterScreen> createState() => _ReRegisterScreenState();
}

class _ReRegisterScreenState extends State<ReRegisterScreen> {
  final _authService = AuthService();
  bool _loading = false;
  String? _error;

  Future<void> _deleteAndReRegister() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _authService.deleteRejectedAccount(
      widget.email,
      widget.password,
    );
    setState(() => _loading = false);
    if (!mounted) return;

    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account deleted. Please register again.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RegisterScreen(initialEmail: widget.email),
        ),
      );
    } else {
      setState(() => _error = result['error']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Re-Register',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Account to delete',
                    style: TextStyle(fontSize: 12, color: AppColors.textGrey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.email,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textWhite,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.4),
                ),
              ),
              child: const Text(
                'This will delete your rejected account.\nYou will then register again.\nYour new application needs admin approval.',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              ErrorBox(message: _error!),
              const SizedBox(height: 14),
            ],
            AppButton(
              text: 'Confirm Delete & Re-Register',
              onPressed: _deleteAndReRegister,
              isLoading: _loading,
              color: AppColors.error,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.textGrey,
                    fontWeight: FontWeight.w600,
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
