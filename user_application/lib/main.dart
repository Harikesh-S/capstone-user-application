import 'package:flutter/material.dart';
import 'package:user_application/camera.dart';
import 'package:sizer/sizer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          title: 'User Application',
          home: const HomePage(title: 'User Application'),
          //home: HomePage(title: 'Login'),
          theme: ThemeData(
            colorScheme: const ColorScheme.dark(),
            appBarTheme: AppBarTheme(toolbarHeight: 21.sp),
            textTheme: TextTheme(
              titleLarge: TextStyle(fontSize: 15.sp),
              bodyMedium: TextStyle(fontSize: 10.sp),
              labelLarge: TextStyle(fontSize: 15.sp), // Label content
              titleMedium: TextStyle(fontSize: 10.sp), // Textfield content
            ),
          ),
        );
      },
    );
  }
}
