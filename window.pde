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
  int maxColorValue = 0;
  boolean frameReady = false;
  boolean gettingFrame = false;
  boolean connecting = false;
  boolean canvasReady = false;
  //PGraphics srcCanvas,dstCanvas;
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
    System.out.println(String.format("bBox: %s, frame: %s", boundingBox.toStr(), frameBox.toStr()));
    lastFrameType = DevolayFrameType.NONE;
    srcWidth = 1920;
    srcHeight = 1080;
    //srcCanvas = createGraphics(srcWidth, srcHeight);
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
    canvasReady = false;
    connecting = false;
    numFrames = 0;
    numDraws = 0;
    maxColorValue = 0;
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
      frameType = ndiReceiver.receiveCapture(videoFrame, audioFrame, metadataFrame, timeout);
    } finally {
      lastFrameType = frameType;
      //gettingFrame = false;
    }
    if (lastFrameType == DevolayFrameType.VIDEO){
      //System.out.println(getId()+" got video frame");
      frameReady = true;
      numFrames += 1;
    }
    return frameType;
  }
  
  DevolayFrameType getFrameNoWait(){
    return getFrame(0);
  }
  
  void updateFrame(){
    int frameWidth = videoFrame.getXResolution();
    int frameHeight = videoFrame.getYResolution();
    //System.out.println(String.format("%s frameDims: (%d, %d)", getId(), frameWidth, frameHeight));
    if (frameWidth == 0 || frameHeight == 0){
      srcWidth = 0;
      srcHeight = 0;
      frameReady = false;
      canvasReady = false;
      return;
    }
    if (srcWidth != frameWidth || srcHeight != frameHeight){
      srcWidth = frameWidth;
      srcHeight = frameHeight;
      if (srcWidth != srcImage.width || srcHeight != srcImage.height){
        srcImage.init(frameWidth, frameHeight, ARGB, 1);
        //srcImage.resize(frameWidth, frameHeight);
      }
      assert srcImage.pixels.length == srcWidth * srcHeight;
      //srcCanvas = createGraphics(srcWidth, srcHeight);
    }
    assert videoFrame.getLineStride() == frameWidth * 4;
    ByteBuffer framePixels = videoFrame.getData();
    //PImage img = new PImage(frameWidth, frameHeight, PConstants.ARGB);
    srcImage.loadPixels();
    
    int byteIndex = 0;
    
    for (int _y=0; _y < frameHeight; _y++){
      for (int _x=0; _x < frameWidth; _x++){
        int pixel = _y * frameWidth + _x;
        //int byteIndex = pixel * 4;
        int colorValue = 0;
        byte r, g, b, a;
        r = framePixels.get();
        g = framePixels.get();
        b = framePixels.get();
        a = framePixels.get();
        colorValue &= a << 24;
        colorValue &= r << 16;
        colorValue &= g << 8;
        colorValue &= b;
        
        //color c = color(r,g,b,a);
        //srcImage.set(_x, _y, c); 
        
        //colorValue &= framePixels.get(byteIndex+0) << 16;    // R
        //colorValue &= framePixels.get(byteIndex+1) << 8;     // G
        //colorValue &= framePixels.get(byteIndex+2) << 0;     // B
        ////colorValue &= framePixels.get(byteIndex+3) << 24;    // A
        //colorValue &= 255 << 24;
        //colorValue &= framePixels.getInt(byteIndex+0) << 16;    // R
        //colorValue &= framePixels.getInt(byteIndex+1) << 8;     // G
        //colorValue &= framePixels.getInt(byteIndex+2) << 0;     // B
        //colorValue &= framePixels.getInt(byteIndex+3) << 24;    // A
        
        
        srcImage.pixels[pixel] = colorValue;
        byteIndex += 4;
        assert framePixels.position() == byteIndex;
        int rgbMask = 0xffffffff;
        if ((colorValue & rgbMask) > maxColorValue){
          maxColorValue = colorValue & rgbMask;
        }
      }
    }
    //srcImage.updatePixels();
    //for (int _y=0; _y < frameHeight; _y++){
    //  for (int _x=0; _x < frameWidth; _x++){
    //    int pixel = _y * frameWidth + _x;
    //    int imgValue = srcImage.get(_x, _y);
    //    assert srcImage.pixels[pixel] == imgValue;
    //  }
    //}
    
    //srcCanvas.beginDraw();
    //srcCanvas.image(img, 0, 0);
    //srcCanvas.endDraw();
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
    if (canvasReady){
      canvas.image(srcImage, frameBox.pos.x, frameBox.pos.y, frameBox.size.x, frameBox.size.y);
      canvasReady = false;
    }
    //canvas.textFont(windowFont);
    //canvas.stroke(255);
    //canvas.fill(255);
    //canvas.textAlign(CENTER, TOP);
    //canvas.text(name, frameBox.getHCenter(), frameBox.pos.y); 
    //String imgString = String.format("%dx%d", srcWidth, srcHeight);
    //canvas.textAlign(RIGHT, TOP);
    //canvas.text(imgString, frameBox.getRight(), frameBox.pos.y);
    ////String readyString = String.format("frameReady: %s", "1" ? frameReady : "0");
    //canvas.textAlign(LEFT, BOTTOM);
    //canvas.text(String.format("numFrames: %d", numFrames), frameBox.pos.x, frameBox.getBottom());
    ////canvas.text(getBoolLabel("frameReady: %s", frameReady), frameBox.pos.x, frameBox.getBottom());
    ////String connectedString = String.format("connected: %s", "1" ? isConnected() : "0");
    //canvas.textAlign(RIGHT, BOTTOM);
    //canvas.text(String.format("numDraws: %d", numDraws), frameBox.getRight(), frameBox.getBottom());
    ////canvas.text(getBoolLabel("connected: %s", isConnected()), frameBox.getRight(), frameBox.getBottom());
    //canvas.textAlign(CENTER, BOTTOM);
    //canvas.text(String.format("%h", maxColorValue), frameBox.getHCenter(), frameBox.getBottom());
  }
  String getBoolLabel(String fmt, boolean value){
    String strValue;
    if (value){
      strValue = "1";
    } else {
      strValue = "0";
    }
    return String.format(fmt, strValue);
  }
}

