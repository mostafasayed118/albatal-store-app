import 'package:flutter/material.dart';

/// Shared 2-column product grid delegate matching the DESIGN.md spacing tokens.
const productGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 2,
  childAspectRatio: .68,
  crossAxisSpacing: 12,
  mainAxisSpacing: 12,
);
