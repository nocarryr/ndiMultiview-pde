class WindowGrid {
  int cols, rows, outWidth, outHeight;
  Point padding;
  HashMap<String,Window> windowMap;
  Window[][] windows;
  HashMap<String,FrameThread> updateThreads;
  
  WindowGrid(int _cols, int _rows, int _outWidth, int _outHeight) {
    cols = _cols;
    rows = _rows;
    padding = new Point(2, 2);
    outWidth = _outWidth;
    outHeight = _outHeight;
    init();
  }
  
  WindowGrid(JSONObject json, int _outWidth, int _outHeight){
    cols = json.getInt("cols");
    rows = json.getInt("rows");
    padding = new Point(0, 0);
    padding.x = json.getFloat("xPadding");
    padding.y = json.getFloat("yPadding");
    outWidth = _outWidth;
    outHeight = _outHeight;
    init();
  }
  
  private void init(){
    windowMap = new HashMap<String,Window>();
    updateThreads = new HashMap<String,FrameThread>();
    windows = new Window[cols][rows];
  }
  
  Box calcBox(int col, int row){
    float w = outWidth / rows;
    float h = outHeight / cols;
    return new Box(w * row, h * col, w, h);
  }
  
  Window addWindow(String name, int col, int row, String ndiSourceName){
    Box winBox = calcBox(col, row);
    Window win = new Window(name, col, row, winBox, padding, ndiSourceName);
    windows[col][row] = win;
    windowMap.put(win.getId(), win);
    return win;
  }
  
  void setOutputSize(int w, int h){
    outWidth = w;
    outHeight = h;
    for (Window win : windowMap.values()){
      win.setBoundingBox(calcBox(win.col, win.row));
    }
  }
  
  void scheduleFrames(){
    for (Window win : windowMap.values()){
      if (win.gettingFrame){
        continue;
      }
      if (!win.isConnected()){
        if (win.canConnect() && !win.connecting){
          win.connectToSource();
        }
      } else {
        FrameThread t;
        if (!win.gettingFrame){
          if (updateThreads.containsKey(win.getId())){
            t = updateThreads.get(win.getId());
            if (t.getState() != Thread.State.TERMINATED){
              continue;
            }
            updateThreads.remove(win.getId());
          }
          t = new FrameThread(win);
          updateThreads.put(win.getId(), t);
          t.start();
        }
      }
    }
  }
  
  void render(PGraphics canvas){
    scheduleFrames();
    for (Window win : windowMap.values()){
      if (win.frameReady){
        win.updateFrame();
      }
      win.render(canvas);
    }
  }
}