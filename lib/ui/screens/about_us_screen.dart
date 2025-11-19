import 'package:flutter/material.dart';

class OutletProfile {
  const OutletProfile({
    required this.name,
    required this.description,
    required this.highlights,
    required this.addressLines,
    required this.phone,
    required this.email,
    this.whatsApp,
    this.website,
    required this.operatingHours,
  });

  final String name;
  final String description;
  final List<String> highlights;
  final List<String> addressLines;
  final String phone;
  final String email;
  final String? whatsApp;
  final String? website;
  final String operatingHours;

  String get formattedAddress => addressLines.join('\n');
}

// Update these values whenever outlet details change.
const OutletProfile _profile = OutletProfile(
  name: 'Chaimates Outlet',
  description:
      'Chaimates serves handcrafted tea, coffee, and quick bites for offices and neighbourhoods. '
      'We prepare every order fresh, focusing on consistent taste and quality ingredients.',
  highlights: <String>[
    'Signature handcrafted beverages',
    'Corporate pantry partnerships',
    'Bulk and party catering support',
  ],
  addressLines: <String>[
    'Plot 23, Tower A, Tech Park Road',
    'Sector 135, Noida, Uttar Pradesh 201304',
  ],
  phone: '+91 98765 43210',
  email: 'support@chaimates.com',
  whatsApp: '+91 98765 43210',
  website: 'https://chaimates.com',
  operatingHours: 'Monday – Sunday · 9:00 AM – 11:00 PM',
);

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About us'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _profile.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _profile.description,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_profile.highlights.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _profile.highlights
                          .map(
                            (highlight) => Chip(
                              label: Text(highlight),
                              backgroundColor: primary.withOpacity(0.08),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.place_outlined,
                  title: 'Address',
                  value: _profile.formattedAddress,
                ),
                const Divider(height: 0),
                _InfoTile(
                  icon: Icons.call_outlined,
                  title: 'Phone',
                  value: _profile.phone,
                ),
                if (_profile.whatsApp != null) ...[
                  const Divider(height: 0),
                  _InfoTile(
                    icon: Icons.chat_outlined,
                    title: 'WhatsApp',
                    value: _profile.whatsApp!,
                  ),
                ],
                const Divider(height: 0),
                _InfoTile(
                  icon: Icons.email_outlined,
                  title: 'Email',
                  value: _profile.email,
                ),
                if (_profile.website != null) ...[
                  const Divider(height: 0),
                  _InfoTile(
                    icon: Icons.travel_explore_outlined,
                    title: 'Website',
                    value: _profile.website!,
                  ),
                ],
                const Divider(height: 0),
                _InfoTile(
                  icon: Icons.access_time,
                  title: 'Operating hours',
                  value: _profile.operatingHours,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: SelectableText(value),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    );
  }
}
