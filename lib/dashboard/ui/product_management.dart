import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:untitled/dashboard/bloc/dashboard_bloc.dart';
import 'package:untitled/dashboard/model/product.dart';
import 'package:untitled/dashboard/ui/create_product_page.dart';

// Trang quản lý sản phẩm tổng quát
class ProductManagementPage extends StatelessWidget {
  const ProductManagementPage({super.key});

  // --- Style constants ---
  static const List<Color> _backgroundGradient = [
    Color(0xFF141E30), // Tối hơn
    Color(0xFF243B55), // Sáng hơn một chút
  ];
  static const Color _accentColor = Colors.greenAccent;
  static const Color _cardColor = Colors.white10;

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
      backgroundColor: Colors.transparent, // Rất quan trọng cho gradient
      builder: (ctx) {
        // Đảm bảo BlocProvider vẫn được truyền xuống cho CreateProductPage
        return BlocProvider.value(
          value: context.read<DashboardBloc>(),
          child: const CreateProductPage(),
        );
      },
    );
  }

  // Phương thức hiển thị Modal chuyển giao sản phẩm (Đã style lại)
  void _showTransferProductModal(BuildContext context, Product product) {
    final TextEditingController receiverIdController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF243B55), // Nền tối
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            "Chuyển Giao Sản Phẩm: ${product.name}",
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
                  "Batch ID: ${product.batchId}",
                  style: const TextStyle(color: Colors.white70),
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
                "Hủy",
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final receiverId = receiverIdController.text;
                if (receiverId.isNotEmpty) {
                  context.read<DashboardBloc>().add(
                    TransferProductEvent(
                      batchId: product.batchId,
                      receiverOrganizationId: receiverId,
                    ),
                  );
                  Navigator.of(ctx).pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text("Chuyển Giao"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // 1. Áp dụng gradient nền cho toàn bộ trang
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
            'Quản Lý Sản Phẩm',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            // Nút Refresh
            IconButton(
              icon: const Icon(Icons.refresh, color: _accentColor),
              onPressed: () {
                // Gửi event fetch lại danh sách sản phẩm
                context.read<DashboardBloc>().add(FetchProductsEvent());
              },
            ),
          ],
        ),
        body: BlocConsumer<DashboardBloc, DashboardState>(
          listenWhen: (previous, current) =>
              current is DashboardSuccessState ||
              current is DashboardErrorState,
          listener: (context, state) {
            if (state is DashboardSuccessState &&
                !state.message.contains("Product created")) {
              // Hiển thị thông báo thành công cho giao dịch chuyển giao (Transfer)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: _accentColor,
                ),
              );
            } else if (state is DashboardErrorState &&
                !state.error.contains("create product")) {
              // Hiển thị thông báo lỗi cho giao dịch chuyển giao
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
          builder: (context, state) {
            final products = state is ProductsLoadedState
                ? state.products
                : <Product>[];

            // --- Logic Loading/Error ---
            if (state is DashboardLoadingState && products.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(color: _accentColor),
              );
            }

            if (state is DashboardErrorState && products.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Text(
                    "Lỗi tải sản phẩm: ${state.error}",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            }
            // --- End Logic Loading/Error ---

            return Column(
              children: [
                // Nút "Create Product"
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _showCreateProductModal(context),
                    icon: const Icon(
                      Icons.add_box_rounded,
                      color: Colors.black,
                    ),
                    label: const Text(
                      "Tạo Sản Phẩm Mới",
                      style: TextStyle(fontSize: 18, color: Colors.black),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accentColor, // Màu điểm nhấn
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                    ),
                  ),
                ),
                // Danh sách sản phẩm (Product List)
                Expanded(
                  child: products.isEmpty
                      ? const Center(
                          child: Text(
                            "Không tìm thấy sản phẩm nào.",
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.builder(
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final Product product = products[index];
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _cardColor, // Màu nền tối cho Card
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white12),
                              ),
                              // ✅ THAY THẾ LISTTILE BẰNG ROW TÙY CHỈNH ĐỂ KHẮC PHỤC LỖI TRÀN
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Phần Leading (Icon)
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
                                    // Phần Title + Subtitle + Barcode
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
                                            "Ngày tạo: ${_formatTimestamp(product.date)}",
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          // Barcode
                                          Center(
                                            child: Container(
                                              // ✅ TĂNG CHIỀU RỘNG LÊN 250
                                              width: 250,
                                              // ✅ TĂNG CHIỀU CAO LÊN 70
                                              height: 70,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                              // ✅ NỀN TRẮNG
                                              color: Colors.white,
                                              padding: const EdgeInsets.all(4),
                                              child: BarcodeWidget(
                                                barcode: Barcode.code128(),
                                                data: product.batchId,
                                                drawText: true,
                                                style: const TextStyle(
                                                  // ✅ TĂNG KÍCH THƯỚC CHỮ
                                                  fontSize: 16,
                                                  color:
                                                      Colors.black, // TEXT ĐEN
                                                ),
                                                color:
                                                    Colors.black, // MÃ VẠCH ĐEN
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Phần Trailing (Các nút thao tác)
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                            Icons.send,
                                            color: _accentColor,
                                            size: 26,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          tooltip: 'Chuyển Giao Sản Phẩm',
                                          onPressed: () {
                                            _showTransferProductModal(
                                              context,
                                              product,
                                            );
                                          },
                                        ),
                                        const SizedBox(
                                          height: 10,
                                        ), // Khoảng cách giữa hai nút
                                        IconButton(
                                          icon: const Icon(
                                            Icons.info_outline,
                                            size: 26,
                                            color: Colors.white70,
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          tooltip: 'Xem Chi Tiết',
                                          onPressed: () {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "Xem chi tiết sản phẩm... (Chức năng sắp ra mắt)",
                                                ),
                                              ),
                                            );
                                          },
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
