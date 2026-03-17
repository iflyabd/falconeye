import 'package:flutter/material.dart';

// PERF V50.0: Global RouteObserver singleton.
// Imported by main.dart (to register with Navigator) and by any page
// that uses RouteAware. Using a separate file avoids circular imports.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();
