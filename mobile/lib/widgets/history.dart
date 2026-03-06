import 'package:flutter/material.dart';

class HistorySearchField extends StatelessWidget {
  const HistorySearchField({
    super.key,
    this.controller,
    this.onDateTap,
    required this.hasDateFilter,
    this.hintText = 'Search...',
  });

  final TextEditingController? controller;
  final VoidCallback? onDateTap;
  final bool hasDateFilter;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasDateFilter ? const Color(0xFF007AFF) : const Color(0xFFE5EAF1),
          width: hasDateFilter ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.search_rounded,
            color: Color(0xFF94A3B8),
            size: 26,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              textAlignVertical: TextAlignVertical.center,
              style: const TextStyle(fontSize: 17, color: Color(0xFF334155)),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: const TextStyle(fontSize: 17, color: Color(0xFF94A3B8)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          VerticalDivider(
            color: const Color(0xFFE5EAF1),
            indent: 18,
            endIndent: 18,
            width: 1,
            thickness: 1,
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onDateTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: hasDateFilter ? const Color(0xFFEAF1FB) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                color: hasDateFilter ? const Color(0xFF007AFF) : const Color(0xFF64748B),
                size: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SkelBox extends StatelessWidget {
  const SkelBox({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = 10,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE7EBF1),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class SkelLine extends StatelessWidget {
  const SkelLine({super.key, required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SkelBox(width: width, height: height);
  }
}
