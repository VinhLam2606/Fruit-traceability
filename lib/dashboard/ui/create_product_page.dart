// ignore_for_file: deprecated_member_use

import 'dart:math';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:untitled/dashboard/bloc/dashboard_bloc.dart';
import 'package:untitled/dashboard/model/product.dart';

class CreateProductPage extends StatelessWidget {
  const CreateProductPage({super.key});

  @override
  Widget build(BuildContext context) {
    // We rely on BlocProvider.value being passed down from the parent.
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
  final TextEditingController dateController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // --- Style constants ---
  static const List<Color> _backgroundGradient = [
    Color(0xFF141E30), // Darker
    Color(0xFF243B55), // Slightly Lighter
  ];
  static const Color _accentColor = Colors.greenAccent;
  static const Color _cardColor = Colors.white10;

  String _generateBatchId() {
    final random = Random();
    // Generate a random 6-digit number
    return (100000 + random.nextInt(900000)).toString();
  }

  String _formatTimestamp(BigInt timestamp) {
    if (timestamp == BigInt.zero) return "N/A";
    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      timestamp.toInt() * 1000,
    );
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  @override
  void dispose() {
    nameController.dispose();
    dateController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wrap Scaffold in a Container for the gradient background
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _backgroundGradient,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Crucial for showing the gradient
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: null,
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
              nameController.clear();
              dateController.clear();
              // Auto refresh list after successful creation
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
                state is DashboardLoadingState && state is! ProductsLoadedState;

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
          decoration: _inputDecoration(
            'Product Name',
          ), // Translated: Tên Sản Phẩm
        ),
        const SizedBox(height: 16),
        TextField(
          controller: dateController,
          style: const TextStyle(color: Colors.white),
          decoration: _inputDecoration(
            'Date (Timestamp in seconds)',
          ), // Translated: Ngày (Timestamp, giây)
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: isLoading
              ? null
              : () {
                  final generatedBatchId = _generateBatchId();
                  context.read<DashboardBloc>().add(
                    CreateProductButtonPressedEvent(
                      batchId: generatedBatchId,
                      name: nameController.text,
                      date: int.tryParse(dateController.text) ?? 0,
                    ),
                  );
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: _accentColor,
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.black,
                    strokeWidth: 3,
                  ),
                )
              : const Text(
                  "Create Product", // Translated: Tạo Sản Phẩm
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }

  // Utility to create TextField styling
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

  Widget _buildProductList(
    BuildContext context,
    DashboardState state,
    bool isLoading,
  ) {
    final products = state is ProductsLoadedState
        ? state.products
        : <Product>[];

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Created Products", // Translated: Sản Phẩm Đã Tạo
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
                  "No products have been created.", // Translated: Chưa có sản phẩm nào được tạo.
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
                    final Product product = products[index];
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Batch ID: ${product.batchId}",
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              "Date: ${_formatTimestamp(product.date)}", // Translated: Ngày
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Barcode
                            Center(
                              child: Container(
                                // ✅ Tăng chiều rộng
                                width: 250, // Ví dụ: 250 pixels
                                // ✅ Tăng chiều cao
                                height: 70, // Ví dụ: 70 pixels
                                margin: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ), // Khoảng cách
                                color: Colors.white,
                                padding: const EdgeInsets.all(4),
                                child: BarcodeWidget(
                                  barcode: Barcode.code128(),
                                  data: product.batchId,
                                  drawText: true,
                                  style: const TextStyle(
                                    // ✅ Tăng kích thước chữ
                                    fontSize: 16, // Ví dụ: 16
                                    color: Colors.black,
                                  ),
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ],
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
