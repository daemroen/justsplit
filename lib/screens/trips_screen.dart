import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trip.dart';
import '../services/trip_service.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  // Hardcoded group ID for now
  static const String _groupId = "your_group_id";

  @override
  Widget build(BuildContext context) {
    final tripService = Provider.of<TripService>(context);

    return Scaffold(
      body: StreamBuilder<List<Trip>>(
        stream: tripService.getTrips(_groupId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No trips found for this group.'));
          }

          final trips = snapshot.data!;

          return ListView.builder(
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              return Card(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  title: Text(trip.name),
                  subtitle: Text(
                      '${trip.startDate.toLocal()} - ${trip.endDate.toLocal()}'),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    // Navigate to trip details screen
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateTripDialog(context, tripService),
        tooltip: 'Create Trip',
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showCreateTripDialog(BuildContext context, TripService tripService) {
    final TextEditingController nameController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Trip'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Trip Name'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    startDate = pickedDate;
                  }
                },
                child: const Text('Select Start Date'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: startDate ?? DateTime.now(),
                    firstDate: startDate ?? DateTime.now(),
                    lastDate: DateTime(2100),
                  );
                  if (pickedDate != null) {
                    endDate = pickedDate;
                  }
                },
                child: const Text('Select End Date'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    startDate != null &&
                    endDate != null) {
                  tripService.createTrip(
                      nameController.text, _groupId, startDate!, endDate!);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}