class WindowControls {
  Window win;
  //CallbackListener cb;
  //Button dropdownBtn;
  DropdownList sourceDropdown;
  WindowControls(Window _win){
    win = _win;
    initControls();
  }
  
  void initControls(){
    String dropdownId = win.getId() + "-dropdown";
    Point ddPos = new Point(win.frameBox.pos.x, win.frameBox.pos.y);
    if (sourceDropdown == null){
      buildSourceDropdown(dropdownId, ddPos);
    } else {
      sourceDropdown.setPosition(ddPos.x, ddPos.y);
    }
  }
  
  void updateDropdownItems(){
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
        System.out.println(String.format("%s selIndex=%d, value=%d", win.getId(), selIndex, (int)sourceDropdown.getValue()));
      }
    }
  }

  
  void buildSourceDropdown(String name, Point pos){
    //if (sourceDropdown != null){
    //  cp5.remove(controlId);
    //}
    //HashMap<String,String> srcNames = new HashMap<String,String>();
    DropdownList dd = cp5.addDropdownList(name)
                         .setPosition(pos.x, pos.y);

    sourceDropdown = dd;
    updateDropdownItems();
    dd.close();
    
    Map<String,Object> ddState = new HashMap<String,Object>();
    ddState.put("open", false);
    dd.addCallback(new CallbackListener(){
      public void controlEvent(CallbackEvent theEvent) {
        //System.out.println(theEvent.getAction());
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
      frameType = win.getFrame(5000);
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
