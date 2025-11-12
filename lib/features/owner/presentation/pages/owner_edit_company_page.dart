import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:universal_html/html.dart' as html;
import '../../../../core/theme/theme.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/services/attachment_service.dart';

class EditCompanyPage {
  static Future<bool?> showEditCompanyDialog(
    BuildContext context,
    Map<String, dynamic> companyData,
  ) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EditCompanyDialog(companyData: companyData),
    );
  }
}

class EditCompanyDialog extends StatefulWidget {
  final Map<String, dynamic> companyData;

  const EditCompanyDialog({super.key, required this.companyData});

  @override
  State<EditCompanyDialog> createState() => _EditCompanyDialogState();
}

class _EditCompanyDialogState extends State<EditCompanyDialog> with SingleTickerProviderStateMixin {
  final CompanyService _companyService = CompanyService();
  final AttachmentService _attachmentService = AttachmentService();
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _sectorController;
  late TextEditingController _customSectorController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _timeOpenController;
  late TextEditingController _timeCloseController;
  late TextEditingController _deliveryFeeController;

  List<Uint8List> _selectedImages = [];
  List<String> _selectedFileNames = [];
  List<String> _selectedContentTypes = [];
  Map<int, Uint8List> _imageCache = {};
  List<int> _existingAttachmentIds = [];
  List<int> _deletedAttachmentIds = [];

