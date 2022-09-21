class WindowGrid {
  int cols, rows, outWidth, outHeight;
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
    boundingBox = new Box(0, 0, outWidth, outHeight);
    fpsText = new TextBox(boundingBox.getBottomCenter(), 100, 16);
    fpsText.bgColor = 0xff404040;
    windowMap = new HashMap<String,Window>();
    //updateThreads = new HashMap<String,FrameThread>();
    windows = new Window[cols][rows];
  }
  
  void updateNdiSources(){
    for (Window win : windowMap.values()){
      win.updateNdiSources();
    }
  }
  
  void close(){
    System.out.println("closing windows...");
    for (Window win : windowMap.values()){
      win.disconnect();
    }
    System.out.println("windows closed");
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
    boundingBox = new Box(0, 0, outWidth, outHeight);
    System.out.println("windowGrid bBox: "+boundingBox.toStr());
    fpsText.setBottomCenter(boundingBox.getBottomCenter());
    for (Window win : windowMap.values()){
      win.setBoundingBox(calcBox(win.col, win.row));
    }
  }
  
  void render(PGraphics canvas){
    try {
      //scheduleFrames();
      for (Window win : windowMap.values()){
        if (!win.isConnected()){
          if (win.canConnect() && !win.connecting){
            win.connectToSource();
          }
        } else {
          if (win.frameReady){
            win.updateFrame();
          } else {
            win.getFrameNoWait();
            if (win.frameReady){
              win.updateFrame();
            }
          }
        }
        win.render(canvas);
      }
      fpsText.text = String.format("%dfps", (int)frameRate);
      fpsText.render(canvas);
      
      ////Box txtBox = new Box(boundingBox.getBottomCenter(), new Point(100, 16));
      //Box txtBox = new Box(0, 0, 100, 16);
      //txtBox.setHCenter(boundingBox.getHCenter());
      //txtBox.setBottom(boundingBox.getBottom());
      ////System.out.println(txtBox.toStr());
      //Alignment align = new Alignment(AlignmentType.CENTER | AlignmentType.BOTTOM);
      ////System.out.println(String.format("align: intValue=%d, name=%s", align.intValue, align.name));
      
      //drawText(canvas, txt, align, txtBox, boundingBox.getBottomCenter(), 80, 255); 
      ////canvas.textFont(windowFont);
      ////canvas.stroke(255);
      ////canvas.fill(255);
      ////canvas.textAlign(CENTER, BOTTOM);
      ////canvas.text(String.format("%dfps", (int)frameRate), boundingBox.getHCenter(), boundingBox.getBottom());
    } catch(Exception e){
      close();
      e.printStackTrace();
      throw(e);
    }
  }
}
