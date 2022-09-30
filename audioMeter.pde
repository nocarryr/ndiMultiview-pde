double NINF = Double.NEGATIVE_INFINITY;

class AudioMeter {  
  double[] rmsDbfs, rmsDbu, peakDbfs, peakDbu, peakAmp;
  int sampleRate, nChannels, blockSize, stride;
  float avgTime = .1;
  int[] bufferLength;
  //float[] ticks = {0, -6, -12, -18, -24, -36, -48, -60, -90, -140};
  float[] ticks = {0, -10, -20, -30, -40, -50, -60, -70};
  float maxTick = 0;
  float minTick = -70;
  int nTickContainers;
  Box boundingBox;
  Box[] channelBoxes;
  MeterTickContainer[] tickContainers;
  AudioMeterChannel[] meterChannels;
  AudioMeter(int fs, int nch, int _blockSize){
    boundingBox = new Box(0, 0, 20, 20);
    sampleRate = fs;
    nChannels = nch;
    blockSize = _blockSize;
    rmsDbfs = new double[nChannels];
    rmsDbu = new double[nChannels];
    peakDbfs = new double[nChannels];
    peakDbu = new double[nChannels];
    peakAmp = new double[nChannels];
    bufferLength = new int[nChannels];
    
    float tickWidth = boundingBox.getWidth() / (nChannels / 2); 
    float channelWidth = tickWidth / 3;
    tickContainers = new MeterTickContainer[int(nChannels / 2)];
    meterChannels = new AudioMeterChannel[nChannels];
    
    nTickContainers = 0;
    int tickIdx = -1;
    for (int i=0; i<nChannels; i++){
      rmsDbfs[i] = NINF;
      rmsDbu[i] = NINF;
      peakDbfs[i] = NINF;
      peakDbu[i] = NINF;
      peakAmp[i] = 0;
      bufferLength[i] = 0;
      if (i % 2 == 0){
        tickIdx += 1;
        MeterTickContainer tickContainer = new MeterTickContainer(this);
        tickContainer.setWidth(tickWidth);
        tickContainer.setX(tickWidth * tickIdx + (channelWidth * (i % 2)) + boundingBox.getX());
        tickContainer.setY(boundingBox.getY());
        //if (i == 0) {
        //  tickContainer.setX(boundingBox.getX());
        //} else {
        //  tickContainer.setX(tickContainers[tickIdx-1].getRight());
        //}
        tickContainers[tickIdx] = tickContainer;
        nTickContainers += 1;
      }
      meterChannels[i] = new AudioMeterChannel(this, i);
      Box b = boundingBox.copy();
      b.setWidth(channelWidth);
      b.setX(channelWidth * i * 2 + boundingBox.getX());
      //if (i % 2 != 0){
      //  b.setX(tickContainers[tickIdx].getX());
      //} else {
      //  b.setRight(tickContainers[tickIdx].getRight());
      //}
        
      //b.setX(b.getWidth() * i + boundingBox.getX());
      meterChannels[i].setBoundingBox(b);
    }
  }
  
  void setBoundingBox(Box b){
    boundingBox = b.copy();
    float tickWidth = boundingBox.getWidth() / (nChannels / 2); 
    float channelWidth = tickWidth / 3;
    for (int i=0; i<nTickContainers; i++){
      Box t = b.copy();
      t.setWidth(tickWidth);
      t.setX(tickWidth * i + (channelWidth * (i % 2)) + b.getX());
      tickContainers[i].setBox(t);
    }
    for (int i=0; i<nChannels; i++){
      b.setWidth(channelWidth);
      b.setX(channelWidth * i * 2 + boundingBox.getX());
      meterChannels[i].setBoundingBox(b);
    }
  }
  
  float dbToYPos(double dbVal){
    double dbMax = maxTick;
    double dbMin = minTick;
    double dbScale = Math.abs(dbMax - dbMin);
    float h = boundingBox.getHeight();
    if (dbVal == NINF){
      return h;
    }
    
    double pos = dbVal / dbScale;
    return (float)pos * -h;
  }
  
  float dbToYPos(double dbVal, boolean withOffset){
    float result = dbToYPos(dbVal);
    if (withOffset){
      result += boundingBox.getY();
    }
    return result;
  }
  
  void render(PGraphics canvas){
    canvas.noFill();
    canvas.stroke(128);
    boundingBox.drawRect(canvas);
    for (int i=0; i<nTickContainers; i++){
      tickContainers[i].render(canvas);
    }
    for (int i=0; i<nChannels; i++){
      meterChannels[i].render(canvas);
    }
  }
  
