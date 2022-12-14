

class FrameHandler {
  boolean connecting = false;
  boolean maybeConnected = false;
  long numFrames = 0, droppedFrames = 0, totalFrames = 0;
  int maxRenders, inFlight, maxInFlight;
  String sourceName = "";
  DevolayFrameFormatType formatType;
  Point videoResolution;
  boolean fielded = false;
  String formatString = "No Signal";
  int frNumerator = 0, frDenominator = 1;
  Deque<Integer> readQueue, writeQueue;
  FrameThread frameThread;
  DevolayReceiver ndiReceiver;
  DevolayVideoFrame videoFrame;
  DevolayAudioFrame audioFrame;
  DevolayMetadataFrame metadataFrame;
  private CombinedTally tally;

  int nextWriteIndex = 0, nextReadIndex = -1;
  NDIImageHandler[] images;
  NDIAudioHandler audio;
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
    tally = new CombinedTally();
    maxRenders = 0;
    inFlight = 0;
    maxInFlight = 0;
    videoResolution = new Point(0, 0);
    readQueue = new ArrayDeque<Integer>();
    writeQueue = new ArrayDeque<Integer>();
    images = new NDIImageHandler[4];
    for (int i=0; i<images.length; i++){
      images[i] = new NDIImageHandler(this, i);
    }
    audio = new NDIAudioHandler(this);
    fillWriteQueue();
    assert writeQueue.size() == images.length - 1;
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

  NDIImageHandler getNextReadImage(){
    rLock.lock();
    NDIImageHandler result = null;
    int idx = -1;
    try {
      if (readQueue.size() == 0){
        idx = nextReadIndex;
      } else {
        idx = readQueue.pop();
        if (readQueue.size() == 0){
          readQueue.addFirst(idx);
        }
      }
      if (idx != -1){
        result = images[idx];
      }
      nextReadIndex = idx;
    } finally {
      rLock.unlock();
    }
    return result;
  }

  private void fillWriteQueue(){
    wLock.lock();
    try {
      rLock.lock();
      try {
        for (int i=0; i<images.length; i++){
          if (writeQueue.contains(i) || i == nextReadIndex || i == nextWriteIndex){
            continue;
          } else if (readQueue.contains(i)){
            readQueue.remove(i);
            //continue;
          }
          writeQueue.addLast(i);
        }
      } finally {
        rLock.unlock();
      }
    } finally {
      wLock.unlock();
    }
  }

  NDIImageHandler getNextWriteImage(){
    wLock.lock();
    NDIImageHandler result = null;
    int idx = -1;
    try {
      if (writeQueue.size() > 0){
        idx = writeQueue.pop();
      } else {
        idx = -1;
      }
      nextWriteIndex = idx;
      fillWriteQueue();
      if (idx != -1){
        result = images[idx];
      }
    } finally {
      wLock.unlock();
    }
    return result;
  }

  void setImageWriteComplete(NDIImageHandler img){
    wLock.lock();
    try {
      rLock.lock();
      try {
        img.readReady = true;
        readQueue.addLast(img.index);
        inFlight = readQueue.size();
        if (inFlight > maxInFlight){
          maxInFlight = inFlight;
        }
      } finally {
        rLock.unlock();
      }
    } finally {
      wLock.unlock();
    }
  }

