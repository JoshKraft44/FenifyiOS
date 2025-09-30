import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../providers/theme_provider.dart';

class ProScreen extends StatefulWidget {
  const ProScreen({Key? key}) : super(key: key);

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  String _selectedPlan = 'yearly'; // Default to yearly for better value

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: context.isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        title: Text(
          'Fenify Pro',
          style: TextStyle(
            color: context.primaryTextColor,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.iconColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Header Section
                Text(
                  'Upgrade to Pro',
                  style: TextStyle(
                    fontSize: context.isDarkMode ? 32 : 28,
                    fontWeight: context.isDarkMode ? FontWeight.w300 : FontWeight.w700,
                    color: context.primaryTextColor,
                    letterSpacing: context.isDarkMode ? 1 : 0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Unlock advanced features and unlimited analysis',
                  style: TextStyle(
                    fontSize: 16,
                    color: context.secondaryTextColor,
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Pro Features
                _buildFeaturesList(),
                
                const SizedBox(height: 32),
                
                // Pricing Plans
                Text(
                  'Choose Your Plan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: context.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Monthly Plan
                _buildPricingPlan(
                  'monthly',
                  'Monthly',
                  _getMonthlyPrice(),
                  'per month',
                  null,
                ),
                
                const SizedBox(height: 12),
                
                // Yearly Plan (Best Value)
                _buildPricingPlan(
                  'yearly',
                  'Yearly',
                  _getYearlyPrice(),
                  'per month',
                  'Best Value - Save ${_getSavingsText()}',
                ),
                
                const SizedBox(height: 32),
                
                // Subscribe Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _handleSubscription,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.columbiaBlue,
                      foregroundColor: AppColors.deepNavy,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Start Free Trial',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Terms and Privacy
                Text(
                  'By continuing, you agree to our Terms of Service and Privacy Policy. Subscription automatically renews unless cancelled.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: context.secondaryTextColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFeaturesList() {
    final features = [
      'Unlimited position analysis',
      'Advanced engine settings',
      'Cloud position sync',
      'Export analysis to PGN',
      'Priority customer support',
      'Ad-free experience',
    ];
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pro Features',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.primaryTextColor,
            ),
          ),
          const SizedBox(height: 16),
          ...features.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7FB069),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    feature,
                    style: TextStyle(
                      color: context.primaryTextColor,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  Widget _buildPricingPlan(String planId, String title, String price, String period, String? badge) {
    final isSelected = _selectedPlan == planId;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlan = planId;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.columbiaBlue.withOpacity(0.1) : context.surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.columbiaBlue : context.borderColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: context.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: price,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: context.primaryTextColor,
                            ),
                          ),
                          TextSpan(
                            text: ' $period',
                            style: TextStyle(
                              fontSize: 14,
                              color: context.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.columbiaBlue : context.secondaryTextColor,
                      width: 2,
                    ),
                    color: isSelected ? AppColors.columbiaBlue : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
            if (badge != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF7FB069),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  String _getMonthlyPrice() {
    // Check locale for currency - TODO: Implement proper localization
    return '\$3.99'; // USD monthly
  }
  
  String _getYearlyPrice() {
    // Check locale for currency - TODO: Implement proper localization
    return '\$2.19'; // USD yearly
  }
  
  String _getSavingsText() {
    return '45%'; // Approximate savings
  }
  
  void _handleSubscription() {
    // TODO: Implement subscription logic
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Subscription functionality coming soon!'),
        backgroundColor: AppColors.columbiaBlue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}