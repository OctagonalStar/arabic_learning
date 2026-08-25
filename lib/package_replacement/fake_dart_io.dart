
class File {
  File(String filePath);
  String get path {
    // nothing
    return "";
  }
  bool existsSync() {return false;}

  void deleteSync() {}

  Future<void> create({required bool recursive}) async {}

  Future<void> writeAsBytes(List<int> content) async {}

  Future readAsBytes() async {}

  Future<String> readAsString() async {return "";}

  void delete() {}
}

class Directory {
  String path;

  Directory(this.path);

  Future<void> create({required bool recursive}) async {}
}

class Platform{
  static const String pathSeparator = "";

  static bool get isWindows => false;

  static bool get isLinux => false;

  static bool get isMacOS => false;

  static bool get isAndroid => false;

  static String get localHostname => "Web";

  static String get operatingSystem => "Web";

  static String get operatingSystemVersion => "Web";

  static Map<String, String> get environment => {};
}

class IdbFactory{
  Future<Database> open(String s, {required int version, required Null Function(VersionChangeEvent event) onUpgradeNeeded}) async {return Database();}
  
}

class Database {
  dynamic transaction(String s, String t) {}
  void createObjectStore(String s, {required bool autoIncrement}) {}
}

IdbFactory? getIdbFactory(){
  return IdbFactory();
}

class VersionChangeEvent {
  Database get database => Database();
}

const String idbModeReadWrite = "";