
class File {
  File(String filePath);
  String get path {
    // nothing
    return "";
  }
  bool existsSync() {return true;}

  void deleteSync() {}

  Future<void> create({required bool recursive}) async {}

  Future<void> writeAsBytes(List<int> content) async {}

  Future readAsBytes() async {}

  Future<String> readAsString() async {return "";}

  void delete() {}
}

class Directory {
  Directory(String filePath);

  Future<void> create({required bool recursive}) async {}
}

class Platform{
  static const String pathSeparator = "";

  static bool get isWindows => false;

  static bool get isLinux => false;

  static bool get isMacOS => false;
}

class IdbFactory{
  Future<Database> open(String s, {required int version, required Null Function(VersionChangeEvent event) onUpgradeNeeded}) async {return Database();}
  
}

class Database {
  transaction(String s, String t) {}
  void createObjectStore(String s, {required bool autoIncrement}) {}
}

IdbFactory? getIdbFactory(){
  return IdbFactory();
}

class VersionChangeEvent {
  Database get database => Database();
}

const String idbModeReadWrite = "";