import java.util.Map;
import java.nio.ByteBuffer;
import me.walkerknapp.devolay.*;

WindowGrid windowGrid;
PFont windowFont;
DevolayFinder ndiFinder;
HashMap<String,DevolaySource> ndiSources;
PGraphics dstCanvas;

void setup(){
  windowFont = createFont("Georgia", 12);
  ndiSources = new HashMap<String,DevolaySource>();
  System.out.println("loadingLibraries...");
  Devolay.loadLibraries();
  ndiFinder = new DevolayFinder();
  System.out.println("Creating WindowGrid...");
  windowGrid = new WindowGrid(2, 2, 0, 0);
  size(640, 360);
  dstCanvas = createGraphics(width, height);
  windowGrid.setOutputSize(width, height);
  windowGrid.addWindow("A", 0, 0, "");
  windowGrid.addWindow("B", 0, 1, "");
  windowGrid.addWindow("C", 1, 0, "");
  windowGrid.addWindow("D", 1, 1, "");
  System.out.println("setup complete");
}

void draw(){
  background(0);
  dstCanvas.beginDraw();
  dstCanvas.background(0);
  windowGrid.render(dstCanvas);
  dstCanvas.endDraw();
  image(dstCanvas, 0, 0);
}

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
