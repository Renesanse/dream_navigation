import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:dream_navigation/dream_navigation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

void main() {
  // kProfileBolterPerformanceLogging = true;
  runApp(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        color: Colors.black,
        child: Localizations(
          locale: const Locale('ru'),
          delegates: const [
            DefaultMaterialLocalizations.delegate,
            DefaultCupertinoLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          child: MediaQuery.fromWindow(
              child: DreamNavigation(
                initialWidgets: [
                  Builder(
                      builder: (context) {
                        return Container(
                            color: Colors.red,
                            child: CupertinoButton(
                              child: Text("back"),
                              onPressed: () {
                                DreamNavigation.of(context).removeLast();
                              },
                            ));
                      }
                  ),
                  Builder(
                      builder: (context) {
                        return Container(
                            color: Colors.red,
                            child: CupertinoButton(
                              child: Text("back"),
                              onPressed: () {
                                DreamNavigation.of(context).removeLast();
                              },
                            ));
                      }
                  ),
                  DreamNavigation(
                    initialWidgets: [
                      Builder(
                          builder: (context) {
                            return Container(
                                color: Colors.green,
                                child: CupertinoButton(
                                  child: Text("back"),
                                  onPressed: () {
                                    DreamNavigation.of(context).removeLast();
                                  },
                                ));
                          }
                      ),
                      Builder(
                          builder: (context) {
                            return Container(
                                color: Colors.green,
                                child: CupertinoButton(
                                  child: Text("back"),
                                  onPressed: () {
                                    DreamNavigation.of(context).removeLast();
                                  },
                                ));
                          }
                      ),
                    ],
                  )
                ],
              )),
        ),
      ),
    ),
  );
}
