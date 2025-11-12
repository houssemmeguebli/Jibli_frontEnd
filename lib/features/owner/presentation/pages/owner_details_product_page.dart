import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:universal_html/html.dart' as html;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/theme/theme.dart';
import '../../../../Core/services/category_service.dart';
import '../../../../Core/services/product_service.dart';
import '../../../../Core/services/attachment_service.dart';
import '../../../../core/services/company_service.dart';
import '../../../../core/services/auth_service.dart';

class DetailsProductPage {
  static Future<bool?> showProductDetailsDialog(
    BuildContext context, {
    required int productId,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ProductDetailsDialog(productId: productId),
    );
  }
}

class ProductDetailsDialog extends StatefulWidget {
  final int productId;
  final VoidCallback? onProductUpdated;

  const ProductDetailsDialog({
    super.key,
    required this.productId,
    this.onProductUpdated,
  });

  @override
  State<ProductDetailsDialog> createState() => _ProductDetailsDialogState();
}

class _ProductDetailsDialogState extends State<ProductDetailsDialog> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _discountController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isAvailable = true;
  bool _isEditMode = false;
  List<Uint8List> _selectedImages = [];
  List<String> _selectedFileNames = [];
  List<String> _selectedContentTypes = [];
  List<Map<String, dynamic>> _existingAttachments = [];
  List<Uint8List> _existingImages = [];
  late List<int> _originalAttachmentIds;
  final ImagePicker _picker = ImagePicker();
  double _finalPrice = 0.0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int? _currentUserId;
  final AuthService _authService = AuthService();
  final CategoryService _categoryService = CategoryService();
  final ProductService _productService = ProductService();
  final AttachmentService _attachmentService = AttachmentService();
  final CompanyService _companyService = CompanyService();
  List<dynamic> _categories = [];
  int? _selectedCategoryId;
  String? _companyName;
  bool _isLoading = true;
  bool _isLoadingCategories = true;
  bool _isLoadingImages = true;
  String? _categoryError;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _priceController.addListener(_calculateFinalPrice);
    _discountController.addListener(_calculateFinalPrice);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final userId = await _authService.getUserId();
    setState(() {
      _currentUserId = userId;
    });
    _loadCategories();
    _loadProduct();
  }
  Future<void> _loadProductImages() async {
    try {
      setState(() => _isLoadingImages = true);

      final List<Uint8List> images = [];

      if (_existingAttachments.isNotEmpty) {
        // Get all attachment IDs for batch processing
        final List<int> attachmentIds = _existingAttachments
            .map((a) => int.tryParse(a['attachmentId'].toString()))
            .where((id) => id != null)
            .cast<int>()
            .toList();

        if (attachmentIds.isNotEmpty) {
          // Fetch all attachments in parallel
          final attachmentFutures = attachmentIds.map((id) => _attachmentService.downloadAttachment(id));
          final attachmentResults = await Future.wait(attachmentFutures);

          for (var result in attachmentResults) {
            if (result.data.isNotEmpty) {
              images.add(result.data);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _existingImages = images;
          _isLoadingImages = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading product images: $e');
      if (mounted) {
        setState(() {
          _isLoadingImages = false;
        });
      }
    }
  }
  Future<void> _loadProduct() async {
    try {
      setState(() => _isLoading = true);

      if (_currentUserId == null) {
        _showErrorAndExit('User not authenticated');
        return;
      }
      final productsData = await _productService.getProductByUserId(_currentUserId!);

      if (productsData is! List || productsData!.isEmpty) {
        _showErrorAndExit('Produit non trouvé');
        return;
      }

      final List<Map<String, dynamic>> productList = List<Map<String, dynamic>>.from(productsData as Iterable);
      final product = productList.firstWhere(
            (p) => p['productId'] == widget.productId,
        orElse: () => <String, dynamic>{},
      );

      if (product.isEmpty) {
        _showErrorAndExit('Produit non trouvé');
        return;
      }

      _nameController.text = product['productName'] ?? '';
      _descriptionController.text = product['productDescription'] ?? '';
      _priceController.text = product['productPrice']?.toString() ?? '0';
      _discountController.text = product['discountPercentage']?.toString() ?? '0';
      _isAvailable = product['available'] ?? true;
      _selectedCategoryId = product['categoryId'];
      _finalPrice = product['productFinalePrice']?.toDouble() ?? 0.0;

      // Load company name
      final companyId = product['companyId'];
      if (companyId != null) {
        try {
          final companyData = await _companyService.getCompanyByUserID(_currentUserId!);
          if (companyData != null) {
            if (companyData is List) {
              final company = (companyData as List).cast<Map<String, dynamic>>().firstWhere(
                    (c) => c['companyId'] == companyId,
                orElse: () => <String, dynamic>{},
              );
              if (company.isNotEmpty) {
                _companyName = company['companyName'] as String?;
              }
            } else if (companyData is Map<String, dynamic>) {
              final dataMap = Map<String, dynamic>.from(companyData as Map);
              if (dataMap['companyId'] == companyId) {
                _companyName = dataMap['companyName'] as String?;
              }
            }
          }
        } catch (e) {
          debugPrint('Error loading company: $e');
        }
      }

      // Load attachments directly from attachment service
      try {
        final attachments = await _attachmentService.findByProductProductId(widget.productId);
        _existingAttachments = attachments.cast<Map<String, dynamic>>();
        _originalAttachmentIds = _existingAttachments.map((a) => int.parse(a['attachmentId'].toString())).toList();
      } catch (e) {
        debugPrint('Error loading attachments: $e');
        _existingAttachments = [];
        _originalAttachmentIds = [];
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // Load images after product data is loaded
      if (_existingAttachments.isNotEmpty) {
        await _loadProductImages();
      } else {
        if (mounted) {
          setState(() {
            _isLoadingImages = false;
          });
        }
      }

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de chargement: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showErrorAndExit(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    }
  }

  Future<void> _loadCategories() async {
    try {
      setState(() {
        _isLoadingCategories = true;
        _categoryError = null;
      });

      if (_currentUserId == null) {
        throw Exception('User not authenticated');
      }
      final categories = await _categoryService.getAllCategories();

      setState(() {
        _categories = categories as List;
        _isLoadingCategories = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingCategories = false;
        _categoryError = 'Erreur de chargement des catégories';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _calculateFinalPrice() {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final discount = double.tryParse(_discountController.text) ?? 0.0;
    setState(() {
      _finalPrice = price - (price * discount / 100);
    });
  }

  Future<void> _pickImages() async {
    if (!_isEditMode) return;

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
            names.add(file.name);
            types.add(file.type.isEmpty ? 'application/octet-stream' : file.type);
          }
          setState(() {
            _selectedImages.addAll(bytesList);
            _selectedFileNames.addAll(names);
            _selectedContentTypes.addAll(types);
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
          names.add(img.name);
          types.add(img.mimeType ?? 'image/jpeg');
        }
        setState(() {
          _selectedImages.addAll(bytesList);
          _selectedFileNames.addAll(names);
          _selectedContentTypes.addAll(types);
        });
      }
    }
  }

  void _removeImage(int index) {
    if (!_isEditMode) return;
    setState(() {
      _selectedImages.removeAt(index);
      _selectedFileNames.removeAt(index);
      _selectedContentTypes.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    if (!_isEditMode) return;
    setState(() {
      _existingImages.removeAt(index);
      _existingAttachments.removeAt(index);
    });
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final maxWidth = isMobile ? double.infinity : 700.0;

    if (_isLoading) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 200),
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
              const SizedBox(height: 20),
              const Text('Chargement du produit...', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    return FadeTransition(
      opacity: _fadeAnimation,
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        _buildStatsCards(),
                        const SizedBox(height: 20),
                        _buildImageSection(),
                        const SizedBox(height: 20),
                        _buildInfoSection(),
                        const SizedBox(height: 20),
                        _buildPricingCard(),
                        const SizedBox(height: 20),
                        _buildAvailabilityCard(),
                      ],
                    ),
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
        gradient: LinearGradient(
          colors: [
            _isEditMode ? AppColors.accent : AppColors.primary,
            (_isEditMode ? AppColors.accent : AppColors.primary).withOpacity(0.85),
          ],
        ),
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
            child: Icon(
              _isEditMode ? Icons.edit_document : Icons.visibility_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditMode ? 'Modifier Produit' : 'Détails Produit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                if (_companyName != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _companyName!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  _isEditMode ? 'Mode édition activé' : 'Consultation des informations',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (!_isEditMode)
            GestureDetector(
              onTap: _toggleEditMode,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 20),
              ),
            ),
          const SizedBox(width: 8),
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
    if (!_isEditMode) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() => _isEditMode = false);
                _loadProduct();
              },
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
                gradient: LinearGradient(colors: [AppColors.accent, AppColors.accent.withOpacity(0.8)]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
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
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_outlined, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Enregistrer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Chargement du produit...',
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 24,
        right: 24,
        bottom: 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _isEditMode ? AppColors.accent : AppColors.primary,
            _isEditMode ? AppColors.accent.withOpacity(0.85) : AppColors.primary.withOpacity(0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: (_isEditMode ? AppColors.accent : AppColors.primary).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _isEditMode ? Icons.edit_document : Icons.visibility_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditMode ? 'Modifier le Produit' : 'Détails Produit',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isEditMode
                      ? 'Mode édition activé'
                      : 'Consultation des informations',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: _showInfoDialog,
                  icon: const Icon(Icons.info_outline, color: Colors.white, size: 24),
                  tooltip: 'Aide',
                ),
              ),
              const SizedBox(width: 8),
              if (!_isEditMode)
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.accent, AppColors.accent.withOpacity(0.8)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _toggleEditMode,
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                            SizedBox(width: 6),
                            Text(
                              'Modifier',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards() {
    final hasDiscount = (double.tryParse(_discountController.text) ?? 0) > 0;
    final originalPrice = double.tryParse(_priceController.text) ?? 0.0;
    
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: _isEditMode ? Icons.edit_rounded : Icons.visibility_rounded,
            title: _isEditMode ? 'Mode' : 'Consultation',
            value: _isEditMode ? 'Edition' : 'Lecture',
            subtitle: _isEditMode ? 'actif' : 'seule',
            color: _isEditMode ? Colors.orange : Colors.blue,
            gradient: _isEditMode ? [Colors.orange[400]!, Colors.orange[600]!] : [Colors.blue[400]!, Colors.blue[600]!],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: Icons.image_rounded,
            title: 'Images',
            value: '${_existingImages.length + _selectedImages.length}',
            subtitle: 'total',
            color: Colors.purple,
            gradient: [Colors.purple[400]!, Colors.purple[600]!],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            icon: hasDiscount ? Icons.local_offer_rounded : Icons.euro_rounded,
            title: hasDiscount ? 'Prix Réduit' : 'Prix',
            value: hasDiscount ? '${_finalPrice.toStringAsFixed(0)}' : '${originalPrice.toStringAsFixed(0)}',
            subtitle: 'DT',
            color: hasDiscount ? Colors.red : Colors.green,
            gradient: hasDiscount ? [Colors.red[400]!, Colors.red[600]!] : [Colors.green[400]!, Colors.green[600]!],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required List<Color> gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    if (_isLoadingImages) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (_isEditMode ? AppColors.accent : AppColors.primary).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Images du Produit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _isEditMode ? AppColors.accent : AppColors.primary)),
          const SizedBox(height: 12),
          if (_existingImages.isNotEmpty || _selectedImages.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _existingImages.length + _selectedImages.length,
              itemBuilder: (context, index) {
                if (index < _existingImages.length) {
                  return _buildExistingAttachmentTile(index);
                } else {
                  final newIndex = index - _existingImages.length;
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          _selectedImages[newIndex],
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      ),
                      if (_isEditMode)
                        Positioned(
                          top: 4, right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(newIndex),
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
          if ((_existingImages.isNotEmpty || _selectedImages.isNotEmpty) && _isEditMode) const SizedBox(height: 12),
          if (_isEditMode)
            InkWell(
              onTap: _pickImages,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.accent.withOpacity(0.3), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_upload_outlined, color: AppColors.accent, size: 24),
                      const SizedBox(height: 4),
                      Text('Ajouter images', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            )
          else if (_existingImages.isEmpty && _selectedImages.isEmpty)
            Container(
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_not_supported_outlined, size: 32, color: Colors.grey.shade400),
                    const SizedBox(height: 4),
                    Text('Aucune image', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExistingAttachmentTile(int index) {
    if (index >= _existingImages.length) {
      return Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.image_not_supported_outlined, color: Colors.grey),
        ),
      );
    }

    final bytes = _existingImages[index];

    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: bytes.isEmpty
              ? Container(
            color: Colors.grey.shade200,
            child: const Center(
              child: Icon(Icons.image_not_supported_outlined, color: Colors.grey),
            ),
          )
              : Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            cacheHeight: 500,
            cacheWidth: 500,
          ),
        ),
        if (_isEditMode)
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () => _removeExistingImage(index),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 14),
              ),
            ),
          ),
      ],
    );
  }
  Widget _buildInfoSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (_isEditMode ? AppColors.accent : AppColors.primary).withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Informations Générales', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _isEditMode ? AppColors.accent : AppColors.primary)),
          const SizedBox(height: 12),
          _buildCompactTextField('Nom du Produit', _nameController, Icons.restaurant_menu, enabled: _isEditMode),
          const SizedBox(height: 12),
          _buildCompactTextField('Description', _descriptionController, Icons.description_outlined, maxLines: 3, enabled: _isEditMode),
          const SizedBox(height: 12),
          _buildCategoryDropdown(),
        ],
      ),
    );
  }

  Widget _buildCompactTextField(String label, TextEditingController controller, IconData icon, {int maxLines = 1, bool enabled = true}) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _isEditMode && enabled ? AppColors.accent : AppColors.primary, size: 20),
        suffixIcon: !enabled ? Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 16) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey.shade50,
      ),
    );
  }

  Widget _buildPricingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tarification', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.green)),
          const SizedBox(height: 12),
          _buildPricingSection(),
          const SizedBox(height: 12),
          _buildFinalPriceCard(),
        ],
      ),
    );
  }

  Widget _buildPricingSection() {
    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: _isEditMode ? Border.all(color: AppColors.accent.withOpacity(0.3), width: 2) : null,
            ),
            child: TextFormField(
              controller: _priceController,
              enabled: _isEditMode,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _isEditMode ? Colors.black87 : Colors.grey.shade600),
              decoration: InputDecoration(
                labelText: 'Prix (DT)',
                hintText: '0.00',
                prefixIcon: Icon(Icons.attach_money, color: _isEditMode ? AppColors.accent : AppColors.primary, size: 22),
                suffixIcon: !_isEditMode ? Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 18) : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                filled: true,
                fillColor: _isEditMode ? Colors.white : Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
              validator: (value) {
                if (!_isEditMode) return null;
                if (value?.isEmpty == true) return 'Ce champ est obligatoire';
                final number = double.tryParse(value!);
                if (number == null) return 'Nombre invalide';
                if (number < 0) return 'Doit être positif';
                return null;
              },
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: _isEditMode ? Border.all(color: AppColors.accent.withOpacity(0.3), width: 2) : null,
            ),
            child: TextFormField(
              controller: _discountController,
              enabled: _isEditMode,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'\d'))],
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _isEditMode ? Colors.black87 : Colors.grey.shade600),
              decoration: InputDecoration(
                labelText: 'Réduction (%)',
                hintText: '0',
                prefixIcon: Icon(Icons.local_offer_outlined, color: _isEditMode ? AppColors.accent : AppColors.primary, size: 22),
                suffixIcon: !_isEditMode ? Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 18) : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                filled: true,
                fillColor: _isEditMode ? Colors.white : Colors.grey.shade50,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(18),
        border: _isEditMode ? Border.all(color: AppColors.accent.withOpacity(0.3), width: 2) : null,
      ),
      child: _isLoadingCategories
          ? Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 16),
            Text('Chargement des catégories...', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      )
          : _categoryError != null
          ? Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(child: Text(_categoryError!, style: const TextStyle(color: Colors.red))),
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadCategories, tooltip: 'Réessayer'),
          ],
        ),
      )
          : _categories.isEmpty
          ? Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange[700]),
            const SizedBox(width: 12),
            const Expanded(child: Text('Aucune catégorie disponible. Veuillez en créer une.', style: TextStyle(color: Colors.orange))),
          ],
        ),
      )
          : DropdownButtonFormField<int>(
        value: _selectedCategoryId,
        decoration: InputDecoration(
          labelText: 'Catégorie',
          prefixIcon: Icon(Icons.category_outlined, color: _isEditMode ? AppColors.accent : AppColors.primary, size: 22),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: _isEditMode ? AppColors.accent : AppColors.primary, width: 2)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          filled: true,
          fillColor: _isEditMode ? Colors.white : Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        items: _categories.map<DropdownMenuItem<int>>((category) {
          return DropdownMenuItem<int>(
            value: category['categoryId'],
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: (_isEditMode ? AppColors.accent : AppColors.primary).withOpacity(0.6), shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(child: Text(category['name'] ?? 'Catégorie ${category['categoryId']}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
              ],
            ),
          );
        }).toList(),
        onChanged: _isEditMode ? (int? newValue) => setState(() => _selectedCategoryId = newValue) : null,
        validator: (value) => value == null ? 'Veuillez sélectionner une catégorie' : null,
        icon: Icon(Icons.keyboard_arrow_down_rounded, color: _isEditMode ? AppColors.accent : AppColors.primary),
        isExpanded: true,
        dropdownColor: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }

  Widget _buildModernTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isNumber = false,
    bool isDecimal = false,
    int maxLines = 1,
    bool enabled = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(18),
        border: _isEditMode && enabled ? Border.all(color: AppColors.accent.withOpacity(0.3), width: 2) : null,
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        keyboardType: isNumber ? (isDecimal ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number) : TextInputType.text,
        inputFormatters: isNumber ? [FilteringTextInputFormatter.allow(isDecimal ? RegExp(r'^\d*\.?\d*') : RegExp(r'\d'))] : null,
        maxLines: maxLines,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: enabled ? Colors.black87 : Colors.grey.shade600),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          prefixIcon: Icon(icon, color: _isEditMode && enabled ? AppColors.accent : AppColors.primary, size: 22),
          suffixIcon: !enabled ? Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 18) : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: _isEditMode ? AppColors.accent : AppColors.primary, width: 2)),
          disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: Colors.red, width: 2)),
          filled: true,
          fillColor: enabled ? Colors.white : Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        validator: (value) {
          if (!enabled) return null;
          if (value?.isEmpty == true) return 'Ce champ est obligatoire';
          if (isNumber) {
            final number = double.tryParse(value!);
            if (number == null) return 'Veuillez entrer un nombre valide';
            if (number < 0) return 'Le nombre doit être positif';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildFinalPriceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF00B894).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00B894).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.payment, size: 18, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text('Prix Final: ', style: TextStyle(fontSize: 14, color: Colors.grey[700], fontWeight: FontWeight.w600)),
          Text('${_finalPrice.toStringAsFixed(2)} DT', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF00B894))),
          const Spacer(),
          if (_discountController.text.isNotEmpty && double.tryParse(_discountController.text) != null && double.tryParse(_discountController.text)! > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('-${_discountController.text}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (_isAvailable ? const Color(0xFF00B894) : Colors.red).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(_isAvailable ? Icons.check_circle : Icons.block, color: _isAvailable ? const Color(0xFF00B894) : Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Disponibilité', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                Text(_isAvailable ? 'Disponible' : 'Indisponible', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Switch(
            value: _isAvailable,
            onChanged: _isEditMode ? (value) => setState(() => _isAvailable = value) : null,
            activeColor: const Color(0xFF00B894),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppColors.accent.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.accent.withOpacity(0.3))),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.accent, size: 20),
              const SizedBox(width: 12),
              Expanded(child: Text('Les modifications seront sauvegardées après validation', style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500))),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() => _isEditMode = false);
                  _loadProduct();
                },
                icon: const Icon(Icons.close),
                label: const Text('Annuler'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: Colors.grey[400]!, width: 2),
                  foregroundColor: Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.accent, AppColors.accent.withOpacity(0.8)]),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitProduct,
                  icon: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_outlined, size: 22),
                  label: Text(_isSubmitting ? 'Enregistrement...' : 'Enregistrer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _submitProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      try {
        final DateTime now = DateTime.now();
        final List<int> dateList = [now.year, now.month, now.day, now.hour, now.minute, now.second];

        final Map<String, dynamic> product = {
          "productName": _nameController.text.trim(),
          "productDescription": _descriptionController.text.trim(),
          "productPrice": double.parse(_priceController.text),
          "productFinalePrice": _finalPrice,
          "discountPercentage": double.parse(_discountController.text.isEmpty ? '0' : _discountController.text),
          "categoryId": _selectedCategoryId,
          "userId": _currentUserId,
          "createdAt": dateList,
          "lastUpdated": dateList,
          "attachmentIds": [],
          "available": _isAvailable,
          "reviewIds": [],
          "orderItemIds": []
        };

        await _productService.updateProduct(widget.productId, product);

        for (var id in _originalAttachmentIds) {
          try {
            await _attachmentService.deleteAttachment(id);
          } catch (e) {}
        }

        final allBytes = [..._existingImages, ..._selectedImages];
        final allNames = [
          ..._existingAttachments.map((a) => a['fileName'] ?? 'image.jpg'),
          ..._selectedFileNames
        ];
        final allTypes = [
          ..._existingAttachments.map((a) => a['fileType'] ?? 'image/jpeg'),
          ..._selectedContentTypes
        ];

        for (int i = 0; i < allBytes.length; i++) {
          await _attachmentService.createAttachment(
            fileBytes: allBytes[i],
            fileName: allNames[i],
            contentType: allTypes[i],
            entityType: 'Product',
            entityId: widget.productId,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [const Icon(Icons.check_circle, color: Colors.white), const SizedBox(width: 12), const Expanded(child: Text('Produit mis à jour avec succès!', style: TextStyle(fontWeight: FontWeight.w600)))]),
              backgroundColor: const Color(0xFF00B894),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 3),
            ),
          );
          setState(() => _isEditMode = false);
          widget.onProductUpdated?.call();
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(children: [const Icon(Icons.error_outline, color: Colors.white), const SizedBox(width: 12), Expanded(child: Text('Erreur: ${e.toString()}', style: const TextStyle(fontWeight: FontWeight.w600)))]),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [const Icon(Icons.warning_amber_rounded, color: Colors.white), const SizedBox(width: 12), const Expanded(child: Text('Veuillez corriger les erreurs dans le formulaire', style: TextStyle(fontWeight: FontWeight.w600)))]),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [Icon(Icons.help_outline, color: _isEditMode ? AppColors.accent : AppColors.primary), const SizedBox(width: 12), const Text('Aide')]),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isEditMode ? 'Mode Édition Actif' : 'Mode Consultation', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (_isEditMode) ...[
                _buildInfoItem(Icons.edit, 'Vous pouvez modifier tous les champs'),
                _buildInfoItem(Icons.image, 'Ajoutez ou supprimez des images'),
                _buildInfoItem(Icons.calculate, 'Le prix final est calculé automatiquement'),
                _buildInfoItem(Icons.toggle_on, 'Activez/désactivez la disponibilité'),
                _buildInfoItem(Icons.save, 'N\'oubliez pas d\'enregistrer vos modifications'),
              ] else ...[
                _buildInfoItem(Icons.visibility, 'Vous êtes en mode lecture seule'),
                _buildInfoItem(Icons.edit_note, 'Cliquez sur l\'icône de modification pour éditer'),
                _buildInfoItem(Icons.lock, 'Les champs sont verrouillés pour éviter les modifications accidentelles'),
              ],
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Compris', style: TextStyle(fontWeight: FontWeight.bold)))],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: _isEditMode ? AppColors.accent : AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.4))),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    _descriptionController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}