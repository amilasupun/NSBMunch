import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/services/auth_service.dart';
import '../../widgets/app_widgets.dart';
import '../student/student_home.dart';

// register screen for all users
class RegisterScreen extends StatefulWidget {
  final String? initialEmail;
  const RegisterScreen({super.key, this.initialEmail});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _shopNameCtrl = TextEditingController();
  final _shopIdCtrl = TextEditingController();
  final _authService = AuthService();

  String _role = AppStrings.student;
  bool _loading = false;
  String? _error;

  // Role options
  final _roles = [
    {'value': AppStrings.student, 'label': 'Student'},
    {'value': AppStrings.staff, 'label': 'Staff'},
    {'value': AppStrings.vendor, 'label': 'Shop'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialEmail != null) {
      _emailCtrl.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _shopNameCtrl.dispose();
    _shopIdCtrl.dispose();
    super.dispose();
  }

  // Email hint based on role
  String get _emailHint {
    if (_role == AppStrings.student) return 'you@students.nsbm.ac.lk';
    if (_role == AppStrings.staff) return 'you@nsbm.ac.lk';
    return 'you@gmail.com';
  }

  // Register function
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await _authService.register(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passCtrl.text,
      role: _role,
      shopName: _shopNameCtrl.text,
      shopId: _shopIdCtrl.text,
    );
    // Save FCM token for notifications
    setState(() => _loading = false);
    if (!mounted) return;

    if (result['success'] == true) {
      if (_role == AppStrings.vendor) {
        _showVendorPendingDialog();
      } else {
        // Student or staff - go to home
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StudentHome()),
        );
      }
    } else {
      setState(() => _error = result['error']);
    }
  }

  // Vendor pending status
  void _showVendorPendingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Registration Submitted',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Your shop registration was submitted.\n\n'
          'You can login once an admin approves your account.',
          style: TextStyle(color: AppColors.textGrey, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.green,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Go to Login',
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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Register',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create your NSBM account',
                  style: TextStyle(fontSize: 13, color: AppColors.textGrey),
                ),

                const SizedBox(height: 20),

                // role selection
                const Text(
                  'I am a',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textWhite,
                  ),
                ),
                const SizedBox(height: 10),

                Row(
                  children: _roles.map((role) {
                    final bool selected = _role == role['value'];
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _role = role['value']!),
                        child: Container(
                          margin: role['value'] != AppStrings.vendor
                              ? const EdgeInsets.only(right: 8)
                              : EdgeInsets.zero,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.green
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selected
                                  ? AppColors.green
                                  : AppColors.border,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              role['label']!,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textGrey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),

                // full name
                AppTextField(
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  controller: _nameCtrl,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Please enter your name'
                      : null,
                ),

                const SizedBox(height: 14),

                // email
                AppTextField(
                  label: 'Email',
                  hint: _emailHint,
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!v.contains('@')) {
                      return 'Enter a valid email';
                    }

                    if (_role == AppStrings.student &&
                        !v.trim().endsWith(AppStrings.studentDomain)) {
                      return 'Students must use ${AppStrings.studentDomain}';
                    }
                    if (_role == AppStrings.staff) {
                      if (!v.trim().endsWith(AppStrings.staffDomain) ||
                          v.trim().endsWith(AppStrings.studentDomain)) {
                        return 'Staff must use ${AppStrings.staffDomain}';
                      }
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // Vendor only fields
                if (_role == AppStrings.vendor) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: AppColors.error,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Shop accounts need admin approval before login.',
                            style: TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Shop name
                  AppTextField(
                    label: 'Shop Name',
                    hint: 'e.g. NSBM Canteen A',
                    controller: _shopNameCtrl,
                    validator: (v) {
                      if (_role != AppStrings.vendor) return null;
                      if (v == null || v.isEmpty) return 'Enter shop name';
                      if (v.trim().length < 3) return 'Shop name too short';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Shop ID
                  AppTextField(
                    label: 'Shop ID (unique, e.g. SHOP001)',
                    hint: 'SHOP001',
                    controller: _shopIdCtrl,
                    validator: (v) {
                      if (_role != AppStrings.vendor) return null;
                      if (v == null || v.isEmpty) return 'Enter a Shop ID';
                      if (v.trim().length < 3) return 'Shop ID too short';
                      if (v.contains(' ')) return 'No spaces allowed';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // password
                AppTextField(
                  label: 'Password',
                  hint: 'At least 8 characters',
                  controller: _passCtrl,
                  isPassword: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a password';
                    if (v.length < 8) return 'At least 8 characters';
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // confirm password
                AppTextField(
                  label: 'Confirm Password',
                  hint: 'Re-enter your password',
                  controller: _confirmCtrl,
                  isPassword: true,
                  validator: (v) =>
                      v != _passCtrl.text ? 'Passwords do not match' : null,
                ),

                const SizedBox(height: 14),

                // Error
                if (_error != null) ...[
                  ErrorBox(message: _error!),
                  const SizedBox(height: 12),
                ],

                // Register button
                AppButton(
                  text: 'Register',
                  icon: Icons.person_add,
                  onPressed: _register,
                  isLoading: _loading,
                ),

                const SizedBox(height: 20),

                // Login link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(color: AppColors.textGrey),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
