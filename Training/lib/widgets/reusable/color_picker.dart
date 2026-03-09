import 'package:flutter/material.dart';

class ColorPicker extends StatefulWidget {
  final ValueChanged<Color> onColorSelected;
  final Color selectedColor;

  const ColorPicker({
    super.key,
    required this.onColorSelected,
    required this.selectedColor,
  });

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  final List<Color> colors = [
    Colors.black,
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.pink,
    Colors.brown,
    Colors.yellow,
    Colors.teal,
    Colors.indigo,
    Colors.cyan,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: colors.map((color) {
          return GestureDetector(
            onTap: () => widget.onColorSelected(color),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.selectedColor == color
                      ? Colors.black
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: widget.selectedColor == color
                  ? const Icon(
                Icons.check,
                color: Colors.white,
                size: 16,
              )
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }
}