import java.util.Arrays;
import java.nio.ByteBuffer;
import java.nio.IntBuffer;


class FrameHandler {
  boolean connecting = false;
  boolean maybeConnected = false;
  long numFrames = 0, droppedFrames = 0, totalFrames = 0;
  String sourceName = "";
  FrameThread frameThread;
  DevolayReceiver ndiReceiver;
  DevolayVideoFrame videoFrame;
  DevolayAudioFrame audioFrame;
  DevolayMetadataFrame metadataFrame;
  
  int nextWriteIndex = 0, nextReadIndex = -1;
  NDIImageHandler[] images;
  Object stateLockObj;
  ReentrantReadWriteLock rwLock;
  Lock rLock;
  Lock wLock;
  
  private boolean _isOpen = false;
  
  FrameHandler(){
    stateLockObj = new Object();
    rwLock = new ReentrantReadWriteLock();
    rLock = rwLock.readLock();
    wLock = rwLock.writeLock();
    images = new NDIImageHandler[4];
    for (int i=0; i<images.length; i++){
      images[i] = new NDIImageHandler(this, i);
    }
    //open();
  }
  
  public void open(){
    if (_isOpen){
      return;
    }
    assert frameThread == null;
    frameThread = new FrameThread(this);
    frameThread.start();
    _isOpen = true;
  }
  
  public void close(){
    if (!_isOpen){
      return;
    }
    maybeConnected = false;
    if (frameThread != null){
      synchronized(stateLockObj){
        frameThread.running = false;
        stateLockObj.notifyAll();
      }
      frameThread = null;
    }
    disconnect();
    _isOpen = false;
  }
  
  public boolean isOpen(){
    return _isOpen;
  }
  
  int incrementWriteIndex(){
    wLock.lock();
    int idx = nextWriteIndex + 1;
    int result = -1;
    int iterCount = 0;
    try {
      //result = 0;
      if (idx >= images.length){
        idx = 0;
      }
      while (iterCount <= images.length){
        if (idx != nextReadIndex){
          result = idx;
          break;
        }
        idx += 1;
        
        iterCount += 1;
      }
      nextWriteIndex = result;
    } finally {
      wLock.unlock();
    }
    return result;
  }
  
  void setReadIndex(int idx){
    rLock.lock();
    nextReadIndex = idx;
    rLock.unlock();
  }
  
  NDIImageHandler getNextReadImage(){
    rLock.lock();
    int idx = nextReadIndex;
    NDIImageHandler result = null;
    try {
      if (idx != -1){
        result = images[idx];
      }
    } finally {
      rLock.unlock();
    }
    return result;
  }
  
  NDIImageHandler getNextWriteImage(){
    wLock.lock();
    int idx = nextWriteIndex;
    NDIImageHandler result = null;
    try {
      if (idx != -1){
        result = images[idx];
      }
    } finally {
      wLock.unlock();
    }
    return result;
  }
  
  private void notifyConnected(){
    if (!maybeConnected){
      return;
    }
    if (frameThread != null){
      synchronized(stateLockObj){
        stateLockObj.notifyAll();
      }
    }
  }
  
  public void connectToSource(DevolaySource source){
    if (source == null && !maybeConnected){
      return;
    }
    println("connectToSource");
    synchronized(stateLockObj){
      _connectToSource(source);
    }
  }
  
  private void _connectToSource(DevolaySource source){
    if (ndiReceiver != null){
      ndiReceiver.connect(source);
      if (source == null){
        //ndiReceiver.connect(null);
        //disconnect();
        sourceName = "";
        maybeConnected = false;
      } else {
        sourceName = source.getSourceName();
        maybeConnected = true;
      }
      notifyConnected();
      return;
    }
    
    if (source == null){
      maybeConnected = false;
      sourceName = "";
      return;
    }
    println("create ndiReceiver");
    connecting = true;
    try {
      ndiReceiver = new DevolayReceiver(source, DevolayReceiver.ColorFormat.RGBX_RGBA, DevolayReceiver.RECEIVE_BANDWIDTH_HIGHEST, false, null);
      videoFrame = new DevolayVideoFrame();
      audioFrame = new DevolayAudioFrame();
      metadataFrame = new DevolayMetadataFrame();
      maybeConnected = true;
      println("receiver created");
      sourceName = source.getSourceName();
    } catch (Exception e){
      maybeConnected = false;
      e.printStackTrace();
      throw(e);
    } finally {
      connecting = false;
      println("maybeConnected: ", maybeConnected);
    }
    notifyConnected();
  }
  
