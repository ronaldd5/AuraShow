import 'package:flutter/material.dart';
import '../../../models/slide_model.dart';

class DashboardController extends ChangeNotifier {
  // State variables
  List<SlideContent> slides = [];
  int selectedSlideIndex = 0;
  int selectedTopTab = 0; // 0=Show, 1=Edit, 2=Stage
  bool isPlaying = false;

  // Placeholder for output configuration
  // List<OutputConfig> outputs = []; 

  void setSlides(List<SlideContent> newSlides) {
    slides = newSlides;
    notifyListeners();
  }

  void selectSlide(int index) {
    if (index >= 0 && index < slides.length) {
      selectedSlideIndex = index;
      notifyListeners();
    }
  }

  void togglePlayPause() {
    isPlaying = !isPlaying;
    notifyListeners();
  }

  void prevSlide() {
    if (selectedSlideIndex > 0) {
      selectedSlideIndex--;
      notifyListeners();
    }
  }

  void nextSlide() {
    if (selectedSlideIndex < slides.length - 1) {
      selectedSlideIndex++;
      notifyListeners();
    }
  }
}
