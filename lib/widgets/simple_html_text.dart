import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

/// Affiche du HTML limité (b, i, u, span, div, p) sans dépendance lourde.
/// Alternative à flutter_html pour éviter les conflits avec les versions Flutter.
class SimpleHtmlText extends StatelessWidget {
  final String data;
  final TextStyle? baseStyle;

  const SimpleHtmlText({super.key, required this.data, this.baseStyle});

  @override
  Widget build(BuildContext context) {
    final doc = html_parser.parse(data.trim());
    final body = doc.body ?? doc.documentElement;
    if (body == null) return const SizedBox.shrink();

    final defaultStyle = baseStyle ?? TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16);
    final widgets = <Widget>[];
    List<InlineSpan>? currentSpans = [];

    void flushInline() {
      if (currentSpans != null && currentSpans!.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text.rich(TextSpan(children: currentSpans!, style: defaultStyle)),
        ));
        currentSpans = [];
      }
    }

    for (final node in body.nodes) {
      if (node is dom.Text) {
        final t = node.text.trim();
        if (t.isNotEmpty) {
          currentSpans ??= [];
          currentSpans!.add(TextSpan(text: t, style: defaultStyle));
        }
      } else if (node is dom.Element) {
        final tag = node.localName?.toLowerCase() ?? '';
        if (tag == 'div' || tag == 'p') {
          flushInline();
          final w = _buildFromNode(context, node, defaultStyle);
          if (w != null) widgets.add(w);
        } else {
          currentSpans ??= [];
          final span = _buildInlineSpan(node, defaultStyle);
          if (span != null) currentSpans!.add(span);
        }
      }
    }
    flushInline();

    if (widgets.isEmpty) return const SizedBox.shrink();
    if (widgets.length == 1) return widgets.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  Widget? _buildFromNode(BuildContext context, dom.Node node, TextStyle style) {
    if (node is dom.Text) {
      final t = node.text.trim();
      if (t.isEmpty) return null;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: style),
      );
    }
    if (node is dom.Element) {
      switch (node.localName?.toLowerCase()) {
        case 'b':
          return _buildInline(context, node, style.copyWith(fontWeight: FontWeight.bold));
        case 'i':
          return _buildInline(context, node, style.copyWith(fontStyle: FontStyle.italic));
        case 'u':
          return _buildInline(context, node, style.copyWith(decoration: TextDecoration.underline));
        case 'span':
          return _buildSpan(context, node, style);
        case 'div':
          return _buildDiv(context, node, style);
        case 'p':
          return _buildBlock(context, node, style.copyWith(), bottom: 12);
        default:
          return _buildInline(context, node, style);
      }
    }
    return null;
  }

  Widget _buildInline(BuildContext context, dom.Element el, TextStyle style) {
    final children = el.nodes.map((n) => _buildInlineSpan(n, style)).whereType<InlineSpan>().toList();
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(TextSpan(children: children)),
    );
  }

  InlineSpan? _buildInlineSpan(dom.Node node, TextStyle style) {
    if (node is dom.Text) {
      final t = node.text;
      if (t.isEmpty) return null;
      return TextSpan(text: t, style: style);
    }
    if (node is dom.Element) {
      switch (node.localName?.toLowerCase()) {
        case 'b':
          return _spanFromElement(node, style.copyWith(fontWeight: FontWeight.bold));
        case 'i':
          return _spanFromElement(node, style.copyWith(fontStyle: FontStyle.italic));
        case 'u':
          return _spanFromElement(node, style.copyWith(decoration: TextDecoration.underline));
        case 'span':
          return _spanFromStyledElement(node, style);
        default:
          return _spanFromElement(node, style);
      }
    }
    return null;
  }

  InlineSpan _spanFromElement(dom.Element el, TextStyle style) {
    final children = el.nodes.map((n) => _buildInlineSpan(n, style)).whereType<InlineSpan>().toList();
    if (children.isEmpty) return TextSpan(text: '', style: style);
    return TextSpan(children: children, style: style);
  }

  InlineSpan _spanFromStyledElement(dom.Element el, TextStyle style) {
    Color? color = style.color;
    final styleAttr = el.attributes['style'];
    if (styleAttr != null) {
      final colorMatch = RegExp(r'color:\s*#([0-9A-Fa-f]{6})').firstMatch(styleAttr);
      if (colorMatch != null) {
        color = Color(int.parse('FF${colorMatch.group(1)}', radix: 16));
      }
    }
    final s = style.copyWith(color: color);
    return _spanFromElement(el, s);
  }

  Widget _buildSpan(BuildContext context, dom.Element el, TextStyle style) {
    final span = _spanFromStyledElement(el, style);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(span),
    );
  }

  Widget _buildDiv(BuildContext context, dom.Element el, TextStyle style) {
    TextAlign align = TextAlign.left;
    final styleAttr = el.attributes['style'];
    if (styleAttr != null) {
      if (styleAttr.contains('text-align: center')) align = TextAlign.center;
      if (styleAttr.contains('text-align: right')) align = TextAlign.right;
    }
    final children = el.nodes.map((n) => _buildInlineSpan(n, style)).whereType<InlineSpan>().toList();
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(TextSpan(children: children, style: style), textAlign: align),
    );
  }

  Widget _buildBlock(BuildContext context, dom.Element el, TextStyle style, {double bottom = 0}) {
    final children = el.nodes.map((n) => _buildInlineSpan(n, style)).whereType<InlineSpan>().toList();
    if (children.isEmpty) return SizedBox(height: bottom);
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Text.rich(TextSpan(children: children, style: style)),
    );
  }
}
