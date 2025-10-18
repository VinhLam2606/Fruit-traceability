// lib/dashboard/model/timeline_item.dart
import 'product.dart';
import 'productHistory.dart';

/// Model cơ sở (abstract) để đảm bảo mọi item đều có timestamp
abstract class TimelineItem {
  final BigInt timestamp;
  TimelineItem(this.timestamp);
}

/// Model bọc một sự kiện LỊCH SỬ (Created, Transferred) - (Viền Xanh 🔵)
class HistoryEventItem extends TimelineItem {
  final ProductHistory historyEvent;
  HistoryEventItem(this.historyEvent) : super(historyEvent.timestamp);
}

/// Model bọc một sự kiện QUY TRÌNH (có đầy đủ chi tiết) - (Viền Cam 🟠)
class ProcessEventItem extends TimelineItem {
  final ProcessStep processStep;
  ProcessEventItem(this.processStep) : super(processStep.date);
}