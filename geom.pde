class Point {
  float x, y;
  Point(float _x, float _y){
    x = _x;
    y = _y;
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
   
  String toStr(){
    return String.format("(%f, %f)", x, y);
  }
}

class Box {
  Point pos, size;
  Box(float x, float y, float w, float h){
    pos = new Point(x, y);
    size = new Point(w, h);
    //updateGeometry();
  }
  Box(Point _pos, Point _size){
    pos = _pos;
    size = _size;
    //updateGeometry();
  }
  Box(Point _pos, float w, float h){
    pos = _pos;
    size = new Point(w, h);
    //updateGeometry();
  }
  Box(float x, float y, Point _size){
    pos = new Point(x, y);
    size = _size;
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
  
  Point getPos(){
    return pos.copy();
  }
  void setPos(Point p){
    pos.x = p.x;
    pos.y = p.y;
    updateGeometry();
  }
  
  Point getSize(){
    return size.copy();
  }
  void setSize(Point s){
    size.x = s.x;
    size.y = s.y;
    updateGeometry();
  }
  
  float getX(){
    return pos.x;
  }
  void setX(float x){
    pos.x = x;
    updateGeometry();
  }
  
  float getY(){
    return pos.y;
  }
  void setY(float y){
    pos.y = y;
    updateGeometry();
  }
  
  float getWidth(){
    return size.x;
  }
  void setWidth(float w){
    size.x = w;
    updateGeometry();
  }
  
  float getHeight(){
    return size.y;
  }
  void setHeight(float h){
    size.y = h;
    updateGeometry();
  }
  
  float getRight(){
    return pos.x + getWidth();
  }
  void setRight(float r){
    pos.x = r - getWidth();
    updateGeometry();
  }
  
  float getBottom(){
    return pos.y + getHeight();
  }
  void setBottom(float b){
    pos.y = b - getHeight();
    assert getBottom() == b;
    updateGeometry();
  }
  
  float getHCenter(){
    return pos.x + getWidth() / 2;
  }
  void setHCenter(float c){
    pos.x = c - getWidth() / 2;
    assert getHCenter() == c;
    updateGeometry();
  }
  
  float getVCenter(){
    return pos.y + getHeight() / 2;
  }
  void setVCenter(float c){
    pos.y = c - getHeight() / 2;
    updateGeometry();
  }
  
  Point getCenter(){
    return new Point(getHCenter(), getVCenter());
  }
  void setCenter(Point c){
    pos.x = c.x - getWidth() / 2;
    pos.y = c.y - getHeight() / 2;
    updateGeometry();
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
    updateGeometry();
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
  
  Point getBottomCenter(){
    return new Point(getHCenter(), getBottom());
  }
  void setBottomCenter(Point p){
    pos.x = p.x - getWidth() / 2;
    pos.y = p.y - getHeight();
    updateGeometry();
  }
  
  Point getBottomRight(){
    return new Point(getRight(), getBottom());
  }
  
  float getTotalArea(){
    return getWidth() * getHeight();
  }
  
  void updateGeometry(){ }
  
  String toStr(){
    return String.format("%s, %s", pos.toStr(), size.toStr());
  }
}