  void processSamples(DevolayAudioFrame frame){
    int size = frame.getSamples();
    int stride = frame.getChannelStride();
    int nch = frame.getChannels();
    ByteBuffer data = frame.getData().order(ByteOrder.LITTLE_ENDIAN);
    double[] chPeaks = new double[nch];
    double[] chSums = new double[nch];
    for (int i=0; i<nch; i++){
      chPeaks[i] = 0;
      chSums[i] = 0;
    }
    
    for (int ch=0; ch<nch; ch++){
      for (int samp=0; samp<size; samp++){
        Float vf = data.getFloat();
        double v = vf.doubleValue();
        
        double vabs = Math.abs(v);
        if (vabs > chPeaks[ch]){
          chPeaks[ch] = vabs;
        }
        v *= .1;
        chSums[ch] += v * v;
      }
    }
    
    for (int ch=0; ch<nch; ch++){
      double vabs = chPeaks[ch] * .1;
      peakAmp[ch] = vabs;
      peakDbfs[ch] = 10 * Math.log10(vabs);
      peakDbu[ch] = peakDbfs[ch] + 24;
      double mag = Math.sqrt(chSums[ch] / size);
      if (mag == 0){
        rmsDbfs[ch] = NINF;
      } else {
        rmsDbfs[ch] = 10 * Math.log10(mag);
        rmsDbu[ch] = rmsDbfs[ch] + 24;
      }
      bufferLength[ch] = size;
    }
  }
}
    
class AudioMeterChannel {
  AudioMeter parent;
  Box boundingBox;
  int index;
  float greenStop = -12, yellowStart = -6, redStart = -1;
  color greenBg = 0xff008000, yellowBg = 0xff808000, redBg = 0xff800000;
  //color greenBg = color(0, 128, 0), yellowBg = color(128, 128, 0), redBg = color(128, 0, 0);
  PShape greenRect, yellowRect, redRect;
  PShape[] bgShapes;
  PImage[] bgImgs;
  color bgColors[] = {0xff00ff00, 0xffffff00, 0xffff0000};
  Box meterBox;
  Box greenBox, greenYellowBox, yellowRedBox;
  Box[] bgBoxes;
  AudioMeterChannel(AudioMeter _parent, int _index){
    parent = _parent;
    index = _index;
    boundingBox = new Box(0, 0, 10, 100);
    meterBox = boundingBox.copy();
    bgShapes = new PShape[3];
    bgImgs = new PImage[3];
    bgBoxes = new Box[3];
    buildImages();
    buildGradientBoxes();
    
    //Box b = new Box(0, 0, 20, 10);
    
  }
  
  
  
  void buildImages(){
    for (int i=0; i<bgImgs.length; i++){
      bgImgs[i] = new PImage(50, 100, ARGB);
    }
    PImage gImg = bgImgs[0], gyImg = bgImgs[1], yrImg = bgImgs[2];
    Arrays.fill(bgImgs[0].pixels, greenBg);
    Arrays.fill(bgImgs[1].pixels, yellowBg);
    Arrays.fill(bgImgs[2].pixels, redBg);
    fillVGradient(bgImgs[0], greenBg, greenBg);
    fillVGradient(bgImgs[1], yellowBg, greenBg);
    fillVGradient(bgImgs[2], redBg, yellowBg);
    //alphaGradient(bgImgs[0], 0, 1, 0, 1);
    //alphaGradient(bgImgs[1], 0, 1, 0, 1);
    //alphaGradient(bgImgs[2], 0, 1, 0, 1);
  }
  
  void alphaGradient(PImage img, float fromPos, float toPos, float fromValue, float toValue){
    int w = img.width, h = img.height;
    int fromPxl = int(fromPos * h),
        toPxl = int(round(toPos * h));
    if (toPxl > h){
      toPxl = h;
    }
    assert fromPxl < toPxl;
    float imgScale = toPxl - fromPxl,
          minV = Math.min(fromValue, toValue),
          maxV = Math.max(fromValue, toValue),
          valueScale = maxV - minV;
    //float valueScale = float(Math.max(fromValue, toValue)) / float(Math.min(fromValue, toValue));
    
    img.loadPixels();
    for (int y=fromPxl; y<toPxl; y++){
      int alpha = int(round((y - fromPxl) / imgScale * valueScale));
      alpha = (alpha & 0xff) << 24;
      for (int x=0; x<w; x++){
        int i = y * w + x;
        int colorValue = img.pixels[i];
        colorValue |= alpha;
        img.pixels[i] = colorValue;
      }
    }
    img.updatePixels();
  }
  
