//import java.util.Map;
import java.awt.Frame;
import java.awt.Shape;
import java.awt.Rectangle;
import java.awt.GraphicsEnvironment;
import java.awt.GraphicsDevice;
import java.awt.DisplayMode;
import processing.awt.*;
import processing.awt.ShimAWT;
import java.nio.ByteBuffer;
import java.io.File;
import me.walkerknapp.devolay.*;
import controlP5.*;

MultiviewApplet mvApp;
PFont baseWindowFont;
//boolean isFullScreen = false;
//int fullScreenDisplay = 0;
int confSaveInterval = 60;
float resizeCheckInterval = .25; 
//int lastConfSaveFrame = -1;
//int nextConfSaveFrame = -1;

//WindowGrid windowGrid;
//PFont windowFont;
//DevolayFinder ndiFinder;
//DevolaySource[] ndiSourceArray;
//boolean updatingSources = false;
//boolean sourcesUpdated = false;
boolean baseloopInitial = true;
//int lastSourceUpdateFrame = 0;
float sourceUpdateTimeInterval = 10;
//HashMap<String,DevolaySource> ndiSources;
//PGraphics dstCanvas;
//Box windowBounds;
ControlP5 basecp5;

//public void controlEvent(ControlEvent theEvent){
//  println(theEvent.toString());
//}

JSONObject loadConfig(){
  //return new JSONObject();
  File confFile = getConfigFile();
  System.out.println("loadConfig: " + confFile.getPath());
  if (!confFile.exists()){
    return new JSONObject();
  }
  return loadJSONObject(confFile.getPath());
  //JSONObject json = loadJSONObject(confFile.getPath());
  //Config config = new Config(json);
}

Config getConfig(){
  //return new JSONObject();
  File confFile = getConfigFile();
  System.out.println("loadConfig: " + confFile.getPath());
  if (!confFile.exists()){
    return new Config();
  }
  //return loadJSONObject(confFile.getPath());
  JSONObject json = loadJSONObject(confFile.getPath());
  return new Config(json);
}



void setup(){
  String[] args = {"NDI Multiviewer"};
  mvApp = new MultiviewApplet();
  PApplet.runSketch(args, mvApp);
  
  basecp5 = new ControlP5(this);
  baseWindowFont = createFont("Georgia", 12);
  size(200, 100);
  frameRate(10);
  basecp5.addButton("fullScreenToggle")
         .setValue(0)
         .setSwitch(true)
         .setLabel("Fullscreen");
  basecp5.addTextlabel("appSizeLbl")
         .setText(String.format("(%d, %d)", (int)mvApp.width, (int)mvApp.height))
         .setPosition(0, 50)
         .setFont(baseWindowFont);
  //windowFont = createFont("Georgia", 12);
  //ndiSourceArray = new DevolaySource[0];
  //ndiSources = new HashMap<String,DevolaySource>();
  //System.out.println("loadingLibraries...");
  //Devolay.loadLibraries();
  //ndiFinder = new DevolayFinder();
  
  //JSONObject confData = loadConfig();
  //Config config = getConfig();
  //System.out.println("Creating WindowGrid...");
  //if (!confData.isNull("isFullScreen")){
  //  isFullScreen = confData.getBoolean("isFullScreen");
  //}
  //if (isFullScreen){
  //  fullScreenDisplay = confData.getInt("fullScreenDisplay");
  //  fullScreen(fullScreenDisplay);
  //} else {
  //  //surface.setResizable(true);
  //  if (confData.isNull("windowBounds")){
  //    //size(800, 450);
  //    surface.setSize(800, 450);
  //  } else {
  //    surface.setSize(800, 450);
  //    //Box bBox = new Box(confData.getJSONObject("windowBounds"));
  //    //surface.setLocation((int)bBox.getX(), (int)bBox.getY());
  //    //surface.setSize((int)bBox.getWidth(), (int)bBox.getHeight());
  //  }
  //}
  //cp5.setGraphics(this, 0, 0);
  
  //size(800, 450);
  //dstCanvas = createGraphics(width, height);
  //config.windowGrid.outputSize = new Point(width, height);
  //windowGrid = new WindowGrid(config.windowGrid);
  
  //if (confData.isNull("windowGrid")){
  //  windowGrid = new WindowGrid(2, 2, width, height);
  //} else {
  //  windowGrid = new WindowGrid(confData.getJSONObject("windowGrid"), width, height);
  //}
  //windowGrid.setOutputSize(width, height);
  //System.out.println("setup complete");
}



