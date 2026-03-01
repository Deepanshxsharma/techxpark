class OnboardingData {
  final String image;
  final String title;
  final String subtitle;

  OnboardingData({
    required this.image,
    required this.title,
    required this.subtitle,
  });
}

final onboardingPages = [
  OnboardingData(
    image: "assets/images/park1.png",
    title: "Find Parking Easily",
    subtitle: "Search and locate nearby parking spaces in seconds.",
  ),
  OnboardingData(
    image: "assets/images/park2.png",
    title: "Book Your Slot",
    subtitle: "Reserve your parking slot before you arrive.",
  ),
  OnboardingData(
    image: "assets/images/park3.png",
    title: "Cashless Payments",
    subtitle: "Pay securely using online payment methods.",
  ),
];
