import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24.0),
      children: [
        Text(
          'Welcome Back!',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        const SizedBox(height: 20),
        Text(
          'Here\'s a look at your recent activity.',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: () {
            Navigator.pushNamed(context, '/receipt_scanner');
          },
          child: const Text('Scan Receipt'),
        ),
        const SizedBox(height: 30),
        _buildRecentActivity(context),
      ],
    );
  }

  Widget _buildRecentActivity(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Trips',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const Icon(Icons.flight_takeoff),
            title: const Text('Trip to Bali'),
            subtitle: const Text('You spent \$540'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () {},
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Recent Expenses',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long),
            title: const Text('Dinner at a local restaurant'),
            subtitle: const Text('You paid \$45'),
            trailing: const Text('View Details'),
            onTap: () {},
          ),
        ),
      ],
    );
  }
}
