import 'package:flutter/material.dart';

import '../models/group.dart';

class GroupDetailsScreen extends StatelessWidget {
  final Group group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(group.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Members', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: group.members.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(group.members[index]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
