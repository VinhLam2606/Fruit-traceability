import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:untitled/dashboard/bloc/dashboard_bloc.dart';
import 'package:untitled/dashboard/model/product.dart';
import 'package:untitled/dashboard/ui/create_product_page.dart'; // Để gọi trang tạo sản phẩm

// Trang quản lý sản phẩm tổng quát
class ProductManagementPage extends StatelessWidget {
  const ProductManagementPage({super.key});

  // Hàm tiện ích để định dạng thời gian
  String _formatTimestamp(BigInt timestamp) {
    if (timestamp == BigInt.zero) return "N/A";
    final dateTime = DateTime.fromMillisecondsSinceEpoch(
      timestamp.toInt() * 1000,
    );
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }

  // Phương thức hiển thị trang tạo sản phẩm dưới dạng Bottom Sheet
  void _showCreateProductModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        // Đảm bảo BlocProvider vẫn được truyền xuống cho CreateProductPage
        return BlocProvider.value(
          value: context.read<DashboardBloc>(),
          child: const CreateProductPage(),
        );
      },
    );
  }

  // Phương thức hiển thị Modal chuyển giao sản phẩm
  void _showTransferProductModal(BuildContext context, Product product) {
    final TextEditingController receiverIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text("Transfer Product: ${product.name}"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Batch ID: ${product.batchId}"),
                const SizedBox(height: 16),
                TextField(
                  controller: receiverIdController,
                  decoration: const InputDecoration(
                    labelText: "Receiver Organization ID",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final receiverId = receiverIdController.text;
                if (receiverId.isNotEmpty) {
                  // Gửi event chuyển giao sản phẩm
                  context.read<DashboardBloc>().add(
                    TransferProductEvent(
                      batchId: product.batchId,
                      receiverOrganizationId: receiverId,
                    ),
                  );
                  Navigator.of(ctx).pop(); // Đóng modal
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Attempting to transfer product ${product.batchId} to $receiverId...",
                      ),
                    ),
                  );
                }
              },
              child: const Text("Transfer"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Management'),
        actions: [
          // Nút Refresh
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Gửi event fetch lại danh sách sản phẩm
              context.read<DashboardBloc>().add(FetchProductsEvent());
            },
          ),
        ],
      ),
      // Sử dụng BlocConsumer để lắng nghe kết quả giao dịch (như Transfer)
      body: BlocConsumer<DashboardBloc, DashboardState>(
        listenWhen: (previous, current) =>
            current is DashboardSuccessState || current is DashboardErrorState,
        listener: (context, state) {
          if (state is DashboardSuccessState &&
              !state.message.contains("Product created")) {
            // Hiển thị thông báo thành công cho giao dịch chuyển giao (Transfer)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is DashboardErrorState &&
              !state.error.contains("create product")) {
            // Hiển thị thông báo lỗi cho giao dịch chuyển giao
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error), backgroundColor: Colors.red),
            );
          }
        },
        builder: (context, state) {
          // --- Logic Loading/Error ---

          // 1. Hiển thị loading overlay nếu đang fetch data lần đầu
          if (state is DashboardLoadingState && state is! ProductsLoadedState) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Xác định danh sách sản phẩm (an toàn)
          final products = state is ProductsLoadedState
              ? state.products
              : <Product>[];

          // 3. Hiển thị lỗi nếu có lỗi VÀ danh sách sản phẩm trống (không thể hiển thị dữ liệu cũ)
          if (state is DashboardErrorState && products.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  "Error loading products: ${state.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            );
          }
          // --- End Logic Loading/Error ---

          return Column(
            children: [
              // Nút "Create Product"
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ElevatedButton.icon(
                  onPressed: () => _showCreateProductModal(context),
                  icon: const Icon(Icons.add_box_rounded),
                  label: const Text(
                    "Create New Product",
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const Divider(),
              // Danh sách sản phẩm (Product List)
              Expanded(
                child: products.isEmpty
                    ? const Center(child: Text("No products found."))
                    : ListView.builder(
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final Product product = products[index];
                          return Card(
                            margin: const EdgeInsets.only(
                              bottom: 8,
                              left: 16,
                              right: 16,
                            ),
                            elevation: 2,
                            child: ListTile(
                              leading: const Icon(Icons.inventory),
                              title: Text(
                                product.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Batch ID: ${product.batchId}"),
                                  Text(
                                    "Date: ${_formatTimestamp(product.date)}",
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 70,
                                    child: BarcodeWidget(
                                      barcode: Barcode.code128(),
                                      data: product.batchId,
                                      drawText: true,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              // Thêm nút Transfer và chi tiết
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.send,
                                      color: Colors.blue,
                                    ),
                                    tooltip: 'Transfer Product',
                                    onPressed: () {
                                      _showTransferProductModal(
                                        context,
                                        product,
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                    ),
                                    tooltip: 'View Details',
                                    onPressed: () {
                                      // TODO: Thêm chức năng xem chi tiết sản phẩm
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Viewing Product details... (Feature coming soon)",
                                          ),
                                        ),
                                      );
                                    },
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
    );
  }
}
