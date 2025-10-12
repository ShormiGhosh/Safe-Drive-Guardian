import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool _isLoading = false;
  bool _isSignUp = false;
  bool _isPasswordVisible = false;

  final SupabaseClient _supabase = Supabase.instance.client;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // Replace your current _isValidEmail method with this simpler version:
  bool _isValidEmail(String email) {
    // Simpler regex that accepts most common email formats
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  // In _AuthPageState class, update the _signUp method:

  Future<void> _signUp() async {
    final String username = _usernameController.text.trim();
    final String email = _emailController.text.trim().toLowerCase();
    final String password = _passwordController.text.trim();

    // Basic validation
    if (username.isEmpty || email.isEmpty || password.isEmpty) {
      _showSnackBar('Please fill all fields', isError: true);
      return;
    }

    if (username.length < 3) {
      _showSnackBar('Username must be at least 3 characters', isError: true);
      return;
    }

    if (password.length < 6) {
      _showSnackBar('Password must be at least 6 characters', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Sign up with Supabase
      final AuthResponse response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'username': username, // store in user_metadata
        },
      );

      if (response.user != null) {
        // Insert into profiles table immediately
        await _supabase.from('profiles').insert({
          'id': response.user!.id,
          'username': username, // exact username
          'email': email,
          'created_at': DateTime.now().toIso8601String(),
        });

        _showSnackBar(
          'Registration successful! Please check your email to verify your account.',
          isError: false,
        );

        // Clear form and switch to login mode
        setState(() {
          _isSignUp = false;
          _emailController.clear();
          _passwordController.clear();
          _usernameController.clear();
        });
      }
    } on AuthException catch (error) {
      String errorMessage = 'Sign up failed';

      if (error.message.toLowerCase().contains('invalid email')) {
        errorMessage = 'Please enter a valid email address';
      } else if (error.message.contains('already registered')) {
        errorMessage = 'This email is already registered. Please sign in instead.';
      } else {
        errorMessage = error.message;
      }

      _showSnackBar(errorMessage, isError: true);
    } catch (error) {
      _showSnackBar('Registration error: Please try again', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }


  Future<void> _signIn() async {
    String email = _emailController.text.trim().toLowerCase();
    final String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Please enter both email and password', isError: true);
      return;
    }

    // Basic validation
    if (!_isValidEmail(email)) {
      _showSnackBar('Please enter a valid email address', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        _showSnackBar('Login successful!', isError: false);
      }
    } on AuthException catch (error) {
      String errorMessage = 'Login failed';

      if (error.message.contains('Invalid login credentials')) {
        errorMessage = 'Invalid email or password';
      } else if (error.message.contains('Email not confirmed')) {
        errorMessage = 'Please verify your email before signing in';
      } else {
        errorMessage = error.message;
      }

      _showSnackBar(errorMessage, isError: true);
    } catch (error) {
      _showSnackBar('An error occurred during login', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        backgroundColor: isError ? Colors.red[700] : Colors.green[700],
      ),
    );
  }

  void _toggleAuthMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _emailController.clear();
      _passwordController.clear();
      _usernameController.clear();
    });
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 60),
              Icon(
                Icons.security,
                size: 80,
                color: Colors.blue[700],
              ),
              const SizedBox(height: 20),
              Text(
                'Safe Drive Guardian',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                _isSignUp ? 'Create your account' : 'Sign in to your account',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              if (_isSignUp)
                TextField(
                  controller: _usernameController,
                  enabled: !_isLoading,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    hintText: 'At least 3 characters',
                    prefixIcon: Icon(Icons.person, color: Colors.blue[600]),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue[600]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              if (_isSignUp) const SizedBox(height: 16),

              TextField(
                controller: _emailController,
                enabled: !_isLoading,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'user@gmail.com',
                  prefixIcon: Icon(Icons.email, color: Colors.blue[600]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue[600]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _passwordController,
                enabled: !_isLoading,
                obscureText: !_isPasswordVisible,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: _isSignUp ? 'At least 6 characters' : 'Enter your password',
                  prefixIcon: Icon(Icons.lock, color: Colors.blue[600]),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.blue[600],
                    ),
                    onPressed: _togglePasswordVisibility,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.blue[600]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _isSignUp ? _signUp : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                      : Text(
                    _isSignUp ? 'Sign Up' : 'Sign In',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              TextButton(
                onPressed: _isLoading ? null : _toggleAuthMode,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue[600],
                ),
                child: Text(
                  _isSignUp
                      ? 'Already have an account? Sign In'
                      : 'Don\'t have an account? Sign Up',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}