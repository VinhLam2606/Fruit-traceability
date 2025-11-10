// product_management.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:untitled/dashboard/bloc/dashboard_bloc.dart';
import 'package:untitled/dashboard/model/product.dart';
import 'package:untitled/dashboard/ui/create_product_page.dart';

class ProductManagementPage extends StatefulWidget {
  const ProductManagementPage({super.key});

  @override
  State<ProductManagementPage> createState() => _ProductManagementPageState();
}

class _ProductManagementPageState extends State<ProductManagementPage> {
  static const List<Color> _backgroundGradient = [
    Color(0xFF141E30),
    Color(0xFF243B55),
  ];
  static const Color _accentColor = Colors.greenAccent;
  static const Color _cardColor = Colors.white10;

  final Set<String> _selectedBatchIds = {};
  bool _selectAll = false;

  String _formatTimestamp(BigInt timestamp) {
    if (timestamp == BigInt.zero) return "N/A";
    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      timestamp.toInt() * 1000,
    );
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }

  void _showCreateProductModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return BlocProvider.value(
          value: context.read<DashboardBloc>(),
          child: const CreateProductPage(),
        );
      },
    );
  }

  void _showTransferProductModal(BuildContext context, List<String> batchIds) {
    final TextEditingController receiverIdController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF243B55),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            "Transfer ${batchIds.length} Product(s)",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Selected batch IDs:\n${batchIds.join(", ")}",
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: receiverIdController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: "Receiver Organization ID",
                    labelStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Colors.white30),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: _accentColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final receiverId = receiverIdController.text;
                if (receiverId.isNotEmpty) {
                  for (final batchId in batchIds) {
                    context.read<DashboardBloc>().add(
                      TransferProductEvent(
                        batchId: batchId,
                        receiverOrganizationId: receiverId,
                      ),
                    );
                  }

                  // ✅ SỬA 1: Thêm `if (mounted)` check trước `setState`
                  // Vì `ProductManagementPage` có thể bị dispose
                  // trong khi dialog này đang mở.
                  if (mounted) {
                    setState(() {
                      _selectedBatchIds.clear();
                      _selectAll = false;
                    });
                  }
                  Navigator.of(ctx).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.black,
              ),
              child: const Text("Transfer"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveBarcodePNG(
    BuildContext context,
    GlobalKey repaintKey,
    String batchId,
  ) async {
    // ✅ SỬA 2: Lưu `ScaffoldMessenger` TRƯỚC khi `await`
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      if (Platform.isAndroid) {
        // `await` có thể làm widget bị dispose
        final permissions = await [
          Permission.storage,
          Permission.photos,
          Permission.mediaLibrary,
        ].request();

        // ✅ SỬA 3: Thêm `if (!mounted)` check sau khi `await`
        if (!mounted) return;
        if (permissions.values.every((status) => !status.isGranted)) {
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('❌ App does not have permission to save files!'),
            ),
          );
          return;
        }
      }

      final boundary =
          repaintKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      // ...nhiều lệnh `await`...
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData!.buffer.asUint8List();

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!(await directory.exists())) {
          directory = await getExternalStorageDirectory();
        }
      } else {
        directory = await getDownloadsDirectory();
      }

      if (directory == null) {
        // Handle error case
        if (!mounted) return;
        scaffoldMessenger.showSnackBar(
          const SnackBar(content: Text('❌ Could not find save directory.')),
        );
        return;
      }

      final filePath = '${directory.path}/barcode_$batchId.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes); // `await` cuối cùng

      // ✅ SỬA 4: Thêm `if (!mounted)` check sau khi `await`
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('✅ Barcode saved to:\n$filePath'),
          backgroundColor: _accentColor,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      // ✅ SỬA 5: Thêm `if (!mounted)` check trong `catch`
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('❌ Error saving barcode: $e')),
      );
    }
  }

  void _showErrorDialog(
    BuildContext context,
    String message, {
    bool isInitError = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: !isInitError,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF243B55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text(
          'Thao tác thất bại',
          style: TextStyle(
            color: Colors.redAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: <Widget>[
          if (!isInitError)
            TextButton(
              child: const Text(
                'Đã hiểu',
                style: TextStyle(color: _accentColor, fontSize: 16),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
          if (isInitError)
            TextButton(
              child: const Text(
                'Thử lại',
                style: TextStyle(color: _accentColor, fontSize: 16),
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                context.read<DashboardBloc>().add(FetchProductsEvent());
              },
            ),
        ],
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
          title: const Text(
            'Product Management',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: _accentColor),
              onPressed: () =>
                  context.read<DashboardBloc>().add(FetchProductsEvent()),
            ),
          ],
        ),
        body: BlocConsumer<DashboardBloc, DashboardState>(
          listener: (context, state) {
            // ✅ DÒNG NÀY BẠN ĐÃ THÊM ĐÚNG!
            if (!mounted) return;

            if (state is DashboardSuccessState &&
                !state.message.contains("Product created")) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: _accentColor,
                ),
              );
            } else if (state is DashboardErrorState) {
              final bool isInitError =
                  state.error.contains("Lỗi khởi tạo") ||
                  state.error.contains("Failed to load products");

              if (!state.error.contains("create product")) {
                _showErrorDialog(
                  context,
                  state.error,
                  isInitError: isInitError,
                );
              }
            }
          },
          builder: (context, state) {
            final products = state.products;
            products.sort((a, b) => b.date.compareTo(a.date));

            if (state is DashboardLoadingState && products.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: _accentColor),
              );
            }

            return Column(
              children: [
                if (state is DashboardLoadingState && products.isNotEmpty)
                  const LinearProgressIndicator(color: _accentColor),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _showCreateProductModal(context),
                    icon: const Icon(
                      Icons.add_box_rounded,
                      color: Colors.black,
                    ),
                    label: const Text(
                      "Create New Product",
                      style: TextStyle(fontSize: 18, color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                    ),
                  ),
                ),
                if (products.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _selectAll,
                          activeColor: _accentColor,
                          onChanged: (val) {
                            setState(() {
                              _selectAll = val ?? false;
                              if (_selectAll) {
                                _selectedBatchIds.addAll(
                                  products.map((e) => e.batchId),
                                );
                              } else {
                                _selectedBatchIds.clear();
                              }
                            });
                          },
                        ),
                        const Text(
                          "Select All",
                          style: TextStyle(color: Colors.white),
                        ),
                        const Spacer(),
                        if (_selectedBatchIds.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: () => _showTransferProductModal(
                              context,
                              _selectedBatchIds.toList(),
                            ),
                            icon: const Icon(Icons.send),
                            label: Text(
                              "Transfer Selected (${_selectedBatchIds.length})",
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _accentColor,
                              foregroundColor: Colors.black,
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: products.isEmpty
                      ? const Center(
                          child: Text(
                            "No products found.",
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final Product product = products[index];
                            final barcodeKey = GlobalKey();
                            final isSelected = _selectedBatchIds.contains(
                              product.batchId,
                            );

                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _cardColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? _accentColor
                                      : Colors.white12,
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      activeColor: _accentColor,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedBatchIds.add(
                                              product.batchId,
                                            );
                                          } else {
                                            _selectedBatchIds.remove(
                                              product.batchId,
                                            );
                                            _selectAll = false;
                                          }
                                        });
                                      },
                                    ),
                                    CircleAvatar(
                                      backgroundColor: _accentColor.withOpacity(
                                        0.3,
                                      ),
                                      child: const Icon(
                                        Icons.inventory_2,
                                        color: _accentColor,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            product.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                              fontSize: 16,
                                            ),
                                          ),
                                          Text(
                                            "Batch ID: ${product.batchId}",
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            "Date Created: ${_formatTimestamp(product.date)}",
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Center(
                                            child: RepaintBoundary(
                                              key: barcodeKey,
                                              child: Container(
                                                width: 250,
                                                height: 70,
                                                color: Colors.white,
                                                padding: const EdgeInsets.all(
                                                  4,
                                                ),
                                                child: BarcodeWidget(
                                                  barcode: Barcode.code128(),
                                                  data: product.batchId,
                                                  drawText: true,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    color: Colors.black,
                                                  ),
                                                  color: Colors.black,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Center(
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.download_rounded,
                                                color: _accentColor,
                                              ),
                                              tooltip: "Download Barcode",
                                              onPressed: () => _saveBarcodePNG(
                                                context,
                                                barcodeKey,
                                                product.batchId,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.info_outline,
                                            size: 26,
                                            color: Colors.white70,
                                          ),
                                          tooltip: 'View Details',
                                          onPressed: () =>
                                              _showProductDetailsDialog(
                                                context,
                                                product,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ====================== 💡 WIDGET NÀY GIỮ NGUYÊN ======================
// (Đã copy từ file của bạn)

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
              _buildDetailRow("Seed Variety:", product.seedVariety),
              _buildDetailRow("Origin:", product.origin),
              _buildDetailRow("Creator:", product.creator, isAddress: true),
              _buildDetailRow(
                "Current Owner:",
                product.currentOwner,
                isAddress: true,
              ),
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
          Text(step.description, style: const TextStyle(color: Colors.white70)),
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