  void fillVGradient(PImage img, color c1, color c2) {
    //img.loadPixels();
    //int i = 0, w = img.width;
    int a1 = (c1 & 0xff000000) >> 24,
        a2 = (c2 & 0xff000000) >> 24,
        r1 = (c1 & 0xff0000)   >> 16,
        r2 = (c2 & 0xff0000)   >> 16,
        g1 = (c1 & 0xff00)     >>  8,
        g2 = (c2 & 0xff00)     >>  8,
        b1 = c1 & 0xff,
        b2 = c2 & 0xff;
    int w = img.width;
    float h = img.height;
    int i = 0;
    for (int y=0; y<(int)h; y++) {
      float inter = y / h;
      color c = mvApp.lerpColor(c1, c2, inter);
      //int a = int(lerp(a1, a2, inter)) >> 24,
      //    r = int(lerp(r1, r2, inter)) >> 16,
      //    g = int(lerp(g1, g2, inter)) >>  8,
      //    b = int(lerp(b1, b2, inter)) & 0xff;
      //color c = a | r | g | b;
      //println(y, inter, Integer.toHexString(c));
      for (int x=0; x<w; x++){
        i = y * w + x;
        img.pixels[i] = c;
        //i += i;
      }
    }
    assert i+1 == w*h;
    assert img.pixels.length == w*h;
    img.updatePixels();
  }
  
  void setBoundingBox(Box b){
    boundingBox = b.copy();
    meterBox = b.copy();
    try {
      buildGradientBoxes();
    } catch(Exception e){
      e.printStackTrace();
      throw(e);
    }
  }
  
  void buildGradientBoxes(){
    float bottomPos = dbToYPos(-90, true),
          greenPos = dbToYPos(greenStop, true), 
          yellowPos = dbToYPos(yellowStart, true), 
          redPos = dbToYPos(redStart, true),
          topPos = dbToYPos(0, true);
    //assert dbToYPos(0, true) == boundingBox.getY();
    //assert dbToYPos(-90, true) == boundingBox.getBottom();
    Box baseBox = boundingBox.copy();
    //baseBox.setPos(new Point(0, 0));
    
    greenBox = baseBox.copy();
    greenBox.setHeight(baseBox.getBottom() - greenPos);
    greenBox.setY(greenPos);
    bgBoxes[0] = greenBox;
    
    greenYellowBox = baseBox.copy();
    greenYellowBox.setHeight(greenPos - yellowPos);
    greenYellowBox.setBottom(greenPos);
    bgBoxes[1] = greenYellowBox;
    
    yellowRedBox = baseBox.copy();
    yellowRedBox.setHeight(yellowPos - topPos);
    yellowRedBox.setY(topPos);
    //yellowRedBox.setBottom(greenYellowBox.getY());
    //yellowRedBox.setY(baseBox.getY());
    bgBoxes[2] = yellowRedBox;
    
    ////for (int i=0; i<bgBoxes.length; i++){
    ////  Box bx = bgBoxes[i];
    ////  bgImgs[i].init(int(round(bx.getWidth())), int(round(bx.getHeight())), ARGB);
    ////}
    
    ////greenYellowBox = new Box(
    ////  baseBox.getX(), yellowPos, baseBox.getWidth(), greenPos - yellowPos
    ////);
    
    
    ////greenBox.setBottom(baseBox.getBottom());
    ////println("gr: ", greenBox.toStr());
    //greenRect = greenBox.buildRect(mvApp);
    //greenRect.setFill(greenBg);
    
    
    ////yellowRedBox.setY(baseBox.getY());
    ////println("yl: ", yellowRedBox.toStr());
    //redRect = yellowRedBox.buildRect(mvApp);
    //yellowRedBox.fillVGradient(bgImgs[2], redBg, yellowBg);
    ////redRect.setTexture(bgImgs[0]);
    ////redRect.setTexture(bgImgs[2]);
    //redRect.setFill(0);
    
    ////greenYellowBox = baseBox.copy();
    ////float gyHeight = boundingBox.getHeight() - greenRect.getHeight() - yellowRedBox.getHeight();
    ////greenYellowBox.setHeight(gyHeight);
    ////println("greenYellowBox.height: ", gyHeight);
    
    ////greenYellowBox.setBottom(greenBox.getY());
    ////println("gy: ", greenYellowBox.toStr());
    //yellowRect = greenYellowBox.buildRect(mvApp);
    //greenYellowBox.fillVGradient(bgImgs[1], greenBg, yellowBg);
    ////yellowRect.setTexture(bgImgs[0]);
    ////yellowRect.setTexture(bgImgs[1]);
    //yellowRect.setFill(yellowBg);
    
    //bgShapes[0] = greenRect;
    //bgShapes[1] = yellowRect;
    //bgShapes[2] = redRect;
    
    //Point offset = boundingBox.getPos();
    ////for (int i=0; i<bgBoxes.length; i++){
    ////  bgBoxes[i].translate(offset);
    ////}
  }
  
