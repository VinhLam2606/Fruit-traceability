// dashboard/ui/create_product_page.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:barcode_widget/barcode_widget.dart'; // Thêm package để render barcode
import 'package:untitled/dashboard/bloc/dashboard_bloc.dart';
import 'package:untitled/dashboard/model/product.dart';

class CreateProductPage extends StatelessWidget {
  const CreateProductPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => DashboardBloc()..add(DashboardInitialFetchEvent()),
      child: const CreateProductView(),
    );
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

  String _generateBatchId() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString(); // random 6 số
  }

  String _formatTimestamp(BigInt timestamp) {
    if (timestamp == BigInt.zero) return "N/A";
    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      timestamp.toInt() * 1000,
    );
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Product Dashboard')),
      body: BlocConsumer<DashboardBloc, DashboardState>(
        listenWhen: (previous, current) => current is! ProductsLoadedState,
        listener: (context, state) {
          if (state is DashboardSuccessState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.green),
            );
            nameController.clear();
            dateController.clear();
            context.read<DashboardBloc>().add(FetchProductsEvent());
          } else if (state is DashboardErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          if (state is DashboardInitial && state is! DashboardLoadingState) {
            return const Center(child: Text("Initializing connection..."));
          }
          if (state is DashboardLoadingState && state is! ProductsLoadedState) {
            return const Center(child: CircularProgressIndicator());
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                _buildCreateProductForm(context),
                const SizedBox(height: 24),
                const Divider(),
                _buildProductList(context, state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreateProductForm(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          "Create New Product",
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: "Product Name"),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: dateController,
          decoration: const InputDecoration(labelText: "Date (Timestamp)"),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: () {
            final generatedBatchId = _generateBatchId();
            context.read<DashboardBloc>().add(
              CreateProductButtonPressedEvent(
                batchId: generatedBatchId,
                name: nameController.text,
                date: int.tryParse(dateController.text) ?? 0,
              ),
            );
          },
          child: const Text("Create Product"),
        ),
      ],
    );
  }

  Widget _buildProductList(BuildContext context, DashboardState state) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Created Products",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  context.read<DashboardBloc>().add(FetchProductsEvent());
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state is DashboardLoadingState)
            const Center(child: CircularProgressIndicator()),
          if (state is ProductsLoadedState)
            state.products.isEmpty
                ? const Center(child: Text("No products found."))
                : Expanded(
              child: ListView.builder(
                itemCount: state.products.length,
                itemBuilder: (context, index) {
                  final Product product = state.products[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Date: ${_formatTimestamp(product.date)}"),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 80,
                            child: BarcodeWidget(
                              barcode: Barcode.code128(), // Kiểu barcode
                              data: product.batchId,      // Sinh barcode từ batchId
                              drawText: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
