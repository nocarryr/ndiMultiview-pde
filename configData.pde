import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.InvocationTargetException;

class ConfigBase{
  HashMap<String,String> _fieldMap;
  
  ConfigBase(JSONObject json){
    _getFieldMap();
    setValuesFromJSON(json);
  }
  
  ConfigBase(){
    _getFieldMap();
  }
  
  void setValuesFromJSON(JSONObject json){
    for (Map.Entry<String,String> entry : _fieldMap.entrySet()){
      String className = entry.getValue();
      boolean isarr = false;
      if (className.endsWith("[]")){
        isarr = true;
        className = className.substring(0, className.length());
      }
      //Class<?> c;
      //if (className == "int"){
      //  c = Class.forName("int");
      //}
      //try {
      //  c = Class.forName(entry.getKey());
      //} catch(ClassNotFoundException e){
      //  e.printStackTrace();
      //  continue;
      //}
      
      
      Object value = getValueFromJSON(className, isarr, entry.getKey(), json);
      try {
        Field f = this.getClass().getDeclaredField(entry.getKey());
        try {
          f.set(this, value);
        } catch(IllegalAccessException e){
          e.printStackTrace();
          throw(new Error(entry.getKey()));
        }
      } catch(NoSuchFieldException e){
        e.printStackTrace();
        throw(new Error(String.format("key=%s, cls=%s, value=%s", entry.getKey(), this.getClass(), value)));
      }
    }
  }
  
  Object getValueFromJSON(String className, boolean isarr, String fieldName, JSONObject json){
    //try {
      
    Object value;
    if (className == "int"){
      //f.setInt(this, json.getInt(fieldName));
      value = json.getInt(fieldName);
    } else if (className == "boolean"){
      //f.setBoolean(this, json.getBoolean(fieldName));
      value = json.getBoolean(fieldName);
    } else if (className == "String"){
      value = json.getString(fieldName);
    } else if (className == "Point"){
      value = new Point(json.getJSONObject(fieldName));
      //f.set(this, p);
    } else if (className == "Box"){
      value = new Box(json.getJSONObject(fieldName));
    } else {
      throw(new Error(String.format("could not serialize field '%s', className='%s', cls=%s", fieldName, className, this.getClass())));
    }
    return value;
  }
  
  JSONObject serialize(){
    JSONObject json = new JSONObject();
    for (Map.Entry<String,String> entry : _fieldMap.entrySet()){
      String className = entry.getValue();
      boolean isarr = false;
      if (className.endsWith("[]")){
        isarr = true;
        className = className.substring(0, className.length());
      }
      Object value;
      try {
        Field f = this.getClass().getDeclaredField(entry.getKey());
        try {
          value = f.get(this);
        } catch(IllegalAccessException e){
          e.printStackTrace();
          continue;
        }
      } catch(NoSuchFieldException e){
        e.printStackTrace();
        throw(new Error(String.format("key=%s, cls=%s", entry.getKey(), this.getClass())));
      }
      setJSONValue(className, isarr, entry.getKey(), value, json);
    }
    return json;
  }
  
  void setJSONValue(String className, boolean isarr, String fieldName, Object value, JSONObject json){
    if (value instanceof ConfigBase){
      try {
        Class c = value.getClass();
        Method m = c.getMethod("serialize");
        Object _json = m.invoke(value);
        json.setJSONObject(fieldName, (JSONObject)_json);
        //if (_json instanceof JSONArray){
        //  json.setJSONArray(fieldName, (JSONArray)_json);
        //} else {
        //  json.setJSONObject(fieldName, (JSONObject)_json);
        //}
      } catch(NoSuchMethodException e){
        e.printStackTrace();
        throw(new Error(String.format("key=%s, cls=%s", fieldName, this.getClass())));
      } catch(IllegalAccessException e){
        e.printStackTrace();
        throw(new Error(String.format("key=%s, cls=%s", fieldName, this.getClass())));
      } catch(InvocationTargetException e){
        e.printStackTrace();
        throw(new Error(String.format("key=%s, cls=%s", fieldName, this.getClass())));
      }
    } else if (className == "int"){
      json.setInt(fieldName, (int)value);
    } else if (className == "boolean"){
      json.setBoolean(fieldName, (boolean)value);
    } else if (className == "String"){
      json.setString(fieldName, (String)value);
    } else if (className == "Point"){
      Point p = (Point)value;
      json.setJSONObject(fieldName, p.serialize());
    } else if (className == "Box"){
      Box b = (Box)value;
      json.setJSONObject(fieldName, b.serialize());
    } else {
      throw(new Error(String.format("could not set value '%s' for field '%s' (className='%s'), cls=%s", value, fieldName, className, this.getClass())));
    }
  }
  
  void _getFieldMap(){
    _fieldMap = new HashMap<String,String>();
  }
}



class Config extends ConfigBase {
  AppConfig app;
  GridConfig windowGrid;
  
