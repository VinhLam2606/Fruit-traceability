// dashboard/ui/scan_barcode_page.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:untitled/dashboard/bloc/scan_bloc.dart'; // Import ScanBloc
import 'package:untitled/dashboard/model/product.dart'; // Import Product
import 'package:untitled/dashboard/model/productHistory.dart'; // Import ProductHistory

class ScanBarcodePage extends StatelessWidget {
  const ScanBarcodePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Lấy instance của ScanBloc
    final scanBloc = context.read<ScanBloc>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Quét Mã Sản Phẩm',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF141E30), Color(0xFF243B55)],
          ),
        ),
        // Sử dụng BlocConsumer để vừa xây dựng UI vừa lắng nghe actions
        child: BlocConsumer<ScanBloc, ScanState>(
          listener: (context, state) {
            if (state is ScanErrorState) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text("❌ ${state.error}"),
                    backgroundColor: Colors.redAccent,
                  ),
                );
            }
          },
          builder: (context, state) {
            return Column(
              children: [
                // --- 1. Khu vực máy quét Barcode ---
                Container(
                  padding: const EdgeInsets.only(top: 80),
                  height: 330,
                  child: MobileScanner(
                    controller: MobileScannerController(
                      // Chỉ quét 1 lần duy nhất cho mỗi mã
                      detectionTimeoutMs: 1000,
                    ),
                    onDetect: (capture) {
                      final code = capture.barcodes.first.rawValue;
                      if (code != null && code.isNotEmpty && state is! ScanLoadingState) {
                        // Kích hoạt Event BarcodeScannedEvent
                        scanBloc.add(BarcodeScannedEvent(code));
                      }
                    },
                  ),
                ),

                // --- 2. Hiển thị Trạng thái (Loading, Data, Error) ---
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _buildContent(context, state, scanBloc),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ====================================================================
  //                         BUILDER FUNCTIONS
  // ====================================================================

  Widget _buildContent(
      BuildContext context,
      ScanState state,
      ScanBloc bloc,
      ) {
    // Loading State
    if (state is ScanLoadingState || state is ProductHistoryLoadingState) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.greenAccent),
      );
    }

    // Initial State / Error State
    if (state is ScanInitialState || state is ScanErrorState) {
      final message = state is ScanErrorState
          ? "Lỗi: ${state.error}\nVui lòng scan lại."
          : "Hướng camera vào mã vạch để quét sản phẩm.";

      return Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      );
    }

    // Loaded State (Product Info / Details)
    if (state is ProductInfoLoadedState) {
      final product = state.product;
      final history = state.history;

      return RefreshIndicator(
        color: Colors.greenAccent,
        onRefresh: () async {
          // Refresh: Gửi lại Event quét mã vạch để lấy lại thông tin sản phẩm
          bloc.add(BarcodeScannedEvent(product.batchId));
        },
        child: ListView(
          children: [
            // 🌟 Product Header Card
            _buildProductHeader(context, product),
            const SizedBox(height: 20),

            // ⚡ Transaction History Section
            _buildHistorySection(context, product, history, state, bloc),

            // Hiển thị lỗi tải lịch sử cục bộ (nếu có)
            if (state.historyErrorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  state.historyErrorMessage!,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      );
    }

    return const Center(child: Text("Đang tải dữ liệu..."));
  }

  Widget _buildProductHeader(BuildContext context, Product product) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.greenAccent.withOpacity(0.6),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            product.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(color: Colors.white38, height: 25),
          _infoRow('Batch ID', product.batchId, isAddress: true, context: context),
          _infoRow('Tổ chức', product.organizationName),
          _infoRow(
            'Ngày tạo',
            DateTime.fromMillisecondsSinceEpoch(product.date.toInt() * 1000)
                .toLocal()
                .toString()
                .split(' ')[0],
          ),
          _infoRow('Chủ sở hữu hiện tại', product.currentOwner, isAddress: true, context: context),
        ],
      ),
    );
  }

  Widget _buildHistorySection(
      BuildContext context,
      Product product,
      List<ProductHistory>? history,
      ProductInfoLoadedState state,
      ScanBloc bloc,
      ) {
    if (state is! ProductDetailsLoadedState) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent.withOpacity(0.9),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.history, size: 20),
            label: const Text(
              "Xem Lịch sử Giao dịch",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              // Kích hoạt Event tải lịch sử
              bloc.add(FetchProductHistoryEvent(product.batchId));
            },
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 30),
        const Text(
          "Lịch sử giao dịch",
          style: TextStyle(
            color: Colors.white70,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        if (history!.isEmpty)
          const Text(
            "Chưa có giao dịch nào được ghi lại.",
            style: TextStyle(color: Colors.white54),
          )
        else
          ...history.map((h) => _buildHistoryItemCard(h)).toList(),
      ],
    );
  }

  Widget _buildHistoryItemCard(ProductHistory h) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        title: Text(
          h.note,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.greenAccent,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _historyDetailRow('Từ', h.from),
            _historyDetailRow('Đến', h.to),
            _historyDetailRow(
              'Thời gian',
              DateTime.fromMillisecondsSinceEpoch(h.timestamp.toInt() * 1000)
                  .toLocal()
                  .toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(
      String title,
      String value, {
        bool isAddress = false,
        BuildContext? context,
      }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              "$title:",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: isAddress ? 13 : 16,
                      color: Colors.white,
                      fontFamily: isAddress ? "monospace" : null,
                    ),
                    maxLines: isAddress ? 1 : 2,
                    overflow: isAddress ? TextOverflow.ellipsis : TextOverflow.clip,
                  ),
                ),
                if (isAddress && context != null)
                  IconButton(
                    icon: const Icon(
                      Icons.copy,
                      color: Colors.greenAccent,
                      size: 18,
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📋 Đã sao chép địa chỉ!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyDetailRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "$title: ",
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}