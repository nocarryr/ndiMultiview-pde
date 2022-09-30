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
  }
  
  void translate(Point p){
    translate(p.x, p.y);
  }
  
  void setBox(Box b){
    pos.x = b.pos.x;
    pos.y = b.pos.y;
    size.x = b.size.x;
    size.y = b.size.y;
    updateGeometry();
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
    //assert getBottom() == b;
    updateGeometry();
  }
  
  float getHCenter(){
    return pos.x + getWidth() / 2;
  }
  void setHCenter(float c){
    pos.x = c - getWidth() / 2;
    //assert getHCenter() == c;
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
  void setBottomLeft(Point p){
    pos.x = p.x;
    pos.y = p.y - getHeight();
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
  
  void drawRect(PGraphics canvas){
    canvas.rect(getX(), getY(), getWidth(), getHeight());
  }
  
  void drawImage(PGraphics canvas, PImage img){
    canvas.image(img, getX(), getY(), getWidth(), getHeight());
  }
  
  void fillRect(PShape canvas, color c){
    canvas.fill(c);
  }
  
  PImage fillVGradient(color c1, color c2){
    PImage img = new PImage(int(round(getWidth())), int(round(getHeight())), ARGB);
    fillVGradient(img, c1, c2);
    return img;
  }
  
  void fillVGradient(PShape shape, color c1, color c2){
    int w = int(round(getWidth())), h = int(round(getHeight()));
    PImage img = new PImage(w, h, ARGB);
    fillVGradient(img, c1, c2);
    shape.setTextureMode(IMAGE);
    shape.setTexture(img);
    String s = "{ ";
    for (int i=0; i<shape.getVertexCount(); i++){
      PVector vt = shape.getVertex(i);
      s = s + String.format("(vt: [%s, %s], u=%s, v=%s), ", vt.x, vt.y, shape.getTextureU(i), shape.getTextureV(i));
    }
    println(s+"}");
  }
  
  void fillVGradient(PImage img, color c1, color c2) {
    img.loadPixels();
    if (img.width != getWidth() || img.height != getHeight()){
      img.init((int)getWidth(), (int)getHeight(), ARGB);
    }
    int i = 0, w = img.width, h = img.height;
    for (int y=0; y<h; y++) {
      float inter = float(y) / float(h);
      color c = lerpColor(c1, c2, inter);
      for (int x=0; x<w; x++){
        img.pixels[i] = c;
        i += i;
      }
    }
    img.updatePixels();
  }
  
  PImage fillHGradient(color c1, color c2){
    PImage img = new PImage(int(round(getWidth())), int(round(getHeight())), ARGB);
    fillHGradient(img, c1, c2);
    return img;
  }
  
  void fillHGradient(PImage img, color c1, color c2) {
    int i = 0, w = img.width, h = img.height;
    for (int x=0; x<w; x++) {
      float inter = x / float(w);
      color c = lerpColor(c1, c2, inter);
      for (int y=0; y<h; y++) {
        i = y * w + x;
        img.pixels[i] = 0;
      }
      i += i;
    }
  }
  
  //void fillHGradient(PShape canvas, color c1, color c2){
  //  //int x = getX(), y = getY(), w = getWidth(), h = getHeight();
  //  float x = getX(), y = getY(), w = getWidth(), h = getHeight();
  //  //canvas.noFill();
  //  for (int i = int(round(x)); i <= x+w; i++) {
  //    float inter = map(i, x, x+w, 0, 1);
  //    color c = lerpColor(c1, c2, inter);
  //    canvas.stroke(c);
  //    canvas.line(i, y, i, y+h);
  //  }
  //}
  
  PShape buildRect(PApplet applet){
    //PShape rect = applet.createShape(RECT, getX(), getY(), getWidth(), getHeight());
    float x = pos.x, y = pos.y, w = size.x, h = size.y;
    //Box shapeBox = copy();
    //shapeBox.translate(-x, -y);
    PShape s = applet.createShape(RECT, 0, 0, w, h);
    //s.beginShape(RECT);
    ////s.vertex(-0.5, -0.5, 0, 0, 0);
    ////s.vertex(-0.5,  0.5, 0, 0, 1);
    ////s.vertex( 0.5,  0.5, 0, 1, 1);
    ////s.vertex( 0.5, -0.5, 0, 1, 0);
    //s.vertex(  x,   y, 0, 0);
    //s.vertex(  x, y+h, 0, y);
    //s.vertex(x+w, y+w, x, y);
    //s.vertex(x+w,   y, x, 0);
    //s.endShape();
    ////s.scale(getWidth(), getHeight());
    //s.translate(getX(), getY());
    return s;
  }
  
  String toStr(){
    return String.format("%s, %s", pos.toStr(), size.toStr());
  }
}
