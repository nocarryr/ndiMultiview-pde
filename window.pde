import java.util.List;
import java.util.Map;

class Window {
  String name = "";
  int col,row;
  Point padding;
  Box boundingBox, frameBox;
  String ndiSourceName = "";
  int srcWidth,srcHeight;
  int numFrames = 0, numDraws = 0;
  long droppedFrames = 0;
  boolean frameReady = false;
  boolean gettingFrame = false;
  boolean connecting = false;
  boolean canvasReady = false;
  boolean clearImageOnNextFrame = false;
  PImage srcImage;

  DevolaySource ndiSource;
  DevolayReceiver ndiReceiver;
  DevolayVideoFrame videoFrame;
  DevolayAudioFrame audioFrame;
  DevolayMetadataFrame metadataFrame;
  DevolayFrameType lastFrameType;
  WindowControls controls;

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
    System.out.println(String.format("%s bBox: %s, frame: %s", getId(), boundingBox.toStr(), frameBox.toStr()));
    lastFrameType = DevolayFrameType.NONE;
    srcWidth = 1920;
    srcHeight = 1080;
    srcImage = new PImage(srcWidth, srcHeight, ARGB);

    //connectToSource();
    controls = new WindowControls(this);
  }

  Box calcFrameBox(){
    Point pos = new Point(boundingBox.getX() + padding.x, boundingBox.getY() + padding.y);
    Point size = new Point(boundingBox.size.x - padding.x*2, boundingBox.size.y - padding.y*2);
    return new Box(pos, size);
  }

  void setBoundingBox(Box _boundingBox){
    boundingBox = _boundingBox;
    frameBox = calcFrameBox();
    controls.initControls();
  }

  String getId(){
    return String.format("%02d-%02d", col, row);
  }

  void setSourceName(String srcName){
    setSourceName(srcName, true);
  }

  void setSourceName(String srcName, boolean updateControls){
    if (srcName == ndiSourceName){
      return;
    }
    ndiSourceName = srcName;
    System.out.println(getId()+" ndiSourceName: '"+srcName+"'");
    connectToSource();
    if (updateControls){
      //controls.updateDropdownItems();
      updateNdiSources();
    }
  }

  void updateNdiSources(){
    controls.updateDropdownItems();
  }

  void connectToSource(){
    if (ndiSourceName == "" && ndiReceiver != null){
      ndiReceiver.connect(null);
      ndiSource = null;
      clearImageOnNextFrame = true;
      return;
    }
    if (!ndiSources.containsKey(ndiSourceName)){
      if (ndiReceiver != null){
        ndiReceiver.connect(null);
        ndiSource = null;
        clearImageOnNextFrame = true;
      }
      return;
    }
    connecting = true;
    try {
      ndiSource = ndiSources.get(ndiSourceName);
      ndiReceiver = new DevolayReceiver(ndiSource, DevolayReceiver.ColorFormat.RGBX_RGBA, DevolayReceiver.RECEIVE_BANDWIDTH_LOWEST, false, null);
      videoFrame = new DevolayVideoFrame();
      audioFrame = new DevolayAudioFrame();
      metadataFrame = new DevolayMetadataFrame();
    } catch (Exception e){
      clearImageOnNextFrame = true;
      throw(e);
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
    canvasReady = false;
    connecting = false;
    numFrames = 0;
    numDraws = 0;
    droppedFrames = 0;
    clearImageOnNextFrame = true;
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

  DevolayFrameType getFrame(int timeout) {
    DevolayFrameType frameType = DevolayFrameType.NONE;
    if (frameReady){
      return frameType;
    }
    //gettingFrame = true;
    try {
      //frameType = ndiReceiver.receiveCapture(videoFrame, audioFrame, metadataFrame, timeout);
      frameType = ndiReceiver.receiveCapture(videoFrame, null, null, timeout);
    } finally {
      lastFrameType = frameType;
    }
    if (lastFrameType == DevolayFrameType.VIDEO){
      frameReady = true;
      numFrames += 1;
    }
    try (DevolayPerformanceData performanceData = new DevolayPerformanceData()) {
      ndiReceiver.queryPerformance(performanceData);
      long _droppedFrames = performanceData.getDroppedVideoFrames();
      long _totalFrames = performanceData.getTotalVideoFrames();
      if (_droppedFrames != droppedFrames){
        droppedFrames = _droppedFrames;
        System.out.println(String.format("Dropped Video: %d / %d", droppedFrames, _totalFrames));
        
      }
    }
    return frameType;
  }

  DevolayFrameType getFrameNoWait(){
    return getFrame(0);
  }

  void updateFrame(){
    int frameWidth = videoFrame.getXResolution();
    int frameHeight = videoFrame.getYResolution();
    DevolayFrameFourCCType fourCC = videoFrame.getFourCCType();
    assert (fourCC == DevolayFrameFourCCType.RGBA || fourCC == DevolayFrameFourCCType.RGBX);
    
    if (frameWidth == 0 || frameHeight == 0){
      System.out.println("frameSize = 0");
      srcWidth = 0;
      srcHeight = 0;
      frameReady = false;
      canvasReady = false;
      return;
    }
    if (srcWidth != frameWidth || srcHeight != frameHeight){
      System.out.println(String.format("resize image to %dx%d", frameWidth, frameHeight));
      srcWidth = frameWidth;
      srcHeight = frameHeight;
      if (srcWidth != srcImage.width || srcHeight != srcImage.height){
        srcImage.init(frameWidth, frameHeight, ARGB);
      }
      assert srcImage.pixels.length == srcWidth * srcHeight;
    }
    assert videoFrame.getLineStride() == frameWidth * 4;
    
    ByteBuffer framePixels = videoFrame.getData();
    
    int byteIndex = 0;
    
    for (int _y=0; _y < frameHeight; _y++){
      for (int _x=0; _x < frameWidth; _x++){
        int pixel = _y * frameWidth + _x;
        int colorValue = 0;
        int r, g, b, a;
         
        r = (framePixels.get() & 0xff) << 16;
        g = (framePixels.get() & 0xff) << 8;
        b = (framePixels.get() & 0xff);
        a = (framePixels.get() & 0xff) << 24;
        colorValue = r | b | g | a;
        
        srcImage.pixels[pixel] = colorValue;
        byteIndex += 4;
        assert framePixels.position() == byteIndex;
      }
    }
    srcImage.updatePixels();
     
    frameReady = false;
    canvasReady = true;
    numDraws += 1;
  }

  void render(PGraphics canvas){
    canvas.stroke(0);
    canvas.fill(255);
    canvas.rect(boundingBox.pos.x, boundingBox.pos.y, boundingBox.size.x, boundingBox.size.y);
    canvas.fill(0);
    canvas.rect(frameBox.pos.x, frameBox.pos.y, frameBox.size.x, frameBox.size.y);
    if (clearImageOnNextFrame){
      for (int _i=0; _i < srcImage.width * srcImage.height; _i++){
        srcImage.pixels[_i] = 0;
      }
      srcImage.updatePixels();
      clearImageOnNextFrame = false;
    }
    canvas.image(srcImage, frameBox.pos.x, frameBox.pos.y, frameBox.size.x, frameBox.size.y);
    canvasReady = false;
    canvas.textFont(windowFont);
    canvas.stroke(255);
    canvas.fill(255);
    canvas.textAlign(CENTER, TOP);
    canvas.text(name, frameBox.getHCenter(), frameBox.pos.y);
    String imgString = String.format("%dx%d", srcWidth, srcHeight);
    canvas.textAlign(RIGHT, TOP);
    canvas.text(imgString, frameBox.getRight(), frameBox.pos.y);
    //if (videoFrame != null){
    //  canvas.textAlign(CENTER, BOTTOM);
    //  canvas.text(timecodeStr(videoFrame.getTimecode()), frameBox.getHCenter(), frameBox.getBottom());
    //}
  }
}

class WindowControls {
  Window win;
  String winId;
  DropdownList sourceDropdown;
  WindowControls(Window _win){
    win = _win;
    winId = _win.getId();
    initControls(true);
  }

  void initControls(){
    initControls(false);
  }
  
  void initControls(boolean create){
    if (sourceDropdown == null && !create){
      return;
    }
    System.out.println("initControls: win.getId = '" + win.getId() + "', myId='" + winId + "'");
    String dropdownId = winId + "-dropdown";
    Point ddPos = new Point(win.frameBox.pos.x, win.frameBox.pos.y);
    if (sourceDropdown == null){
      buildSourceDropdown(dropdownId, ddPos);
    } else {
      sourceDropdown.setPosition(ddPos.x, ddPos.y);
    }
  }

  void updateDropdownItems(){
    if (sourceDropdown == null){
      return;
    }
    List<String> itemNames = new ArrayList<String>();
    int selIndex = -2;
    itemNames.add("None");
    for (int i=0; i<ndiSourceArray.length; i++){
      String srcName = ndiSourceArray[i].getSourceName();
      itemNames.add(srcName);
      if (srcName == win.ndiSourceName){
        selIndex = i+1;
      }
    }
    if (selIndex == -2 && win.ndiSourceName != ""){
      itemNames.add(win.ndiSourceName);
    }
    sourceDropdown.setItems(itemNames);
    if (selIndex >= 0){
      sourceDropdown.setValue(selIndex);
      sourceDropdown.getCaptionLabel().setText(itemNames.get(selIndex));
      if (selIndex >= 1){
        System.out.println(String.format("%s selIndex=%d, value=%d", winId, selIndex, (int)sourceDropdown.getValue()));
      }
    }
  }


  void buildSourceDropdown(String name, Point pos){
    DropdownList dd = cp5.addDropdownList(name)
                         .setPosition(pos.x, pos.y);

    sourceDropdown = dd;
    updateDropdownItems();
    dd.close();

    Map<String,Object> ddState = new HashMap<String,Object>();
    ddState.put("open", false);
    dd.addCallback(new CallbackListener(){
      public void controlEvent(CallbackEvent theEvent) {
        boolean openState = (boolean)ddState.get("open");
        if (theEvent.getAction()==ControlP5.ACTION_CLICK) {
          if (!openState){
            ddState.put("open", true);
            return;
          }
          int idx = (int)dd.getValue();
          Map<String,Object> item = dd.getItem(idx);
          String srcName = (String)item.get("name");
          if (srcName == "None"){
            srcName = "";
          }
          System.out.println(String.format("idx=%d, srcName=%s", idx, srcName));
          win.setSourceName(srcName, false);
          dd.close();
          ddState.put("open", false);
        }
      }
    });
  }

  Box getWidgetBox(Controller widget){
    float[] xy;
    float w, h;
    xy = widget.getPosition();
    w = widget.getWidth();
    h = widget.getHeight();
    return new Box(xy[0], xy[1], w, h);
  }
}


//class FrameThread extends Thread {
//  Window win;
//  DevolayFrameType frameType;
//  Exception error;
//  FrameThread(Window _win){
//    win = _win;
//  }
//  public void run(){
//    DevolayFrameType ft;
//    win.frameReady = false;
//    win.gettingFrame = true;
//    try {
//      frameType = win.getFrame(5000);
//      win.frameReady = true;
//    } catch (Exception e) {
//      frameType = DevolayFrameType.NONE;
//      error = e;
//      throw(e);
//    } finally {
//      win.gettingFrame = false;
//    }
//  }
//}
