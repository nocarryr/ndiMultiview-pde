class Point {
  float x, y;
  Point(float _x, float _y){
    x = _x;
    y = _y;
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
  }
  Box(Point _pos, Point _size){
    pos = _pos;
    size = _size;
  }
  float getX(){
    return pos.x;
  }
  float getY(){
    return pos.y;
  }
  float getWidth(){
    return size.x;
  }
  float getHeight(){
    return size.y;
  }
  float getRight(){
    return pos.x + size.x;
  }
  void setRight(float r){
    size.x = r - pos.x;
  }
  float getBottom(){
    return pos.y + size.y;
  }
  void setBottom(float b){
    size.y = b - pos.y;
  }
  float getHCenter(){
    return pos.x + size.x / 2;
  }
  float getVCenter(){
    return pos.y + size.y / 2;
  }
  String toStr(){
    return String.format("%s, %s", pos.toStr(), size.toStr());
  }
}
