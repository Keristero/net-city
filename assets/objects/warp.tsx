<?xml version="1.0" encoding="UTF-8"?>
<tileset version="1.9" tiledversion="1.9.2" name="warp" tilewidth="61" tileheight="32" tilecount="6" columns="6" objectalignment="top">
 <grid orientation="orthogonal" width="62" height="32"/>
 <image source="warp.png" width="366" height="32"/>
 <tile id="0">
  <objectgroup draworder="index" id="2">
   <object id="1" x="30" y="7">
    <polygon points="0,0 -16.5625,8.5 0,16.9375 16.4375,8.4375"/>
   </object>
  </objectgroup>
 </tile>
 <tile id="1">
  <objectgroup draworder="index" id="3">
   <object id="9" x="30" y="7">
    <polygon points="0,0 -16.5625,8.5 0,16.9375 16.4375,8.4375"/>
   </object>
  </objectgroup>
  <animation>
   <frame tileid="1" duration="100"/>
   <frame tileid="2" duration="100"/>
   <frame tileid="3" duration="100"/>
   <frame tileid="4" duration="100"/>
   <frame tileid="5" duration="100"/>
  </animation>
 </tile>
</tileset>