  Config(JSONObject json){ super(json); }
  Config(){
    super();
    app = new AppConfig();
    windowGrid = new GridConfig();
  }
  
  void update(MultiviewApplet applet){
    app.update(applet);
    windowGrid.update(applet);
  }
  
  Object getValueFromJSON(String className, boolean isarr, String fieldName, JSONObject json){
    if (className == "AppConfig"){
      return new AppConfig(json.getJSONObject(fieldName));
    } else if (className == "GridConfig"){
      return new GridConfig(json.getJSONObject(fieldName));
    } else {
      return super.getValueFromJSON(className, isarr, fieldName, json);
    }
  }
  //void setJSONValue(String className, boolean isarr, String fieldName, Object value, JSONObject json){
  //  if (className == "AppConfig"){
  //    AppConfig c = (AppConfig)value;
  //    json.setJSONObject(fieldName, c.
  
  void _getFieldMap(){
    _fieldMap = new HashMap<String,String>();
    _fieldMap.put("app", "AppConfig");
    _fieldMap.put("windowGrid", "GridConfig");
  }
}

class AppConfig extends ConfigBase {
  boolean fullScreen;
  int displayNumber;
  Point canvasSize;
  Box windowBounds;
  
  AppConfig(JSONObject json){ super(json); }
  AppConfig(){
    super();
    fullScreen = false;
    displayNumber = -1;
    canvasSize = new Point(640, 360);
    windowBounds = new Box(0, 0, 640, 360);
  }
  
  void update(MultiviewApplet applet){
    fullScreen = applet.isFullScreen;
    canvasSize = new Point(applet.width, applet.height);
    windowBounds = applet.getWindowDims();
  }
  
  void _getFieldMap(){
    _fieldMap = new HashMap<String,String>();
    _fieldMap.put("fullScreen", "boolean");
    _fieldMap.put("displayNumber", "int");
    _fieldMap.put("canvasSize", "Point");
    _fieldMap.put("windowBounds", "Box");
  }
}

class GridConfig extends ConfigBase {
  int cols, rows;
  Point padding;
  Point outputSize;
  WindowConfig[] windows;
  
  GridConfig(JSONObject json){ super(json); }
  GridConfig(){
    super();
    cols = 2;
    rows = 2;
    padding = new Point(2, 2);
    outputSize = new Point(640, 360);
    windows = new WindowConfig[4];
    String windowNames[] = {"A", "B", "C", "D"};
    int i = 0;
    for (int x=0; x<cols; x++){
      for (int y=0; y<rows; y++){
        WindowConfig w = new WindowConfig();
        w.col = x;
        w.row = y;
        w.name = windowNames[i];
      }
    }
    //update(mvApp.windowGrid);
  }
  //GridConfig(WindowGrid grid){
  //  super();
  //  setValuesFromJSON(grid.serialize());
  //}
  void update(MultiviewApplet applet){
    update(applet.windowGrid);
  }
  
  void update(WindowGrid grid){
    setValuesFromJSON(grid.serialize());
  }
  
  Object getValueFromJSON(String className, boolean isarr, String fieldName, JSONObject json){
    if (className.startsWith("WindowConfig")){
      JSONArray jsonArr = json.getJSONArray(fieldName);
      WindowConfig[] w = new WindowConfig[jsonArr.size()];
      for (int i=0; i<jsonArr.size(); i++){
        w[i] = new WindowConfig(jsonArr.getJSONObject(i));
      }
      return w;
    } else {
      return super.getValueFromJSON(className, isarr, fieldName, json);
    }
  }
  
  void setJSONValue(String className, boolean isarr, String fieldName, Object value, JSONObject json){
    if (className.startsWith("WindowConfig")){
      JSONArray _json = new JSONArray();
      for (int i=0; i<windows.length; i++){
        _json.append(windows[i].serialize());
      }
      json.setJSONArray(fieldName, _json);
    } else {
      super.setJSONValue(className, isarr, fieldName, value, json);
    }
  }
  
  void _getFieldMap(){
    _fieldMap = new HashMap<String,String>();
    _fieldMap.put("cols", "int");
    _fieldMap.put("rows", "int");
    _fieldMap.put("padding", "Point");
    _fieldMap.put("outputSize", "Point");
    _fieldMap.put("windows", "WindowConfig[]");
  }
}

//class WindowConfigs extends ConfigBase {
//  WindowConfig[] windows;
  
//}
class WindowConfig extends ConfigBase {
  String name, ndiSourceName;
  int col, row;
  
  WindowConfig(JSONObject json){ super(json); }
  WindowConfig(){
    super();
    name = "";
    ndiSourceName = "";
    col = 0;
    row = 0;
  }
  
  void _getFieldMap(){
    _fieldMap = new HashMap<String,String>();
    _fieldMap.put("name", "String");
    _fieldMap.put("ndiSourceName", "String");
    _fieldMap.put("col", "int");
    _fieldMap.put("row", "int");
  }
}
