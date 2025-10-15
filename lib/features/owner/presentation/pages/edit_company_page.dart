import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

class EditCompanyPage extends StatefulWidget {
  final Map<String, dynamic> companyData;
  
  const EditCompanyPage({super.key, required this.companyData});

  @override
  State<EditCompanyPage> createState() => _EditCompanyPageState();
}

class _EditCompanyPageState extends State<EditCompanyPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _websiteController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.companyData['name']);
    _descriptionController = TextEditingController(text: widget.companyData['description']);
    _emailController = TextEditingController(text: widget.companyData['email']);
    _phoneController = TextEditingController(text: widget.companyData['phone']);
    _addressController = TextEditingController(text: widget.companyData['address']);
    _websiteController = TextEditingController(text: widget.companyData['website']);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Company'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textLight,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _buildFormField('Company Name', _nameController, 'Enter company name'),
            const SizedBox(height: 16),
            _buildFormField('Description', _descriptionController, 'Enter company description', maxLines: 3),
            const SizedBox(height: 16),
            _buildFormField('Email', _emailController, 'Enter email address'),
            const SizedBox(height: 16),
            _buildFormField('Phone', _phoneController, 'Enter phone number'),
            const SizedBox(height: 16),
            _buildFormField('Address', _addressController, 'Enter company address', maxLines: 2),
            const SizedBox(height: 16),
            _buildFormField('Website', _websiteController, 'Enter website URL'),
            const SizedBox(height: 30),
            _buildUpdateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField(String label, TextEditingController controller, String hint, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) => value?.isEmpty == true ? 'This field is required' : null,
    );
  }

  Widget _buildUpdateButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ElevatedButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: const Text('Update Company', style: TextStyle(color: AppColors.textLight, fontWeight: FontWeight.bold)),
      ),
    );
  }
}