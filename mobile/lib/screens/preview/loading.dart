part of 'preview.dart';

class SalePreviewLoadingScreen extends StatelessWidget {
  const SalePreviewLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Color(0xFF46566E),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Preview',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0E1930),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFDDE6F2)),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 18),
                    child: Column(
                      children: [
                        _PreviewSkelCircle(size: 74),
                        SizedBox(height: 12),
                        _PreviewSkelLine(width: 220, height: 24),
                        SizedBox(height: 8),
                        _PreviewSkelLine(width: 180, height: 16),
                        SizedBox(height: 6),
                        _PreviewSkelLine(width: 150, height: 16),
                        SizedBox(height: 16),
                        Divider(color: Color(0xFFE5ECF6), height: 1),
                        SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: _PreviewSkelLine(width: 120, height: 46),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: _PreviewSkelLine(width: 120, height: 46),
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        Divider(color: Color(0xFFE5ECF6), height: 1),
                        SizedBox(height: 14),
                        _PreviewSkelCard(height: 56),
                        SizedBox(height: 8),
                        _PreviewSkelCard(height: 56),
                        SizedBox(height: 8),
                        _PreviewSkelCard(height: 56),
                        SizedBox(height: 12),
                        Divider(color: Color(0xFFE5ECF6), height: 1),
                        SizedBox(height: 12),
                        _PreviewSkelLine(width: double.infinity, height: 20),
                        SizedBox(height: 8),
                        _PreviewSkelLine(width: double.infinity, height: 24),
                        SizedBox(height: 24),
                        _PreviewSkelLine(width: 240, height: 20),
                        SizedBox(height: 16),
                        _PreviewSkelLine(width: 160, height: 68),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PreviewSkelButton(height: 58),
                  SizedBox(height: 10),
                  _PreviewSkelButton(height: 58),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewSkelCard extends StatelessWidget {
  const _PreviewSkelCard({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FB),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _PreviewSkelButton extends StatelessWidget {
  const _PreviewSkelButton({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EFF8),
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}

class _PreviewSkelLine extends StatelessWidget {
  const _PreviewSkelLine({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE8EFF8),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _PreviewSkelCircle extends StatelessWidget {
  const _PreviewSkelCircle({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFFE8EFF8),
        shape: BoxShape.circle,
      ),
    );
  }
}
