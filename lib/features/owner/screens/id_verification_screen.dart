import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/services/owner_document_service.dart';
import '../../../../shared/widgets/vsp_upload_widgets.dart';
import '../../../core/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'owner_main_screen.dart';

class IdVerificationScreen extends StatefulWidget {
  const IdVerificationScreen({super.key});

  @override
  State<IdVerificationScreen> createState() => _IdVerificationScreenState();
}

class _IdVerificationScreenState extends State<IdVerificationScreen> {
  final OwnerDocumentService _documentService = OwnerDocumentService();

  // State
  String? _idFrontUrl;
  bool _isUploadingFront = false;

  String? _idBackUrl;
  bool _isUploadingBack = false;

  Future<void> _handleUpload(OwnerDocumentType type) async {
    try {
      final XFile? pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      setState(() {
        if (type == OwnerDocumentType.nationalIdFront) {
          _isUploadingFront = true;
        } else if (type == OwnerDocumentType.nationalIdBack) {
          _isUploadingBack = true;
        }
      });

      // 1. Get UID
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final uid = authProvider.currentUser?.uid;

      if (uid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: User not logged in')));
        }
        return;
      }

      final url = await _documentService.uploadAndSave(
        type: type, 
        filePath: pickedFile.path,
        uid: uid,
      );

      if (!mounted) return;
      setState(() {
        if (type == OwnerDocumentType.nationalIdFront) {
          _idFrontUrl = url;
        } else if (type == OwnerDocumentType.nationalIdBack) {
          _idBackUrl = url;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (type == OwnerDocumentType.nationalIdFront) {
            _isUploadingFront = false;
          } else if (type == OwnerDocumentType.nationalIdBack) {
            _isUploadingBack = false;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Owner information',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             // Indicators (Step 2/3)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Container(
                  width: index == 1 ? 30 : 8,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: index == 1 ? VSPColors.accent : VSPColors.divider, 
                    borderRadius: BorderRadius.circular(VSPRadius.xs),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            Text(
              'Upload an image',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
             const SizedBox(height: 16),

            // Front ID
            VspUploadMainCard(
              title: 'National ID Front',
              isLoading: _isUploadingFront,
              onTap: () => _handleUpload(OwnerDocumentType.nationalIdFront),
            ),
            
            if (_idFrontUrl != null) ...[
              const SizedBox(height: 16),
              VspUploadedItemRow(
                title: 'ID Front',
                subtitle: 'Uploaded Successfully',
                thumbnailUrl: _idFrontUrl,
                onDelete: () => setState(() => _idFrontUrl = null),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Back ID
            VspUploadMainCard(
              title: 'National ID Back',
              isLoading: _isUploadingBack,
              onTap: () => _handleUpload(OwnerDocumentType.nationalIdBack),
            ),

            if (_idBackUrl != null) ...[
              const SizedBox(height: 16),
              VspUploadedItemRow(
                title: 'ID Back',
                subtitle: 'Uploaded Successfully',
                thumbnailUrl: _idBackUrl,
                onDelete: () => setState(() => _idBackUrl = null),
              ),
            ],

            const SizedBox(height: 40),

            PrimaryButton(
              text: 'Save',
              onPressed: (_idFrontUrl != null && _idBackUrl != null) 
                ? () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const OwnerMainScreen()),
                    (route) => false,
                  );
                }
                : () {}, // Effectively disabled if logic requires both
            ),
          ],
        ),
      ),
    );
  }
}
