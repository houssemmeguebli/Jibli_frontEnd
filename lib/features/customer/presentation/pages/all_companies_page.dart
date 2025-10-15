import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/services/company_service.dart';
import '../widgets/company_card.dart';
import 'company_detail_page.dart';

class AllCompaniesPage extends StatefulWidget {
  const AllCompaniesPage({super.key});

  @override
  State<AllCompaniesPage> createState() => _AllCompaniesPageState();
}

class _AllCompaniesPageState extends State<AllCompaniesPage> {
  final CompanyService _companyService = CompanyService();
  List<Map<String, dynamic>> _companies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    try {
      final companies = await _companyService.getAllCompanies();
      setState(() {
        _companies = companies;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Toutes les entreprises'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: _companies.length,
                itemBuilder: (context, index) {
                  final company = _companies[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CompanyDetailPage(
                            companyId: company['companyId'].toString(),
                          ),
                        ),
                      );
                    },
                    child: CompanyCard(
                      name: company['companyName'] ?? 'Entreprise',
                      category: company['companySector'] ?? 'Commerce',
                      rating: (company['reviews'] ?? 4.0).toDouble(),
                      imageUrl: company['imageUrl'],
                    ),
                  );
                },
              ),
            ),
    );
  }
}