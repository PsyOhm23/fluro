/*
 * fluro
 * A Posse Production
 * http://goposse.com
 * Copyright (c) 2018 Posse Productions LLC. All rights reserved.
 * See LICENSE for distribution and usage details.
 */
part of fluro;

enum TransitionType {
  native,
  nativeModal,
  fluroNative,
  inFromLeft,
  inFromRight,
  inFromBottom,
  fadeIn,
  custom, // if using custom then you must also provide a transition
}

class Router {
  static final appRouter = new Router();

  /// The tree structure that stores the defined routes
  final RouteTree _routeTree = new RouteTree();

  /// Generic handler for when a route has not been defined
  Handler notFoundHandler;

  /// Creates a [PageRoute] definition for the passed [RouteHandler]. You can optionally provide a custom
  /// transition builder for the route.
  void define(String routePath, {@required Handler handler}) {
    _routeTree.addRoute(new AppRoute(routePath, handler));
  }

  /// Finds a defined [AppRoute] for the path value. If no [AppRoute] definition was found
  /// then function will return null.
  AppRouteMatch match(String path) {
    return _routeTree.matchRoute(path);
  }

  ///
  Future navigateTo(BuildContext context, String path,
      {bool replace = false,
      TransitionType transition = TransitionType.fluroNative,
      Duration transitionDuration = const Duration(milliseconds: 250),
      RouteTransitionsBuilder transitionBuilder}) {
    RouteMatch routeMatch = matchRoute(context, path,
        transitionType: transition,
        transitionsBuilder: transitionBuilder,
        transitionDuration: transitionDuration);
    Route<dynamic> route = routeMatch.route;
    Completer completer = new Completer();
    Future future = completer.future;
    if (routeMatch.matchType == RouteMatchType.nonVisual) {
      completer.complete("Non visual route type.");
    } else {
      if (route == null && notFoundHandler != null) {
        route = _notFoundRoute(context, path);
      }
      if (route != null) {
        future = replace
            ? Navigator.pushReplacement(context, route)
            : Navigator.push(context, route);
        completer.complete();
      } else {
        String error = "No registered route was found to handle '$path'.";
        print(error);
        completer.completeError(error);
      }
    }

    return future;
  }

  bool pop(BuildContext context) => Navigator.of(context).pop();

  List<NavigatorObserver> get routerObservers {
    return [
      new RoutableObserver(),
    ];
  }

  ///
  Route<Null> _notFoundRoute(BuildContext context, String path) {
    RouteCreator<Null> creator =
        (RouteSettings routeSettings, Map<String, List<String>> parameters) {
      return new MaterialPageRoute<Null>(
          settings: routeSettings,
          builder: (BuildContext context) {
            return notFoundHandler.handlerFunc(context, parameters);
          });
    };
    return creator(new RouteSettings(name: path), null);
  }

  ///
  RouteMatch matchRoute(BuildContext buildContext, String path,
      {RouteSettings routeSettings,
      TransitionType transitionType,
      Duration transitionDuration = const Duration(milliseconds: 250),
      RouteTransitionsBuilder transitionsBuilder}) {
    RouteSettings settingsToUse = routeSettings;
    if (routeSettings == null) {
      settingsToUse = new RouteSettings(name: path);
    }
    AppRouteMatch match = _routeTree.matchRoute(path);
    AppRoute route = match?.route;
    Handler handler = (route != null ? route.handler : notFoundHandler);
    if (route == null && notFoundHandler == null) {
      return new RouteMatch(
          matchType: RouteMatchType.noMatch,
          errorMessage: "No matching route was found");
    }
    Map<String, List<String>> parameters =
        match?.parameters ?? <String, List<String>>{};
    if (handler.type == HandlerType.function) {
      handler.handlerFunc(buildContext, parameters);
      return new RouteMatch(matchType: RouteMatchType.nonVisual);
    }

    final platform = currentPlatform();
    RouteCreator creator =
        (RouteSettings routeSettings, Map<String, List<String>> parameters) {
      // We use the standard material route for .native, .nativeModal and
      // .fluroNative if you're on iOS
      bool isNativeTransition = (transitionType == TransitionType.native ||
          transitionType == TransitionType.nativeModal ||
          (transitionType == TransitionType.fluroNative &&
              platform != TargetPlatform.android));
      if (isNativeTransition) {
        return new MaterialPageRoute<dynamic>(
            settings: routeSettings,
            fullscreenDialog: transitionType == TransitionType.nativeModal,
            builder: (BuildContext context) =>
                handler.handlerFunc(context, parameters));
      } else {
        var routeTransitionsBuilder;
        if (transitionType == TransitionType.custom) {
          routeTransitionsBuilder = transitionsBuilder;
        } else {
          if (transitionType == TransitionType.fluroNative &&
              platform == TargetPlatform.android) {
            transitionDuration = new Duration(milliseconds: 150);
          }
          routeTransitionsBuilder = _standardTransitionsBuilder(transitionType);
        }
        return new PageRouteBuilder<dynamic>(
          settings: routeSettings,
          pageBuilder: (BuildContext context, Animation<double> animation,
              Animation<double> secondaryAnimation) {
            return handler.handlerFunc(context, parameters);
          },
          transitionDuration: transitionDuration,
          transitionsBuilder: routeTransitionsBuilder,
        );
      }
    };
    return new RouteMatch(
      matchType: RouteMatchType.visual,
      route: creator(settingsToUse, parameters),
    );
  }

  RouteTransitionsBuilder _standardTransitionsBuilder(
      TransitionType transitionType) {
    return (BuildContext context, Animation<double> animation,
        Animation<double> secondaryAnimation, Widget child) {
      if (transitionType == TransitionType.fluroNative) {
        return new SlideTransition(
          position: new Tween<Offset>(
            begin: const Offset(0.0, 0.12),
            end: const Offset(0.0, 0.0),
          ).animate(new CurvedAnimation(
              parent: animation,
              curve: new Interval(0.125, 0.950, curve: Curves.fastOutSlowIn),
            reverseCurve: Curves.easeOut,
          )),
          child: new FadeTransition(
            opacity: new Tween<double>(
              begin: 0.0,
              end: 1.0,
            ).animate(animation),
            child: child,
          ),
        );
      } else if (transitionType == TransitionType.fadeIn) {
        return new FadeTransition(opacity: animation, child: child);
      } else {
        const Offset topLeft = const Offset(0.0, 0.0);
        const Offset topRight = const Offset(1.0, 0.0);
        const Offset bottomLeft = const Offset(0.0, 1.0);
        Offset startOffset = bottomLeft;
        Offset endOffset = topLeft;
        if (transitionType == TransitionType.inFromLeft) {
          startOffset = const Offset(-1.0, 0.0);
          endOffset = topLeft;
        } else if (transitionType == TransitionType.inFromRight) {
          startOffset = topRight;
          endOffset = topLeft;
        }

        return new SlideTransition(
          position: new Tween<Offset>(
            begin: startOffset,
            end: endOffset,
          ).animate(animation),
          child: child,
        );
      }
    };
  }

  /// Route generation method. This function can be used as a way to create routes on-the-fly
  /// if any defined handler is found. It can also be used with the [MaterialApp.onGenerateRoute]
  /// property as callback to create routes that can be used with the [Navigator] class.
  Route<dynamic> generator(RouteSettings routeSettings) {
    RouteMatch match =
        matchRoute(null, routeSettings.name, routeSettings: routeSettings);
    return match.route;
  }

  /// Prints the route tree so you can analyze it.
  void printTree() {
    _routeTree.printTree();
  }
}
