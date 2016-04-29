import de.bezier.data.sql.*;
import controlP5.*;
import java.io.BufferedReader;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.ArrayList;

MySQL dbconnection;
ControlP5 cp5;
CheckBox checkbox;

// Define sizes of page's layout frames
final int borderSize = 50;
final int mapWidth = 640;
final int mapHeight = 360;
final int sliderWidth = 200;
final int smallSpace = 25;
final int verySmallSpace = 5;

boolean updateMap = true;
int maxMag = 6;
int minMag = 0;
int futureTime = 0;
float showNamed;
PGraphics starMap;

final String user     = "starApp_reader";
final String pass     = "starAppPassword";
final String database = "starmap";

void setup() {
  frameRate(30);
  size(mapWidth + sliderWidth + 2*borderSize, mapHeight + 2*borderSize);
  noStroke();
  connectDB();
  starMap = createGraphics(mapWidth, mapHeight);
  
  cp5 = new ControlP5(this);

  checkbox = cp5.addCheckBox("checkBox")
                .setPosition(mapWidth+borderSize+smallSpace, mapHeight*0.10)
                .setSize(20, 20)
                .setItemsPerRow(1)
                .setSpacingColumn(30)
                .setSpacingRow(20)
                .addItem("showNamed", 0)
                ;

  cp5.addSlider("maxMag")
   .setPosition(mapWidth+borderSize+smallSpace, mapHeight*0.20)
   .setSize(125,20)
   .setRange(0,15)
   .setNumberOfTickMarks(16)
   .setValue(6)
   ;
   
   cp5.addSlider("minMag")
   .setPosition(mapWidth+borderSize+smallSpace, mapHeight*0.30)
   .setSize(125,20)
   .setRange(0,15)
   .setNumberOfTickMarks(16)
   ;
   
  cp5.addSlider("futureTime")
   .setPosition(mapWidth+borderSize+smallSpace, mapHeight*0.40)
   .setSize(125,20)
   .setRange(0,10000)
   .setNumberOfTickMarks(11)
   ;
}

void controlEvent(ControlEvent theEvent) {
  if (theEvent.isFrom(checkbox)) {
    showNamed = (float)checkbox.getArrayValue()[0];
    updateMap = true;
  }
}

void drawCrosshairs() {
  if(mouseX > borderSize && mouseX < borderSize + mapWidth && 
     mouseY > borderSize && mouseY < borderSize + mapHeight) {
    float ra = 24. * (1. - (float(mouseX) - borderSize)/mapWidth);
    float dec = 180. * (0.5 - (float(mouseY) - borderSize) / mapHeight);
    String text = "  RA: " + round(100*ra)/100. + " h\nDec: " + (dec>0?"+":"") + round(10*dec)/10. + "°";
//    float textWidth = textWidth(text);
    float textWidth =  76.00;  // Hard-coding this for now.  TODO - fix this
    fill(0,20,50);
    noStroke();
    rect(borderSize+mapWidth+smallSpace, borderSize+mapHeight-0.5*smallSpace, 
         textWidth, 1.2*smallSpace);

    textAlign(LEFT);
    fill(255, 255, 255);
    text(text, borderSize+mapWidth+smallSpace, borderSize+mapHeight);
    
    stroke(0, 150, 30);
    line(mouseX, borderSize-verySmallSpace, mouseX, borderSize+mapHeight+verySmallSpace);
    stroke(170, 30, 30);
    line(borderSize-verySmallSpace, mouseY, borderSize+mapWidth+verySmallSpace, mouseY);
    
  }
}

void drawGridSpace() {
   // Draw map outline
  stroke(60,70,90);
  line(borderSize, borderSize, borderSize+mapWidth, borderSize);
  line(borderSize, borderSize, borderSize, borderSize+mapHeight);
  line(borderSize+mapWidth, borderSize, borderSize+mapWidth, borderSize+mapHeight);
  line(borderSize, borderSize+mapHeight, borderSize+mapWidth, borderSize+mapHeight);

  // Draw right ascension (vertical-lined) axes
  int numZones = 6;
  textAlign(CENTER);
  for (int i = 0; i <= numZones; i++) {
    int x = borderSize + (mapWidth * (numZones - i) / numZones);
    line(x, borderSize, x, borderSize+mapHeight);
    text(i * 24 / numZones + "h", x, borderSize*3/2 + mapHeight);
  }

  // Draw declination (horizontal-lined) axis
  for (int i = 0; i <= numZones; i++) {
    int y = borderSize + (mapHeight * (numZones - i) / numZones);
    line(borderSize, y, borderSize+mapWidth, y);
    int dec = ((2*i - numZones) * 90 / numZones);
    text((dec>0?"+":"") + dec + "°", borderSize/2, y);
  } 
}

