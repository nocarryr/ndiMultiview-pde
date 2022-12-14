
class WindowGrid {
  int cols, rows, outWidth, outHeight;
  Point outputSize;
  Point padding;
  Box boundingBox;
  HashMap<String,Window> windowMap;
  Window[][] windows;
  TextBox fpsText;
  //HashMap<String,FrameThread> updateThreads;

  WindowGrid(int _cols, int _rows, int _outWidth, int _outHeight) {
    cols = _cols;
    rows = _rows;
    padding = new Point(2, 2);
    outWidth = _outWidth;
    outHeight = _outHeight;
    outputSize = new Point(outWidth, outHeight);
    buildDefaultWindows();
    init();
  }

  WindowGrid(JSONObject json, int _outWidth, int _outHeight){
    cols = json.getInt("cols");
    rows = json.getInt("rows");
    padding = new Point(json.getJSONObject("padding"));
    outWidth = _outWidth;
    outHeight = _outHeight;
    outputSize = new Point(outWidth, outHeight);
    init();
    JSONArray winJson = json.getJSONArray("windows");
    for (int i=0; i<winJson.size(); i++){
      addWindow(winJson.getJSONObject(i));
    }
  }

  WindowGrid(GridConfig config){
    cols = config.cols;
    rows = config.rows;
    padding = config.padding.copy();
    outputSize = config.outputSize.copy();
    outWidth = (int)outputSize.x;
    outHeight = (int)outputSize.y;
    init();
    for (int i=0; i<config.windows.length; i++){
      addWindow(config.windows[i]);
    }
  }

  private void buildDefaultWindows(){
    int i = 0;
    for (int x=0; x < cols; x++){
      for (int y=0; y < rows; y++){
        addWindow(String.format("%d", i), x, y, "");
      }
    }
  }

  private void init(){
    boundingBox = new Box(0, 0, outWidth, outHeight);
    fpsText = new TextBox(boundingBox.getPos(), 100, 20);
    fpsText.bgColor = 0xff404040;
    fpsText.setBottomCenter(boundingBox.getBottomCenter());
    fpsText.align(CENTER, CENTER);
    //fpsText.setTextPos(fpsText.getCenter());
    //fpsText.setTextPos(fpsText.getHCenter(), fpsText.getY() + 10);
    System.out.println("windowGrid bBox: "+boundingBox.toStr());
    windowMap = new HashMap<String,Window>();
    //updateThreads = new HashMap<String,FrameThread>();
    windows = new Window[cols][rows];
  }

  JSONObject serialize(){
    JSONObject json = new JSONObject();
    json.setInt("cols", cols);
    json.setInt("rows", rows);
    json.setJSONObject("padding", padding.serialize());
    json.setJSONObject("outputSize", outputSize.serialize());
    JSONArray winJson = new JSONArray();
    for (Window win : windowMap.values()){
      winJson.append(win.serialize());
    }
    json.setJSONArray("windows", winJson);
    return json;
  }

  void updateNdiSources(){
    for (Window win : windowMap.values()){
      win.updateNdiSources();
    }
  }

  void close(){
    System.out.println("closing windows...");
    for (Window win : windowMap.values()){
      win.close();
    }
    System.out.println("windows closed");
  }

  Box calcBox(int col, int row){
    //if (outWidth == 0 || outHeight == 0){
    //  return new Box(0, 0, 0, 0);
    //}
    float w = outWidth / rows;
    float h = outHeight / cols;
    return new Box(w * row, h * col, w, h);
  }

  Window addWindow(String name, int col, int row, String ndiSourceName){
    String winId = String.format("%02d-%02d", col, row);
    assert !windowMap.containsKey(winId);
    Box winBox = calcBox(col, row);
    Window win = new Window(name, col, row, winBox, padding, ndiSourceName);
    windows[col][row] = win;
    windowMap.put(win.getId(), win);
    return win;
  }

  Window addWindow(JSONObject json){
    int col = json.getInt("col"), row = json.getInt("row");
    String winId = String.format("%02d-%02d", col, row);
    assert !windowMap.containsKey(winId);
    Box winBox = calcBox(col, row);
    Window win = new Window(json, winBox, padding);
    windows[col][row] = win;
    windowMap.put(win.getId(), win);
    return win;
  }

  Window addWindow(WindowConfig config){
    int col = config.col, row = config.row;
    String winId = String.format("%02d-%02d", col, row);
    assert !windowMap.containsKey(winId);
    Box winBox = calcBox(col, row);
    Window win = new Window(config, winBox, padding);
    windows[col][row] = win;
    windowMap.put(win.getId(), win);
    return win;
  }

  void setOutputSize(int w, int h){
    outWidth = w;
    outHeight = h;
    outputSize.x = w;
    outputSize.y = h;
    boundingBox = new Box(0, 0, outWidth, outHeight);
    System.out.println("windowGrid bBox: "+boundingBox.toStr());
    fpsText.setBottomCenter(boundingBox.getBottomCenter());
    //padding.x = Math.round(w / 200.0);
    //padding.y = Math.round(h / 200.0);
    for (Window win : windowMap.values()){
      win.setBoundingBox(calcBox(win.col, win.row));
    }
  }

  void setOutputSize(Point s){
    setOutputSize((int)s.x, (int)s.y);
  }

  void render(PGraphics canvas){
    try {
      synchronized(mvApp.ndiSourceLock){
        for (Window win : windowMap.values()){
          if (!win.isConnected()){
            if (win.canConnect()){
              win.connectToSource();
            }
          }
        }
      }
      for (Window win : windowMap.values()){
        win.render(canvas);
      }
      fpsText.text = String.format("%dfps", (int)mvApp.frameRate);
      fpsText.render(canvas);
    } catch(Exception e){
      close();
      e.printStackTrace();
      throw(e);
    }
  }
}
