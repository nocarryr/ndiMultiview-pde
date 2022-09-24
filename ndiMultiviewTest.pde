//import java.util.Map;
import java.awt.Frame;
import java.awt.Shape;
import java.awt.Rectangle;
import processing.awt.*;
import processing.awt.ShimAWT;
import java.nio.ByteBuffer;
import java.io.File;
import me.walkerknapp.devolay.*;
import controlP5.*;

boolean isFullScreen = false;
int fullScreenDisplay = 0;
int confSaveInterval = 60;
int lastConfSaveFrame = -1;
int nextConfSaveFrame = -1;

WindowGrid windowGrid;
PFont windowFont;
DevolayFinder ndiFinder;
DevolaySource[] ndiSourceArray;
boolean updatingSources = false;
boolean sourcesUpdated = false;
boolean loopInitial = true;
int lastSourceUpdateFrame = 0;
float sourceUpdateTimeInterval = 60;
HashMap<String,DevolaySource> ndiSources;
PGraphics dstCanvas;
Box windowBounds;
ControlP5 cp5;

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

void saveConfig(JSONObject json){
  File confFile = getConfigFile();
  System.out.println("saveConfig: " + confFile.getAbsolutePath());
  saveJSONObject(json, confFile.getPath());
}

void saveConfig(){
  //JSONObject json = new JSONObject();
  //if (windowBounds != null){
  //  json.setJSONObject("windowBounds", windowBounds.serialize());
  //}
  //Point canvasSize = new Point(width, height);
  //json.setJSONObject("canvasSize", canvasSize.serialize());
  //json.setBoolean("isFullScreen", isFullScreen);
  //json.setInt("fullScreenDisplay", fullScreenDisplay);
  //json.setJSONObject("windowGrid", windowGrid.serialize());
  try {
    Config config = new Config();
    JSONObject json = config.serialize();
    saveConfig(json);
  } catch(Exception e){
    e.printStackTrace();
    throw(e);
  }
  
}

void setup(){
  cp5 = new ControlP5(this);
  windowFont = createFont("Georgia", 12);
  ndiSourceArray = new DevolaySource[0];
  ndiSources = new HashMap<String,DevolaySource>();
  System.out.println("loadingLibraries...");
  Devolay.loadLibraries();
  ndiFinder = new DevolayFinder();
  
  //JSONObject confData = loadConfig();
  Config config = getConfig();
  System.out.println("Creating WindowGrid...");
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
  
  size(800, 450);
  dstCanvas = createGraphics(width, height);
  config.windowGrid.outputSize = new Point(width, height);
  windowGrid = new WindowGrid(config.windowGrid);
  
  //if (confData.isNull("windowGrid")){
  //  windowGrid = new WindowGrid(2, 2, width, height);
  //} else {
  //  windowGrid = new WindowGrid(confData.getJSONObject("windowGrid"), width, height);
  //}
  //windowGrid.setOutputSize(width, height);
  System.out.println("setup complete");
}

Box getWindowDims(){
  PSurfaceAWT.SmoothCanvas nativeWin = (PSurfaceAWT.SmoothCanvas)surface.getNative();
  java.awt.Rectangle bBox = nativeWin.getFrame().getBounds();
  Box b = new Box(bBox.x, bBox.y, bBox.width, bBox.height);
  return b;
}

void draw(){
  updateNdiSources();
  if (exitCalled){
    System.out.println("Closing resources");
    windowGrid.close();
    return;
  }
  
  background(0);
  dstCanvas.beginDraw();
  dstCanvas.background(0);
  windowGrid.render(dstCanvas);
  dstCanvas.endDraw();
  image(dstCanvas, 0, 0);
  //textFont(windowFont);
  //stroke(255);
  //fill(255);
  //textAlign(LEFT, BOTTOM);
  //text(String.format("%dfps, frame: %d", (int)frameRate, frameCount), 0, height / 3);
  
  //float numFrames = calcUpdateNumFrames();
  //int nextFrame = calcNextUpdateFrame();
  //stroke(255);
  //fill(255);
  //textAlign(RIGHT, BOTTOM);
  //text(String.format("nFrames: %d, prev: %d, next: %d", (int)numFrames, lastSourceUpdateFrame, nextFrame), width, height / 2);
  loopInitial = false;
  confAutoSave();
}

public class MultiviewApplet extends PApplet {
  MultiviewApplet(){
    
  }

  public void settings() {
    size(200, 100);
  }
  public void draw() {
    background(255);
    fill(0);
    ellipse(100, 50, 10, 10);
  }
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

int secondsToFrame(float sec){
  float fr = frameRate;
  if (fr == 0){
    fr = 1;
  }
  return (int)(fr * sec);
}

float frameToSeconds(int f){
  float fr = frameRate;
  if (fr == 0){
    fr = 1;
  }
  return f / fr;
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

void updateNdiSources(){
  if (sourcesUpdated){
    System.out.println("sourcesUpdated");
    sourcesUpdated = false;
    lastSourceUpdateFrame = frameCount;
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
  int nextFrame = frameCount + numFrames;
  if (loopInitial || frameCount >= nextFrame){
    updatingSources = true;
    thread("_updateNDISources");
  }
}

void _updateNDISources() {
  System.out.println("updateNdiSources");
  int timeout = 5000;
  int maxTries = 1;
  updatingSources = true;
  
  //DevolayFinder finder = new DevolayFinder();
  DevolayFinder finder = ndiFinder;
  int numAttempts = 0;
  try {
    DevolaySource[] sources = new DevolaySource[0];
    //while ((sources = ndiFinder.getCurrentSources()).length == 0){
    while (numAttempts < maxTries){
      sources = finder.getCurrentSources();
      if (sources.length > 0){
        break;
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
  }
}
