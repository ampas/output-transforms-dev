import "otdevLib";


/*
This CTL code is derivative of DCTL code written by Jed Smith that is licensed under an 
MIT license. 

Source is available at: <https://github.com/jedypod/rgbdrt>

The following copyright notice is pasted from the original code.
*/

/* 
Copyright 2022 Jedediah Smith

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/



const Chromaticities RGBDT_PRI = 
{
	{0.8590, 0.2640},
	{0.1370, 1.1200},
	{0.0850, -0.0960},
	{0.3127, 0.3290}
};

const float XYZ_2_RENDERING_PRI_MAT[4][4] = XYZtoRGB(RGBDT_PRI, 1.0);
const float RENDERING_PRI_2_XYZ_MAT[4][4] = RGBtoXYZ(RGBDT_PRI, 1.0);
const float AP0_2_RGBDT_PRI_MAT[4][4] = mult_f44_f44( AP0_2_XYZ_MAT, XYZ_2_RENDERING_PRI_MAT);

const float SAT = 0.9;

const float REC709_RGB2Y[3] = {0.212639005871510, 0.715168678767756, 0.0721923153607337};
const float DESAT_MAT[3][3] = calc_sat_adjust_matrix( SAT, REC709_RGB2Y);

const Chromaticities DISPLAY_PRI = REC709_PRI;
const float XYZ_2_DISPLAY_PRI_MAT[4][4] = XYZtoRGB(DISPLAY_PRI,1.0);




void main 
( 
  input varying float rIn,
  input varying float gIn,
  input varying float bIn,
  input varying float aIn,
  output varying float rOut,
  output varying float gOut,
  output varying float bOut,
  output varying float aOut,
  input varying float Lp = 100.
)
{

  // Put input variables into a 3-element array (ACES)
  float aces[3] = {rIn, gIn, bIn};

  // Convert from ACES RGB encoding to rgbDT
  float rgbDT[3] = mult_f3_f44( aces, AP0_2_RGBDT_PRI_MAT);

	  // Apply the tone scale
	  float rgbPost[3];
	  rgbPost[0] = tsm_mms_dc( rgbDT[0], Lp);
	  rgbPost[1] = tsm_mms_dc( rgbDT[1], Lp);
	  rgbPost[2] = tsm_mms_dc( rgbDT[2], Lp);
  
  // --- ODT ---
  // Convert from rendering primaries RGB encoding to display encoding primaries
  float XYZ[3] = mult_f3_f44( rgbPost, invert_f44(XYZ_2_RENDERING_PRI_MAT));

  // Apply CAT from ACES white point to assumed observer adapted white point
  XYZ = mult_f3_f33( XYZ, D60_2_D65_CAT);

  // CIE XYZ to display primaries
  float lin_displayRGB[3] = mult_f3_f44( XYZ, XYZ_2_DISPLAY_PRI_MAT);

  // Saturation
  lin_displayRGB = mult_f3_f33( lin_displayRGB, DESAT_MAT);

  // Inverse EOTF for display
  float out[3] = eotf( lin_displayRGB );

  // Assign display RGB to output variables (OCES)
  rOut = out[0];
  gOut = out[1];
  bOut = out[2];
  aOut = aIn;

}