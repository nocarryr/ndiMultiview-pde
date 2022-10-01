//import java.util.Map;
import java.awt.Frame;
import java.awt.Shape;
import java.awt.Rectangle;
import java.awt.GraphicsEnvironment;
import java.awt.GraphicsDevice;
import java.awt.DisplayMode;
import processing.awt.*;
import processing.awt.ShimAWT;
import java.io.File;
import me.walkerknapp.devolay.*;
import controlP5.*;

MultiviewApplet mvApp;
PFont baseWindowFont;
int confSaveInterval = 60;
float resizeCheckInterval = .25;
boolean baseloopInitial = true;
float sourceUpdateTimeInterval = 10;
ControlP5 basecp5;


JSONObject loadConfig(){
  File confFile = getConfigFile();
  System.out.println("loadConfig: " + confFile.getPath());
  if (!confFile.exists()){
    return new JSONObject();
  }
  return loadJSONObject(confFile.getPath());
}

Config getConfig(){
  File confFile = getConfigFile();
  System.out.println("loadConfig: " + confFile.getPath());
  if (!confFile.exists()){
    return new Config();
  }
  JSONObject json = loadJSONObject(confFile.getPath());
  return new Config(json);
}



void setup(){
  String[] args = {"--sketch-path="+sketchPath(), "NDI Multiviewer"};
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

  if (baseloopInitial && !mvApp.loopInitial){
    basecp5.getController("fullScreenToggle").setValue(mvApp.isFullScreen ? 1 : 0);
    baseloopInitial = false;
  }
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
  Object ndiSourceLock = new Object();
  Object ndiSourceNotify = new Object();
  boolean isFullScreen = false;
  boolean updatingSources = false;
  boolean sourcesUpdated = false;
  boolean loopInitial = true;
  int lastSourceUpdateFrame = 0;
  int lastConfSaveFrame = -1;
  int nextConfSaveFrame = -1;
  HashMap<String,DevolaySource> ndiSources;
  Box windowBounds;
  ControlP5 cp5;

  public void settings() {
    config = getConfig();
    isFullScreen = config.app.fullScreen;
    if (config.app.fullScreen){
      fullScreen(P3D, config.app.displayNumber);
    } else {
      int maxWidth = displayWidth - 100;
      int maxHeight = displayHeight - 100;
      if (config.app.canvasSize.x >= maxWidth){
        config.app.canvasSize.x = maxWidth;
      }
      if (config.app.canvasSize.y >= maxHeight){
        config.app.canvasSize.y = maxHeight;
      }
      size((int)config.app.canvasSize.x, (int)config.app.canvasSize.y, P3D);
    }
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
    this.frameRate(60);
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

    windowFont = createFont("Georgia", 12, true);
    ndiSourceArray = new DevolaySource[0];
    ndiSources = new HashMap<String,DevolaySource>();
    System.out.println("loadingLibraries...");
    Devolay.loadLibraries();
    ndiFinder = new DevolayFinder();
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
    g.background(0);
    windowGrid.render(g);
    loopInitial = false;
  }

  void checkResize(){
    //int frInterval = secondsToFrame(resizeCheckInterval);
    if ((int)frameCount % 120 != 0){
      return;
    }
    if ((int)this.width != windowGrid.outWidth || (int)this.height != windowGrid.outHeight){
      println("resize canvas");
      cp5.setGraphics(this, 0, 0);

      Box btnBox = new Box(0, 0, 40, 20);
      btnBox.setRight(width);
      Button btn = (Button)cp5.getController("closeBtn");
      btn.setPosition(btnBox.getX(), btnBox.getY())
         .setSize((int)btnBox.getWidth(), (int)btnBox.getHeight());

      btnBox.setRight(btnBox.getX() - 10);
      btn = (Button)cp5.getController("fullScreenToggle");
      btn.setPosition(btnBox.getX(), btnBox.getY())
         .setSize((int)btnBox.getWidth(), (int)btnBox.getHeight());

      windowGrid.setOutputSize((int)this.width, (int)this.height);
      saveConfig();
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
      //windowBounds = getWindowDims();
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
    thread("_updateNDISources");
  }

  void _updateNDISources() {
    System.out.println("updateNdiSources");
    int timeout = 8000;
    int maxTries = 5;
    updatingSources = true;

    //DevolayFinder finder = new DevolayFinder();
    DevolayFinder finder = ndiFinder;
    int numAttempts = 0;
    boolean changed = false;
    if (!loopInitial){
      changed = finder.waitForSources(timeout);
      if (!changed){
        sourcesUpdated = false;
        updatingSources = false;
        println("updateExit");
        return;
      }
    }
    synchronized(ndiSourceLock){
      DevolaySource[] sources = new DevolaySource[0];
      sources = finder.getCurrentSources();
      ndiSources.clear();
      for (int i=0;i<sources.length;i++){
        ndiSources.put(sources[i].getSourceName(), sources[i]);
        System.out.println(sources[i].getSourceName());
      }
      ndiSourceArray = sources;
      sourcesUpdated = true;
      updatingSources = false;
      ndiSourceLock.notifyAll();
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
