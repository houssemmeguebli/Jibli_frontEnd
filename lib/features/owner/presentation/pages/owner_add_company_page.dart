import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/services/attachment_service.dart';
import 'package:universal_html/html.dart' as html;

class AddCompanyPage {
  static Future<bool?> showAddCompanyDialog(
    BuildContext context, {
    Map<String, dynamic>? companyData,
    bool isEditing = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddCompanyDialog(
        companyData: companyData,
        isEditing: isEditing,
      ),
    );
  }
}

class AddCompanyDialog extends StatefulWidget {
  final Map<String, dynamic>? companyData;
  final bool isEditing;
  final VoidCallback? onCompanyAdded;

  const AddCompanyDialog({
    super.key,
    this.companyData,
    this.isEditing = false,
    this.onCompanyAdded,
  });

  @override
  State<AddCompanyDialog> createState() => _AddCompanyDialogState();
}

class _AddCompanyDialogState extends State<AddCompanyDialog> with SingleTickerProviderStateMixin {
  final CompanyService _companyService = CompanyService();
  final AttachmentService _attachmentService = AttachmentService();
  final ImagePicker _imagePicker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _sectorController;
  late TextEditingController _customSectorController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _timeOpenController;
  late TextEditingController _timeCloseController;

  List<Uint8List> _selectedImages = [];
  List<String> _selectedFileNames = [];
  List<String> _selectedContentTypes = [];
  final ImagePicker _picker = ImagePicker();
  Map<int, Uint8List> _imageCache = {};
  List<int> _existingAttachmentIds = [];

  bool _isLoading = false;
  bool _isCustomSector = false;
  static const int currentUserId = 2;
  late AnimationController _slideController;

