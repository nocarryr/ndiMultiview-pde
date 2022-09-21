import java.util.Map;
import java.nio.ByteBuffer;
import me.walkerknapp.devolay.*;
import controlP5.*;


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
StringList fakeSourceArray;
HashMap<String,String> fakeSources;
PGraphics dstCanvas;
ControlP5 cp5;

void setup(){
  cp5 = new ControlP5(this);
  windowFont = createFont("Georgia", 12);
  fakeSources = new HashMap<String,String>();
  fakeSources.put("Foo", "foo");
  fakeSources.put("Bar", "bar");
  ndiSourceArray = new DevolaySource[0];
  ndiSources = new HashMap<String,DevolaySource>();
  //fakeSourceArray = new String[](["Foo", "Bar"]);
  fakeSourceArray = new StringList();
  fakeSourceArray.append("Foo");
  fakeSourceArray.append("Bar");
  System.out.println("loadingLibraries...");
  Devolay.loadLibraries();
  ndiFinder = new DevolayFinder();
  
  System.out.println("Creating WindowGrid...");
  windowGrid = new WindowGrid(2, 2, 0, 0);
  size(800, 450);
  dstCanvas = createGraphics(width, height);
  windowGrid.setOutputSize(width, height);
  Window win = windowGrid.addWindow("A", 0, 0, "");
  //win.ndiSourceName = "Foo";
  //win.setSourceName("BIRDDOG-1F8A1 (CAM)");
  
  windowGrid.addWindow("B", 0, 1, "");
  windowGrid.addWindow("C", 1, 0, "");
  windowGrid.addWindow("D", 1, 1, "");
  
  //updateNdiSources();
  System.out.println("setup complete");
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
}


float calcUpdateNumFrames(){
  float fr = frameRate;
  if (fr == 0){
    fr = 1;
  }
  //return sourceUpdateTimeInterval / fr;
  //return fr / sourceUpdateTimeInterval;
  return fr * sourceUpdateTimeInterval;
}

int calcNextUpdateFrame(){
  float numFrames = calcUpdateNumFrames();
  return lastSourceUpdateFrame + (int)numFrames;
}

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
  int nextFrame = calcNextUpdateFrame();
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
