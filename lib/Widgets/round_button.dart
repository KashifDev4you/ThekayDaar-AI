import 'package:flutter/material.dart';
import 'package:ali_app/utils/app_theme.dart';

class RoundButton extends StatelessWidget {
  final String title;
  final VoidCallback? onPressed;
  const RoundButton({super.key,required this.title, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
    

      child: Container(
        alignment: Alignment.center,
      
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.gold,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(title, style: const TextStyle(color: AppTheme.emerald, fontWeight: FontWeight.bold, fontSize: 16),textAlign: TextAlign.center,),
      ),
    );
  }
}