//import java.util.Map;
//import static java.util.Map.entry;



class TextBox extends Box {
  private int hAlign, vAlign;
  private int bgColor, fgColor;
  public String text;
  private Point textPos;
  private boolean textPosOverride;
  private int textSize;
  
  TextBox(Point _pos, Point _size, String _text, int _hAlign, int _vAlign, int _textSize, int _bg, int _fg){
    super(_pos, _size);
    initDefaults();
    text = _text;
    hAlign = _hAlign;
    vAlign = _vAlign;
    textSize = _textSize;
    bgColor = _bg;
    fgColor = _fg;
    //updateGeometry();
  }
  TextBox(Box _b, String _text, int _hAlign, int _vAlign, int _textSize, int _bg, int _fg){
    super(_b);
    initDefaults();
    text = _text;
    hAlign = _hAlign;
    vAlign = _vAlign;
    textSize = _textSize;
    bgColor = _bg;
    fgColor = _fg;
    //updateGeometry();
  }
  
  TextBox(Point _pos, Point _size) {
    super(_pos, _size);
    initDefaults();
    //updateGeometry();
  }
  TextBox(Point _pos, float w, float h){
    super(_pos, w, h);
    initDefaults();
    //updateGeometry();
  }
  TextBox(float x, float y, Point _size){
    super(x, y, _size);
    initDefaults();
    //updateGeometry();
  }
  
  void initDefaults(){
    textPosOverride = false;
    text = "";
    hAlign = CENTER;
    vAlign = CENTER;
    bgColor = 0x60303030;
    fgColor = 255;
    textSize = 12;
    textPos = new Point(0, 0);
    updateGeometry();
  }
      
  
  //@Override
  TextBox copy(){
    Box b = new Box(this);
    return new TextBox(b, text, hAlign, vAlign, textSize, bgColor, fgColor);
  }
  
  void setAlign(int _hAlign){
    if (_hAlign == hAlign){
      return;
    }
    hAlign = _hAlign;
    updateGeometry();
  }
  
  void setAlign(int _hAlign, int _vAlign){
    if (_hAlign == hAlign && _vAlign == vAlign){
      return;
    }
    hAlign = _hAlign;
    vAlign = _vAlign;
    updateGeometry();
  }
  
  Point getTextPos(){
    return textPos.copy();
  }
  
  void setTextPos(Point p){
    setTextPos(p.x, p.y);
  }
  
  void setTextPos(float x, float y){
    textPos.x = x;
    textPos.y = y;
    textPosOverride = true;
  }
  
  void setTextPosRelative(Point p){
    Point offset = getPos();
    setTextPos(p.x + offset.x, p.y + offset.y);
  }
  
  void updateGeometry(){
    super.updateGeometry();
    if (textPosOverride){
      return;
    }
    Point _textPos = new Point(-1, -1);
    if (hAlign == LEFT){
      _textPos.x = getX();
    } else if (hAlign == CENTER){
      _textPos.x = getHCenter();
    } else if (hAlign == RIGHT){
      _textPos.x = getRight();
    }
    
    if (vAlign == TOP){
      _textPos.y = getY();
    } else if (vAlign == CENTER){
      _textPos.y = getVCenter();
    } else if (vAlign == BOTTOM){
      _textPos.y = getBottom();
    }
    textPos = _textPos;
  }
  
  void render(PGraphics canvas){
    canvas.fill(bgColor);
    //canvas.noStroke();
    canvas.stroke(128);
    canvas.rect(getX(), getY(), getWidth(), getHeight());
    canvas.fill(fgColor);
    canvas.textFont(mvApp.windowFont);
    canvas.textSize(textSize);
    canvas.textAlign(hAlign, vAlign);
    canvas.text(text, textPos.x, textPos.y);
  }
  
  String toStr(){
    String s = super.toStr();
    return String.format("TextBox '%s': text='%s', textPos=%s, bgColor=%d, fgColor=%d", s, text, textPos.toStr(), bgColor, fgColor);
  }
}
  