void draw() {
  if (updateMap || (mousePressed && showNamed > 0.001)) {
    updateStarMap();
    updateMap = false;
  }

  // Clear canvas for drawing stars
  background(0,20,50);
  drawStars();
  drawGridSpace();  
  drawCrosshairs();
}

void maxMag(int mag){
  updateMap = true; 
  maxMag = mag;
}

void minMag(int mag){
  updateMap = true; 
  minMag = mag;
}

void futureTime(int time){
  updateMap = true; 
  futureTime = time;
}

void connectDB() {
  dbconnection = new MySQL( this, "", database, user, pass );
  if(!dbconnection.connect()) {
    println("Error: Unable to connect database.");
    exit();
  }
}

String getQuery(String table) {
    String query = "SELECT * FROM " + database + "." + table + " WHERE mag < " + maxMag + " and mag > " + minMag;
    if(showNamed > 0.001)
      query += " and proper != ' '";      
    return query;
}

void updateStarMap() {
  dbconnection.query(getQuery(showNamed > 0.001? "hygdata_v3_namedStars" : "hygdata_v3"));

  starMap.beginDraw();
  starMap.noStroke();
  starMap.fill(255, 255, 255);
  starMap.clear();
    
  String minStarName = "";
  float minDist2 = 0.03;
  float minRa = 0;
  float minDec = 0;
    
  while(dbconnection.next()){
//      float ra = dbconnection.getFloat("ra");
//      float dec = dbconnection.getFloat("dec");

    float starRa = dbconnection.getFloat("ra")
                + futureTime * (0.001/3600.)*dbconnection.getFloat("pmra");
    float starDec = dbconnection.getFloat("dec")
                + futureTime * (0.001/3600.)*dbconnection.getFloat("pmdec");

    starMap.ellipse(mapWidth * (1 - starRa / 24.), 
                    mapHeight * (0.5 - starDec/180.),
                    1., 1.);

    if(mousePressed && showNamed > 0.001) {
      float mouseRA = 24. * (1. - (float(mouseX) - borderSize)/mapWidth);
      float mouseDec = 180. * (0.5 - (float(mouseY) - borderSize) / mapHeight);
      float posX = cos(mouseDec*3.14/180)*cos(mouseRA*2*3.14/24);
      float posY = cos(mouseDec*3.14/180)*sin(mouseRA*2*3.14/24);
      float posZ = sin(mouseDec*3.14/180);

      float starX = cos(starDec*3.14/180)*cos(starRa*2*3.14/24);
      float starY = cos(starDec*3.14/180)*sin(starRa*2*3.14/24);
      float starZ = sin(starDec*3.14/180);
     
      float dist2 = sq(starX - posX) + sq(starY - posY) + sq(starZ - posZ);

      if(dist2 < minDist2) {
        minStarName = dbconnection.getString("proper");
        minDist2 = dist2;
        minRa = starRa;
        minDec = starDec;
      }      
    }
  }
  
  starMap.textAlign(LEFT);
  float textY = mapHeight * (0.5 - minDec/180.) - verySmallSpace;
  if(textY < smallSpace) {
    textY = mapHeight * (0.5 - minDec/180.) + verySmallSpace;
    starMap.textAlign(LEFT,TOP);
  }
  float textX = mapWidth * (1 - minRa / 24.) + verySmallSpace;
  if (textX + textWidth(minStarName) + verySmallSpace > mapWidth) {
    textX = mapWidth * (1 - minRa / 24.) - verySmallSpace;
    starMap.textAlign(RIGHT);
  }
  starMap.text(minStarName, textX, textY);
  
  starMap.endDraw();
}
  
void drawStars() {
  image(starMap, borderSize, borderSize);
}


