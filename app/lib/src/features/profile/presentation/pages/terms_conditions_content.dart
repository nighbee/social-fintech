class TermsSectionData {
  const TermsSectionData({
    required this.title,
    required this.summary,
    required this.paragraphs,
    this.bullets = const <String>[],
  });

  final String title;
  final String summary;
  final List<String> paragraphs;
  final List<String> bullets;
}

const String kTermsLastUpdated = 'Last updated: February 17, 2026';

const List<TermsSectionData> kTermsSections = <TermsSectionData>[
  TermsSectionData(
    title: '1. Introduction',
    summary:
        'In short: Welcome to Social-Fintech! By using our app, you agree to these rules.',
    paragraphs: <String>[
      'Welcome to Social-Fintech ("Company", "we", "our", "us"). These Terms and Conditions ("Terms", "Agreement") govern your use of our mobile application (the "App") and services operated by Social-Fintech.',
      'By accessing or using the App, you agree to be bound by these Terms. If you disagree with any part of the terms, then you may not access the Service.',
    ],
  ),
  TermsSectionData(
    title: '2. Accounts',
    summary:
        'In short: Keep your password safe. You are responsible for what happens on your account.',
    paragraphs: <String>[
      'When you create an account with us, you must provide information that is accurate, complete, and current at all times. Failure to do so constitutes a breach of the Terms, which may result in immediate termination of your account on our Service.',
      'You are responsible for safeguarding the password that you use to access the Service and for any activities or actions under your password.',
    ],
  ),
  TermsSectionData(
    title: '3. Use of the App (User Conduct)',
    summary:
        'In short: Be nice. Don\'t break the law, don\'t hack us, and don\'t spam.',
    paragraphs: <String>[
      'You agree not to use the App for any purpose that is illegal or prohibited by these Terms. You agree not to:',
    ],
    bullets: <String>[
      'Use the App in any way that violates any applicable national or international law.',
      'Attempt to decipher, decompile, disassemble, or reverse engineer any of the software comprising the App.',
      'Harass, intimidate, or threaten any of our employees or agents engaged in providing any portion of the App to you.',
      'Upload or transmit viruses, Trojan horses, or other harmful material.',
    ],
  ),
  TermsSectionData(
    title: '4. Intellectual Property',
    summary:
        'In short: We own the Social-Fintech logo, design, and code. You own your personal data.',
    paragraphs: <String>[
      'The Service and its original content (excluding Content provided by users), features, and functionality are and will remain the exclusive property of Social-Fintech and its licensors. The Service is protected by copyright, trademark, and other laws of both [Your Country] and foreign countries. Our trademarks and trade dress may not be used in connection with any product or service without the prior written consent of Social-Fintech.',
    ],
  ),
  TermsSectionData(
    title: '5. Subscriptions and Payments (If applicable)',
    summary:
        'In short: If you buy a premium plan, here is how billing works.',
    paragraphs: <String>[
      'Some parts of the Service are billed on a subscription basis ("Subscription(s)"). You will be billed in advance on a recurring and periodic basis (such as daily, weekly, monthly, or annually), depending on the type of subscription plan you select when purchasing the Subscription.',
      'Free Trial: We may offer a Subscription with a free trial for a limited period of time.',
      'Cancellation: You may cancel your Subscription renewal either through your Account settings page or by contacting us.',
    ],
  ),
  TermsSectionData(
    title: '6. Links To Other Web Sites',
    summary:
        'In short: If you click a link to another site, we are not responsible for what happens there.',
    paragraphs: <String>[
      'Our Service may contain links to third-party web sites or services that are not owned or controlled by Social-Fintech. Social-Fintech has no control over, and assumes no responsibility for, the content, privacy policies, or practices of any third-party web sites or services.',
    ],
  ),
  TermsSectionData(
    title: '7. Termination',
    summary: 'In short: We can ban you if you break these rules.',
    paragraphs: <String>[
      'We may terminate or suspend your account immediately, without prior notice or liability, for any reason whatsoever, including without limitation if you breach the Terms. Upon termination, your right to use the Service will immediately cease.',
    ],
  ),
  TermsSectionData(
    title: '8. Limitation of Liability',
    summary:
        'In short: If something goes wrong with the app, we are not liable for lost profits or data damages.',
    paragraphs: <String>[
      'In no event shall Social-Fintech, nor its directors, employees, partners, agents, suppliers, or affiliates, be liable for any indirect, incidental, special, consequential or punitive damages, including without limitation, loss of profits, data, use, goodwill, or other intangible losses, resulting from your access to or use of or inability to access or use the Service.',
    ],
  ),
  TermsSectionData(
    title: '9. Disclaimer',
    summary:
        'In short: The app is provided "as is". We don\'t promise it will be perfect or bug-free forever.',
    paragraphs: <String>[
      'Your use of the Service is at your sole risk. The Service is provided on an "AS IS" and "AS AVAILABLE" basis. The Service is provided without warranties of any kind, whether express or implied, including, but not limited to, implied warranties of merchantability, fitness for a particular purpose, non-infringement, or course of performance.',
    ],
  ),
  TermsSectionData(
    title: '10. Governing Law',
    summary:
        'In short: Any legal disputes will be handled in [Your Country/State].',
    paragraphs: <String>[
      'These Terms shall be governed and construed in accordance with the laws of [Your Country/State, e.g., Kazakhstan or Delaware, USA], without regard to its conflict of law provisions.',
    ],
  ),
  TermsSectionData(
    title: '11. Changes to Terms',
    summary:
        'In short: We might change these rules later. If we do, we will let you know.',
    paragraphs: <String>[
      'We reserve the right, at our sole discretion, to modify or replace these Terms at any time. If a revision is material, we will try to provide at least 30 days\' notice prior to any new terms taking effect. What constitutes a material change will be determined at our sole discretion.',
    ],
  ),
];
