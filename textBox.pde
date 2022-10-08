
class TextSettings extends Callbacks<TextSettings,String[]> {
  private int _hAlign = CENTER, _vAlign = CENTER, _size = 12;
  private color _color = 0xffffffff;

  TextSettings(){
    String[] t = {""};
    setCallbackArgType(t.getClass());
  }

  TextSettings(int h, int v, int s, color c){
    String[] t = {""};
    setCallbackArgType(t.getClass());
    _hAlign = h;
    _vAlign = v;
    _size = s;
    _color = c;
  }

  TextSettings copy(){
    return new TextSettings(_hAlign, _vAlign, _size, _color);
  }

  void _triggerCallback(String ... arg){
    triggerCallback(arg);
  }

  public int hAlign(){ return _hAlign; }
  public TextSettings hAlign(int v){
    if (_hAlign != v){
      _hAlign = v;
      _triggerCallback("halign");
    }
    return this;
  }

  public int vAlign(){ return _vAlign; }
  public TextSettings vAlign(int v){
    if (_vAlign != v){
      _vAlign = v;
      _triggerCallback("vAlign");
    }
    return this;
  }

  public int[] align(){
    int[] result = {_hAlign, _vAlign};
    return result;
  }
  public TextSettings align(int h){
    return hAlign(h);
  }

  public TextSettings align(int h, int v){
    //StringList props = new StringList();
    List<String> props = new ArrayList<String>();
    if (_hAlign != h){
      props.add("hAlign");
    }
    if (_vAlign != v){
      props.add("vAlign");
    }
    _hAlign = h;
    _vAlign = v;
    String[] arg = new String[props.size()];
    triggerCallback(props.toArray(arg));
    return this;
  }

  public int size(){ return _size; }
  public TextSettings size(int s){
    if (_size != s){
      _size = s;
      _triggerCallback("size");
    }
    return this;
  }

  public color fillColor() { return _color; }
  public TextSettings fillColor(color c){
    if (_color != c){
      _color = c;
      _triggerCallback("color");
    }
    return this;
  }

  public void render(PGraphics canvas, String txt, PFont font, Point pos){
    canvas.fill(_color);
    canvas.textFont(font);
    canvas.textSize(_size);
    canvas.textAlign(_hAlign, _vAlign);
    canvas.text(txt, pos.x, pos.y);
  }
}


class TextBox extends Box {
  public final TextSettings settings;
  private int bgColor;
  public String text;
  public boolean drawBackground = true;
  private Point textPos;
  private boolean textPosOverride;

  TextBox(){
    super();
    settings = new TextSettings();
    initDefaults();
  }

  TextBox(Point _pos, Point _size, String _text, int _hAlign, int _vAlign, int _textSize, int _bg, int _fg){
    super(_pos, _size);
    settings = new TextSettings();
    initDefaults();
    text = _text;
    settings.align(_hAlign, _vAlign);
    settings.size(_textSize);
    bgColor = _bg;
    settings.fillColor(_fg);
  }
  TextBox(Box _b, String _text, int _hAlign, int _vAlign, int _textSize, int _bg, int _fg){
    super(_b);
    settings = new TextSettings();
    initDefaults();
    text = _text;
    settings.align(_hAlign, _vAlign);
    settings.size(_textSize);
    bgColor = _bg;
    settings.fillColor(_fg);
  }

  TextBox(Box _b, String _text, TextSettings _settings, int _bg){
    super(_b);
    settings = _settings;
    initDefaults();
    text = _text;
    bgColor = _bg;
  }

  TextBox(Point _pos, Point _size) {
    super(_pos, _size);
    settings = new TextSettings();
    initDefaults();
  }
  TextBox(Point _pos, float w, float h){
    super(_pos, w, h);
    settings = new TextSettings();
    initDefaults();
  }
  TextBox(float x, float y, Point _size){
    super(x, y, _size);
    settings = new TextSettings();
    initDefaults();
  }

  void initDefaults(){
    textPosOverride = false;
    text = "";
    bgColor = 0x60303030;
    textPos = new Point(0, 0);
    updateGeometry();
    settings.registerCallback(this, "onTextSettingsChanged");
  }

  void onTextSettingsChanged(String ... props){
    List<String> propList = Arrays.asList(props);
    if (propList.size() == 0 || propList.contains("vAlign") || propList.contains("hAlign")){
      updateGeometry();
    }
  }

  TextBox copy(){
    Box b = new Box(this);
    return new TextBox(b, text, settings, bgColor);
  }

  int[] align() { return settings.align(); }
  void align(int _hAlign){ settings.align(_hAlign); }
  void align(int _hAlign, int _vAlign){ settings.align(_hAlign, _vAlign); }

  int hAlign(){ return settings.hAlign(); }
  void hAlign(int v){ settings.hAlign(v); }

  int vAlign(){ return settings.vAlign(); }
  void vAlign(int v){ settings.vAlign(v); }

  void textSize(int value){ settings.size(value); }
  int textSize(){ return settings.size(); }

  Point textPos(){ return textPos.copy(); }
  void textPos(Point p){ textPos(p.x, p.y); }
  void textPos(float x, float y){
    textPos.x = x;
    textPos.y = y;
    textPosOverride = true;
  }

  void setTextPosRelative(Point p){
    Point offset = getPos();
    textPos(p.x + offset.x, p.y + offset.y);
  }

  void updateGeometry(){
    super.updateGeometry();
    if (textPosOverride){
      return;
    }
    Point _textPos = new Point(-1, -1);
    int hAlign = settings.hAlign(),
        vAlign = settings.vAlign();
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
    if (drawBackground){
      canvas.fill(bgColor);
      canvas.stroke(128);
      canvas.rect(getX(), getY(), getWidth(), getHeight());
    }
    settings.render(canvas, text, mvApp.windowFont, textPos);
  }

  String toStr(){
    String s = super.toStr();
    return String.format("TextBox '%s': text='%s', textPos=%s, bgColor=%d, fgColor=%d", s, text, textPos.toStr(), bgColor, settings.fillColor());
  }
}