  public void disconnect(){
    synchronized(stateLockObj){
      _disconnect();
    }
  }
  
  private void _disconnect(){
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
    sourceName = "";
    ndiReceiver = null;
    connecting = false;
    numFrames = 0;
    droppedFrames = 0;
    maybeConnected = false;
  }
  
  boolean isConnected(){
   if (sourceName == ""){
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
  
  DevolayFrameType getFrame(int timeout) {
    
    DevolayFrameType frameType = DevolayFrameType.NONE;
    //try {
      //frameType = ndiReceiver.receiveCapture(videoFrame, audioFrame, metadataFrame, timeout);
      frameType = ndiReceiver.receiveCapture(videoFrame, null, null, timeout);
    //} finally {
    //  lastFrameType = frameType;
    //}
    if (frameType == DevolayFrameType.VIDEO){
      numFrames += 1;
    }
    if (frameType != DevolayFrameType.NONE){
      DevolayPerformanceData performanceData = new DevolayPerformanceData();
      try {
        ndiReceiver.queryPerformance(performanceData);
        droppedFrames = performanceData.getDroppedVideoFrames();
        totalFrames = performanceData.getTotalVideoFrames();
        //if (_droppedFrames != droppedFrames){
        //  droppedFrames = _droppedFrames;
        //}
      } finally {
        performanceData.close();
      }
    }
    return frameType;
  }
}

class NDIImageHandler implements PConstants{
  FrameHandler parent;
  int index;
  Point resolution;
  PImage image;
  ReentrantReadWriteLock rwLock;
  Lock rLock;
  Lock wLock;
  boolean writeReady = true, readReady = true, isBlank = true;
  
  NDIImageHandler(FrameHandler _parent, int _index){
    parent = _parent;
    index = _index;
    resolution = new Point(1920, 1080);
    image = new PImage((int)resolution.x, (int)resolution.y, ARGB);
    rwLock = new ReentrantReadWriteLock();
    rLock = rwLock.readLock();
    wLock = rwLock.writeLock();
  }
  
  int getWidth(){ return (int)resolution.x; }
  int getHeight(){ return (int)resolution.y; }
  void setWidth(float w){ resolution.x = w; }
  void setHeight(float h){ resolution.y = h; }
  void setResolution(float w, float h){
    resolution.x = w;
    resolution.y = h;
  }
  
  boolean drawToCanvas(PGraphics canvas, Box dims){
    boolean acquired = wLock.tryLock();
    if (!acquired){
      return false;
    }
    try {
      if (!parent.maybeConnected && !isBlank){
        Arrays.fill(image.pixels, 0xff000000);
        isBlank = true;
      }
      //assert readReady;
      image.updatePixels();
      canvas.image(image, dims.getX(), dims.getY(), dims.getWidth(), dims.getHeight());
    } finally {
      //writeReady = true;
      //readReady = false;
      wLock.unlock();
      //parent.incrementReadIndex();
    }
    return true;
  }
  
  boolean setImagePixels(DevolayVideoFrame videoFrame){
    //println("setImagePixels");
    boolean result = false;
    wLock.lock();
    readReady = false;
    try {
      assert writeReady;
      result = _setImagePixels(videoFrame);
      readReady = true;
      //writeReady = false;
      isBlank = false;
    } catch (Exception e){
      e.printStackTrace();
      throw(e);
    } finally {
      wLock.unlock();
    }
    //parent.incrementWriteIndex();
    return result;
  }
  
  boolean _setImagePixels(DevolayVideoFrame videoFrame){
    int frameWidth = videoFrame.getXResolution();
    int frameHeight = videoFrame.getYResolution();
    DevolayFrameFourCCType fourCC = videoFrame.getFourCCType();
    assert (fourCC == DevolayFrameFourCCType.RGBA || fourCC == DevolayFrameFourCCType.RGBX);
    
    if (frameWidth == 0 || frameHeight == 0){
      System.out.println("frameSize = 0");
      setResolution(0, 0);
      return false;
    }
    if (getWidth() != frameWidth || getHeight() != frameHeight){
      System.out.println(String.format("resize image to %dx%d", frameWidth, frameHeight));
      setResolution(frameWidth, frameHeight);
      if (getWidth() != image.width || getHeight() != image.height){
        image.init(frameWidth, frameHeight, ARGB);
      }
      assert image.pixels.length == getWidth() * getHeight();
    }
    assert videoFrame.getLineStride() == frameWidth * 4;
    
    if (fourCC == DevolayFrameFourCCType.RGBA){
      videoFrameToImageArr_RGBA(videoFrame, image.pixels);
    } else {
      videoFrameToImageArr_RGBX(videoFrame, image.pixels);
    }
    image.updatePixels();
    return true;
  }
}

class FrameThread extends Thread {
  FrameHandler handler;
  boolean running = false;
  Exception error;
  FrameThread(FrameHandler _handler){
    handler = _handler;
  }
  
  public void run(){
    println("FrameThread run start");
    running = true;
    while (running){
      try {
        if (!handler.maybeConnected){
          synchronized (handler.stateLockObj){
            try{
              while (!handler.maybeConnected){
                handler.stateLockObj.wait();
              }
            } catch (InterruptedException e) {
              
            }
          }
          //println("first wait complete");
          if (!running){
            break;
          }
          if (!handler.maybeConnected){
            break;
          }
        }
        //println("getting frame");
        DevolayFrameType ft = handler.getFrame(100);
        //println(ft);
        if (ft == DevolayFrameType.VIDEO){  
        
          NDIImageHandler img = null;
          //println("locking");
          synchronized(handler.stateLockObj){
            if (!handler.maybeConnected){
              continue;
            }
            img = handler.getNextWriteImage();
            if (img != null){
              //println("got img");
              img.setImagePixels(handler.videoFrame);
              img.readReady = true;
              handler.setReadIndex(img.index);
              handler.incrementWriteIndex();
            } else {
              println("img is null :(");
            }
          }
        }
      } catch(Exception e){
        e.printStackTrace();
        throw(e);
      }
    }
    running = false;
    println("FrameThread run stop");
  }
}

void videoFrameToImageArr_RGBA(DevolayVideoFrame videoFrame, int[] pixelArray){
  int frameWidth = videoFrame.getXResolution();
  int frameHeight = videoFrame.getYResolution();
  ByteBuffer framePixels = videoFrame.getData();
  IntBuffer framePixelsInt = framePixels.asIntBuffer();
  
  int numPixels = frameWidth * frameHeight;
  
  for (int i=0; i<numPixels; i++){
    int colorValue = framePixelsInt.get();
    int alpha = colorValue & 0xff;
    colorValue = (colorValue >> 8) | alpha << 24;
    pixelArray[i] = colorValue;
  }
}

void videoFrameToImageArr_RGBX(DevolayVideoFrame videoFrame, int[] pixelArray){
  int frameWidth = videoFrame.getXResolution();
  int frameHeight = videoFrame.getYResolution();
  ByteBuffer framePixels = videoFrame.getData();
  IntBuffer framePixelsInt = framePixels.asIntBuffer();
  
  int numPixels = frameWidth * frameHeight;
  int alphaMask = 0xff << 24;
  
  for (int i=0; i<numPixels; i++){
    pixelArray[i] = (framePixelsInt.get() >> 8) | alphaMask;
  }
}
