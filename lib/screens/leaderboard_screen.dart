import 'package:flutter/material.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leaderboards'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Mileage'),
              Tab(text: 'PvP Kills/Wins'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildList([
              'All-Time Mileage',
              'Yearly Mileage',
              'Monthly Mileage',
              'Weekly Mileage',
            ]),
            _buildList([
              'All-Time PvP Wins',
              'Yearly PvP Wins',
              'Monthly PvP Wins',
              'Weekly PvP Wins',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<String> categories) {
    return ListView.builder(
      itemCount: categories.length,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.all(8),
          child: ListTile(
            title: Text(categories[index]),
            trailing: const Icon(Icons.arrow_forward_ios),
          ),
        );
      },
    );
  }
}
