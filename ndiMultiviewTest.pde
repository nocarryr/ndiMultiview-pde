import java.util.Map;
import java.nio.ByteBuffer;
import me.walkerknapp.devolay.*;

WindowGrid windowGrid;
//Window[] windows;
//HashMap<String,Window> windowMap;
//int windowCols,windowRows;
DevolayFinder ndiFinder;
//DevolaySource[] ndiSourceList;
HashMap<String,DevolaySource> ndiSources;
PGraphics dstCanvas;

void setup(){
  ndiSources = new HashMap<String,DevolaySource>();
  Devolay.loadLibraries();
  ndiFinder = new DevolayFinder();
  windowGrid = new WindowGrid(4, 4, 0, 0);
}

//void loadWindows(String jsonData){
//  JSONArray json = parseJSONArray(jsonData);
//  if (json == null){
//    return;
//  }
//  for (int i=0; i < json.size(); i++){
//    JSONObject obj = json.getJSONObject(i);
//    String objId = obj.getString("id");
//    if (windowMap.containsKey(objId)){
//      continue;
//    } else {
//      Window win = new Window(obj);
//      windowMap.put(win.getId(), win);
//    }
//  }
//}

void updateNDISources() {
  DevolaySource[] sources;
  ndiSources.clear();
  while ((sources = ndiFinder.getCurrentSources()).length == 0){
    ndiFinder.waitForSources(5000);
  }
  for (int i=0;i<sources.length;i++){
    ndiSources.put(sources[i].getSourceName(), sources[i]);
  }
}

class Point {
  float x, y;
  Point(float _x, float _y){
    x = _x;
    y = _y;
  }
}

class Box {
  Point pos, size;
  Box(float x, float y, float w, float h){
    pos = new Point(x, y);
    size = new Point(w, h);
  }
  Box(Point _pos, Point _size){
    pos = _pos;
    size = _size;
  }
}
  

class WindowGrid {
  int cols, rows, outWidth, outHeight;
  float xSpacing, ySpacing;
  HashMap<String,Window> windowMap;
  Window[][] windows;
  
  WindowGrid(int _cols, int _rows, int _outWidth, int _outHeight) {
    cols = _cols;
    rows = _rows;
    xSpacing = 2;
    ySpacing = 2;
    outWidth = _outWidth;
    outHeight = _outHeight;
  }
  WindowGrid(JSONObject json, int _outWidth, int _outHeight){
    cols = json.getInt("cols");
    rows = json.getInt("rows");
    xSpacing = json.getFloat("xSpacing");
    ySpacing = json.getFloat("ySpacing");
    outWidth = _outWidth;
    outHeight = _outHeight;
  }
  
  Box calcBox(int col, int row){
    float w = outWidth / rows + xSpacing * 2;
    float h = outHeight / cols + xSpacing * 2;
    return new Box(w * row, h * col, w, h);
  }
  
  Window addWindow(String name, int col, int row, String ndiSourceName){
    Box winBox = calcBox(col, row);
    Window win = new Window(name, col, row, winBox, ndiSourceName);
    windows[col][row] = win;
    windowMap.put(win.getId(), win);
    return win;
  }
  
  void setOutputSize(int w, int h){
    outWidth = w;
    outHeight = h;
    for (Window win : windowMap.values()){
      win.bBox = calcBox(win.col, win.row);
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
        if (!win.gettingFrame){
          win.getFrame();
        }
      }
    }
  }
  
  void render(PGraphics canvas){
    float w = outWidth / rows;
    float h = outHeight / cols;
    canvas.stroke(255);
    
    for (int y=0; y < rows; y++){
      canvas.line(0, y * h, outWidth, y * h);
    }
    for (int x=0; x < cols; x++){
      canvas.line(x * w, 0, x * w, outHeight);  
    }
    for (Window win : windowMap.values()){
      win.render(canvas);
    }
  }
  
}

class Window {
  String name = "";
  int col,row;
  //float x,y;
  //float w,h;
  Box bBox;
  String ndiSourceName = ""; 
  //int[] sourceResolution;
  int srcWidth,srcHeight;
  boolean frameReady = false;
  boolean gettingFrame = false;
  boolean connecting = false;
  PGraphics srcCanvas,dstCanvas;
  DevolaySource ndiSource;
  DevolayReceiver ndiReceiver;
  DevolayVideoFrame videoFrame;
  DevolayAudioFrame audioFrame;
  DevolayMetadataFrame metadataFrame;
  DevolayFrameType lastFrameType;
  
  Window(String _name, int _col, int _row, float _x, float _y, float _w, float _h, String _ndiSourceName) {
    name = _name;
    col = _col;
    row = _row;
    bBox = new Box(_x, _y, _w, _h);
    //x = _x;
    //y = _y;
    //w = _w;
    //h = _h;
    ndiSourceName = _ndiSourceName;
    init();
  }
  
  Window(String _name, int _col, int _row, Box _bBox, String _ndiSourceName) {
    name = _name;
    col = _col;
    row = _row;
    bBox = _bBox;
    ndiSourceName = _ndiSourceName;
    init();
  }
  
