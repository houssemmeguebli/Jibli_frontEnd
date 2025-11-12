import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/services/category_service.dart';
import '../../../../core/services/attachment_service.dart';
class CategoryDialog extends StatefulWidget {
  final VoidCallback onCategorySaved;
  final Map<String, dynamic>? category;
  final CategoryService categoryService;
  final AttachmentService attachmentService;

  const CategoryDialog({
    super.key,
    required this.onCategorySaved,
    this.category,
    required this.categoryService,
    required this.attachmentService,
  });

  @override
  State<CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<CategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  final ImagePicker _picker = ImagePicker();

  Uint8List? _selectedImageBytes;
  Uint8List? _existingImageBytes;
  String? _selectedFileName;
  String? _selectedContentType;
  bool _isLoading = false;
  bool _isLoadingImage = true;
  final int currentUserId = 1;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.category?['name'] ?? '');
    _descriptionController =
        TextEditingController(text: widget.category?['description'] ?? '');

    // Load existing image if editing
    if (widget.category != null) {
      _loadExistingCategoryImage();
    } else {
      setState(() => _isLoadingImage = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingCategoryImage() async {
    try {
      final categoryId = widget.category?['categoryId'] as int?;
      if (categoryId == null) {
        setState(() => _isLoadingImage = false);
        return;
      }

      final attachments =
      await widget.attachmentService.getAttachmentsByEntity('CATEGORY', categoryId);

      if (attachments.isNotEmpty) {
        final firstAttachment = attachments.first as Map<String, dynamic>;
        final attachmentId = firstAttachment['attachmentId'] as int?;

        if (attachmentId != null) {
          final attachmentDownload =
          await widget.attachmentService.downloadAttachment(attachmentId);
          if (attachmentDownload.data.isNotEmpty) {
            setState(() {
              _existingImageBytes = attachmentDownload.data;
            });
          }
        }
      }

      setState(() => _isLoadingImage = false);
    } catch (e) {
      debugPrint('⚠️ Error loading existing category image: $e');
      setState(() => _isLoadingImage = false);
    }
  }

  Future<void> _pickImage() async {
    try {
      if (kIsWeb) {
        final html.FileUploadInputElement uploadInput = html
            .FileUploadInputElement();
        uploadInput.accept = 'image/*';
        uploadInput.click();

        uploadInput.onChange.listen((event) async {
          final files = uploadInput.files;
          if (files != null && files.isNotEmpty) {
            final file = files.first;
            final reader = html.FileReader();
            reader.readAsArrayBuffer(file);
            await reader.onLoadEnd.first;
            setState(() {
              _selectedImageBytes = reader.result as Uint8List;
              _selectedFileName =
              file.name.isEmpty ? 'category.jpg' : file.name;
              _selectedContentType =
              file.type.isEmpty ? 'image/jpeg' : file.type;
            });
          }
        });
      } else {
        final XFile? image = await _picker.pickImage(
            source: ImageSource.gallery);
        if (image != null) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImageBytes = bytes;
            _selectedFileName =
            image.name.isEmpty ? 'category.jpg' : image.name;
            _selectedContentType = image.mimeType ?? 'image/jpeg';
          });
        }
      }
    } catch (e) {
      _showSnackBar(
          'Erreur lors de la sélection de l\'image: $e', isError: true);
    }
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final categoryData = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'userId': currentUserId,
      };

      late Map<String, dynamic> savedCategory;
      late int categoryId;

      if (widget.category != null) {
        // Update existing category
        categoryId = widget.category!['categoryId'];
        await widget.categoryService.updateCategory(categoryId, categoryData);
        savedCategory = widget.category!;
      } else {
        // Create new category
        savedCategory =
        await widget.categoryService.createCategory(categoryData);
        categoryId = savedCategory['categoryId'] ?? savedCategory['id'];
      }

      // Upload image if a new one was selected
      if (_selectedImageBytes != null && categoryId != null) {
        try {
          // Delete existing attachments for this category if editing
          if (widget.category != null) {
            try {
              final existingAttachments =
              await widget.attachmentService.getAttachmentsByEntity('CATEGORY', categoryId);
              for (final attachment in existingAttachments) {
                final attachmentId = attachment['attachmentId'] as int?;
                if (attachmentId != null) {
                  await widget.attachmentService.deleteAttachment(attachmentId);
                }
              }
            } catch (e) {
              debugPrint('Note: Could not delete existing attachments: $e');
            }
          }

          // Create new attachment with CATEGORY entity type
          await widget.attachmentService.createAttachment(
            fileBytes: _selectedImageBytes!,
            fileName: _selectedFileName!,
            contentType: _selectedContentType!,
            entityType: 'CATEGORY',
            entityId: categoryId,
          );
        } catch (e) {
          debugPrint('Warning: Image upload failed: $e');
          _showSnackBar(
            'Catégorie sauvegardée, mais l\'image n\'a pas pu être uploadée: $e',
            isError: false,
          );
        }
      }

      widget.onCategorySaved();
      if (mounted) {
        Navigator.of(context).pop();
        _showSnackBar('Catégorie sauvegardée avec succès');
      }
    } catch (e) {
      _showSnackBar('Erreur: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
      ),
    );
  }

  Widget _buildImageSection() {
    if (_isLoadingImage) {
      return Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[50],
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: Colors.grey[400],
          ),
        ),
      );
    }

    // Show newly selected image if available
    if (_selectedImageBytes != null) {
      return GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[50],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _selectedImageBytes!,
              fit: BoxFit.cover,
            ),
          ),
        ),
      );
    }

    // Show existing image if available
    if (_existingImageBytes != null) {
      return GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[50],
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  _existingImageBytes!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(
                    Icons.edit,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show empty state
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.grey[50],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate, size: 40,
                color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text(
              'Ajouter une image (optionnel)',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.orange[400]!, Colors.orange[600]!],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_rounded : Icons.category_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'Modifier la catégorie'
                          : 'Ajouter une catégorie',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nom de la catégorie',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le nom est requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnel)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description_outlined),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _buildImageSection(),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () =>
                          Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveCategory,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange[600],
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                          : Text(isEditing ? 'Modifier' : 'Créer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}