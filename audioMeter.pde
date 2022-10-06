double NINF = Double.NEGATIVE_INFINITY;

class AudioMeter {
  double[] rmsDbfs, rmsDbu, rmsAmp, peakDbfs, peakDbu, peakAmp;
  int sampleRate, nChannels, blockSize, stride;
  float avgTime = .1;
  int[] bufferLength;
  float[] ticks = {0, -3, -6, -9, -12, -15, -18, -24, -30, -36, -40, -50, -60};
  float maxTick = 0;
  float minTick = -60;
  int nTickContainers;
  int maxChannels = 2;
  int channelOffset = 0;
  color bgColor = 0x80000000;
  DisplayBox box;
  Box[] channelBoxes;
  MeterTickContainer[] tickContainers;
  AudioMeterChannel[] meterChannels;
  AudioMeter(int fs, int nch, int _blockSize){
    box = new DisplayBox();
    box.bounds(0, 0, 26, 52);
    box.setPadding(3, 16);

    sampleRate = fs;
    nChannels = nch;
    blockSize = _blockSize;
    rmsDbfs = new double[nChannels];
    rmsDbu = new double[nChannels];
    rmsAmp = new double[nChannels];
    peakDbfs = new double[nChannels];
    peakDbu = new double[nChannels];
    peakAmp = new double[nChannels];
    bufferLength = new int[nChannels];

    tickContainers = new MeterTickContainer[int(maxChannels / 2)];
    meterChannels = new AudioMeterChannel[maxChannels];

    for (int i=0; i<nChannels; i++){
      rmsDbfs[i] = NINF;
      rmsDbu[i] = NINF;
      rmsAmp[i] = 0;
      peakDbfs[i] = NINF;
      peakDbu[i] = NINF;
      peakAmp[i] = 0;
      bufferLength[i] = 0;
    }

    nTickContainers = 0;
    int tickIdx = -1;
    for (int i=0; i<maxChannels; i++){
      if (i % 2 == 0){
        tickIdx += 1;
        MeterTickContainer tickContainer = new MeterTickContainer(this);
        tickContainers[tickIdx] = tickContainer;
        nTickContainers += 1;
      }
      meterChannels[i] = new AudioMeterChannel(this, i);
    }
    updateChildGeom();
  }

  void setBoundingBox(Box b){
    box.bounds(b);
    updateChildGeom();
  }

  void updateChildGeom(){
    Box content = box.content();
    float channelWidth = Math.min(40, content.getWidth() / maxChannels / 2.5);
    float tickWidth = content.getWidth() - channelWidth * maxChannels;

    for (int i=0; i<maxChannels; i++){
      content.setWidth(channelWidth);
      float tw = 0;
      if (i % 2 != 0){
        tw = tickWidth;
      }
      content.setX(channelWidth * i + tw + content.getX());
      meterChannels[i].setBoundingBox(content);
    }
    for (int i=0; i<nTickContainers; i++){
      AudioMeterChannel prevMc = meterChannels[floor(i / 2)];
      Box t = content.copy();
      t.setWidth(tickWidth);
      float p = (tickWidth - 20) / 2.;
      if (p <= 0){
        p = 0;
      }
      tickContainers[i].setHorizontalPadding(p);
      t.setX(prevMc.box.bounds().getRight());
      tickContainers[i].bounds(t);
    }
  }

  float dbToYPos(Box bounds, double dbVal){
    double dbMax = maxTick;
    double dbMin = minTick;
    double dbScale = Math.abs(dbMax - dbMin);
    float h = bounds.getHeight();
    if (dbVal == NINF){
      return h;
    }

    double pos = dbVal / dbScale;
    return (float)pos * -h;
  }

  float dbToYPos(Box bounds, double dbVal, boolean withOffset){
    float result = dbToYPos(bounds, dbVal);
    if (withOffset){
      result += bounds.getY();
    }
    return result;
  }