  Window(JSONObject json, Box _bBox){
    //int _col, _row;
    //float _x, _y, _w, _h;
    //string _ndiSourceName;
    name = json.getString("name");
    col = json.getInt("col");
    row = json.getInt("row");
    //float x = json.getFloat("x");
    //float y = json.getFloat("y");
    //float w = json.getFloat("w");
    //float h = json.getFloat("h");
    //bBox = new Box(x, y, w, h);
    bBox = _bBox;
    ndiSourceName = json.getString("ndiSourceName");
    //this(_col, _row, _x, _y, _w, _h, _ndiSourceName);
    init();
  }
  
  private void init(){
    lastFrameType = DevolayFrameType.NONE;
    srcWidth = 1920;
    srcHeight = 1080;
    srcCanvas = createGraphics(srcWidth, srcHeight);
    connectToSource();
  }
  
  String getId(){
    return String.format("%02d-%02d", col, row);
  }
  
  void connectToSource(){
    disconnect();
    if (!ndiSources.containsKey(ndiSourceName)){
      return;
    }
    connecting = true;
    try {
      //ndiReceiver = new DevolayReceiver();
      ndiSource = ndiSources.get(ndiSourceName);
      //ndiReceiver.connect(ndiSource);
      ndiReceiver = new DevolayReceiver(ndiSource, DevolayReceiver.ColorFormat.RGBX_RGBA, DevolayReceiver.RECEIVE_BANDWIDTH_HIGHEST, true, null); 
      videoFrame = new DevolayVideoFrame();
      audioFrame = new DevolayAudioFrame();
      metadataFrame = new DevolayMetadataFrame();
    } finally {
      connecting = false;
    }
  }
  
  void disconnect(){
    //if (!isConnected()){
    //  return;
    //}
    if (ndiReceiver != null){
      ndiReceiver.close();
      ndiReceiver = null;
    }
    if (videoFrame != null){
      videoFrame.close();
      videoFrame = null;
    }
    if (audioFrame != null){
      audioFrame.close();
      audioFrame = null;
    }
    if (metadataFrame != null){
      metadataFrame.close();
      metadataFrame = null;
    }
    ndiReceiver = null;
    ndiSource = null;
    frameReady = false;
    connecting = false;
  }
  
  boolean isConnected(){
     //if (ndiSourceName.length() == 0){
     //  return false;
     //}
     if (ndiSource == null){
       return false;
     }
     if (ndiReceiver == null){
       return false;
     }
     if (ndiReceiver.getConnectionCount() == 0){
       return false;
     }
     return true;
  }
  
  boolean canConnect(){
    return (ndiSourceName.length() > 0);
  }
  
  DevolayFrameType getFrame() {
    gettingFrame = true;
    DevolayFrameType frameType = DevolayFrameType.NONE;
    try {
      frameType = ndiReceiver.receiveCapture(videoFrame, audioFrame, metadataFrame, 5000);
    //} catch (Exception e) {
      //frameType = DevolayFrameType.NONE;
    } finally {
      gettingFrame = false;
      lastFrameType = frameType;
    }
    //switch (frameType) {
    //  case NONE:
    //    return false;
    //  case VIDEO:
    //    videoFrame.
    //}
    if (frameType == DevolayFrameType.VIDEO){
      int frameWidth = videoFrame.getXResolution();
      int frameHeight = videoFrame.getYResolution();
      if (srcWidth != frameWidth || srcHeight != frameHeight){
        srcWidth = frameWidth;
        srcHeight = frameHeight;
        srcCanvas = createGraphics(srcWidth, srcHeight);
      }
      ByteBuffer framePixels = videoFrame.getData();
      PImage img = new PImage(frameWidth, frameHeight, PConstants.ARGB);
      img.loadPixels();
      
      for (int _y=0; _y < videoFrame.getYResolution(); _y++){
        for (int _x=0; _x < frameWidth; _x++){
          int pixel = _y * frameWidth + _x;
          int byteIndex = pixel * 4;
          int colorValue = 0;
          colorValue &= framePixels.getInt(byteIndex+0) << 16;    // R
          colorValue &= framePixels.getInt(byteIndex+1) << 8;     // G
          colorValue &= framePixels.getInt(byteIndex+2) << 0;     // B
          colorValue &= framePixels.getInt(byteIndex+3) << 24;    // A
          img.pixels[pixel] = colorValue;
        }
      }
      img.updatePixels();
      srcCanvas.beginDraw();
      srcCanvas.image(img, 0, 0);
      srcCanvas.endDraw();
      frameReady = true;
    }
    return frameType;
  }
  
  void render(PGraphics canvas){
    if (frameReady){
      canvas.image(srcCanvas, bBox.pos.x, bBox.pos.y, bBox.size.x, bBox.size.y);
      frameReady = false;
    }
  }
}

class FrameThread extends Thread {
  Window win;
  FrameThread(Window _win){
    win = _win;
  }
  public void run(){
    win.getFrame();
  }
}