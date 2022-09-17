class Window {
  String name = "";
  int col,row;
  Point padding;
  Box boundingBox, frameBox;
  String ndiSourceName = ""; 
  int srcWidth,srcHeight;
  boolean frameReady = false;
  boolean gettingFrame = false;
  boolean connecting = false;
  boolean canvasReady = false;
  PGraphics srcCanvas,dstCanvas;
  DevolaySource ndiSource;
  DevolayReceiver ndiReceiver;
  DevolayVideoFrame videoFrame;
  DevolayAudioFrame audioFrame;
  DevolayMetadataFrame metadataFrame;
  DevolayFrameType lastFrameType;
  
  Window(String _name, int _col, int _row, float _x, float _y, float _w, float _h, Point _padding, String _ndiSourceName) {
    name = _name;
    col = _col;
    row = _row;
    padding = _padding;
    boundingBox = new Box(_x, _y, _w, _h);
    ndiSourceName = _ndiSourceName;
    init();
  }
  
  Window(String _name, int _col, int _row, Box _boundingBox, Point _padding, String _ndiSourceName) {
    name = _name;
    col = _col;
    row = _row;
    padding = _padding;
    boundingBox = _boundingBox;
    ndiSourceName = _ndiSourceName;
    init();
  }
  
  Window(JSONObject json, Box _boundingBox, Point _padding){
    name = json.getString("name");
    col = json.getInt("col");
    row = json.getInt("row");
    padding = _padding;
    boundingBox = _boundingBox;
    ndiSourceName = json.getString("ndiSourceName");
    init();
  }
  
  private void init(){
    frameBox = calcFrameBox();
    System.out.println(String.format("bBox: %s, frame: %s", boundingBox.toStr(), frameBox.toStr()));
    lastFrameType = DevolayFrameType.NONE;
    srcWidth = 1920;
    srcHeight = 1080;
    srcCanvas = createGraphics(srcWidth, srcHeight);
    connectToSource();
  }
  
  Box calcFrameBox(){
    Point pos = new Point(boundingBox.getX() + padding.x, boundingBox.getY() + padding.y);
    Point size = new Point(boundingBox.size.x - padding.x*2, boundingBox.size.y - padding.y*2); 
    return new Box(pos, size); 
  }
  
  void setBoundingBox(Box _boundingBox){
    boundingBox = _boundingBox;
    frameBox = calcFrameBox();
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
      ndiSource = ndiSources.get(ndiSourceName);
      ndiReceiver = new DevolayReceiver(ndiSource, DevolayReceiver.ColorFormat.RGBX_RGBA, DevolayReceiver.RECEIVE_BANDWIDTH_HIGHEST, true, null); 
      videoFrame = new DevolayVideoFrame();
      audioFrame = new DevolayAudioFrame();
      metadataFrame = new DevolayMetadataFrame();
    } finally {
      connecting = false;
    }
  }
  
  void disconnect(){
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
    DevolayFrameType frameType = DevolayFrameType.NONE;
    try {
      frameType = ndiReceiver.receiveCapture(videoFrame, audioFrame, metadataFrame, 5000);
    } finally {
      lastFrameType = frameType;
    }
    return frameType;
  }
  
  void updateFrame(){
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
      frameReady = false;
      canvasReady = true;
  }
  
  void render(PGraphics canvas){
    canvas.stroke(0);
    canvas.fill(255);
    canvas.rect(boundingBox.pos.x, boundingBox.pos.y, boundingBox.size.x, boundingBox.size.y); 
    canvas.fill(0);
    canvas.rect(frameBox.pos.x, frameBox.pos.y, frameBox.size.x, frameBox.size.y);
    if (canvasReady){
      canvas.image(srcCanvas, frameBox.pos.x, frameBox.pos.y, frameBox.size.x, frameBox.size.y);
      canvasReady = false;
    }
    canvas.textFont(windowFont);
    canvas.stroke(255);
    canvas.fill(255);
    canvas.textAlign(CENTER, TOP);
    canvas.text(name, frameBox.getHCenter(), frameBox.pos.y); 
  }
}

class FrameThread extends Thread {
  Window win;
  DevolayFrameType frameType;
  Exception error;
  FrameThread(Window _win){
    win = _win;
  }
  public void run(){
    DevolayFrameType ft;
    win.frameReady = false;
    win.gettingFrame = true;
    try {
      frameType = win.getFrame();
      win.frameReady = true;
    } catch (Exception e) {
      frameType = DevolayFrameType.NONE;
      error = e;
      throw(e);
    } finally {
      win.gettingFrame = false;
    }
  }
}