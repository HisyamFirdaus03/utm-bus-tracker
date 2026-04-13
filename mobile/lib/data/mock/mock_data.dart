// ============================================================
// MOCK DATA - Delete this file when integrating with Firebase
// ============================================================

import '../../models/models.dart';

class MockData {
  // UTM campus coordinates (approximate center)
  static const double utmCenterLat = 1.5592;
  static const double utmCenterLng = 103.6375;

  static const List<AppUser> users = [
    AppUser(
      id: 'student-1',
      name: 'Ahmad bin Ibrahim',
      email: 'student@utm.my',
      role: UserRole.student,
      matricNumber: 'A22EC0001',
    ),
    AppUser(
      id: 'driver-1',
      name: 'Pak Razak',
      email: 'driver@utm.my',
      role: UserRole.driver,
      assignedBusId: 'bus-1',
    ),
    AppUser(
      id: 'admin-1',
      name: 'Dr. Siti Admin',
      email: 'admin@utm.my',
      role: UserRole.admin,
    ),
  ];

  static final List<BusRoute> routes = [
    BusRoute(
      id: 'route-1',
      name: 'Route A',
      description: 'Main Campus Loop - Kolej Rahman Putra to Faculty Area',
      color: '#4CAF50',
      stops: [
        const BusStop(
          id: 'stop-1',
          name: 'Kolej Rahman Putra',
          latitude: 1.5625,
          longitude: 103.6472,
          order: 1,
        ),
        const BusStop(
          id: 'stop-2',
          name: 'Dewan Sultan Iskandar',
          latitude: 1.5607,
          longitude: 103.6437,
          order: 2,
        ),
        const BusStop(
          id: 'stop-3',
          name: 'Fakulti Komputeran',
          latitude: 1.5590,
          longitude: 103.6380,
          order: 3,
        ),
        const BusStop(
          id: 'stop-4',
          name: 'Perpustakaan Sultanah Zanariah',
          latitude: 1.5605,
          longitude: 103.6350,
          order: 4,
        ),
        const BusStop(
          id: 'stop-5',
          name: 'Arked Meranti',
          latitude: 1.5575,
          longitude: 103.6365,
          order: 5,
        ),
      ],
    ),
    BusRoute(
      id: 'route-2',
      name: 'Route B',
      description: 'Kolej Tun Fatimah to Faculty of Engineering',
      color: '#2196F3',
      stops: [
        const BusStop(
          id: 'stop-6',
          name: 'Kolej Tun Fatimah',
          latitude: 1.5537,
          longitude: 103.6425,
          order: 1,
        ),
        const BusStop(
          id: 'stop-7',
          name: 'Fakulti Kejuruteraan Elektrik',
          latitude: 1.5560,
          longitude: 103.6390,
          order: 2,
        ),
        const BusStop(
          id: 'stop-8',
          name: 'Fakulti Kejuruteraan Mekanikal',
          latitude: 1.5572,
          longitude: 103.6355,
          order: 3,
        ),
        const BusStop(
          id: 'stop-9',
          name: 'Pusat Kesihatan UTM',
          latitude: 1.5600,
          longitude: 103.6410,
          order: 4,
        ),
      ],
    ),
    BusRoute(
      id: 'route-3',
      name: 'Route C',
      description: 'Evening Route - Residential to Main Gate',
      color: '#FF9800',
      stops: [
        const BusStop(
          id: 'stop-10',
          name: 'Kolej Datin Seri Endon',
          latitude: 1.5530,
          longitude: 103.6460,
          order: 1,
        ),
        const BusStop(
          id: 'stop-11',
          name: 'Kolej Tun Razak',
          latitude: 1.5555,
          longitude: 103.6445,
          order: 2,
        ),
        const BusStop(
          id: 'stop-12',
          name: 'Main Gate UTM',
          latitude: 1.5635,
          longitude: 103.6480,
          order: 3,
        ),
      ],
    ),
  ];

  static final List<Bus> buses = [
    Bus(
      id: 'bus-1',
      plateNumber: 'JQR 1234',
      routeId: 'route-1',
      status: BusStatus.active,
      capacity: 40,
      latitude: 1.5610,
      longitude: 103.6450,
      speed: 25.0,
      lastUpdated: DateTime.now(),
    ),
    Bus(
      id: 'bus-2',
      plateNumber: 'JQR 5678',
      routeId: 'route-1',
      status: BusStatus.active,
      capacity: 40,
      latitude: 1.5585,
      longitude: 103.6370,
      speed: 18.0,
      lastUpdated: DateTime.now(),
    ),
    Bus(
      id: 'bus-3',
      plateNumber: 'JQR 9012',
      routeId: 'route-2',
      status: BusStatus.active,
      capacity: 35,
      latitude: 1.5550,
      longitude: 103.6400,
      speed: 30.0,
      lastUpdated: DateTime.now(),
    ),
    Bus(
      id: 'bus-4',
      plateNumber: 'JQR 3456',
      routeId: 'route-3',
      status: BusStatus.inactive,
      capacity: 40,
    ),
  ];
}