  float dbToYPos(double dbVal){
    return parent.dbToYPos(dbVal);
    //double dbMax = parent.maxTick;
    //double dbMin = parent.minTick;
    //double dbScale = Math.abs(dbMax - dbMin);
    //if (dbVal == NINF){
    //  return boundingBox.getBottom();
    //}
    //float h = boundingBox.getHeight();
    
    //double pos = dbVal / dbScale;
    //return (float)pos * -h;
  }
  
  float dbToYPos(double dbVal, boolean withOffset){
    return parent.dbToYPos(dbVal, withOffset);
    //float result = dbToYPos(dbVal);
    //if (withOffset){
    //  result += boundingBox.getY();
    //}
    //return result;
  }
  
  void render(PGraphics canvas){
    canvas.stroke(255);
    canvas.fill(0);
    //greenBox.drawRect(canvas);
    //greenYellowBox.drawRect(canvas);
    //yellowRedBox.drawRect(canvas);
    //canvas.noStroke();
    //canvas.fill(green);
    //greenBox.fill(canvas);
    //greenYellowBox.fillVGradient(canvas, green, yellow);
    //yellowRedBox.fillVGradient(canvas, yellow, green);
    for (int i=0; i<bgShapes.length; i++){
      //canvas.stroke(bgColors[i]);
      Box b = bgBoxes[i];
      //b.drawRect(canvas);
      PImage img = bgImgs[i];
      //b.drawImage(canvas, img);
      canvas.image(img, b.getX(), b.getY(), b.getWidth(), b.getHeight());
      //PShape s = bgShapes[i];
      //s.setStroke(255);
      //canvas.shape(s, b.getX(), b.getY());
      //canvas.shape(s, 0, 0);
    }
    //greenRect.draw(canvas);
    //yellowRect.draw(canvas);
    //redRect.draw(canvas);
    meterBox.setHeight(parent.dbToYPos(parent.rmsDbfs[index], false));
    //println(String.format("meterBox: %s, boundingBox: %s", meterBox.toStr(), boundingBox.toStr()));
    //println(String.format("mHeight=%s, mBottom=%s, bbBotom=%s", meterBox.getHeight(), meterBox.getBottom(), boundingBox.getBottom()));
    assert round(meterBox.getBottom()) <= round(boundingBox.getBottom());
    canvas.noStroke();
    canvas.fill(0xa0000000);
    meterBox.drawRect(canvas);
    
  }
}

class MeterTickContainer extends Box {
  AudioMeter meter;
  TickLabel[] tickLabels;
  color bgColor = 0x80000000;
  MeterTickContainer(AudioMeter _meter){
    super();
    meter = _meter;
    tickLabels = new TickLabel[meter.ticks.length];
    for (int i=0; i<tickLabels.length; i++){
      TickLabel t = new TickLabel(this, meter.ticks[i]);
      tickLabels[i] = t;
    }
    setPos(meter.boundingBox.getPos());
    setSize(meter.boundingBox.getSize());
  }
  
  void updateGeometry(){
    super.updateGeometry();
    for (int i=0; i<tickLabels.length; i++){
      tickLabels[i].calcTickPosition();
    }
  }
  
  void render(PGraphics canvas){
    canvas.noStroke();
    canvas.fill(bgColor);
    drawRect(canvas);
    for (int i=0; i<tickLabels.length; i++){
      tickLabels[i].render(canvas);
    }
  }
}

class TickLabel extends TextBox {
  MeterTickContainer parent;
  AudioMeter meter;
  float dbValue;
  float realTickPos;
  
  TickLabel(MeterTickContainer _parent, float _dbValue){
    super();
    parent = _parent;
    meter = parent.meter;
    dbValue = _dbValue;
    text = String.format("%d", int(dbValue));
    setTextSize(10);
    drawBackground = false;
    int v = CENTER;
    if (dbValue == meter.minTick){
      v = BOTTOM;
    } else if (dbValue == meter.maxTick){
      v = TOP;
    }
    setSize(new Point(parent.getWidth(), 10));
    setAlign(CENTER, v);
    calcTickPosition();
  }
  
  void calcTickPosition(){
    setWidth(parent.getWidth());
    setX(parent.getX());
    float yp = meter.dbToYPos(dbValue, true);
    realTickPos = yp;
    int _vAlign = getVAlign();
    if (_vAlign == CENTER){
      setVCenter(yp);
    } else if (_vAlign == BOTTOM){
      setBottom(yp);
    } else if (_vAlign == TOP){
      setY(yp);
    } else {
      throw new Error("Invalid valign");
    }
    setHCenter(parent.getHCenter());
  }
  
  void render(PGraphics canvas){
    super.render(canvas);
    //canvas.stroke(255);
    //float y = realTickPos;
    //canvas.line(getX(), y, getRight(), y);
  }
}
