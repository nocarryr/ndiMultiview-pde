import java.nio.ByteBuffer;
import java.nio.IntBuffer;

void videoFrameToImageArr_RGBA(DevolayVideoFrame videoFrame, int[] pixelArray){
  int frameWidth = videoFrame.getXResolution();
  int frameHeight = videoFrame.getYResolution();
  ByteBuffer framePixels = videoFrame.getData();
  IntBuffer framePixelsInt = framePixels.asIntBuffer();
  
  int numPixels = frameWidth * frameHeight;
  //int numBytes = numPixels * 4;
  //int pixelIndex = 0;
  
  for (int i=0; i<numPixels; i++){
    int colorValue = framePixelsInt.get();
    int alpha = colorValue & 0xff;
    colorValue = (colorValue >> 8) | alpha << 24;
    //int colorValue = 0;
    //int r, g, b, a;
     
    //r = (framePixels.get() & 0xff) << 16;
    //g = (framePixels.get() & 0xff) << 8;
    //b = (framePixels.get() & 0xff);
    //a = (framePixels.get() & 0xff) << 24;
    //colorValue = r | b | g | a;
    pixelArray[i] = colorValue;
  }
}

void videoFrameToImageArr_RGBX(DevolayVideoFrame videoFrame, int[] pixelArray){
  int frameWidth = videoFrame.getXResolution();
  int frameHeight = videoFrame.getYResolution();
  ByteBuffer framePixels = videoFrame.getData();
  IntBuffer framePixelsInt = framePixels.asIntBuffer();
  
  int numPixels = frameWidth * frameHeight;
  //int numBytes = numPixels * 4;
  //int pixelIndex = 0;
  int alphaMask = 0xff << 24;
  
  for (int i=0; i<numPixels; i++){
    //int colorValue = (framePixelsInt.get() >> 8) | alphaMask;
    
    //int r, g, b, a;
     
    //a = (framePixels.get() & 0xff) << 24;
    //r = (framePixels.get() & 0xff) << 16;
    //g = (framePixels.get() & 0xff) << 8;
    //b = (framePixels.get() & 0xff);
    
    //colorValue = r | b | g | a;
    pixelArray[i] = (framePixelsInt.get() >> 8) | alphaMask;
  }
}
