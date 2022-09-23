//import java.util.Map;
//import static java.util.Map.entry;



class TextBox extends Box {
  private int hAlign, vAlign;
  private int bgColor, fgColor;
  public String text;
  private Point textPos;
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
    text = "";
    hAlign = CENTER;
    vAlign = CENTER;
    bgColor = 0x60808080;
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
  
  void updateGeometry(){
    super.updateGeometry();
    //Point _textPos = new Point(0, 0);
    //switch (hAlign){
    //  case LEFT:
    //    _textPos.x = getX();
    //  case CENTER:
    //    _textPos.x = getHCenter();
    //  case RIGHT:
    //    _textPos.x = getRight();
    //}
    //switch (vAlign){
    //  case TOP:
    //    _textPos.y = getY();
    //  case CENTER:
    //    _textPos.y = getVCenter();
    //  case BOTTOM:
    //    _textPos.y = getBottom();
    //}
    //textPos = _textPos;
    textPos = getCenter();
    System.out.println(toStr());
  }
  
  void render(PGraphics canvas){
    canvas.fill(bgColor);
    //canvas.noStroke();
    canvas.stroke(128);
    canvas.rect(getX(), getY(), getWidth(), getHeight());
    canvas.fill(fgColor);
    canvas.textFont(windowFont);
    canvas.textSize(textSize);
    canvas.textAlign(hAlign, vAlign);
    canvas.text(text, textPos.x, textPos.y);
  }
  
  String toStr(){
    String s = super.toStr();
    return String.format("TextBox '%s': text='%s', textPos=%s, bgColor=%d, fgColor=%d", s, text, textPos.toStr(), bgColor, fgColor);
  }
}
  
