import 'package:flutter/material.dart';

/// Official vertical logo from the design kit, used on login and splash.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 96});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'UniConnect',
      image: true,
      child: ExcludeSemantics(
        child: Image.asset(
          'assets/brand/uniconnect-logo-vertical.png',
          height: height,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
