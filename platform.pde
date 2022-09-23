import java.io.File;

enum Platform {
 LINUX, MAC, WINDOWS, UNKNOWN;
}

Platform getPlatform(){
  if (System.getProperty("os.name").indexOf("Mac") != -1){
    return Platform.MAC;
  } else if (System.getProperty("os.name").indexOf("Windows") != -1){
    return Platform.WINDOWS;
  } else if (System.getProperty("os.name").indexOf("Linux") != -1){
    return Platform.LINUX;
  }
  return Platform.UNKNOWN;
}

String joinPath(StringList args){
  StringList parts = new StringList();
  //for (int i=0; i<args.size(); i++){
  for (String s : args){
    //String s = args[i];
    if (s.contains("/")){
      for (String _s : s.split("/")){
        if (_s.length() > 0){
          parts.append(_s);
        }
      }
    } else if (s.length() > 0){
      parts.append(s);
    }
  }
  return parts.join("/");
}
File getUserConfigDir(){
  StringList dirNames = new StringList();
  dirNames.append(System.getProperty("user.home"));
  //Path p;
  switch(getPlatform()){
    case LINUX:
      //dirNames.append(System.getenv("HOME"));
      dirNames.append(".config");
    case MAC:
      //dirNames.append(System.getenv("HOME"));
      dirNames.append("Library");
      dirNames.append("Preferences");
    case WINDOWS:
      dirNames.clear();
      dirNames.append(System.getenv("LOCALAPPDATA"));
    case UNKNOWN:
    
  }
  return new File(joinPath(dirNames), "ndiMultiview");
}

File getConfigFile(){
  //String userHome = System.getProperty("user.home");
  //assert userHome != null;
  //return new File("config.json");
  File confDir = getUserConfigDir();
  if (!confDir.exists()){
    confDir.mkdir();
  }
  return new File(confDir, "config.json");
}
