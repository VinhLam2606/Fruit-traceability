import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:untitled/dashboard/bloc/dashboard_bloc.dart';
import 'package:untitled/dashboard/model/product.dart';

class CreateProductPage extends StatelessWidget {
  const CreateProductPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CreateProductView();
  }
}

class CreateProductView extends StatefulWidget {
  const CreateProductView({super.key});

  @override
  State<CreateProductView> createState() => _CreateProductViewState();
}

class _CreateProductViewState extends State<CreateProductView> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController(
    text: '1',
  );
  final ScrollController _scrollController = ScrollController();

  static const List<Color> _backgroundGradient = [
    Color(0xFF141E30),
    Color(0xFF243B55),
  ];
  static const Color _accentColor = Colors.greenAccent;
  static const Color _cardColor = Colors.white10;

  bool _isProcessing = false;
  final List<Product> _createdProducts = [];

  String _generateBatchId() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }

  String _formatTimestamp(BigInt timestamp) {
    if (timestamp == BigInt.zero) return "N/A";
    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      timestamp.toInt() * 1000,
    );
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  @override
  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _backgroundGradient,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: BlocConsumer<DashboardBloc, DashboardState>(
          listenWhen: (previous, current) => current is! ProductsLoadedState,
          listener: (context, state) {
            if (state is DashboardSuccessState) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: _accentColor,
                ),
              );
              context.read<DashboardBloc>().add(FetchProductsEvent());
            } else if (state is DashboardErrorState) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
          builder: (context, state) {
            final isLoading =
                _isProcessing ||
                    (state is DashboardLoadingState &&
                        state is! ProductsLoadedState);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  _buildCreateProductForm(context, isLoading),
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white30),
                  _buildProductList(context, state, isLoading),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCreateProductForm(BuildContext context, bool isLoading) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Product Name'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: quantityController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Quantity (Number of Products)'),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () => _createProductsSequentially(context, false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Create Product (No Print)",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: isLoading
                    ? null
                    : () => _createProductsSequentially(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "Create & Print PDF",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _createProductsSequentially(
      BuildContext context,
      bool generatePdf,
      ) async {
    final int quantity = int.tryParse(quantityController.text) ?? 1;
    final int currentTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final String baseName = nameController.text.trim();

    if (baseName.isEmpty || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter valid product info."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    _showLoadingDialog(context);

    setState(() {
      _isProcessing = true;
      _createdProducts.clear();
    });

    try {
      for (int i = 1; i <= quantity; i++) {
        final generatedBatchId = _generateBatchId();
        final name = quantity > 1 ? "$baseName #$i" : baseName;

        final product = Product(
          batchId: generatedBatchId,
          name: name,
          organizationName: "N/A",
          creator: "0x0",
          date: BigInt.from(currentTimestamp),
          currentOwner: "0x0",
          status: "Created",
          processSteps: [],
        );

        _createdProducts.add(product);

        context.read<DashboardBloc>().add(
          CreateProductButtonPressedEvent(
            batchId: generatedBatchId,
            name: name,
            date: currentTimestamp,
          ),
        );

        await Future.delayed(const Duration(seconds: 2));
      }

      if (generatePdf) {
        await _generateQrPdf(_createdProducts);
      }

      nameController.clear();
      quantityController.text = '1';
    } finally {
      _hideLoadingDialog(context);
      setState(() => _isProcessing = false);
    }
  }

  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const CustomLoadingDialog(),
    );
  }

  void _hideLoadingDialog(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _generateQrPdf(List<Product> products) async {
    final pdf = pw.Document();

    const int columns = 3;
    const int rows = 4;
    int totalPerPage = columns * rows;
    int totalPages = (products.length / totalPerPage).ceil();

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final start = pageIndex * totalPerPage;
      final end = (start + totalPerPage > products.length)
          ? products.length
          : start + totalPerPage;
      final pageProducts = products.sublist(start, end);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (context) {
            return pw.GridView(
              crossAxisCount: columns,
              childAspectRatio: 1.1,
              children: [
                for (final product in pageProducts)
                  pw.Container(
                    margin: const pw.EdgeInsets.all(6),
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Column(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Text(
                          product.name,
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.SizedBox(height: 4),
                        pw.BarcodeWidget(
                          barcode: pw.Barcode.code128(),
                          data: product.batchId,
                          width: 120,
                          height: 40,
                          drawText: false,
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          "Batch: ${product.batchId}",
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        pw.Text(
                          "Date: ${_formatTimestamp(product.date)}",
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: "product_barcodes.pdf",
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.white30),
        borderRadius: BorderRadius.circular(10),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: _accentColor),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  void _showProductDetailsDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return ProductDetailsDialog(product: product);
      },
    );
  }

  Widget _buildProductList(
      BuildContext context,
      DashboardState state,
      bool isLoading,
      ) {
    final products = state is ProductsLoadedState
        ? state.products.reversed.toList()
        : <Product>[];

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Created Products",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: _accentColor),
                onPressed: isLoading
                    ? null
                    : () {
                  context.read<DashboardBloc>().add(FetchProductsEvent());
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading && products.isEmpty)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(color: _accentColor),
              ),
            )
          else if (products.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  "No products have been created.",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            )
          else
            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: _cardColor,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _accentColor.withOpacity(0.3),
                          child: const Icon(
                            Icons.inventory_2,
                            color: _accentColor,
                          ),
                        ),
                        title: Text(
                          product.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        subtitle: Text(
                          "Batch ID: ${product.batchId}",
                          style: const TextStyle(color: Colors.white70),
                        ),
                        // --- THAY ĐỔI: Thêm nút info ---
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.info_outline,
                            color: Colors.white70,
                          ),
                          onPressed: () =>
                              _showProductDetailsDialog(context, product),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// --- WIDGET MỚI: Dialog hiển thị chi tiết sản phẩm ---
class ProductDetailsDialog extends StatelessWidget {
  final Product product;

  const ProductDetailsDialog({super.key, required this.product});

  // Helper để định dạng timestamp
  String _formatTimestamp(BigInt timestamp) {
    if (timestamp == BigInt.zero) return "N/A";
    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      timestamp.toInt() * 1000,
    );
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1c2a41),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.greenAccent.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Batch: ${product.batchId}",
                style: const TextStyle(color: Colors.greenAccent, fontSize: 14),
              ),
              const Divider(color: Colors.white24, height: 24),
              _buildDetailRow("Status:", product.status),
              _buildDetailRow("Created Date:", _formatTimestamp(product.date)),
              _buildDetailRow("Creator:", product.creator, isAddress: true),
              _buildDetailRow("Current Owner:", product.currentOwner, isAddress: true),
              _buildDetailRow("Organization:", product.organizationName),
              const SizedBox(height: 20),
              _buildProcessSteps(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value, {bool isAddress = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isAddress ? Colors.amber[300] : Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessSteps() {
    if (product.processSteps.isEmpty) {
      return const Center(
        child: Text(
          "No process history available.",
          style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Process History",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...product.processSteps.map((step) => _buildProcessStepCard(step)),
      ],
    );
  }

  Widget _buildProcessStepCard(ProcessStep step) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.processName,
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            step.description,
            style: const TextStyle(color: Colors.white70),
          ),
          const Divider(color: Colors.white12, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                step.organizationName,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                _formatTimestamp(step.date),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CustomLoadingDialog extends StatelessWidget {
  const CustomLoadingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    const Color accentColor = Colors.greenAccent;
    const Color cardBackgroundColor = Color(0xFF243B55);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: cardBackgroundColor.withOpacity(0.95),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accentColor.withOpacity(0.3)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      strokeWidth: 5,
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                  Icon(Icons.inventory_2, color: accentColor, size: 40),
                ],
              ),
              SizedBox(height: 20),
              Text(
                'Creating Products...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}