// Example: How to integrate Firebase Authentication in Signup Screen
// This is a reference implementation - adapt to your actual signup screens

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart' as app_auth;

class SignupIntegrationExample extends StatefulWidget {
  final String role; // 'player' or 'owner'
  
  const SignupIntegrationExample({super.key, required this.role});

  @override
  State<SignupIntegrationExample> createState() => _SignupIntegrationExampleState();
}

class _SignupIntegrationExampleState extends State<SignupIntegrationExample> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  Future<void> _handleSignup() async {
    final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    // Attempt signup
    bool success = await authProvider.signUp(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      role: widget.role,
      userData: {
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
      },
    );

    // Hide loading
    if (mounted) Navigator.pop(context);

    if (success) {
      // Navigate based on role
      if (widget.role == 'player') {
        // Navigate to Player Home
        Navigator.pushReplacementNamed(context, '/player-home');
      } else {
        // Navigate to Owner Dashboard or Documentation Wizard
        Navigator.pushReplacementNamed(context, '/owner-dashboard');
      }
    } else {
      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Signup failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleSignup,
              child: const Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// Example: How to integrate Stadium Provider
// ============================================

class StadiumListIntegrationExample extends StatelessWidget {
  const StadiumListIntegrationExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StadiumProvider>(
      builder: (context, stadiumProvider, child) {
        if (stadiumProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (stadiumProvider.errorMessage != null) {
          return Center(
            child: Text(
              'Error: ${stadiumProvider.errorMessage}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final stadiums = stadiumProvider.stadiums;

        if (stadiums.isEmpty) {
          return const Center(child: Text('No stadiums available'));
        }

        return ListView.builder(
          itemCount: stadiums.length,
          itemBuilder: (context, index) {
            final stadium = stadiums[index];
            return ListTile(
              leading: Image.network(stadium.imageUrl),
              title: Text(stadium.name),
              subtitle: Text(stadium.location),
              trailing: Text('\$${stadium.pricePerHour}/hr'),
            );
          },
        );
      },
    );
  }
}

// ============================================
// Example: How to integrate Match Join Logic
// ============================================

import '../../../core/services/database_service.dart';

class MatchCardIntegrationExample extends StatefulWidget {
  final String matchId;
  final String userId;
  
  const MatchCardIntegrationExample({
    super.key,
    required this.matchId,
    required this.userId,
  });

  @override
  State<MatchCardIntegrationExample> createState() => _MatchCardIntegrationExampleState();
}

class _MatchCardIntegrationExampleState extends State<MatchCardIntegrationExample> {
  final DatabaseService _databaseService = DatabaseService();
  bool _isJoined = false;
  bool _isLoading = false;

  Future<void> _toggleJoin() async {
    setState(() => _isLoading = true);

    bool success;
    if (_isJoined) {
      success = await _databaseService.leaveMatch(widget.matchId, widget.userId);
    } else {
      success = await _databaseService.joinMatch(widget.matchId, widget.userId);
    }

    if (success) {
      setState(() {
        _isJoined = !_isJoined;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update match'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _isLoading ? null : _toggleJoin,
      child: _isLoading
          ? const CircularProgressIndicator()
          : Text(_isJoined ? 'Leave' : 'Join'),
    );
  }
}

// ============================================
// Example: How to integrate Storage Service
// ============================================

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../../../core/services/storage_service.dart';

class DocumentUploadIntegrationExample extends StatefulWidget {
  final String ownerId;
  
  const DocumentUploadIntegrationExample({super.key, required this.ownerId});

  @override
  State<DocumentUploadIntegrationExample> createState() => _DocumentUploadIntegrationExampleState();
}

class _DocumentUploadIntegrationExampleState extends State<DocumentUploadIntegrationExample> {
  final StorageService _storageService = StorageService();
  final ImagePicker _picker = ImagePicker();
  String? _uploadedUrl;
  bool _isUploading = false;

  Future<void> _pickAndUploadDocument() async {
    // Pick image
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;

    setState(() => _isUploading = true);

    // Upload to Firebase Storage
    String? url = await _storageService.uploadOwnerDocument(
      file: File(image.path),
      ownerId: widget.ownerId,
      documentType: 'nationalIdFront',
    );

    setState(() {
      _uploadedUrl = url;
      _isUploading = false;
    });

    if (url != null) {
      // Save URL to Firestore user profile
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      await authProvider.updateProfile({
        'documents': {
          'nationalIdFront': url,
        },
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Upload failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: _isUploading ? null : _pickAndUploadDocument,
          child: _isUploading
              ? const CircularProgressIndicator()
              : const Text('Upload Document'),
        ),
        if (_uploadedUrl != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.network(_uploadedUrl!),
          ),
      ],
    );
  }
}