  private void resetQueues(){
    wLock.lock();
    try {
      rLock.lock();
      try {
        nextReadIndex = -1;
        nextWriteIndex = 0;
        readQueue.clear();
        writeQueue.clear();
      } finally {
        rLock.unlock();
      }
    } finally {
      wLock.unlock();
    }
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
      resetQueues();
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
      ndiReceiver = new DevolayReceiver(source, DevolayReceiver.ColorFormat.RGBX_RGBA, DevolayReceiver.RECEIVE_BANDWIDTH_HIGHEST, true, null);
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
    maxRenders = 0;
    inFlight = 0;
    maxInFlight = 0;
    maybeConnected = false;
    resetQueues();
    updateVideoFormat();
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

  private boolean setTally(Tally _tally){
    //synchronized(this){
      tally.local(_tally);
      println(String.format("Tally from setter: %s", tally));
      if (ndiReceiver == null){
        return false;
      }
    //}
    return ndiReceiver.setTally(_tally.toDevolay());
  }

  Tally tally(){ return tally.local; }
  boolean tally(Tally _tally){
    return setTally(_tally);
  }

  CombinedTally globalTally(){
    return tally;
  }

  boolean globalProgramTally(){
    return tally.or().program();
  }

  boolean globalPreviewTally(){
    return tally.or().preview();
  }

  boolean programTally(){ return tally.local.program(); }
  boolean programTally(boolean state){
    Tally t = new Tally(state, tally.local().preview());
    return tally(t);
  }

  boolean previewTally(){ return tally.local.preview(); }
  boolean previewTally(boolean state){
    Tally t = new Tally(tally.local().program, state);
    return tally(t);
  }

  void processMetadata(){
    try {
      //synchronized(this) {
        String metadata = metadataFrame.getData();
        XML parsed = XML.parse(metadata);
        if (parsed.getName() == "ndi_tally_echo"){
          assert parsed.hasAttribute("on_program") && parsed.hasAttribute("on_preview");
          boolean pgm = parsed.getString("on_program").contains("true"),
                  pvw = parsed.getString("on_preview").contains("true");
          DevolayTally d = new DevolayTally(pgm, pvw);
          tally.source(d);
          println(String.format("Tally from meta: %s", tally));
        }
      //}
    } catch(Exception e){
      e.printStackTrace();
    }
  }

  void updateVideoFormat(){
    if (videoFrame == null || !maybeConnected){
      formatType = null;
      videoResolution = new Point(0, 0);
      updateFormatString();
      return;
    }
    boolean changed = false;
    DevolayFrameFormatType ftype = videoFrame.getFormatType();
    boolean _fielded = ftype != DevolayFrameFormatType.PROGRESSIVE;
    if (_fielded != fielded){
      fielded = _fielded;
      changed = true;
    }
    if (ftype != formatType){
      formatType = ftype;
      //changed = true;
    }
    Point res = new Point(videoFrame.getXResolution(), videoFrame.getYResolution());
    if (!(videoResolution.equals(res))){
      changed = true;
      videoResolution = res;
    }
    int frN = videoFrame.getFrameRateN(), frD = videoFrame.getFrameRateD();
    if (frN != frNumerator || frD != frDenominator){
      frNumerator = frN;
      frDenominator = frD;
      changed = true;
    }
    if (changed){
      updateFormatString();
    }
  }

  void updateFormatString(){
    if (formatType == null){
      formatString = "No Signal";
      return;
    }
    String fmt = "%d%s";
    String fieldStr = fielded ? "i" : "p";
    float fr = frNumerator / float(frDenominator);
    boolean isFractional = fr == floor(fr);
    if (isFractional){
      fmt = fmt + "%d";
      formatString = String.format(fmt, int(videoResolution.y), fieldStr, int(fr));
    } else {
      fmt = fmt + "%4.2f";
      formatString = String.format(fmt, int(videoResolution.y), fieldStr, fr);
    }
  }

  DevolayFrameType getFrame(int timeout) {

    DevolayFrameType frameType = DevolayFrameType.NONE;
    //try {
      //frameType = ndiReceiver.receiveCapture(videoFrame, audioFrame, metadataFrame, timeout);
      frameType = ndiReceiver.receiveCapture(videoFrame, audioFrame, metadataFrame, timeout);
    //} finally {
    //  lastFrameType = frameType;
    //}
    if (frameType == DevolayFrameType.VIDEO){
      numFrames += 1;
      updateVideoFormat();
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

class Tally {
  private boolean program = false, preview = false;
  Tally(){

  }
  Tally(boolean pgm, boolean pvw){
    program = pgm;
    preview = pvw;
  }
  Tally(DevolayTally t){
    program = t.isOnProgram();
    preview = t.isOnPreview();
  }

  Tally copy(){
    return new Tally(program, preview);
  }

  boolean program(){ return this.program; }
  boolean preview(){ return this.preview; }

  Tally or(Tally other){
    Tally result = new Tally(program || other.program(), preview || other.preview());
    return result;
  }

  Tally and(Tally other){
    Tally result = new Tally(program && other.program(), preview && other.preview());
    return result;
  }

  DevolayTally toDevolay(){
    DevolayTally result = new DevolayTally(program, preview);
    return result;
  }

  String toString(){
    return String.format("program=%s, preview=%s", program, preview);
  }
}

class CombinedTally {
  private Tally local, source;
  CombinedTally(){
    local = new Tally();
    source = new Tally();
  }
  CombinedTally(Tally _local, Tally _source){
    local = _local;
    source = _source;
  }

  CombinedTally copy(){
    return new CombinedTally(local.copy(), source.copy());
  }

  Tally local(){ return this.local; }
  void local(Tally t){ this.local = t; }
  void local(DevolayTally t){ this.local = new Tally(t); }

  Tally source(){ return this.source; }
  void source(Tally t){ this.source = t; }
  void source(DevolayTally t){ this.source = new Tally(t); }

  Tally or(){ return local.or(source); }
  Tally and(){ return local.and(source); }

  String toString(){
    return String.format("local: '%s', source: '%s'", local, source);
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
  int numRenders;

  NDIImageHandler(FrameHandler _parent, int _index){
    parent = _parent;
    index = _index;
    resolution = new Point(1920, 1080);
    image = new PImage((int)resolution.x, (int)resolution.y, ARGB);
    rwLock = new ReentrantReadWriteLock();
    rLock = rwLock.readLock();
    wLock = rwLock.writeLock();
    numRenders = 0;
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
      numRenders += 1;
      if (numRenders > parent.maxRenders){
        parent.maxRenders = numRenders;
      }
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
      numRenders = 0;
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
    //println(videoFrame.getFormatType());
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

class NDIAudioHandler {
  FrameHandler parent;
  int sampleRate, nChannels, blockSize, stride;
  private boolean initialized = false;
  boolean meterChanged = false;
  AudioMeter meter;
  NDIAudioHandler(FrameHandler _parent){
    parent = _parent;
    initialized = false;
    meter = new AudioMeter(1, 4, 1);
  }

  void setInitData(DevolayAudioFrame frame){
    sampleRate = frame.getSampleRate();
    nChannels = frame.getChannels();
    blockSize = frame.getSamples();
    //Box bbox = meter.boundingBox.copy();
    synchronized(this){
      meter = new AudioMeter(sampleRate, nChannels, blockSize);
      meterChanged = true;
    }
    //meter.boundingBox = bbox;
    //setMeterChanged(true);
  }

  void processFrame(){
    DevolayAudioFrame frame = parent.audioFrame;
    if (!initialized){
      setInitData(frame);
      initialized = true;
    }
    stride = frame.getChannelStride();
    //meter.processSamples(frame.getData(), frame.getSamples(), frame.getChannelStride());
    meter.processSamples(frame);
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
        switch (ft){
          case VIDEO:
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
                handler.setImageWriteComplete(img);
              } else {
                println("img is null :(");
              }
            }
            break;

          case AUDIO:
            handler.audio.processFrame();
            break;

          case METADATA:
            handler.processMetadata();
            break;
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