  final List<String> _predefinedSectors = [
    'Électronique',
    'Restaurant',
    'Épicerie',
    'Mode',
    'Santé',
    'Éducation',
  ];

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideController.forward();
    _initializeControllers();
    if (widget.isEditing && widget.companyData != null) {
      _populateFields();
      _loadExistingImages();
    }
  }

  void _initializeControllers() {
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _sectorController = TextEditingController();
    _customSectorController = TextEditingController();
    _addressController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _timeOpenController = TextEditingController();
    _timeCloseController = TextEditingController();
  }

  void _populateFields() {
    final company = widget.companyData!;
    _nameController.text = company['companyName'] ?? '';
    _descriptionController.text = company['companyDescription'] ?? '';
    final sector = company['companySector'] ?? '';
    _addressController.text = company['companyAddress'] ?? '';
    _phoneController.text = company['companyPhone'] ?? '';
    _emailController.text = company['companyEmail'] ?? '';

    // Check if sector is predefined or custom
    if (_predefinedSectors.contains(sector)) {
      _sectorController.text = sector;
      _isCustomSector = false;
    } else {
      _customSectorController.text = sector;
      _isCustomSector = true;
    }

    // Handle time format - could be "HH:mm:ss" or "HH:mm"
    final timeOpen = company['timeOpen'];
    if (timeOpen != null) {
      _timeOpenController.text = timeOpen.toString().substring(0, 5);
    }

    final timeClose = company['timeClose'];
    if (timeClose != null) {
      _timeCloseController.text = timeClose.toString().substring(0, 5);
    }
  }

  Future<void> _loadExistingImages() async {
    if (widget.companyData == null) return;
    
    final attachments = widget.companyData!['attachments'] as List<dynamic>?;
    if (attachments != null && attachments.isNotEmpty) {
      for (final attachment in attachments) {
        final attachmentId = attachment['attachmentId'] as int;
        _existingAttachmentIds.add(attachmentId);
        try {
          final download = await _attachmentService.downloadAttachment(attachmentId);
          if (mounted) {
            setState(() {
              _imageCache[attachmentId] = download.data;
            });
          }
        } catch (e) {
          debugPrint('Error loading image $attachmentId: $e');
        }
      }
    }
  }

  void _removeExistingImage(int attachmentId) {
    setState(() {
      _imageCache.remove(attachmentId);
      _existingAttachmentIds.remove(attachmentId);
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _sectorController.dispose();
    _customSectorController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _timeOpenController.dispose();
    _timeCloseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    _selectedImages.clear();
    _selectedFileNames.clear();
    _selectedContentTypes.clear();

    if (kIsWeb) {
      final html.FileUploadInputElement uploadInput = html.FileUploadInputElement();
      uploadInput.multiple = true;
      uploadInput.accept = 'image/*';
      uploadInput.click();

      uploadInput.onChange.listen((event) async {
        final files = uploadInput.files;
        if (files != null && files.isNotEmpty) {
          final List<Uint8List> bytesList = [];
          final List<String> names = [];
          final List<String> types = [];
          for (var file in files) {
            final reader = html.FileReader();
            reader.readAsArrayBuffer(file);
            await reader.onLoadEnd.first;
            bytesList.add(reader.result as Uint8List);
            names.add(file.name.isEmpty ? 'image.jpg' : file.name);
            types.add(file.type.isEmpty ? 'image/jpeg' : file.type);
          }
          setState(() {
            _selectedImages = bytesList;
            _selectedFileNames = names;
            _selectedContentTypes = types;
          });
        }
      });
    } else {
      final List<XFile> images = await _picker.pickMultiImage(
        imageQuality: 85,
      );
      if (images.isNotEmpty) {
        final List<Uint8List> bytesList = [];
        final List<String> names = [];
        final List<String> types = [];
        for (var img in images) {
          bytesList.add(await img.readAsBytes());
          names.add(img.name.isEmpty ? 'image.jpg' : img.name);
          types.add(img.mimeType ?? 'image/jpeg');
        }
        setState(() {
          _selectedImages = bytesList;
          _selectedFileNames = names;
          _selectedContentTypes = types;
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);

    try {
      // Format times to HH:mm:ss for backend
      final timeOpen = '${_timeOpenController.text}:00';
      final timeClose = '${_timeCloseController.text}:00';

      debugPrint('Time Open: $timeOpen');
      debugPrint('Time Close: $timeClose');

      // Get the appropriate sector value
      final sectorValue = _isCustomSector ? _customSectorController.text.trim() : _sectorController.text;

      final companyData = {
        'companyName': _nameController.text.trim(),
        'companyDescription': _descriptionController.text.trim(),
        'companySector': sectorValue,
        'companyAddress': _addressController.text.trim(),
        'companyPhone': _phoneController.text.trim(),
        'companyEmail': _emailController.text.trim(),
        'timeOpen': timeOpen,
        'timeClose': timeClose,
        'userId': currentUserId,

      };

      debugPrint('Company Data: $companyData');

      int companyId;

      if (widget.isEditing) {
        // For editing existing company
        companyId = widget.companyData!['companyId'];
        companyData['companyId'] = companyId as String;
        await _companyService.updateCompany(companyId, companyData);
      } else {
        // For creating new company
        final response = await _companyService.createCompany(companyData);
        companyId = response['companyId'];
      }

      // Upload new attachments if any images are selected
      if (_selectedImages.isNotEmpty) {
        await _addAttachmentsToCompany(companyId);
      }

      if (mounted) {
        _showSnackBar(
          widget.isEditing
              ? 'Entreprise mise à jour avec succès'
              : 'Entreprise créée avec succès',
        );
        widget.onCompanyAdded?.call();
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      debugPrint('Error: $e');
      _showSnackBar('Erreur: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _validateForm() {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('Veuillez entrer le nom de l\'entreprise', isError: true);
      return false;
    }

    if (_isCustomSector) {
      if (_customSectorController.text.trim().isEmpty) {
        _showSnackBar('Veuillez entrer un secteur', isError: true);
        return false;
      }
    } else {
      if (_sectorController.text.trim().isEmpty) {
        _showSnackBar('Veuillez sélectionner un secteur', isError: true);
        return false;
      }
    }

    if (_phoneController.text.trim().isEmpty) {
      _showSnackBar('Veuillez entrer un numéro de téléphone', isError: true);
      return false;
    }
    if (_emailController.text.trim().isEmpty) {
      _showSnackBar('Veuillez entrer une adresse email', isError: true);
      return false;
    }
    if (_timeOpenController.text.trim().isEmpty ||
        _timeCloseController.text.trim().isEmpty) {
      _showSnackBar('Veuillez entrer les horaires d\'ouverture', isError: true);
      return false;
    }
    return true;
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _selectedFileNames.removeAt(index);
      _selectedContentTypes.removeAt(index);
    });
  }

  Future<void> _addAttachmentsToCompany(int companyId) async {
    for (int i = 0; i < _selectedImages.length; i++) {
      final bytes = _selectedImages[i];
      final fileName = _selectedFileNames[i];
      final contentType = _selectedContentTypes[i];

      print('Uploading attachment $i: name=$fileName, type=$contentType, bytesLength=${bytes.length}, entity=Company:$companyId');

      try {
        await _attachmentService.createAttachment(
          fileBytes: bytes,
          fileName: fileName,
          contentType: contentType,
          entityType: 'Company',
          entityId: companyId,
        );
      } catch (e) {
        print('Attachment upload failed: $e');
        throw Exception('Échec upload image $i: $e');
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red[600] : Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        // Convert to 24-hour format HH:mm
        final hour = time.hour.toString().padLeft(2, '0');
        final minute = time.minute.toString().padLeft(2, '0');
        controller.text = '$hour:$minute';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final maxWidth = isMobile ? double.infinity : 700.0;

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic)),
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 24,
          vertical: isMobile ? 16 : 40,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildInfoSection(),
                      const SizedBox(height: 20),
                      _buildContactSection(),
                      const SizedBox(height: 20),
                      _buildHoursSection(),
                      const SizedBox(height: 20),
                      _buildImagesSection(),
                    ],
                  ),
                ),
              ),
              _buildDialogActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.business, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isEditing ? 'Modifier Entreprise' : 'Nouvelle Entreprise',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isEditing ? 'Modifiez les informations' : 'Créez votre entreprise',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogActions() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: Colors.grey[300]!, width: 2),
              ),
              child: Text(
                'Annuler',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text('Enregistrement...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      widget.isEditing ? 'Mettre à jour' : 'Créer',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informations générales', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          _buildCompactTextField(_nameController, 'Nom entreprise', Icons.business_rounded),
          const SizedBox(height: 12),
          _buildSectorSelection(),
          const SizedBox(height: 12),
          _buildCompactTextField(_descriptionController, 'Description', Icons.description_outlined, maxLines: 3),
        ],
      ),
    );
  }

  Widget _buildSectorSelection() {
    return !_isCustomSector
        ? Column(
      children: [
        DropdownButtonFormField<String>(
          value: _sectorController.text.isEmpty ? null : _sectorController.text,
          decoration: InputDecoration(
            labelText: 'Secteur',
            prefixIcon: const Icon(Icons.category_outlined, color: AppColors.primary, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            filled: true,
            fillColor: Colors.white,
          ),
          items: _predefinedSectors.map((item) => DropdownMenuItem(value: item, child: Text(item, style: const TextStyle(fontSize: 13)))).toList(),
          onChanged: (value) => setState(() => _sectorController.text = value ?? ''),
        ),
        TextButton.icon(
          onPressed: () => setState(() { _isCustomSector = true; _sectorController.clear(); }),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Secteur personnalisé', style: TextStyle(fontSize: 12)),
        ),
      ],
    )
        : Column(
      children: [
        _buildCompactTextField(_customSectorController, 'Secteur personnalisé', Icons.category_rounded),
        TextButton.icon(
          onPressed: () => setState(() { _isCustomSector = false; _customSectorController.clear(); }),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Secteurs prédéfinis', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildCompactTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildTimeField(TextEditingController controller, String label) {
    return GestureDetector(
      onTap: () => _selectTime(controller),
      child: TextFormField(
        controller: controller,
        enabled: false,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.schedule, color: AppColors.primary, size: 20),
          suffixIcon: const Icon(Icons.access_time, color: AppColors.primary, size: 16),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Contact', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          _buildCompactTextField(_phoneController, 'Téléphone', Icons.phone_rounded),
          const SizedBox(height: 12),
          _buildCompactTextField(_emailController, 'Email', Icons.email_rounded),
          const SizedBox(height: 12),
          _buildCompactTextField(_addressController, 'Adresse', Icons.location_on_rounded),
        ],
      ),
    );
  }

  Widget _buildHoursSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Horaires', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTimeField(_timeOpenController, 'Ouverture')),
              const SizedBox(width: 12),
              Expanded(child: _buildTimeField(_timeCloseController, 'Fermeture')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Images', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          if (_selectedImages.isEmpty && _imageCache.isEmpty)
            InkWell(
              onTap: _pickImages,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 32),
                      const SizedBox(height: 8),
                      Text('Ajouter images', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            )
          else
            Column(
              children: [
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _imageCache.length + _selectedImages.length,
                  itemBuilder: (context, index) {
                    if (index < _imageCache.length) {
                      final attachmentId = _imageCache.keys.elementAt(index);
                      final imageData = _imageCache[attachmentId]!;
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(imageData, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                          ),
                          Positioned(
                            top: 4, right: 4,
                            child: GestureDetector(
                              onTap: () => _removeExistingImage(attachmentId),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      );
                    } else {
                      final newImageIndex = index - _imageCache.length;
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(_selectedImages[newImageIndex], fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                          ),
                          Positioned(
                            top: 4, right: 4,
                            child: GestureDetector(
                              onTap: () => _removeImage(newImageIndex),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 14),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Ajouter plus'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }








}