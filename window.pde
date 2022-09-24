import java.util.List;
import java.util.Map;
import java.util.concurrent.locks.*;

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
  boolean maybeConnected = false;
  PImage srcImage;
  TextBox nameLabel, formatLabel;

  //Lock videoFrameLock;
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
  
  Window(WindowConfig config, Box _boundingBox, Point _padding){
    name = config.name;
    col = config.col;
    row = config.row;
    padding = _padding;
    boundingBox = _boundingBox;
    ndiSourceName = config.ndiSourceName;
    init();
  }
  
  JSONObject serialize(){
    JSONObject json = new JSONObject();
    json.setInt("col", col);
    json.setInt("row", row);
    json.setString("name", name);
    json.setString("ndiSourceName", ndiSourceName);
    return json;
  }

  private void init(){
    //videoFrameLock = new ReentrantLock();
    frameBox = calcFrameBox();
    nameLabel = new TextBox(frameBox.getTopLeft(), 100, 18);
    //nameLabel.text = name;
    formatLabel = new TextBox(frameBox.getTopLeft(), 100, 18);
    nameLabel.setBottomCenter(frameBox.getBottomCenter());
    //System.out.println(String.format("frame.bottomCenter = %s, nameLabel.bottomCenter = %s", frameBox.getBottomCenter().toStr(), nameLabel.getBottomCenter().toStr()));
    formatLabel.setTopCenter(frameBox.getTopCenter());
    System.out.println(String.format("%s bBox: %s, frame: %s", getId(), boundingBox.toStr(), frameBox.toStr()));
    lastFrameType = DevolayFrameType.NONE;
    srcWidth = 1920;
    srcHeight = 1080;
    srcImage = new PImage(srcWidth, srcHeight, ARGB);

    //connectToSource();
    controls = new WindowControls(this);
    //if (boundingBox.getTotalArea() > 0){
    //  controls.initControls();
    //}
    
  }

  Box calcFrameBox(){
    Point pos = new Point(boundingBox.getX() + padding.x, boundingBox.getY() + padding.y);
    Point size = new Point(boundingBox.size.x - padding.x*2, boundingBox.size.y - padding.y*2);
    Box b = new Box(pos, size.copy());
    b.setAspectRatioH(16.0/9.0);
    if (b.getHeight() > size.y){
      b.setSize(size.copy());
      b.setAspectRatioW(9.0/16.0);
    }
    b.setCenter(boundingBox.getCenter());
    return b;
  }

  void setBoundingBox(Box _boundingBox){
    boundingBox = _boundingBox;
    frameBox = calcFrameBox();
    nameLabel.setBottomCenter(frameBox.getBottomCenter());
    //System.out.println(String.format("frame.bottomCenter = %s, nameLabel.bottomCenter = %s", frameBox.getBottomCenter().toStr(), nameLabel.getBottomCenter().toStr()));
    formatLabel.setTopCenter(frameBox.getTopCenter());
    
    //formatLabel.setHCenter(frameBox.getHCenter());
    //formatLabel.setY(frameBox.getY());
    //if (boundingBox.getWidth() > 0 && boundingBox.getHeight() > 0){
    //  controls = new WindowControls(this);
    //}
    //if (boundingBox.getTotalArea() > 0){
    //  controls.initControls();
    //}
  }

  String getId(){
    return String.format("%02d-%02d", col, row);
  }
  
  void setName(String _name){
    setName(_name, true);
  }
  
  void setName(String _name, boolean updateControls){
    System.out.println("setName: '" + _name + "'");
    if (_name == name){
      return;
    }
    name = _name;
    mvApp.saveConfig();
    if (updateControls){
      controls.updateFieldValues();
    }
  }

  void setSourceName(String srcName){
    setSourceName(srcName, true);
  }

  void setSourceName(String srcName, boolean updateControls){
    if (srcName == ndiSourceName){
      return;
    }
    ndiSourceName = srcName;
    mvApp.saveConfig();
    System.out.println(getId()+" ndiSourceName: '"+srcName+"'");
    connectToSource();
    if (updateControls){
      //controls.updateDropdownItems();
      updateNdiSources();
    }
  }

  void updateNdiSources(){
    controls.updateFieldValues();
  }

  void connectToSource(){
    if (ndiSourceName == "" && ndiReceiver != null){
      ndiReceiver.connect(null);
      //disconnect();
      ndiSource = null;
      clearImageOnNextFrame = true;
      maybeConnected = false;
      return;
    }
    if (!mvApp.ndiSources.containsKey(ndiSourceName)){
      if (ndiReceiver != null){
        ndiReceiver.connect(null);
        ndiSource = null;
        clearImageOnNextFrame = true;
      }
      return;
    }
    connecting = true;
    try {
      ndiSource = mvApp.ndiSources.get(ndiSourceName);
      ndiReceiver = new DevolayReceiver(ndiSource, DevolayReceiver.ColorFormat.RGBX_RGBA, DevolayReceiver.RECEIVE_BANDWIDTH_LOWEST, false, null);
      videoFrame = new DevolayVideoFrame();
      audioFrame = new DevolayAudioFrame();
      metadataFrame = new DevolayMetadataFrame();
      maybeConnected = true;
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
    maybeConnected = false;
  }

  boolean isConnected(){
     if (ndiSource == null){
       maybeConnected = false;
       return false;
     }
     if (ndiReceiver == null){
       maybeConnected = false;
       return false;
     }
     if (ndiReceiver.getConnectionCount() == 0){
       maybeConnected = false;
       return false;
     }
     maybeConnected = true;
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
    DevolayPerformanceData performanceData = new DevolayPerformanceData();
    try {
      ndiReceiver.queryPerformance(performanceData);
      long _droppedFrames = performanceData.getDroppedVideoFrames();
      long _totalFrames = performanceData.getTotalVideoFrames();
      if (_droppedFrames != droppedFrames){
        droppedFrames = _droppedFrames;
        System.out.println(String.format("'%s' Dropped Video: %d / %d", getId(), droppedFrames, _totalFrames));
      }
    } finally {
      performanceData.close();
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
    canvas.fill(0);
    canvas.rect(boundingBox.pos.x, boundingBox.pos.y, boundingBox.size.x, boundingBox.size.y);
    canvas.stroke(255);
    canvas.rect(frameBox.pos.x-1, frameBox.pos.y-1, frameBox.size.x+2, frameBox.size.y+2);
    //canvas.stroke(0);
    //canvas.rect(frameBox.pos.x, frameBox.pos.y, frameBox.size.x, frameBox.size.y);
    if (clearImageOnNextFrame){
      for (int _i=0; _i < srcImage.width * srcImage.height; _i++){
        srcImage.pixels[_i] = 0;
      }
      srcImage.updatePixels();
      clearImageOnNextFrame = false;
      canvas.image(srcImage, frameBox.pos.x, frameBox.pos.y, frameBox.size.x, frameBox.size.y);
    } else if (maybeConnected){
      canvas.image(srcImage, frameBox.pos.x, frameBox.pos.y, frameBox.size.x, frameBox.size.y);
    }
    canvasReady = false;
    nameLabel.text = name;
    nameLabel.render(canvas);
    formatLabel.text = String.format("%dx%d", srcWidth, srcHeight);
    formatLabel.render(canvas);
    //canvas.textFont(windowFont);
    //canvas.stroke(255);
    //canvas.fill(255);
    //canvas.textAlign(CENTER, TOP);
    //canvas.text(name, frameBox.getHCenter(), frameBox.pos.y);
    //String imgString = String.format("%dx%d", srcWidth, srcHeight);
    //canvas.textAlign(RIGHT, TOP);
    //canvas.text(imgString, frameBox.getRight(), frameBox.pos.y);
    
    //if (videoFrame != null){
    //  canvas.textAlign(CENTER, BOTTOM);
    //  canvas.text(timecodeStr(videoFrame.getTimecode()), frameBox.getHCenter(), frameBox.getBottom());
    //}
  }
}

class WindowControls {
  Window win;
  String winId;
  boolean controlsCreated = false;
  DropdownList sourceDropdown;
  Button editNameBtn;
  boolean editNameEnabled = false;
  Textfield editNameField;
  
  WindowControls(Window _win){
    win = _win;
    winId = _win.getId();
    initControls(true);
  }

  void initControls(){
    //boolean create = false;
    //if (!controlsCreated && win.boundingBox.getWidth() > 0 && win.boundingBox.getHeight() > 0){
    //  create = true;
    //}
    //initControls(create);
    initControls(false);
  }
  
  void initControls(boolean create){
    if (!controlsCreated && !create){
      return;
    }
    System.out.println("initControls: win.getId = '" + win.getId() + "', myId='" + winId + "'");
    String dropdownId = winId + "-dropdown";
    Point ddPos = win.frameBox.getPos();//win.frameBox.getHCenter(), win.frameBox.pos.y);
    if (sourceDropdown == null){
      buildSourceDropdown(dropdownId, ddPos);
    }
    //setWidgetPos(sourceDropdown, ddPos);
    //sourceDropdown.setPosition(ddPos.x, ddPos.y);
    
    String editNameBtnId = winId + "-editNameBtn";
    String editNameFieldId = winId + "-editNameField";
    Box editNameBtnBox = new Box(win.nameLabel);
    //Box editNameBtnBox = new Box(0, 0, win.nameLabel.getSize());
    //editNameBtnBox.setCenter(win.frameBox.getCenter());
    editNameBtnBox.setX(win.nameLabel.getRight() + 8);
    Box editNameFieldBox = new Box(win.nameLabel);
    editNameFieldBox.setRight(win.nameLabel.getX() - 8);
    if (editNameBtn == null){
      buildEditNameControls(editNameBtnId, editNameBtnBox, editNameFieldId, editNameFieldBox);
    } else {
      if (!editNameEnabled){
        editNameField.setText(win.name);
      }
    }
    //setWidgetPos(editNameBtn, editNameBtnBox);
    //setWidgetPos(editNameField, editNameFieldBox);
    controlsCreated = true;
  }
  
  Controller setWidgetPos(Controller widget, Point pos){
    widget.setPosition(pos.x, pos.y);
    return widget;
  }
  
  Controller setWidgetPos(Controller widget, Box b){
    return setWidgetPos(widget, b.getPos());
  }
  
  Controller setWidgetSize(Controller widget, Point size){
    widget.setSize((int)size.x, (int)size.y);
    return widget;
  }
  
  Controller setWidgetSize(Controller widget, Box b){
    return setWidgetSize(widget, b.getSize());
  }
  
  Controller setWidgetBox(Controller widget, Box b){
    setWidgetPos(widget, b);
    setWidgetSize(widget, b);
    return widget;
  }
  
  void updateFieldValues(){
    if (controlsCreated){
      updateDropdownItems();
      if (!editNameEnabled){
        editNameField.setText(win.name);
      }
    }
  }

  void updateDropdownItems(){
    if (sourceDropdown == null){
      return;
    }
    List<String> itemNames = new ArrayList<String>();
    int selIndex = -2;
    itemNames.add("None");
    for (int i=0; i<mvApp.ndiSourceArray.length; i++){
      String srcName = mvApp.ndiSourceArray[i].getSourceName();
      itemNames.add(srcName);
      if (srcName == win.ndiSourceName){
        selIndex = i+1;
      }
    }
    if (win.ndiSourceName != "" && !itemNames.contains(win.ndiSourceName)){
    //if (selIndex == -2 && win.ndiSourceName != ""){
      selIndex = itemNames.size();
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
    sourceDropdown = mvApp.cp5.addDropdownList(name)
                        .setOpen(false)
                        .plugTo(this, "onSourceDropdown");
    setWidgetPos(sourceDropdown, pos);
    updateDropdownItems();
  }
  
  void buildEditNameControls(String btnId, Box btnBox, String txtFieldId, Box txtBox){
    editNameBtn = mvApp.cp5.addButton(btnId)
                     .setLabel("Edit Name")
                     .setValue(1)
                     .setSwitch(true)
                     .plugTo(this, "onEditNameBtn");
    setWidgetBox(editNameBtn, btnBox);
    
    editNameField = mvApp.cp5.addTextfield(txtFieldId)
                       .setText(win.name)
                       .setVisible(false)
                       .setAutoClear(false)
                       .plugTo(this, "onEditNameField");
    setWidgetBox(editNameField, txtBox);
  }
  
  void onSourceDropdown(int idx){
    if (sourceDropdown.isOpen()){
      Map<String,Object> item = sourceDropdown.getItem(idx);
      String srcName = (String)item.get("name");
      if (srcName == "None"){
        srcName = "";
      }
      System.out.println(String.format("idx=%d, srcName=%s", idx, srcName));
      win.setSourceName(srcName, false);
      sourceDropdown.close();
    }
  }
  
  void onEditNameBtn(boolean btnOn){
    if (editNameEnabled != btnOn){
      editNameEnabled = btnOn;
      System.out.println(String.format("editNameEnabled = %s", editNameEnabled));
      editNameField.setVisible(editNameEnabled);
      if (editNameEnabled){
        editNameField.setFocus(true);
      }
    }
  }
  
  void onEditNameField(String txtValue){
    if (editNameField.isVisible() && editNameEnabled){
        win.setName(txtValue, false);
        editNameField.setFocus(false);
        editNameEnabled = false;
        editNameBtn.setOff();
        editNameField.setVisible(false);
    }
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
//  boolean running = false;
//  Exception error;
//  FrameThread(Window _win){
//    win = _win;
//  }
//  public void run(){
//    running = true;
//    while (running){
//      win.frameReady = false;
//      win.gettingFrame = true;
//      try {
//        frameType = win.getFrame(500);
//        if (frameType == DevolayFrameType.VIDEO){
//          win.videoFrameLock.lock();
//          try {
//            win.updateFrame();
//          } finally {
//            win.videoFrameLock.unlock();
//          }
//        }
//      } catch (Exception e) {
//        frameType = DevolayFrameType.NONE;
//        error = e;
//        throw(e);
//      } finally {
        
//        //win.gettingFrame = false;
//      }
//    }
//  }
//}
