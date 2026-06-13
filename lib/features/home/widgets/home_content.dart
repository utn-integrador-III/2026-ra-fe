import 'package:flutter/material.dart';

class HomeContent extends StatelessWidget {
  const HomeContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Bienvenido a RA FE',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }
}
