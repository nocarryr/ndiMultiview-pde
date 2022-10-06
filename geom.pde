
class Point {
  float x, y;
  Point(float _x, float _y){
    x = _x;
    y = _y;
  }
  Point(Point other){
    x = other.x;
    y = other.y;
  }

  Point(JSONObject json){
    x = json.getFloat("x");
    y = json.getFloat("y");
  }

  JSONObject serialize(){
    JSONObject json = new JSONObject();
    json.setFloat("x", x);
    json.setFloat("y", y);
    return json;
  }

  Point copy(){
    return new Point(x, y);
  }

  void add(Point other){
    x += other.x;
    y += other.y;
  }

  void subtract(Point other){
    x -= other.x;
    y -= other.y;
  }

  boolean equals(Point other){
    return x == other.x && y == other.y;
  }

  String toStr(){
    return String.format("(%f, %f)", x, y);
  }
}

class Box {
  public final Point pos, size;
  private Callbacks callbacks;

  Box(){
    pos = new Point(0, 0);
    size = new Point(1, 1);
  }
  Box(float x, float y, float w, float h){
    pos = new Point(x, y);
    size = new Point(w, h);
    //updateGeometry();
  }
  Box(Point _pos, Point _size){
    pos = _pos.copy();
    size = _size.copy();
    //updateGeometry();
  }
  Box(Point _pos, float w, float h){
    pos = _pos.copy();
    size = new Point(w, h);
    //updateGeometry();
  }
  Box(float x, float y, Point _size){
    pos = new Point(x, y);
    size = _size.copy();
    //updateGeometry();
  }
  Box(Box _b){
    pos = _b.getPos();
    size = _b.getSize();
    //updateGeometry();
  }
  Box(JSONObject json){
    pos = new Point(json.getJSONObject("pos"));
    size = new Point(json.getJSONObject("size"));
  }

  JSONObject serialize(){
    JSONObject json = new JSONObject();
    json.setJSONObject("pos", pos.serialize());
    json.setJSONObject("size", size.serialize());
    return json;
  }

  Box copy(){
    return new Box(this);
  }

  void move(Point dxy){
    pos.add(dxy);
    //setPos(pos.add(dxy));
    updateGeometry("x", "y");
  }

  float getAspectRatioW(){
    return getHeight() / getWidth();
  }

  void setAspectRatioW(float ar){
    setWidth(getHeight() / ar);
  }

  float getAspectRatioH(){
    return getWidth() / getHeight();
  }

  void setAspectRatioH(float ar){
    setHeight(getWidth() / ar);
  }

  void translate(float dx, float dy){
    pos.x += dx;
    pos.y += dy;
    updateGeometry("x", "y");
  }

  void translate(Point p){
    translate(p.x, p.y);
  }

  void setBox(Box b){
    pos.x = b.pos.x;
    pos.y = b.pos.y;
    size.x = b.size.x;
    size.y = b.size.y;
    updateGeometry("x", "y", "w", "h");
  }

  Point getPos(){
    return pos.copy();
  }
  void setPos(Point p){
    pos.x = p.x;
    pos.y = p.y;
    updateGeometry("x", "y");
  }

  Point getSize(){
    return size.copy();
  }
  void setSize(Point s){
    size.x = s.x;
    size.y = s.y;
    updateGeometry("w", "h");
  }

  float getX(){
    return pos.x;
  }
  void setX(float x){
    pos.x = x;
    updateGeometry("x");
  }

  float getY(){
    return pos.y;
  }
  void setY(float y){
    pos.y = y;
    updateGeometry("y");
  }

  float getWidth(){
    return size.x;
  }
  void setWidth(float w){
    size.x = w;
    updateGeometry("w");
  }

  float getHeight(){
    return size.y;
  }
  void setHeight(float h){
    size.y = h;
    updateGeometry("h");
  }

  float getRight(){
    return pos.x + getWidth();
  }
  void setRight(float r){
    pos.x = r - getWidth();
    updateGeometry("x");
  }

  float getBottom(){
    return pos.y + getHeight();
  }
  void setBottom(float b){
    pos.y = b - getHeight();
    //assert getBottom() == b;
    updateGeometry("y");
  }

  float getHCenter(){
    return pos.x + getWidth() / 2;
  }
  void setHCenter(float c){
    pos.x = c - getWidth() / 2;
    //assert getHCenter() == c;
    updateGeometry("x");
  }

  float getVCenter(){
    return pos.y + getHeight() / 2;
  }
  void setVCenter(float c){
    pos.y = c - getHeight() / 2;
    updateGeometry("y");
  }

  Point getCenter(){
    return new Point(getHCenter(), getVCenter());
  }
  void setCenter(Point c){
    pos.x = c.x - getWidth() / 2;
    pos.y = c.y - getHeight() / 2;
    updateGeometry("x", "y");
  }

  Point getTopLeft(){
    return new Point(getX(), getY());
  }
  Point getTopCenter(){
    return new Point(getHCenter(), getY());
  }
  void setTopCenter(Point p){
    pos.x = p.x - getWidth() / 2;
    pos.y = p.y;
    updateGeometry("x", "y");
  }

  Point getTopRight(){
    return new Point(getRight(), getY());
  }
  Point getMiddleLeft(){
    return new Point(getX(), getVCenter());
  }
  Point getMiddleRight(){
    return new Point(getRight(), getVCenter());
  }
  Point getBottomLeft(){
    return new Point(getX(), getBottom());
  }
  void setBottomLeft(Point p){
    pos.x = p.x;
    pos.y = p.y - getHeight();
    updateGeometry("x", "y");
  }

  Point getBottomCenter(){
    return new Point(getHCenter(), getBottom());
  }
  void setBottomCenter(Point p){
    pos.x = p.x - getWidth() / 2;
    pos.y = p.y - getHeight();
    updateGeometry("x", "y");
  }

  Point getBottomRight(){
    return new Point(getRight(), getBottom());
  }

  float getTotalArea(){
    return getWidth() * getHeight();
  }

  void updateGeometry(){ }
  void updateGeometry(String ... props){
    updateGeometry();
    triggerCallback(props);
  }

  void drawRect(PGraphics canvas){
    canvas.rect(getX(), getY(), getWidth(), getHeight());
  }

  void drawImage(PGraphics canvas, PImage img){
    canvas.image(img, getX(), getY(), getWidth(), getHeight());
  }

  void fillRect(PShape canvas, color c){
    canvas.fill(c);
  }

  public void registerCallback(Callback callback){
    buildCallbacks();
    callbacks.registerCallback(callback);
  }

  public boolean registerCallback(Object obj, String methodName){
    buildCallbacks();
    return callbacks.registerCallback(obj, methodName);
  }

  public void triggerCallback(String ... arg){
    if (callbacks != null){
      callbacks.triggerCallback(this, arg);
    }
  }

  private void buildCallbacks(){
    if (callbacks == null){
      String[] s = {""};
      callbacks = new Callbacks<Box,List<String>>(s.getClass());
    }
  }

  String toStr(){
    return String.format("%s, %s", pos.toStr(), size.toStr());
  }
}