  void render(PGraphics canvas){
    canvas.fill(bgColor);
    canvas.stroke(128);
    box.bounds().drawRect(canvas);
    for (int i=0; i<nTickContainers; i++){
      tickContainers[i].render(canvas);
    }
    for (int i=0; i<maxChannels; i++){
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
      rmsAmp[ch] = mag;
      if (mag == 0){
        rmsDbfs[ch] = NINF;
        rmsDbu[ch] = NINF;
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
  DisplayBox box;
  int index;
  float greenStop = -12, yellowStart = -6, redStart = -1;
  color greenBg = 0xff00ff00, yellowBg = 0xffffff00, redBg = 0xffff0000;
  //color greenBg = color(0, 128, 0), yellowBg = color(128, 128, 0), redBg = color(128, 0, 0);
  PShape greenRect, yellowRect, redRect;
  PShape[] bgShapes;
  PImage[] bgImgs;
  color bgColors[] = {0xff00ff00, 0xffffff00, 0xffff0000};
  Box greenBox, greenYellowBox, yellowRedBox;
  Box[] bgBoxes;
  AudioMeterChannel(AudioMeter _parent, int _index){
    parent = _parent;
    index = _index;
    box = new DisplayBox();
    box.bounds(0, 0, 10, 100);
    bgShapes = new PShape[3];
    bgImgs = new PImage[3];
    bgBoxes = new Box[3];
    buildImages();
    buildGradientBoxes();
  }

  int channelIndex(){
    return index + parent.channelOffset;
  }

  void buildImages(){
    for (int i=0; i<bgImgs.length; i++){
      bgImgs[i] = new PImage(50, 100, ARGB);
    }
    Arrays.fill(bgImgs[0].pixels, greenBg);
    Arrays.fill(bgImgs[1].pixels, yellowBg);
    Arrays.fill(bgImgs[2].pixels, redBg);
    fillVGradient(bgImgs[0], greenBg, greenBg);
    fillVGradient(bgImgs[1], yellowBg, greenBg);
    fillVGradient(bgImgs[2], redBg, yellowBg);
  }

  void fillVGradient(PImage img, color c1, color c2) {
    int w = img.width;
    float h = img.height;
    int i = 0;
    for (int y=0; y<(int)h; y++) {
      float inter = y / h;
      color c = mvApp.lerpColor(c1, c2, inter);
      for (int x=0; x<w; x++){
        i = y * w + x;
        img.pixels[i] = c;
      }
    }
    assert i+1 == w*h;
    assert img.pixels.length == w*h;
    img.updatePixels();
  }

  void setBoundingBox(Box b){
    box.bounds(b);
    box.setHorizontalPadding(2);
    try {
      buildGradientBoxes();
    } catch(Exception e){
      e.printStackTrace();
      throw(e);
    }
  }

  void buildGradientBoxes(){
    float bottomPos = dbToYPos(parent.minTick, true),
          greenPos = dbToYPos(greenStop, true),
          yellowPos = dbToYPos(yellowStart, true),
          redPos = dbToYPos(redStart, true),
          topPos = dbToYPos(parent.maxTick, true);

    Box baseBox = box.content();
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
  }

  float dbToYPos(double dbVal){
    return parent.dbToYPos(box.content(), dbVal);
  }

  float dbToYPos(double dbVal, boolean withOffset){
    return parent.dbToYPos(box.content(), dbVal, withOffset);
  }

  void render(PGraphics canvas){
    canvas.stroke(255);
    canvas.fill(0);

    for (int i=0; i<bgShapes.length; i++){
      Box b = bgBoxes[i];
      canvas.image(bgImgs[i], b.getX(), b.getY(), b.getWidth(), b.getHeight());
    }

    int chIdx = channelIndex();

    // mask over the meter images making them dark above RMS level
    Box meterBox = box.content();
    meterBox.setHeight(dbToYPos(parent.rmsDbfs[chIdx], false));
    canvas.noStroke();
    canvas.fill(0xa0000000);
    meterBox.drawRect(canvas);

    double peakDbfs = parent.peakDbfs[chIdx];
    float peakY = dbToYPos(peakDbfs, true);
    color peakColor;
    if (peakDbfs <= greenStop){
      peakColor = greenBg;
    } else if (peakDbfs < redStart){
      peakColor = yellowBg;
    } else {
      peakColor = redBg;
    }
    float cx = box.content().getX(), cr = box.content().getRight();
    canvas.stroke(peakColor);
    canvas.line(cx, peakY, cr, peakY);
  }
}

class MeterTickContainer extends DisplayBox {
  AudioMeter meter;
  TickLabel[] tickLabels;
  color bgColor = 0x00000000;
  MeterTickContainer(AudioMeter _meter){
    super();
    meter = _meter;
    tickLabels = new TickLabel[meter.ticks.length];
    for (int i=0; i<tickLabels.length; i++){
      TickLabel t = new TickLabel(this, meter.ticks[i]);
      tickLabels[i] = t;
    }
    bounds(meter.box.content());
    setHorizontalPadding(6);
  }

  void updateGeometry(){
    super.updateGeometry();
    for (int i=0; i<tickLabels.length; i++){
      tickLabels[i].calcTickPosition();
    }
  }

  void render(PGraphics canvas){
    if (bgColor > 0){
      canvas.noStroke();
      canvas.fill(bgColor);
      content().drawRect(canvas);
    }
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
    text = String.format("%3d", int(dbValue));
    setTextSize(10);
    drawBackground = false;
    setSize(new Point(parent.content().getWidth(), 10));
    setAlign(CENTER, CENTER);
    calcTickPosition();
  }

  void calcTickPosition(){
    Box content = parent.content();
    setWidth(content.getWidth());
    setX(content.getX());
    float yp = meter.dbToYPos(content, dbValue, true);
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
    setHCenter(content.getHCenter());
  }

  void render(PGraphics canvas){
    super.render(canvas);
    //canvas.stroke(255);
    //float y = realTickPos;
    //canvas.line(getX(), y, getRight(), y);
  }
}