void draw(){
  background(0);
  
  Textlabel lbl = (Textlabel)basecp5.getController("appSizeLbl");
  lbl.setText(String.format("(%d, %d)", (int)mvApp.width, (int)mvApp.height));
  
  String txt0 = String.format("Base  fps=%d, frame=%06d", (int)frameRate, (int)frameCount);
  String txt1 = String.format("mvApp fps=%d, frame=%06d", (int)mvApp.frameRate, (int)mvApp.frameCount);
  textAlign(RIGHT, TOP);
  text(txt0, 0, 0);
  textAlign(RIGHT, BOTTOM);
  text(txt1, 0, height);
  //updateNdiSources();
  //if (exitCalled){
  //  System.out.println("Closing resources");
  //  windowGrid.close();
  //  return;
  //}
  
  //background(0);
  //dstCanvas.beginDraw();
  //dstCanvas.background(0);
  //windowGrid.render(dstCanvas);
  //dstCanvas.endDraw();
  //image(dstCanvas, 0, 0);
  if (baseloopInitial && !mvApp.loopInitial){
    //int fsval = mvApp.isFullScreen==true ? 1 : 0;
    basecp5.getController("fullScreenToggle").setValue(mvApp.isFullScreen ? 1 : 0);
    baseloopInitial = false;
  }
  //confAutoSave();
}

public void fullScreenToggle(boolean value){
  if (!baseloopInitial){
    mvApp.setFullScreen(value);
  }
}

public class MultiviewApplet extends PApplet {
  Config config;
  WindowGrid windowGrid;
  PFont windowFont;
  DevolayFinder ndiFinder;
  DevolaySource[] ndiSourceArray;
  boolean isFullScreen = false;
  boolean updatingSources = false;
  boolean sourcesUpdated = false;
  boolean loopInitial = true;
  int lastSourceUpdateFrame = 0;
  int lastConfSaveFrame = -1;
  int nextConfSaveFrame = -1;
  HashMap<String,DevolaySource> ndiSources;
  PGraphics dstCanvas;
  Box windowBounds;
  ControlP5 cp5;

  public void settings() {
    config = getConfig();
    isFullScreen = config.app.fullScreen;
    if (config.app.fullScreen){
      fullScreen(config.app.displayNumber);
    } else {
      int maxWidth = displayWidth - 100;
      int maxHeight = displayHeight - 100;
      if (config.app.canvasSize.x >= maxWidth){
        config.app.canvasSize.x = maxWidth;
      }
      if (config.app.canvasSize.y >= maxHeight){
        config.app.canvasSize.y = maxHeight;
      }
      size((int)config.app.canvasSize.x, (int)config.app.canvasSize.y);
    }
    //frameRate(60);
  }
  
  public void setFullScreen(boolean value){
    if (value == isFullScreen){
      return;
    }
    isFullScreen = value;
    saveConfig();
  }
  
  StringList getDisplays(){
    GraphicsEnvironment ge = GraphicsEnvironment.getLocalGraphicsEnvironment();
    GraphicsDevice defaultDevice = ge.getDefaultScreenDevice();
    GraphicsDevice[] devices = ge.getScreenDevices();
    StringList result = new StringList();
    for (int i=0; i<devices.length; i++){
      GraphicsDevice device = devices[i];
      DisplayMode mode = device.getDisplayMode();
      String suffix = (device == defaultDevice) ? "(default)" : "";
      String s = String.format("%d x %d%s", mode.getWidth(), mode.getHeight(), suffix);
      //result.append(device.getIDString());
      result.append(s);
    }
    return result;
  }
  
  public void closeBtn(int value){
    exit();
  }
  
  public void fullScreenToggle(boolean value){
    setFullScreen(value);
  }
  
  public void setup(){
    this.surface.setResizable(true);
    cp5 = new ControlP5(this);
    Box btnBox = new Box(0, 0, 40, 20);
    btnBox.setRight(width);
    cp5.addButton("closeBtn")
       .setLabel("Close")
       .setPosition(btnBox.getX(), btnBox.getY())
       .setSize((int)btnBox.getWidth(), (int)btnBox.getHeight());
       
    btnBox.setRight(btnBox.getX() - 10);
    cp5.addButton("fullScreenToggle")
       .setLabel("Fullscreen")
       .setPosition(btnBox.getX(), btnBox.getY())
       .setSize((int)btnBox.getWidth(), (int)btnBox.getHeight())
       .setValue(config.app.fullScreen ? 1 : 0)
       .setSwitch(true);
       
    windowFont = createFont("Georgia", 12);
    ndiSourceArray = new DevolaySource[0];
    ndiSources = new HashMap<String,DevolaySource>();
    System.out.println("loadingLibraries...");
    Devolay.loadLibraries();
    ndiFinder = new DevolayFinder();
    dstCanvas = createGraphics(this.width, this.height);
    System.out.println("Creating WindowGrid...");
    config.windowGrid.outputSize = new Point(this.width, this.height);
    windowGrid = new WindowGrid(config.windowGrid);
  }
  public void draw() {
    checkResize();
    updateNdiSources();
    if (this.exitCalled){
      System.out.println("Closing resources");
      windowGrid.close();
      return;
    }
    
    //background(0);
    //PGraphics cv = getGraphics();
    //cv.beginDraw();
    g.background(0);
    windowGrid.render(g);
    //cv.endDraw();
    //image(dstCanvas, 0, 0, this.width, this.height);
    
    //background(0);
    ////PGraphics cv = getGraphics();
    //dstCanvas.beginDraw();
    //dstCanvas.background(0);
    //windowGrid.render(dstCanvas);
    //dstCanvas.endDraw();
    //image(dstCanvas, 0, 0, this.width, this.height);
    //loopInitial = false;
    //confAutoSave();
  }
  
