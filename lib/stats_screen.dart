import 'package:flutter/material.dart';
import 'classes//firestore_stats_manager.dart';

class PlayerStatsScreen extends StatefulWidget {
  const PlayerStatsScreen({super.key});

  @override
  State<PlayerStatsScreen> createState() => _PlayerStatsScreenState();
}

class _PlayerStatsScreenState extends State<PlayerStatsScreen> {
  PlayerStats? stats;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final loadedStats = await FirestoreStatsManager.getPlayerStats();
    setState(() {
      stats = loadedStats;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Statistics'),
        backgroundColor: Colors.green[800],
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadStats,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green[800]!, Colors.green[900]!],
          ),
        ),
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: Colors.white))
            : stats == null
            ? Center(
          child: Text(
            'No stats available',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        )
            : SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              _buildOverviewCard(),
              SizedBox(height: 16),
              _buildPerformanceCard(),
              SizedBox(height: 16),
              _buildChipsCard(),
              SizedBox(height: 16),
              _buildAchievementsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[700]!, Colors.green[800]!],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(Icons.casino, size: 48, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Total Games: ${stats!.totalGamesPlayed}',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Win Rate: ${stats!.winRate.toStringAsFixed(1)}%',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildStatRow('Wins', stats!.totalGamesWon, Colors.green),
            _buildStatRow('Losses', stats!.totalGamesLost, Colors.red),
            _buildStatRow('Pushes', stats!.totalGamesPush, Colors.orange),
            Divider(height: 24),
            _buildStatRow('Blackjacks', stats!.blackjackCount, Colors.amber),
            _buildStatRow('Busts', stats!.bustCount, Colors.red[700]!),
          ],
        ),
      ),
    );
  }

  Widget _buildChipsCard() {
    final netProfit = stats!.netChips;
    final isProfitable = netProfit >= 0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Chips Statistics',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Current Chips'),
                  Text(
                    '${stats!.currentChips}',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildChipStat(
                    'Lifetime Won',
                    stats!.lifetimeChipsWon,
                    Colors.green,
                    Icons.arrow_upward,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildChipStat(
                    'Lifetime Lost',
                    stats!.lifetimeChipsLost,
                    Colors.red,
                    Icons.arrow_downward,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isProfitable ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isProfitable ? Colors.green : Colors.red,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Net Profit/Loss',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${isProfitable ? '+' : ''}$netProfit',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isProfitable ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Records',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _buildRecordTile(
              'Highest Chips',
              stats!.highestChips,
              Icons.trending_up,
              Colors.blue,
            ),
            _buildRecordTile(
              'Biggest Win',
              stats!.biggestWin,
              Icons.celebration,
              Colors.green,
            ),
            _buildRecordTile(
              'Biggest Loss',
              stats!.biggestLoss,
              Icons.trending_down,
              Colors.red,
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey),
                SizedBox(width: 8),
                Text(
                  'Last played: ${_formatDate(stats!.lastPlayed)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, int value, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 8),
              Text(label),
            ],
          ),
          Text(
            '$value',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildChipStat(String label, int value, Color color, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordTile(String label, int value, IconData icon, Color color) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 8),
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.2),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label),
      trailing: Text(
        '$value',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} minutes ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}