import 'package:flutter/material.dart';
import 'connect.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int currentPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: const [
            Column(
              children: [
                Text(
                  'deltamix - home',
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentPageIndex,
        onDestinationSelected: (int index) {
          if (index == 1) {
            Navigator.push(
              context, 
              MaterialPageRoute(builder: (context) => const Connect()),
            );
          } else {
            setState(() {
              currentPageIndex = index;
            });
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore),
            label: 'Postos',
          ),
          NavigationDestination(
            icon: Icon(Icons.add),
            label: 'Novo Veículo',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.person),
            icon: Icon(Icons.person_outline),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}