  void checkResize(){
    //int frInterval = secondsToFrame(resizeCheckInterval);
    if ((int)frameCount % 20 != 0){
      return;
    }
    //if (this.mousePressed){// && (mouseButton == LEFT)){
    //  return;
    //}
    if ((int)this.width != windowGrid.outWidth || (int)this.height != windowGrid.outHeight){
      println("resize canvas");
      //dstCanvas = createGraphics(this.width, this.height);
      windowGrid.setOutputSize((int)this.width, (int)this.height);
      saveConfig();
      //dstCanvas.resize(this.width, this.height);
    }
  }

  void saveConfig(JSONObject json){
    File confFile = getConfigFile();
    System.out.println("saveConfig: " + confFile.getAbsolutePath());
    saveJSONObject(json, confFile.getPath());
  }
  
  void saveConfig(Config c){
    try {
      JSONObject json = c.serialize();
      saveConfig(json);
    } catch(Exception e){
      e.printStackTrace();
      throw(e);
    }
  }
  
  void saveConfig(){
    config.update(this);
    saveConfig(config);
  }
  
  void confAutoSave(){
    if (nextConfSaveFrame == -1 || frameCount >= nextConfSaveFrame){
      windowBounds = getWindowDims();
      System.out.println("autosave config");
      saveConfig();
      lastConfSaveFrame = frameCount;
      nextConfSaveFrame = frameCount + secondsToFrame(confSaveInterval);
    }
  }
  
  Box getWindowDims(){
    PSurfaceAWT.SmoothCanvas nativeWin = (PSurfaceAWT.SmoothCanvas)this.surface.getNative();
    java.awt.Rectangle bBox = nativeWin.getFrame().getBounds();
    Box b = new Box(bBox.x, bBox.y, bBox.width, bBox.height);
    return b;
  }
  
  void updateNdiSources(){
    if (sourcesUpdated){
      System.out.println("sourcesUpdated");
      sourcesUpdated = false;
      lastSourceUpdateFrame = this.frameCount;
      windowGrid.updateNdiSources();
    }
    if (updatingSources){
      return;
    }
    //int currentFrame = frameCount;
    //float fr = frameRate;
    //if (fr == 0){
    //  fr = 1;
    //}
    //float numFrames = sourceUpdateTimeInterval / fr;
    //int nextFrame = lastSourceUpdateFrame + (int)numFrames;
    //int nextFrame = calcNextUpdateFrame();
    int numFrames = secondsToFrame(sourceUpdateTimeInterval);
    int nextFrame = lastSourceUpdateFrame + numFrames;
    if (loopInitial || this.frameCount >= nextFrame){
      updatingSources = true;
      thread("_updateNDISources");
    }
  }
  
  void _updateNDISources() {
    System.out.println("updateNdiSources");
    int timeout = 5000;
    int maxTries = 3;
    updatingSources = true;
    
    //DevolayFinder finder = new DevolayFinder();
    DevolayFinder finder = ndiFinder;
    int numAttempts = 0;
    boolean changed = false;
    try {
      DevolaySource[] sources = new DevolaySource[0];
      //while ((sources = ndiFinder.getCurrentSources()).length == 0){
      while (numAttempts < maxTries){
        println(numAttempts);
        sources = finder.getCurrentSources();
        if (ndiSourceArray.length == 0){
          if (sources.length > 0){
            changed = true;
            break;
          }
        } else {
          if (sources.length != ndiSourceArray.length){
            changed = true;
            break;
          }
        }
        finder.waitForSources(timeout);
        numAttempts += 1;
      }
      ndiSources.clear();
      for (int i=0;i<sources.length;i++){
        ndiSources.put(sources[i].getSourceName(), sources[i]);
        System.out.println(sources[i].getSourceName());
      }
      ndiSourceArray = sources;
    } catch(Exception e){
      e.printStackTrace();
      throw(e);
    } finally {
      //System.out.println("closing finder");
      //finder.close();
      //lastSourceUpdateFrame = frameCount;
      sourcesUpdated = true;
      updatingSources = false;
      println("updateExit");
    }
  }

  int secondsToFrame(float sec){
    float fr = this.frameRate;
    if (fr == 0){
      fr = 1;
    }
    return (int)(fr * sec);
  }
  
  float frameToSeconds(int f){
    float fr = this.frameRate;
    if (fr == 0){
      fr = 1;
    }
    return f / fr;
  }
}

//float calcUpdateNumFrames(){
//  float fr = frameRate;
//  if (fr == 0){
//    fr = 1;
//  }
//  //return sourceUpdateTimeInterval / fr;
//  //return fr / sourceUpdateTimeInterval;
//  return fr * sourceUpdateTimeInterval;
//}

//int calcNextUpdateFrame(){
//  int numFrames = secondsToFrame(sourceUpdateTimeInterval);
//  return lastSourceUpdateFrame + numFrames;
//}
