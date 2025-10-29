import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import '../../../../core/theme/theme.dart';
import '../../../../Core/services/category_service.dart';
import '../../../../Core/services/product_service.dart';
import '../../../../Core/services/attachment_service.dart';
import '../../../../Core/services/company_service.dart';

class AddProductDialog extends StatefulWidget {
  final VoidCallback? onProductAdded;
  const AddProductDialog({super.key, this.onProductAdded});

  @override
  State<AddProductDialog> createState() => _AddProductDialogState();
}

class _AddProductDialogState extends State<AddProductDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isAvailable = true;
  List<Uint8List> _selectedImages = [];
  List<String> _selectedFileNames = [];
  List<String> _selectedContentTypes = [];
  final ImagePicker _picker = ImagePicker();
  double _finalPrice = 0.0;
  late AnimationController _slideController;
  final currentUserId = 2;
  final CategoryService _categoryService = CategoryService();
  final ProductService _productService = ProductService();
  final AttachmentService _attachmentService = AttachmentService();
  final CompanyService _companyService = CompanyService();
  List<dynamic> _categories = [];
  List<Map<String, dynamic>> _companies = [];
  int? _selectedCategoryId;
  int? _selectedCompanyId;
  bool _isLoadingCategories = true;
  bool _isLoadingCompanies = true;
  String? _categoryError;
  String? _companyError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _priceController.addListener(_calculateFinalPrice);
    _discountController.addListener(_calculateFinalPrice);

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _slideController.forward();
    _loadCategories();
    _loadCompanies();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _descriptionController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _calculateFinalPrice() {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    setState(() {
      _finalPrice = price - (price * discount / 100);
    });
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoadingCategories = true;
        _categoryError = null;
      });
      final categories = await _categoryService.getCategoryByUserId(currentUserId);
      setState(() {
        _categories = categories as List;
        _isLoadingCategories = false;
        _selectedCategoryId = null;
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
      setState(() {
        _isLoadingCategories = false;
        _categoryError = 'Erreur de chargement des catégories';
      });
    }
  }

  Future<void> _loadCompanies() async {
    try {
      setState(() {
        _isLoadingCompanies = true;
        _companyError = null;
      });
      final companiesData = await _companyService.getCompanyByUserID(currentUserId);
      List<Map<String, dynamic>> companiesList = [];

      if (companiesData != null) {
        if (companiesData is List<dynamic>) {
          companiesList = (companiesData as List<dynamic>)
              .where((item) => item is Map)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .where((company) => company.containsKey('companyId'))
              .toList();
        } else if (companiesData is Map) {
          final dataMap = Map<String, dynamic>.from(companiesData as Map);
          if (dataMap.containsKey('companyId')) {
            companiesList = [dataMap];
          }
        }
      }

      setState(() {
        _companies = companiesList;
        _isLoadingCompanies = false;
        _selectedCompanyId = null;
      });
    } catch (e) {
      debugPrint('Error loading companies: $e');
      setState(() {
        _isLoadingCompanies = false;
        _companyError = 'Erreur de chargement des entreprises';
      });
    }
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
      final List<XFile> images = await _picker.pickMultiImage(imageQuality: 85);
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

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      _selectedFileNames.removeAt(index);
      _selectedContentTypes.removeAt(index);
    });
  }

  Future<void> _addAttachmentsToProduct(int productId) async {
    for (int i = 0; i < _selectedImages.length; i++) {
      final bytes = _selectedImages[i];
      final fileName = _selectedFileNames[i];
      final contentType = _selectedContentTypes[i];

      try {
        await _attachmentService.createAttachment(
          fileBytes: bytes,
          fileName: fileName,
          contentType: contentType,
          entityType: 'Product',
          entityId: productId,
        );
      } catch (e) {
        throw Exception('Échec upload image $i: $e');
      }
    }
  }

  Future<void> _submitProduct() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedImages.isEmpty) {
        _showSnackBar('Veuillez ajouter au moins une image', Colors.red);
        return;
      }
      if (_selectedCategoryId == null) {
        _showSnackBar('Veuillez sélectionner une catégorie', Colors.red);
        return;
      }
      if (_selectedCompanyId == null) {
        _showSnackBar('Veuillez sélectionner une entreprise', Colors.red);
        return;
      }

      setState(() => _isSubmitting = true);

      try {
        final DateTime now = DateTime.now();
        final List<int> dateList = [now.year, now.month, now.day, now.hour, now.minute, now.second];

        final double productPrice = double.parse(_priceController.text);
        final double discountPercentage = double.parse(_discountController.text.isEmpty ? '0' : _discountController.text);
        final double productFinalePrice = _finalPrice;

        final Map<String, dynamic> product = {
          "productName": _nameController.text.trim(),
          "productDescription": _descriptionController.text.trim(),
          "productPrice": productPrice,
          "productFinalePrice": productFinalePrice,
          "discountPercentage": discountPercentage,
          "categoryId": _selectedCategoryId,
          "companyId": _selectedCompanyId,
          "userId": currentUserId,
          "createdAt": dateList,
          "lastUpdated": dateList,
          "attachmentIds": [],
          "available": _isAvailable,
          "reviewIds": [],
          "orderItemIds": []
        };


        final createdProduct = await _productService.createProduct(product);
        final int productId = createdProduct['productId'] as int;

        if (mounted) {
          _showSnackBar('Produit ajouté avec succès! 🎉', const Color(0xFF00B894));
          widget.onProductAdded?.call();
          Navigator.pop(context);
        }
      } catch (e) {
        debugPrint('❌ Erreur lors de la création du produit: $e');
        if (mounted) {
          _showSnackBar('Erreur: ${e.toString()}', Colors.red);
        }
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final maxWidth = isMobile ? double.infinity : 750.0;

    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic)),
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 24,
          vertical: isMobile ? 12 : 32,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.25),
                blurRadius: 50,
                offset: const Offset(0, 25),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(isMobile),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Form(
                    key: _formKey,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 28,
                        vertical: 24,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildImageSection(isMobile),
                          const SizedBox(height: 28),
                          _buildProductNameSection(),
                          const SizedBox(height: 20),
                          _buildDescriptionSection(),
                          const SizedBox(height: 20),
                          _buildSelectionsRow(isMobile),
                          const SizedBox(height: 20),
                          _buildPricingSection(isMobile),
                          const SizedBox(height: 20),
                          _buildFinalPriceDisplay(),
                          const SizedBox(height: 20),
                          _buildAvailabilitySwitch(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              _buildFooterButtons(isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Nouveau Produit',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isMobile ? 20 : 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ajoutez un produit à votre catalogue',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.image_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 10),
              const Text(
                'Images du Produit',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_selectedImages.length}/10',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedImages.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isMobile ? 3 : 4,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.memory(
                      _selectedImages[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => _removeImage(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_selectedImages.isNotEmpty) const SizedBox(height: 14),
          InkWell(
            onTap: _selectedImages.length < 10 ? _pickImages : null,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.4),
                  width: 2,
                  strokeAlign: BorderSide.strokeAlignInside,
                ),
                borderRadius: BorderRadius.circular(14),
                color: _selectedImages.length < 10
                    ? AppColors.primary.withOpacity(0.03)
                    : Colors.grey.withOpacity(0.05),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_rounded,
                      size: 40,
                      color: _selectedImages.length < 10
                          ? AppColors.primary.withOpacity(0.7)
                          : Colors.grey.withOpacity(0.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _selectedImages.length < 10 ? 'Ajouter des images' : 'Maximum atteint',
                      style: TextStyle(
                        color: _selectedImages.length < 10 ? AppColors.primary : Colors.grey.withOpacity(0.5),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sélectionnez jusqu\'à 10 images',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.withOpacity(0.6),
                      ),
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

  Widget _buildProductNameSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.label_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            const Text(
              'Nom du Produit',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildModernTextField(
          controller: _nameController,
          hint: 'ex: Pizza Margherita Premium',
          icon: Icons.restaurant_menu_rounded,
          validator: (v) => v?.isEmpty == true ? 'Le nom est obligatoire' : null,
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.description_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            const Text(
              'Description',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildModernTextField(
          controller: _descriptionController,
          hint: 'Décrivez votre produit en détail (saveurs, ingrédients, etc.)',
          icon: Icons.edit_rounded,
          maxLines: 4,
        ),
      ],
    );
  }

  Widget _buildSelectionsRow(bool isMobile) {
    return Column(
      children: [
        _buildCategoryDropdown(),
        const SizedBox(height: 14),
        _buildCompanyDropdown(),
      ],
    );
  }

  Widget _buildPricingSection(bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.price_change_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            const Text(
              'Tarification',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModernTextField(
                controller: _priceController,
                hint: '0.00',
                icon: Icons.attach_money_rounded,
                isNumber: true,
                isDecimal: true,
                suffix: 'TND',
                validator: (v) {
                  if (v?.isEmpty == true) return 'Prix obligatoire';
                  if (double.tryParse(v ?? '') == null) return 'Prix invalide';
                  return null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildModernTextField(
                controller: _discountController,
                hint: '0',
                icon: Icons.local_offer_rounded,
                isNumber: true,
                suffix: '%',
                validator: (v) {
                  if (v?.isNotEmpty == true) {
                    final d = double.tryParse(v ?? '');
                    if (d == null || d > 100 || d < 0) return 'Remise invalide';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFinalPriceDisplay() {
    final originalPrice = double.tryParse(_priceController.text) ?? 0.0;
    final hasDiscount = _discountController.text.isNotEmpty && _finalPrice < originalPrice;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00B894).withOpacity(0.12),
            const Color(0xFF00B894).withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00B894).withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Prix Final',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (hasDiscount)
                    Text(
                      '${originalPrice.toStringAsFixed(2)} TND',
                      style: TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: Colors.grey[500],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  if (hasDiscount) const SizedBox(width: 10),
                  Text(
                    '${_finalPrice.toStringAsFixed(2)} TND',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF00B894),
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (hasDiscount)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B6B), Color(0xFFEE5A6F)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF6B6B).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '-${_discountController.text}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvailabilitySwitch() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isAvailable ? const Color(0xFF00B894).withOpacity(0.08) : Colors.red.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isAvailable ? const Color(0xFF00B894).withOpacity(0.25) : Colors.red.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _isAvailable ? const Color(0xFF00B894).withOpacity(0.15) : Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isAvailable ? Icons.check_circle_rounded : Icons.block_rounded,
                  color: _isAvailable ? const Color(0xFF00B894) : Colors.red,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Disponibilité',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isAvailable ? 'Disponible à la vente' : 'Actuellement indisponible',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Transform.scale(
            scale: 1.15,
            child: Switch(
              value: _isAvailable,
              onChanged: (v) => setState(() => _isAvailable = v),
              activeColor: const Color(0xFF00B894),
              activeTrackColor: const Color(0xFF00B894).withOpacity(0.3),
              inactiveTrackColor: Colors.red.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterButtons(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: isMobile ? 13 : 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: BorderSide(color: Colors.grey[300]!, width: 1.5),
              ),
              child: Text(
                'Annuler',
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w700,
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
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.85)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(vertical: isMobile ? 13 : 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  disabledBackgroundColor: Colors.grey.withOpacity(0.5),
                ),
                child: _isSubmitting
                    ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Enregistrement...',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: isMobile ? 14 : 15,
                      ),
                    ),
                  ],
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      'Enregistrer',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: isMobile ? 14 : 15,
                      ),
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

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    bool isNumber = false,
    bool isDecimal = false,
    String? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumber
          ? (isDecimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number)
          : TextInputType.text,
      inputFormatters: isNumber
          ? [FilteringTextInputFormatter.allow(isDecimal ? RegExp(r'^\d*\.?\d*') : RegExp(r'\d'))]
          : null,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
        suffixText: suffix,
        suffixStyle: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 2.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      validator: validator,
    );
  }

  Widget _buildCategoryDropdown() {
    return _buildDropdownField(
      label: 'Catégorie',
      icon: Icons.category_rounded,
      isLoading: _isLoadingCategories,
      error: _categoryError,
      isEmpty: _categories.isEmpty,
      value: _selectedCategoryId,
      onChanged: (val) => setState(() => _selectedCategoryId = val),
      items: _categories
          .map((cat) => (
      cat['categoryId'] as int,
      cat['name'] as String? ?? 'Catégorie'
      ))
          .toList(),
      onRetry: _loadCategories,
    );
  }

  Widget _buildCompanyDropdown() {
    return _buildDropdownField(
      label: 'Entreprise',
      icon: Icons.business_rounded,
      isLoading: _isLoadingCompanies,
      error: _companyError,
      isEmpty: _companies.isEmpty,
      value: _selectedCompanyId,
      onChanged: (val) => setState(() => _selectedCompanyId = val),
      items: _companies
          .map((comp) => (
      comp['companyId'] as int,
      comp['companyName'] as String? ?? 'Entreprise'
      ))
          .toList(),
      onRetry: _loadCompanies,
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required bool isLoading,
    required String? error,
    required bool isEmpty,
    required int? value,
    required Function(int?) onChanged,
    required List<(int, String)> items,
    required VoidCallback onRetry,
  }) {
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[300]!, width: 1.5),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Chargement...',
              style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (error != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.red.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                error,
                style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppColors.primary, size: 20),
              onPressed: onRetry,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
      );
    }

    if (isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withOpacity(0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: Colors.orange[700], size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Aucun élément disponible',
                style: TextStyle(color: Colors.orange[700], fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    return DropdownButtonFormField<int>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary, size: 22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      items: items
          .map((item) => DropdownMenuItem(
        value: item.$1,
        child: Text(
          item.$2,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ))
          .toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Sélection obligatoire' : null,
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary),
    );
  }
}