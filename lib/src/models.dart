class FlatpakApp {
  FlatpakApp({
    required this.id,
    required this.name,
    required this.version,
    required this.origin,
    required this.installation,
    this.iconPath,
  });

  final String id;
  final String name;
  final String version;
  final String origin;
  final String installation;
  String? iconPath;
}

class AppInstance {
  AppInstance({
    required this.appId,
    required this.name,
    required this.home,
    this.privateBus = true,
    this.isolateHome = true,
    this.temporary = false,
    this.pgid,
  });

  final String appId;
  final String name;
  final String home;
  bool privateBus;
  bool isolateHome;
  bool temporary;
  int? pgid;

  Map<String, dynamic> toJson() => {
        'appId': appId,
        'name': name,
        'home': home,
        'privateBus': privateBus,
        'isolateHome': isolateHome,
        'temporary': temporary,
        if (pgid != null) 'pgid': pgid,
      };

  factory AppInstance.fromJson(Map<String, dynamic> json) => AppInstance(
        appId: json['appId'] as String,
        name: json['name'] as String,
        home: json['home'] as String,
        privateBus: json['privateBus'] as bool? ?? true,
        isolateHome: json['isolateHome'] as bool? ?? true,
        temporary: json['temporary'] as bool? ?? false,
        pgid: json['pgid'] as int?,
      );
}
