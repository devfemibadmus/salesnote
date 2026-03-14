import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:file_saver/file_saver.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:saver_gallery/saver_gallery.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models.dart';
import '../../services/currency.dart';
import '../../services/media.dart';
import '../../services/notice.dart';

part 'loading.dart';
part 'screen.dart';
part 'widgets.dart';
part 'pdf.dart';

class PreviewSaleItem {
  const PreviewSaleItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  final String productName;
  final double quantity;
  final double unitPrice;

  double get lineTotal => quantity * unitPrice;
}
