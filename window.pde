import java.util.List;
import java.util.Map;
import java.util.concurrent.locks.*;

class Window {
  String name = "";
  int col,row;
  Point padding;
  Box boundingBox, frameBox;
  String ndiSourceName = "";
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

  FrameHandler frameHandler;
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
    frameBox = calcFrameBox();
    nameLabel = new TextBox(frameBox.getTopLeft(), 100, 18);
    formatLabel = new TextBox(frameBox.getTopLeft(), 260, 18);
    nameLabel.setBottomCenter(frameBox.getBottomCenter());
    nameLabel.setAlign(CENTER, BOTTOM);
    
    formatLabel.setTopCenter(frameBox.getTopCenter());
    formatLabel.setAlign(CENTER, TOP);
    System.out.println(String.format("%s bBox: %s, frame: %s", getId(), boundingBox.toStr(), frameBox.toStr()));

    frameHandler = new FrameHandler();

    controls = new WindowControls(this);
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
    formatLabel.setTopCenter(frameBox.getTopCenter());
    controls.initControls();
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
      updateNdiSources();
    }
  }

  void updateNdiSources(){
    controls.updateFieldValues();
  }

  void connectToSource(){
    DevolaySource src = null;
    if (ndiSourceName == frameHandler.sourceName){
      return;
    }
    synchronized(mvApp.ndiSourceLock){
      if (ndiSourceName != ""){
        if (mvApp.ndiSources.containsKey(ndiSourceName)){
          src = mvApp.ndiSources.get(ndiSourceName);
        }
      }
      
      frameHandler.connectToSource(src);
      maybeConnected = frameHandler.maybeConnected;
      if (maybeConnected){
        frameHandler.open();
      }
    }
  }
  
  void close(){
    frameHandler.close();
    maybeConnected = false;
  }

  void disconnect(){
    frameHandler.disconnect();
    clearImageOnNextFrame = true;
    maybeConnected = false;
  }

  boolean isConnected(){
     boolean result = frameHandler.isConnected();
     maybeConnected = result;
     return result;
  }

  boolean canConnect(){
    return (ndiSourceName.length() > 0);
  }

  void render(PGraphics canvas){
    canvas.stroke(0);
    canvas.fill(0);
    canvas.rect(boundingBox.pos.x, boundingBox.pos.y, boundingBox.size.x, boundingBox.size.y);
    canvas.stroke(255);
    canvas.rect(frameBox.pos.x-1, frameBox.pos.y-1, frameBox.size.x+2, frameBox.size.y+2);
    NDIImageHandler img = frameHandler.getNextReadImage();
    int imgIdx = -1;
    if (img != null && !img.isBlank){
      img.drawToCanvas(canvas, frameBox);
      imgIdx = img.index;
    }
    nameLabel.text = name;
    nameLabel.render(canvas);
    formatLabel.text = String.format("Dropped %d frames out of %d total", frameHandler.droppedFrames, frameHandler.totalFrames);
    //formatLabel.text = String.format("%02d", imgIdx);
    //formatLabel.text = String.format("%dx%d", srcWidth, srcHeight);
    formatLabel.render(canvas);
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
    initControls(false);
  }
  
  void initControls(boolean create){
    if (!controlsCreated && !create){
      return;
    }
    System.out.println("initControls: win.getId = '" + win.getId() + "', myId='" + winId + "'");
    String dropdownId = winId + "-dropdown";
    Point ddPos = win.frameBox.getPos();
    if (sourceDropdown == null){
      buildSourceDropdown(dropdownId, ddPos);
    } else {
      setWidgetPos(sourceDropdown, ddPos);
    }
    
    String editNameBtnId = winId + "-editNameBtn";
    String editNameFieldId = winId + "-editNameField";
    Box editNameBtnBox = new Box(win.nameLabel);
    editNameBtnBox.setX(win.nameLabel.getRight() + 8);
    Box editNameFieldBox = new Box(win.nameLabel);
    editNameFieldBox.setRight(win.nameLabel.getX() - 8);
    if (editNameBtn == null){
      buildEditNameControls(editNameBtnId, editNameBtnBox, editNameFieldId, editNameFieldBox);
    } else {
      if (!editNameEnabled){
        editNameField.setText(win.name);
      }
      setWidgetBox(editNameBtn, editNameBtnBox);
      setWidgetBox(editNameField, editNameFieldBox);
    }
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
    synchronized(mvApp.ndiSourceLock){
      for (int i=0; i<mvApp.ndiSourceArray.length; i++){
        String srcName = mvApp.ndiSourceArray[i].getSourceName();
        itemNames.add(srcName);
        if (srcName == win.ndiSourceName){
          selIndex = i+1;
        }
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
