import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/owner_document_service.dart';
import '../../../../shared/widgets/vsp_upload_widgets.dart';
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

      final url = await _documentService.uploadAndSave(type: type, filePath: pickedFile.path);

      if (mounted) {
        setState(() {
          if (type == OwnerDocumentType.nationalIdFront) {
            _idFrontUrl = url;
          } else if (type == OwnerDocumentType.nationalIdBack) {
            _idBackUrl = url;
          }
        });
      }
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
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Owner information',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
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
                    color: index == 1 ? AppTheme.neonGreen : Colors.grey[700], 
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            const Text(
              'Upload an image',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (_idFrontUrl != null && _idBackUrl != null) 
                  ? () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const OwnerMainScreen()),
                      (route) => false,
                    );
                  }
                  : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: (_idFrontUrl != null && _idBackUrl != null) 
                    ? AppTheme.neonGreen 
                    : Colors.grey[800],
                  foregroundColor: (_idFrontUrl != null && _idBackUrl != null) 
                    ? Colors.black 
                    : Colors.white38,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