  bool _isLoading = false;
  bool _isCustomSector = false;
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
    _populateFields();
    _loadExistingImages();
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
    _deliveryFeeController = TextEditingController();
  }

  void _populateFields() {
    final company = widget.companyData;
    _nameController.text = company['companyName'] ?? '';
    _descriptionController.text = company['companyDescription'] ?? '';
    final sector = company['companySector'] ?? '';
    _addressController.text = company['companyAddress'] ?? '';
    _phoneController.text = company['companyPhone'] ?? '';
    _emailController.text = company['companyEmail'] ?? '';

    if (_predefinedSectors.contains(sector)) {
      _sectorController.text = sector;
      _isCustomSector = false;
    } else {
      _customSectorController.text = sector;
      _isCustomSector = true;
    }

    _timeOpenController.text = _formatTime(company['timeOpen']);
    _timeCloseController.text = _formatTime(company['timeClose']);
    _deliveryFeeController.text = (company['deliveryFee'] ?? 0.0).toString();
  }

  String _formatTime(dynamic raw) {
    if (raw == null) return '';
    
    // Handle malformed list format like [14, :00]
    if (raw is List && raw.length >= 2) {
      try {
        final hour = raw[0].toString().replaceAll('[', '').replaceAll(',', '').trim();
        final minute = raw[1].toString().replaceAll(':', '').replaceAll(']', '').trim().padLeft(2, '0');
        final hourInt = int.tryParse(hour) ?? 0;
        final minuteInt = int.tryParse(minute) ?? 0;
        return '${hourInt.toString().padLeft(2, '0')}:${minuteInt.toString().padLeft(2, '0')}';
      } catch (e) {
        debugPrint('Error parsing time list: $raw');
        return '';
      }
    }
    
    // Handle string format
    final str = raw.toString();
    if (str.contains(':')) {
      final parts = str.split(':');
      if (parts.length >= 2) {
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      }
    }
    
    return str.length >= 5 ? str.substring(0, 5) : str;
  }

  Future<void> _loadExistingImages() async {
    final attachments = await _attachmentService.getAttachmentsByEntity(
      'COMPANY',
      widget.companyData['companyId'],
    );

    for (final att in attachments) {
      final id = int.tryParse(att['attachmentId'].toString());
      if (id != null) {
        _existingAttachmentIds.add(id);
        try {
          final dl = await _attachmentService.downloadAttachment(id);
          if (mounted) {
            setState(() {
              _imageCache[id] = dl.data as Uint8List;
            });
          }
        } catch (e) {
          debugPrint('Failed to load image $id: $e');
        }
      }
    }
  }

  void _removeExistingImage(int attachmentId) {
    setState(() {
      _imageCache.remove(attachmentId);
      _deletedAttachmentIds.add(attachmentId);
    });
  }

  Future<void> _pickImages() async {
    _selectedImages.clear();
    _selectedFileNames.clear();
    _selectedContentTypes.clear();

    if (kIsWeb) {
      final input = html.FileUploadInputElement()..multiple = true..accept = 'image/*';
      input.click();
      input.onChange.listen((e) async {
        final files = input.files!;
        final List<Uint8List> bytes = [];
        final List<String> names = [];
        final List<String> types = [];
        for (var file in files) {
          final reader = html.FileReader();
          reader.readAsArrayBuffer(file);
          await reader.onLoadEnd.first;
          bytes.add(reader.result as Uint8List);
          names.add(file.name.isEmpty ? 'image.jpg' : file.name);
          types.add(file.type.isEmpty ? 'image/jpeg' : file.type);
        }
        setState(() {
          _selectedImages = bytes;
          _selectedFileNames = names;
          _selectedContentTypes = types;
        });
      });
    } else {
      final images = await _picker.pickMultiImage(imageQuality: 85);
      if (images.isNotEmpty) {
        final List<Uint8List> bytes = [];
        final List<String> names = [];
        final List<String> types = [];
        for (var img in images) {
          bytes.add(await img.readAsBytes());
          names.add(img.name);
          types.add(img.mimeType ?? 'image/jpeg');
        }
        setState(() {
          _selectedImages = bytes;
          _selectedFileNames = names;
          _selectedContentTypes = types;
        });
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _selectedFileNames.removeAt(index);
      _selectedContentTypes.removeAt(index);
    });
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (time != null) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      controller.text = '$h:$m';
    }
  }

  Future<void> _submitForm() async {
    if (!_validateForm()) return;

    setState(() => _isLoading = true);
    try {
      // Ensure proper time format HH:MM:SS
      String timeOpen = _timeOpenController.text.trim();
      String timeClose = _timeCloseController.text.trim();
      
      // Add seconds if not present
      if (timeOpen.isNotEmpty && !timeOpen.contains(':00', timeOpen.length - 3)) {
        timeOpen = timeOpen.length == 5 ? '$timeOpen:00' : timeOpen;
      }
      if (timeClose.isNotEmpty && !timeClose.contains(':00', timeClose.length - 3)) {
        timeClose = timeClose.length == 5 ? '$timeClose:00' : timeClose;
      }
      final sector = _isCustomSector ? _customSectorController.text.trim() : _sectorController.text;

      final payload = {
        'companyName': _nameController.text.trim(),
        'companyDescription': _descriptionController.text.trim(),
        'companySector': sector,
        'companyAddress': _addressController.text.trim(),
        'companyPhone': _phoneController.text.trim(),
        'companyEmail': _emailController.text.trim(),
        'timeOpen': timeOpen,
        'timeClose': timeClose,
        'deliveryFee': double.tryParse(_deliveryFeeController.text.trim()) ?? 0.0,
      };

      final companyId = widget.companyData['companyId'];
      await _companyService.updateCompany(companyId, payload);

      // Delete removed images
      for (var id in _deletedAttachmentIds) {
        try {
          await _attachmentService.deleteAttachment(id);
          debugPrint('✅ Deleted attachment $id');
        } catch (e) {
          debugPrint('❌ Failed to delete attachment $id: $e');
        }
      }

      // Upload new images
      for (int i = 0; i < _selectedImages.length; i++) {
        await _attachmentService.createAttachment(
          fileBytes: _selectedImages[i],
          fileName: _selectedFileNames[i],
          contentType: _selectedContentTypes[i],
          entityType: 'COMPANY',
          entityId: companyId,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entreprise mise à jour !'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true); // ← Critical for refresh
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _validateForm() {
    if (_nameController.text.trim().isEmpty) return _showError('Nom requis');
    if (_isCustomSector && _customSectorController.text.trim().isEmpty) return _showError('Secteur requis');
    if (!_isCustomSector && _sectorController.text.isEmpty) return _showError('Sélectionnez un secteur');
    if (_phoneController.text.trim().isEmpty) return _showError('Téléphone requis');
    if (_emailController.text.trim().isEmpty) return _showError('Email requis');
    if (_timeOpenController.text.isEmpty || _timeCloseController.text.isEmpty) return _showError('Horaires requis');
    return true;
  }

  bool _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
    return false;
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
    _deliveryFeeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final maxWidth = isMobile ? double.infinity : 700.0;

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic)),
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 24, vertical: isMobile ? 16 : 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 40, offset: const Offset(0, 20)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
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
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
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
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.business, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Modifier Entreprise', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Modifiez les informations', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.close, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 8))],
              ),
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                child: _isLoading
                    ? const Text('Enregistrement...')
                    : const Text('Mettre à jour', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection() => _buildCard('Informations générales', [
    _buildField(_nameController, 'Nom entreprise', Icons.business_rounded),
    const SizedBox(height: 12),
    _buildSectorSelection(),
    const SizedBox(height: 12),
    _buildField(_descriptionController, 'Description', Icons.description_outlined, maxLines: 3),
  ]);

  Widget _buildContactSection() => _buildCard('Contact', [
    _buildField(_phoneController, 'Téléphone', Icons.phone_rounded),
    const SizedBox(height: 12),
    _buildField(_emailController, 'Email', Icons.email_rounded),
    const SizedBox(height: 12),
    _buildField(_addressController, 'Adresse', Icons.location_on_rounded),
    const SizedBox(height: 12),
    _buildField(_deliveryFeeController, 'Frais de livraison (DT)', Icons.local_shipping_rounded, keyboardType: TextInputType.number),
  ]);

  Widget _buildHoursSection() => _buildCard('Horaires', [
    Row(
      children: [
        Expanded(child: _buildTimeField(_timeOpenController, 'Ouverture')),
        const SizedBox(width: 12),
        Expanded(child: _buildTimeField(_timeCloseController, 'Fermeture')),
      ],
    ),
  ]);

  Widget _buildImagesSection() {
    return _buildCard('Images', [
      if (_imageCache.isEmpty && _selectedImages.isEmpty)
        _buildAddImageButton()
      else
        Column(
          children: [
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
              itemCount: _imageCache.length + _selectedImages.length,
              itemBuilder: (ctx, i) {
                if (i < _imageCache.length) {
                  final id = _imageCache.keys.elementAt(i);
                  return _buildImageTile(_imageCache[id]!, () => _removeExistingImage(id));
                } else {
                  final idx = i - _imageCache.length;
                  return _buildImageTile(_selectedImages[idx], () => _removeImage(idx));
                }
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: _pickImages, icon: const Icon(Icons.add_photo_alternate), label: const Text('Ajouter plus')),
          ],
        ),
    ]);
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildField(TextEditingController c, String label, IconData icon, {int maxLines = 1, TextInputType? keyboardType}) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildTimeField(TextEditingController c, String label) {
    return GestureDetector(
      onTap: () => _selectTime(c),
      child: TextFormField(
        controller: c,
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

  Widget _buildSectorSelection() {
    return !_isCustomSector
        ? Column(
      children: [
        DropdownButtonFormField<String>(
          value: _sectorController.text.isEmpty ? null : _sectorController.text,
          decoration: InputDecoration(
            labelText: 'Secteur',
            prefixIcon: const Icon(Icons.category_outlined, color: AppColors.primary, size: 20),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          items: _predefinedSectors
              .map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13))))
              .toList(),
          onChanged: (v) => setState(() => _sectorController.text = v ?? ''),
        ),
        TextButton.icon(
          onPressed: () => setState(() => _isCustomSector = true),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Secteur personnalisé', style: TextStyle(fontSize: 12)),
        ),
      ],
    )
        : Column(
      children: [
        _buildField(_customSectorController, 'Secteur personnalisé', Icons.category_rounded),
        TextButton.icon(
          onPressed: () => setState(() => _isCustomSector = false),
          icon: const Icon(Icons.arrow_back, size: 16),
          label: const Text('Secteurs prédéfinis', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildAddImageButton() {
    return InkWell(
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
    );
  }

  Widget _buildImageTile(Uint8List bytes, VoidCallback onRemove) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
        ),
        Positioned(
          top: 4, right: 4,
          child: GestureDetector(
            onTap: onRemove,
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
}