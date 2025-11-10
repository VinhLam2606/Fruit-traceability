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
  final TextEditingController seedVarietyController = TextEditingController();
  final TextEditingController quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController originController = TextEditingController();
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
    seedVarietyController.dispose();
    originController.dispose();
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
          // ✅ SỬA: Không lắng nghe loading state
          listenWhen: (previous, current) =>
              current is! ProductsLoadedState &&
              current is! DashboardLoadingState,
          listener: (context, state) {
            if (!mounted) return;

            // ✅ SỬA: Chỉ xử lý lỗi/success KHÔNG liên quan đến processing
            if (state is DashboardSuccessState && !_isProcessing) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: _accentColor,
                ),
              );
              context.read<DashboardBloc>().add(FetchProductsEvent());
            } else if (state is DashboardErrorState && !_isProcessing) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
          builder: (context, state) {
            // ✅ SỬA: Chỉ dựa vào state của UI
            final isLoading = _isProcessing;

            // ✅ SỬA: Luôn hiển thị list sản phẩm từ state,
            // không quan tâm _isProcessing
            final displayLoading =
                (state is DashboardLoadingState &&
                state.products.isEmpty &&
                !_isProcessing);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  _buildCreateProductForm(isLoading),
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white30),
                  _buildProductList(context, state, displayLoading),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCreateProductForm(bool isLoading) {
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
          controller: seedVarietyController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Seed Variety (e.g., Cát Hòa Lộc)'),
        ),
        TextField(
          controller: originController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration('Origin (e.g., Đồng Tháp)'),
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
                    : () => _createProductsSequentially(false),
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
                    : () => _createProductsSequentially(true),
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

  Future<void> _createProductsSequentially(bool generatePdf) async {
    final int quantity = int.tryParse(quantityController.text) ?? 1;
    final int currentTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final String baseName = nameController.text.trim();
    final String seedVariety = seedVarietyController.text.trim();
    final String origin = originController.text.trim();

    if (baseName.isEmpty ||
        quantity <= 0 ||
        seedVariety.isEmpty ||
        origin.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter valid product info."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!mounted) return;
    _showLoadingDialog();

    setState(() {
      _isProcessing = true;
      _createdProducts.clear();
    });

    // ✅ SỬA: Lấy BLoC ra ngoài
    final bloc = context.read<DashboardBloc>();
    bool stoppedDueToError = false;
    String firstError = "";

    try {
      for (int i = 1; i <= quantity; i++) {
        // Kiểm tra mounted mỗi vòng lặp
        if (!mounted) {
          stoppedDueToError = true;
          break;
        }

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
          seedVariety: seedVariety,
          origin: origin,
          processSteps: [],
        );

        _createdProducts.add(product);

        // ✅ SỬA: Dùng Completer để chờ BLoC
        final completer = Completer<bool>();
        bloc.add(
          CreateProductButtonPressedEvent(
            batchId: generatedBatchId,
            name: name,
            date: currentTimestamp,
            seedVariety: seedVariety,
            origin: origin,
            completer: completer, // Gửi completer
          ),
        );

        // Chờ BLoC xử lý xong (true = success, false = error)
        final bool success = await completer.future;

        if (!success) {
          // Lấy lỗi từ state của BLoC
          if (bloc.state is DashboardErrorState) {
            firstError = (bloc.state as DashboardErrorState).error;
          }
          stoppedDueToError = true;
          break; // Dừng vòng lặp nếu có lỗi
        }
      }

      if (!mounted) return;

      // Hiển thị lỗi (nếu có)
      if (stoppedDueToError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Đã xảy ra lỗi: $firstError. Đã dừng tạo."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }

      // In PDF nếu không có lỗi
      if (generatePdf && !stoppedDueToError) {
        await _generateQrPdf(_createdProducts);
      }

      if (!mounted) return;
      nameController.clear();
      seedVarietyController.clear();
      originController.clear();
      quantityController.text = '1';
    } finally {
      if (mounted) {
        _hideLoadingDialog();
        setState(() => _isProcessing = false);
        // Luôn fetch lại danh sách sau khi kết thúc
        context.read<DashboardBloc>().add(FetchProductsEvent());
      }
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (_) => const CustomLoadingDialog(),
    );
  }

  void _hideLoadingDialog() {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
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

    if (!mounted) return;
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
    // ✅ SỬA: Luôn lấy list từ state
    final products = state.products.reversed.toList();

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
          if (isLoading) // Chỉ hiển thị loading nếu state là loading
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

// --- ProductDetailsDialog (KHÔNG ĐỔI) ---
class ProductDetailsDialog extends StatelessWidget {
  final Product product;
  const ProductDetailsDialog({super.key, required this.product});

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
              _buildDetailRow("Seed Variety:", product.seedVariety),
              _buildDetailRow("Origin:", product.origin),
              _buildDetailRow("Creator:", product.creator, isAddress: true),
              _buildDetailRow(
                "Current Owner:",
                product.currentOwner,
                isAddress: true,
              ),
              _buildDetailRow("Organization:", product.organizationName),
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
}

// --- CustomLoadingDialog (KHÔNG ĐỔI) ---
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
